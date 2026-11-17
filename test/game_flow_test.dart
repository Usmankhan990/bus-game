import 'package:bus_jam/screens/game_screen.dart';
import 'package:bus_jam/screens/home_screen.dart';
import 'package:bus_jam/game/bus_jam_game.dart';
import 'package:bus_jam/game/components/hit_effect_component.dart';
import 'package:bus_jam/game/components/slot_full_tip_component.dart';
import 'package:bus_jam/game/game_layout.dart';
import 'package:bus_jam/game/logic/game_model.dart';
import 'package:bus_jam/game/logic/geometry.dart';
import 'package:bus_jam/game/logic/level_generator.dart';
import 'package:bus_jam/game/render/sprite_bank.dart';
import 'package:bus_jam/models/booster_type.dart';
import 'package:bus_jam/services/ad_service.dart';
import 'package:bus_jam/services/progress_service.dart';
import 'package:bus_jam/widgets/level_badge.dart';
import 'package:bus_jam/widgets/level_banner.dart';
import 'package:bus_jam/widgets/overlays.dart';
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

Future<void> restartViaPause(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.pause_rounded));
  await run(tester, 0.4);
  await tester.tap(find.text('Restart'));
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
      await run(tester, 1.2);

      final order = List.of(game.level.buses)
        ..sort((a, b) => b.order.compareTo(a.order));
      for (final b in order) {
        // Agla slot khaali hone ka intezar (jaise asli player karega)
        for (var i = 0; i < 600 && game.model.freeSlot == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tapAt(game.layout.busCenter(b));
        await run(tester, 0.3);
      }
      for (var i = 0; i < 6000 && !won; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(failed, isFalse);
      expect(
        won,
        isTrue,
        reason:
            'level=$levelNo head=${game.model.head}/${game.model.queue.length} '
            'grid=${game.model.grid.length} views=${game.queueViews.length} '
            'slots=${game.model.slots.map((s) => s == null ? null : "${s.phase}:${s.filled}+${s.reserved}/${s.capacity}").toList()}',
      );
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
      await run(tester, 1.2);
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
    await run(tester, 1.2);
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
    await run(tester, 1.2);

    // Aisi buses jin ka rang queue mein na ho taa ke slots block hon aur fail trigger ho
    final wrong = game.model.grid.take(5).toList();
    for (final b in wrong) {
      b.color = 99;
    }
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

  testWidgets(
    'Slots full hon magar circle mein matching passenger ho to foran fail nahi hota, gate tak aane ka wait karta hai',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var failed = false;
      final game = makeGame(2, onFail: () => failed = true);
      await tester.pumpWidget(GameWidget(game: game));
      await run(tester, 1.2);

      // Circle ke passengers ke rang dhoondo
      final circleColors = game.queueViews
          .where((p) => p.inCircle)
          .map((p) => p.color)
          .toSet();
      expect(circleColors, isNotEmpty);

      // Gate se door wali station ka rang pakdo
      final matchingColor = circleColors.first;

      // 5 slots bharein: 4 dummy rang (jo queue mein na hon) aur 1 matching color
      final testBuses = game.model.grid.take(5).toList();
      testBuses[0].color = 91;
      testBuses[1].color = 92;
      testBuses[2].color = 93;
      testBuses[3].color = 94;
      testBuses[4].color = matchingColor;

      for (var i = 0; i < 5; i++) {
        game.vipMode = true;
        await tester.tapAt(game.layout.busCenter(testBuses[i]));
        await run(tester, 0.6);
      }

      // Saare normal slots bhar chuke hain
      expect(game.model.freeSlot, isNull);

      // Shuru mein foran fail nahi hona chahiye kyunke matching color circle mein hai
      await run(tester, 0.5);
      expect(failed, isFalse, reason: 'Circle mein matching passenger hone ke bawajood fail ho gaya');
      expect(game.isEnded, isFalse);
    },
  );

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

  testWidgets('Level 6: circle aur chutes ki har 4-4 row ek hi rang ki hai', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = makeGame(6);
    await tester.pumpWidget(GameWidget(game: game));
    await run(tester, 1.2);

    // Circle ki har 4-logon ki station mein ek hi rang ho
    final circleByStation = <int, Set<int>>{};
    final chuteColors = <int, Map<int, Set<int>>>{0: {}, 1: {}};
    for (final p in game.queueViews) {
      if (p.inCircle) {
        final st = p.circleSlot ~/ 4;
        circleByStation.putIfAbsent(st, () => {}).add(p.color);
      } else {
        final row = p.chuteRank ~/ 4;
        chuteColors[p.chuteIndex]!.putIfAbsent(row, () => {}).add(p.color);
      }
    }
    for (final e in circleByStation.entries) {
      expect(e.value.length, 1, reason: 'circle station ${e.key}');
    }
    for (final chute in chuteColors.entries) {
      for (final row in chute.value.entries) {
        expect(row.value.length, 1, reason: 'chute ${chute.key} row ${row.key}');
      }
    }

    // Kuch buses park karo aur chalte waqt har station poore 4-4 ek sath nikle (kabhi 2-2 adhi row na chhute)
    final movable = game.model.movableBuses();
    for (var i = 0; i < movable.length && i < 3; i++) {
      await tester.tapAt(game.layout.busCenter(movable[i]));
      await run(tester, 0.2);
    }
    for (var tick = 0; tick < 80; tick++) {
      await tester.pump(const Duration(milliseconds: 50));
      final counts = <int, int>{};
      final colors = <int, Set<int>>{};
      for (final p in game.queueViews) {
        if (!p.inCircle) continue;
        final st = p.circleSlot ~/ 4;
        counts[st] = (counts[st] ?? 0) + 1;
        colors.putIfAbsent(st, () => {}).add(p.color);
      }
      for (final e in counts.entries) {
        expect(e.value, 4, reason: 'tick $tick station ${e.key} split!');
        expect(colors[e.key]!.length, 1, reason: 'tick $tick station ${e.key} mixed!');
      }
    }
  });

  testWidgets('Har QueueShape variant sahi render aur board karta hai', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (var i = 0; i < QueueShape.values.length; i++) {
      final levelNum = i + 8;
      final expectedShape = QueueShape.values[i];
      final game = makeGame(levelNum);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await run(tester, 1.0);

      expect(game.layout.queueShape, expectedShape, reason: 'level $levelNum');
      expect(
        game.layout.queueRoadMetric.length,
        greaterThan(0),
        reason: '$expectedShape road metric',
      );
      expect(
        game.layout.queueFeetMetric.length,
        greaterThan(0),
        reason: '$expectedShape feet metric',
      );

      for (final p in game.queueViews) {
        expect(p.pos.dx.isNaN, isFalse, reason: '$expectedShape x NaN');
        expect(p.pos.dy.isNaN, isFalse, reason: '$expectedShape y NaN');
        expect(p.pos.dx, inInclusiveRange(-60, 472));
        if (p.inCircle) {
          expect(
            p.pos.dy,
            lessThanOrEqualTo(game.layout.roadTop + 8),
            reason: '$expectedShape circle passenger overflowed roadTop',
          );
        }
      }

      // Tez speed ke sath pehli 2 movable gaadiyan park karo aur crash na ho
      final movable = game.model.movableBuses();
      for (var m = 0; m < movable.length && m < 2; m++) {
        await tester.tapAt(game.layout.busCenter(movable[m]));
        await run(tester, 0.15);
      }
      await run(tester, 0.8);
    }
  });

  testWidgets('Restart karne par arena ka shape har bar change hota hai', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await run(tester, 0.6);

    final shapes = <QueueShape>[];
    for (var round = 0; round < 3; round++) {
      final gw = tester.widget<GameWidget<BusJamGame>>(
        find.byType(GameWidget<BusJamGame>),
      );
      shapes.add(gw.game!.layout.queueShape);
      if (round < 2) {
        await restartViaPause(tester);
        await run(tester, 0.6);
      }
    }

    expect(shapes[1], isNot(shapes[0]), reason: 'first restart repeated shape');
    expect(shapes[2], isNot(shapes[1]), reason: 'second restart repeated shape');
  });

  testWidgets(
    'Circle speed 0.70 hai aur boarding ke waqt bhi musalsal ghoomta hai',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final game = makeGame(1);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await run(tester, 1.2);

      final startFlow = game.queueFlow;
      await run(tester, 1.0);
      expect(game.queueFlow - startFlow, closeTo(0.70, 0.04));

      // Movable cars (pehle gate wale rang ki) park karo taa ke boarding shuru ho
      final picks = List.of(game.model.movableBuses())
        ..sort((a, b) {
          final ma = a.color == game.model.frontColor ? 0 : 1;
          final mb = b.color == game.model.frontColor ? 0 : 1;
          return ma.compareTo(mb);
        });
      for (final b in picks.take(4)) {
        await tester.tapAt(game.layout.busCenter(b));
        await run(tester, 0.15);
      }

      var keptMovingDuringWalk = false;
      for (var tick = 0; tick < 400; tick++) {
        final walkingBefore = game.model.slots.any(
          (s) => s != null && s.reserved > 0,
        );
        final prevFlow = game.queueFlow;
        await tester.pump(const Duration(milliseconds: 20));
        final walkingAfter = game.model.slots.any(
          (s) => s != null && s.reserved > 0,
        );
        if (walkingBefore && walkingAfter) {
          expect(game.queueFlow - prevFlow, closeTo(0.70 * 0.02, 0.002));
          keptMovingDuringWalk = true;
          break;
        }
      }

      expect(keptMovingDuringWalk, isTrue);
    },
  );

  testWidgets(
    'Khali jaga foran nahi bharti; pehle left dock phir left khatam hone par right dock se bharti hai',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var won = false;
      final game = makeGame(1, onWin: () => won = true);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await run(tester, 1.2);

      // Pehli baar gate se boarding par khali jaga circle mein rehti hai (foran fill nahi hoti)
      final order = List.of(game.level.buses)
        ..sort((a, b) => b.order.compareTo(a.order));
      for (final b in order.take(4)) {
        await tester.tapAt(game.layout.busCenter(b));
        await run(tester, 0.15);
      }
      var sawGapInCircle = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final inCircleCount = game.queueViews.where((p) => p.inCircle).length;
        if (game.model.head > 0 && inCircleCount < 104) {
          sawGapInCircle = true;
          break;
        }
      }
      expect(sawGapInCircle, isTrue);

      // Poori Level 1 chalao aur verify karo: jab tak left chute mein log hain,
      // right chute kabhi kam nahi hoti; left khatam hone ke baad hi right se fill hota hai
      var nextBus = 4;
      var prevRight = game.rightChuteCount;
      var rightFedAfterLeftEmpty = false;
      for (var step = 0; step < 3000 && !won; step++) {
        if (nextBus < order.length && game.model.freeSlot != null) {
          await tester.tapAt(game.layout.busCenter(order[nextBus++]));
        }
        await tester.pump(const Duration(milliseconds: 100));
        final curLeft = game.leftChuteCount;
        final curRight = game.rightChuteCount;
        if (curRight < prevRight) {
          expect(
            curLeft,
            0,
            reason: 'right chute ne left khatam hone se pehle fill kar diya!',
          );
          rightFedAfterLeftEmpty = true;
        }
        prevRight = curRight;
      }

      expect(won, isTrue);
      expect(rightFedAfterLeftEmpty, isTrue);
    },
  );

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

  testWidgets(
    'Level start par roads & circle khali hote hain, dono sides se log aur upar se gaadiyan aati hain',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final game = makeGame(1);
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump(const Duration(milliseconds: 20));

      expect(game.isIntroFinished, isFalse);
      expect(game.introSoundPlayed, isTrue);
      expect(game.carLandSoundCount, 0);
      expect(game.visibleQueueCount, 0);
      for (final bus in game.model.grid) {
        expect(game.busView(bus.id)?.isDropping, isTrue);
      }

      await run(tester, 0.35);
      expect(game.visibleQueueCount, greaterThan(0));
      final midX = game.size.x / 2;
      expect(
        game.queueViews.any((p) => p.isIntroVisible && p.pos.dx < midX),
        isTrue,
      );
      expect(
        game.queueViews.any((p) => p.isIntroVisible && p.pos.dx > midX),
        isTrue,
      );

      await run(tester, 1.2);
      expect(game.isIntroFinished, isTrue);
      expect(game.carLandSoundCount, inInclusiveRange(1, 6));
      for (final bus in game.model.grid) {
        expect(game.busView(bus.id)?.isDropping, isFalse);
      }
    },
  );

  testWidgets(
    'Blocked gaadi agay wali gaadi se hit hoti hai (hit effect + recoil) aur wapis apni jaga aati hai',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final game = makeGame(31);
      await tester.pumpWidget(GameWidget(game: game));
      await run(tester, 1.3);

      final blocked = game.model.grid.firstWhere(
        (b) => game.model.blockerOf(b) != null,
      );
      final blocker = game.model.blockerOf(blocked)!;
      final blockedView = game.busView(blocked.id)!;
      final blockerView = game.busView(blocker.id)!;
      final origPos = blockedView.pos;
      final blockerOrigPos = blockerView.pos;

      await tester.tapAt(game.layout.busCenter(blocked));
      await tester.pump(const Duration(milliseconds: 20));
      expect(blockedView.isBumping, isTrue);

      var sawHitEffect = false;
      var sawBlockerRecoil = false;
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (game.children.whereType<HitEffectComponent>().isNotEmpty) {
          sawHitEffect = true;
        }
        if (blockerView.isHitRecoiling) {
          sawBlockerRecoil = true;
        }
      }
      expect(sawHitEffect, isTrue);
      expect(sawBlockerRecoil, isTrue);

      await run(tester, 0.8);
      expect(game.model.grid.contains(blocked), isTrue);
      expect(blockedView.isBumping, isFalse);
      expect(blockerView.isHitRecoiling, isFalse);
      expect((blockedView.pos - origPos).distance, lessThan(0.5));
      expect((blockerView.pos - blockerOrigPos).distance, lessThan(0.5));
    },
  );

  testWidgets(
    'Shuffle karne par cars ki arrangement (positions/angles) har bar nayi hoti hai aur smooth glide karta hai',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final game = makeGame(15);
      await tester.pumpWidget(GameWidget(game: game));
      await run(tester, 1.3);

      String arrangementSig() {
        final list = [
          for (final b in game.model.grid)
            '${b.cx.toStringAsFixed(2)},${b.cy.toStringAsFixed(2)},${b.angle.toStringAsFixed(2)},${b.length}',
        ]..sort();
        return list.join('|');
      }

      final seen = <String>{arrangementSig()};
      for (var step = 1; step <= 3; step++) {
        expect(game.shuffleBuses(), isTrue, reason: 'shuffle step $step');
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          game.model.grid.any((b) => game.busView(b.id)?.isShuffling ?? false),
          isTrue,
        );

        await run(tester, 0.5);
        for (final b in game.model.grid) {
          final v = game.busView(b.id)!;
          expect(v.isShuffling, isFalse);
          expect((v.pos - game.layout.busCenter(b)).distance, lessThan(0.5));
        }
        expect(
          seen.add(arrangementSig()),
          isTrue,
          reason: 'Shuffle step $step mein arrangement change honi chahiye',
        );

        final boxes = [for (final b in game.model.grid) Geo.busBox(b)];
        for (var i = 0; i < boxes.length; i++) {
          for (var j = i + 1; j < boxes.length; j++) {
            expect(boxes[i].overlaps(boxes[j]), isFalse);
          }
        }
      }

      // GameScreen UI se Shuffle button daba kar bhi arrangement badalni chahiye
      await ProgressService.instance.load();
      final beforeCount = ProgressService.instance.boosterCount(
        BoosterType.shuffle,
      );
      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await run(tester, 1.3);
      await tester.tap(find.text('Shuffle'));
      await run(tester, 0.5);
      expect(
        ProgressService.instance.boosterCount(BoosterType.shuffle),
        beforeCount - 1,
      );
    },
  );

  testWidgets(
    'Restart karne par cars ki arrangement wahi rehti hai aur sirf rang har bar shuffle hote hain',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({'level': 8});
      await ProgressService.instance.load();

      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await run(tester, 1.3);

      BusJamGame currentGame() => tester
          .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
          .game!;

      String colorSig(BusJamGame g) =>
          [for (final b in g.level.buses) '${b.id}:${b.color}'].join(',');

      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(tester.getTopLeft(find.byType(LevelBadge)).dx, lessThanOrEqualTo(20));

      final baseArr = LevelGenerator.arrangementSignature(
        currentGame().level.buses,
      );
      final seenColors = <String>{colorSig(currentGame())};
      for (var r = 1; r <= 3; r++) {
        await restartViaPause(tester);
        await run(tester, 1.3);
        final g = currentGame();
        expect(
          LevelGenerator.arrangementSignature(g.level.buses),
          baseArr,
          reason: 'Restart #$r par arrangement change nahi honi chahiye',
        );
        expect(
          seenColors.add(colorSig(g)),
          isTrue,
          reason: 'Restart #$r par rang shuffle hone chahiye',
        );
      }
    },
  );

  testWidgets(
    'Slots full hone par message screen ke upar nahi balki tap ki gayi gaadi ke paas chhota bubble dikhta hai',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({'level': 15});
      await ProgressService.instance.load();

      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await run(tester, 1.3);

      final gw = tester.widget<GameWidget<BusJamGame>>(
        find.byType(GameWidget<BusJamGame>),
      );
      final g = gw.game!;
      // Asli player ki tarah 4 khuli gaadiyan tap kar ke saare normal slots bharo
      // (abhi woh slots ki taraf chal rahi hain / circle unka wait kar raha hai -> fail nahi)
      for (var i = 0; i < g.model.normalSlotCount; i++) {
        final next = g.model.movableBuses().first;
        await tester.tapAt(g.layout.busCenter(next));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(g.isEnded, isFalse);
      expect(g.model.freeSlot, isNull);

      // Pehli khuli gaadi par tap -> upar toast nahi, us gaadi ke paas chhota tip
      final movable = g.model.movableBuses();
      expect(movable.length, greaterThanOrEqualTo(2));
      final busA = movable.first;
      await tester.tapAt(g.layout.busCenter(busA));
      await run(tester, 0.15);

      expect(find.textContaining('All slots are full'), findsNothing);
      var tips = g.children.whereType<SlotFullTipComponent>().toList();
      expect(tips, hasLength(1));
      expect(
        (tips.first.targetPos - g.busView(busA.id)!.pos).distance,
        lessThan(1.0),
      );
      expect(
        tips.first.pillRect.top,
        greaterThanOrEqualTo(g.layout.boardPanel.top),
      );

      // Doosri gaadi par tap -> purana tip hat kar nayi gaadi ke paas aaye
      final busB = movable.last;
      await tester.tapAt(g.layout.busCenter(busB));
      await run(tester, 0.15);

      tips = g.children.whereType<SlotFullTipComponent>().toList();
      expect(tips, hasLength(1));
      expect(
        (tips.first.targetPos - g.busView(busB.id)!.pos).distance,
        lessThan(1.0),
      );
    },
  );

  testWidgets(
    'Win stars: clean solve par 3, aur revive / extra slot / 3+ blocked hits par stars kam hote hain',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Unit check: continueAfterFail slotsUnlocked ko double-count nahi karta
      final probe = makeGame(1);
      probe.unlockSlot();
      expect(probe.slotsUnlocked, 1);
      expect(probe.revivesUsed, 0);
      final probe2 = makeGame(1);
      probe2.continueAfterFail();
      expect(probe2.revivesUsed, 1);
      expect(probe2.slotsUnlocked, 0);

      Future<void> solveGameScreenLevel(BusJamGame g) async {
        final order = List.of(g.level.buses)
          ..sort((a, b) => b.order.compareTo(a.order));
        for (final b in order) {
          for (var i = 0; i < 600 && g.model.freeSlot == null; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.tapAt(g.layout.busCenter(b));
          await run(tester, 0.3);
        }
        for (var i = 0; i < 1200 && find.byType(WinOverlay).evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        // WinOverlay ki 650ms coin-flight timer complete hone do
        await run(tester, 1.0);
      }

      // Case 1: Clean win (1 blocked hit maaf -> 3 stars)
      SharedPreferences.setMockInitialValues({'level': 1});
      await ProgressService.instance.load();
      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await run(tester, 1.3);

      final g1 = tester
          .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
          .game!;
      final blocked = g1.model.grid.where(g1.model.isBlocked).toList();
      if (blocked.isNotEmpty) {
        await tester.tapAt(g1.layout.busCenter(blocked.first));
        await run(tester, 0.6);
        expect(g1.blockedHits, 1);
      }

      await solveGameScreenLevel(g1);
      expect(find.byType(WinOverlay), findsOneWidget);
      expect(tester.widget<WinOverlay>(find.byType(WinOverlay)).stars, 3);
      expect(ProgressService.instance.stars, 3);

      // Case 2: Fail revive (continueAfterFail) par 3 nahi balki 2 stars milein
      SharedPreferences.setMockInitialValues({'level': 1});
      await ProgressService.instance.load();
      await tester.pumpWidget(const MaterialApp(key: ValueKey('case2'), home: GameScreen()));
      await run(tester, 1.3);

      final g2 = tester
          .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
          .game!;
      g2.continueAfterFail();
      expect(g2.revivesUsed, 1);
      expect(g2.slotsUnlocked, 0);

      await solveGameScreenLevel(g2);
      expect(find.byType(WinOverlay), findsOneWidget);
      expect(tester.widget<WinOverlay>(find.byType(WinOverlay)).stars, 2);
      expect(ProgressService.instance.stars, 2);

      // Case 3: Extra slot unlock + 3 blocked hits -> 1 star
      SharedPreferences.setMockInitialValues({'level': 1});
      await ProgressService.instance.load();
      await tester.pumpWidget(const MaterialApp(key: ValueKey('case3'), home: GameScreen()));
      await run(tester, 1.3);

      final g3 = tester
          .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
          .game!;
      g3.unlockSlot();
      expect(g3.slotsUnlocked, 1);
      final blocked3 = g3.model.grid.where(g3.model.isBlocked).toList();
      expect(blocked3, isNotEmpty);
      for (var k = 0; k < 3; k++) {
        await tester.tapAt(g3.layout.busCenter(blocked3.first));
        await run(tester, 0.6);
      }
      expect(g3.blockedHits, 3);

      await solveGameScreenLevel(g3);
      expect(find.byType(WinOverlay), findsOneWidget);
      expect(tester.widget<WinOverlay>(find.byType(WinOverlay)).stars, 1);
      expect(ProgressService.instance.stars, 1);
    },
  );

  testWidgets(
    'Hard level: slots full hon ya toast aaye to HARD banner dobara show nahi hota',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Level 5 HARD hai (difficulty == 1)
      SharedPreferences.setMockInitialValues({'level': 5});
      await ProgressService.instance.load();

      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await run(tester, 0.3);
      expect(find.byType(LevelBanner), findsOneWidget);
      expect(find.text('HARD'), findsOneWidget);

      // Banner chalte waqt toast aane par LevelBanner ki State reset na ho
      final bannerStateBefore = tester.state(find.byType(LevelBanner));
      await tester.tap(find.text('Sort'));
      await run(tester, 0.2);
      expect(find.text('Park a vehicle first, then sort'), findsOneWidget);
      expect(tester.state(find.byType(LevelBanner)), same(bannerStateBefore));

      // 1.8s intro banner khatam hone ke baad widget tree se hat jaye
      await run(tester, 2.0);
      expect(find.byType(LevelBanner), findsNothing);

      final g = tester
          .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
          .game!;
      for (var i = 0; i < g.model.normalSlotCount; i++) {
        final next = g.model.movableBuses().first;
        await tester.tapAt(g.layout.busCenter(next));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(g.model.freeSlot, isNull);

      // Slots full par car tap -> sirf chhota tip aaye, HARD banner nahi
      final extra = g.model.movableBuses().first;
      await tester.tapAt(g.layout.busCenter(extra));
      await run(tester, 0.2);
      expect(g.children.whereType<SlotFullTipComponent>(), hasLength(1));
      expect(find.byType(LevelBanner), findsNothing);

      // Slots full par VIP daba kar toast dikhne par bhi HARD banner replay na ho
      await tester.tap(find.text('VIP'));
      await run(tester, 0.2);
      expect(find.text('Tap any vehicle to send it to VIP'), findsOneWidget);
      expect(find.byType(LevelBanner), findsNothing);
      await tester.tap(find.text('VIP'));
      await run(tester, 1.7);
      expect(find.byType(LevelBanner), findsNothing);
    },
  );

  testWidgets(
    'HomeScreen redesign: top HUD stars pill, city passport card, floating events aur bottom dock kaam karte hain',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({'level': 15, 'coins': 320, 'stars': 19});
      await ProgressService.instance.load();

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await run(tester, 0.3);

      // Top HUD, City Passport Card, Event Pods aur Bottom Dock sab dikhai dein
      expect(find.text('320'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('Karachi'), findsOneWidget);
      expect(find.text('15/20'), findsOneWidget);
      expect(find.text('LEVEL 15'), findsOneWidget);
      expect(find.text('Daily Bonus'), findsOneWidget);
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Supplies'), findsOneWidget);
      expect(find.text('Spin'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Garage'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('No Ads'), findsOneWidget);

      // Bottom Dock: Shop tab dabane par Shop popup khule
      await tester.tap(find.text('Shop'));
      await run(tester, 0.4);
      expect(find.text('Boosters'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await run(tester, 0.4);

      // Top Star pill dabane par Garage popup khule
      await tester.tap(find.text('19'));
      await run(tester, 0.4);
      expect(find.text('Win levels to earn stars and unlock new rides!'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await run(tester, 0.4);
    },
  );
}
