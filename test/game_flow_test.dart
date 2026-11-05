import 'package:bus_jam/screens/home_screen.dart';
import 'package:bus_jam/game/bus_jam_game.dart';
import 'package:bus_jam/game/logic/game_model.dart';
import 'package:bus_jam/game/logic/level_generator.dart';
import 'package:bus_jam/game/render/sprite_bank.dart';
import 'package:bus_jam/models/booster_type.dart';
import 'package:bus_jam/services/ad_service.dart';
import 'package:bus_jam/services/progress_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Game ko thodi der chalne do (animations poori hon)
Future<void> run(WidgetTester tester, double seconds) async {
  final steps = (seconds / 0.05).round();
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

BusJamGame makeGame(
  int level, {
  void Function()? onWin,
  void Function()? onFail,
}) {
  return BusJamGame(
    level: LevelGenerator.generate(level),
    callbacks: GameCallbacks(
      onWin: onWin ?? () {},
      onFail: onFail ?? () {},
      onToast: (_) {},
      onVipUsed: () {},
      onLockedSlotTap: () {},
    ),
  );
}

void main() {
  setUp(() {
    AdService.enabled = false;
    SharedPreferences.setMockInitialValues({});
  });

  for (final levelNo in [1, 5, 23]) {
    testWidgets('Level $levelNo: hal karne wale order mein tap se jeet', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var won = false;
      var failed = false;
      final game = makeGame(
        levelNo,
        onWin: () => won = true,
        onFail: () => failed = true,
      );
      await tester.pumpWidget(GameWidget(game: game));
      await run(tester, 0.2);

      final order = List.of(game.level.buses)
        ..sort((a, b) => b.order.compareTo(a.order));
      for (final b in order) {
        // Agla slot khaali hone ka intezar (jaise asli player karega)
        for (var i = 0; i < 60 && game.model.freeSlot == null; i++) {
          await run(tester, 0.1);
        }
        await tester.tapAt(game.layout.busCenter(b));
        await run(tester, 0.3);
      }
      for (var i = 0; i < 100 && !won; i++) {
        await run(tester, 0.1);
      }
      expect(failed, isFalse);
      expect(won, isTrue);
      expect(game.model.isWon, isTrue);
    });
  }

  testWidgets('Tirchhi 3D tasveer: chhat par tap bhi sahi gaadi chunta hai', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(SpriteBank.instance.load);
    expect(SpriteBank.instance.hasVehicles, isTrue);
    var checked = 0;
    for (final level in [4, 8, 99]) {
      final game = makeGame(level);
      await tester.pumpWidget(GameWidget(key: UniqueKey(), game: game));
      await run(tester, 0.3);
      final l = game.layout;
      for (final b in game.model.grid) {
        // Aadi (horizontal) gaadiyan: inhi mein pehle chhat par tap chook jaata tha
        if ((b.fy).abs() > 0.3) continue;
        final c = l.busCenter(b);
        // Nazar aane wali chhat ka upar wala hissa: darmiyan se 0.62 cell upar.
        // Purana (sirf zameen wala) hit-test yahan chook jaata tha.
        final roof = c.translate(0, -l.cell * 0.62);
        final other = game.model.grid.any(
          (o) =>
              o.id != b.id && (l.busCenter(o) - roof).distance < l.cell * 0.6,
        );
        if (other) continue;
        expect(
          game.pickBus(roof)?.id,
          b.id,
          reason: 'level $level gaadi ${b.id}',
        );
        expect(game.pickBus(c)?.id, b.id);
        checked++;
      }
    }
    expect(checked, greaterThan(0));
  });

  testWidgets('Band bus par tap: bus apni jagah rehti hai', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = makeGame(31);
    await tester.pumpWidget(GameWidget(game: game));
    await run(tester, 0.2);
    final blocked = game.model.grid.where(game.model.isBlocked).first;
    final before = game.model.grid.length;
    await tester.tapAt(game.layout.busCenter(blocked));
    await run(tester, 0.5);
    expect(game.model.grid.length, before);
    expect(game.model.grid.contains(blocked), isTrue);
  });

  testWidgets('Ghalat order se slots bhar kar fail, phir continue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var failed = false;
    final game = makeGame(60, onFail: () => failed = true);
    await tester.pumpWidget(GameWidget(game: game));
    await run(tester, 0.2);

    // Helicopter se aisi buses uthao jin ka rang line ke pehle passenger se alag ho
    final front = game.model.frontColor!;
    final wrong = game.model.grid.where((b) => b.color != front).toList();
    for (var i = 0; i < 5; i++) {
      game.vipMode = true;
      await tester.tapAt(game.layout.busCenter(wrong[i]));
      await run(tester, 0.6);
    }
    await run(tester, 1.5);
    expect(failed, isTrue);
    expect(game.isEnded, isTrue);

    game.continueAfterFail();
    expect(game.model.slotCount, 6);
    expect(game.isEnded, isFalse);
    expect(
      game.model.slots.where((s) => s?.phase == SlotPhase.parked).length,
      5,
    );
  });

  testWidgets('Home se Play daba kar game screen khulti hai', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await ProgressService.instance.load();
    expect(ProgressService.instance.boosterCount(BoosterType.shuffle), 2);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await run(tester, 1);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);

    // Pause menu
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await run(tester, 0.5);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await run(tester, 0.5);
    expect(find.text('Settings'), findsNothing);
  });

  test('Progress save hota hai', () async {
    await ProgressService.instance.load();
    final p = ProgressService.instance;
    p.completeLevel(1, 25);
    expect(p.level, 2);
    p.useBooster(BoosterType.vip);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('level'), 2);
    expect(prefs.getInt('booster_vip'), 1);
  });
}
