// Asli phone/emulator par poori game ka test.
// Chalane ka tareeqa (emulator ya phone juda ho):
//   flutter test integration_test/app_test.dart
import 'package:bus_jam/game/render/sprite_bank.dart';
import 'package:bus_jam/screens/home_screen.dart';
import 'package:bus_jam/game/bus_jam_game.dart';
import 'package:bus_jam/models/booster_type.dart';
import 'package:bus_jam/models/bus_data.dart';
import 'package:bus_jam/services/ad_service.dart';
import 'package:bus_jam/services/audio_service.dart';
import 'package:bus_jam/services/progress_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asli waqt mein [seconds] tak app chalne do
Future<void> wait(WidgetTester t, double seconds) async {
  final steps = (seconds / 0.05).ceil();
  for (var i = 0; i < steps; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Jab tak [cond] sach na ho intezar (zyada se zyada [max] second)
Future<bool> waitFor(
  WidgetTester t,
  bool Function() cond, {
  double max = 30,
}) async {
  for (var i = 0; i < max / 0.1; i++) {
    if (cond()) return true;
    await wait(t, 0.1);
  }
  return cond();
}

/// Save data saaf karke diye gaye level par app kholo aur Play dabao
Future<BusJamGame> openLevel(WidgetTester t, int level) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setInt('level', level);
  await ProgressService.instance.load();
  await t.pumpWidget(MaterialApp(key: UniqueKey(), home: const HomeScreen()));
  await wait(t, 1.0);
  expect(find.text('LEVEL $level'), findsOneWidget);
  await t.tap(find.text('Play'));
  await wait(t, 1.5);
  expect(find.text('Level $level'), findsOneWidget);
  return t
      .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
      .game!;
}

Offset origin(WidgetTester t) =>
    t.getTopLeft(find.byType(GameWidget<BusJamGame>));

Future<void> tapBus(WidgetTester t, BusJamGame g, BusData b) async {
  await t.tapAt(origin(t) + g.layout.busCenter(b));
  await wait(t, 0.25);
}

/// Level ko "hal karne wale order" mein taps se khelo jab tak jeet na jaye
Future<void> solveLevel(WidgetTester t, BusJamGame g) async {
  final order = List.of(g.level.buses)
    ..sort((a, b) => b.order.compareTo(a.order));
  for (final plan in order) {
    final bus = g.model.busById(plan.id);
    if (bus == null) continue;
    final freed = await waitFor(t, () => g.model.freeSlot != null);
    expect(
      freed,
      isTrue,
      reason: 'slot khaali nahi hua (level ${g.level.level})',
    );
    await tapBus(t, g, bus);
    expect(
      g.model.busById(plan.id),
      isNull,
      reason: 'gaadi ${plan.id} tap se nahi nikli (level ${g.level.level})',
    );
  }
  final won = await waitFor(
    t,
    () => find.text('Level Complete!').evaluate().isNotEmpty,
    max: 60,
  );
  expect(won, isTrue, reason: 'level ${g.level.level} jeeta nahi gaya');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    AdService.enabled = false;
    // Asli awaazen bhi chalein (crash na ho)
    await AudioService.instance.init();
    await SpriteBank.instance.load();
  });

  testWidgets('Har qisam ke design wale levels shuru se aakhir tak', (t) async {
    // 1-5 grid, 7 diagonal, 26 swirl, 28 fan, 41 burst (10x13), 99 rings
    for (final level in [1, 3, 7, 26, 28, 41, 99]) {
      final g = await openLevel(t, level);
      final sw = Stopwatch()..start();
      await solveLevel(t, g);
      // Awaazon ya animations ke players jama na hon (purana leak)
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        lessThan(30),
        reason: 'frame callbacks jama ho rahe hain (level $level)',
      );
      // ignore: avoid_print
      print(
        'LEVEL $level OK (${g.level.buses.length} gaadiyan, '
        '${sw.elapsed.inSeconds}s)',
      );
    }
  });

  testWidgets('Jeetne par agla level aur progress save', (t) async {
    final g = await openLevel(t, 1);
    await solveLevel(t, g);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('level'), 2);
    expect(prefs.getInt('coins'), greaterThan(100));
    await t.tap(find.text('Next Level'));
    await wait(t, 1.5);
    expect(find.text('Level 2'), findsOneWidget);
  });

  testWidgets('Takrana, boosters, + slot, pause aur restart', (t) async {
    final g = await openLevel(t, 31);
    final total = g.model.grid.length;

    // Band gaadi par tap: takra kar wapis, apni jagah rehti hai
    final blocked = g.model.grid.firstWhere(g.model.isBlocked);
    await tapBus(t, g, blocked);
    await wait(t, 1.0);
    expect(g.model.busById(blocked.id), isNotNull);
    expect(g.model.slots.every((s) => s == null), isTrue);

    // VIP: band gaadi bhi utha kar slot mein
    await t.tap(find.text('VIP'));
    await wait(t, 0.5);
    await tapBus(t, g, blocked);
    await wait(t, 2.0);
    expect(g.model.busById(blocked.id), isNull);
    expect(ProgressService.instance.boosterCount(BoosterType.vip), 1);

    // Shuffle: har rang ki seats wahi rahen
    Map<int, int> seats() {
      final m = <int, int>{};
      for (final b in g.model.grid) {
        m[b.color] = (m[b.color] ?? 0) + b.capacity;
      }
      return m;
    }

    final before = seats();
    await t.tap(find.text('Shuffle'));
    await wait(t, 1.0);
    expect(ProgressService.instance.boosterCount(BoosterType.shuffle), 1);
    expect(seats(), before);

    // Sort: crash na ho (kuch badle ya "Park a vehicle first" paigham)
    await t.tap(find.text('Sort'));
    await wait(t, 1.0);

    // Band "+" slot par tap: dialog khule, Close se band
    await t.tapAt(origin(t) + g.layout.slotCenters[g.model.slotCount]);
    await wait(t, 1.0);
    expect(find.text('Extra Slot'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close_rounded));
    await wait(t, 1.0);
    expect(find.text('Extra Slot'), findsNothing);

    // Pause aur Resume
    await t.tap(find.byIcon(Icons.pause_rounded));
    await wait(t, 0.8);
    expect(find.text('Settings'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close_rounded));
    await wait(t, 0.8);
    expect(find.text('Settings'), findsNothing);

    // Restart: saari gaadiyan wapis
    await t.tap(find.byIcon(Icons.refresh_rounded));
    await wait(t, 1.5);
    final g2 = t
        .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
        .game!;
    expect(g2.model.grid.length, total);
  });

  testWidgets('Slots bhar kar fail, phir Retry', (t) async {
    final g = await openLevel(t, 60);
    final front = g.model.frontColor!;
    final wrong = g.model.grid.where((b) => b.color != front).toList();
    for (var i = 0; i < 5; i++) {
      g.vipMode = true;
      await tapBus(t, g, wrong[i]);
      await wait(t, 1.0);
    }
    final failed = await waitFor(
      t,
      () => find.text('Out of Space!').evaluate().isNotEmpty,
      max: 20,
    );
    expect(failed, isTrue);
    await t.tap(find.text('Retry'));
    await wait(t, 1.5);
    expect(find.text('Out of Space!'), findsNothing);
  });
}
