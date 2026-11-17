import 'package:bus_jam/game/game_layout.dart';
import 'package:bus_jam/game/logic/game_model.dart';
import 'package:bus_jam/game/logic/geometry.dart';
import 'package:bus_jam/game/logic/level_generator.dart';
import 'package:bus_jam/game/logic/seeded_random.dart';
import 'package:bus_jam/game/logic/solver.dart';
import 'package:bus_jam/models/bus_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Levels 1-300: crash nahi, ginti barabar, solver hal kar leta hai', () {
    final failed = <int>[];
    final arrangements = <String>{};
    for (var level = 1; level <= 300; level++) {
      final data = LevelGenerator.generate(level);
      expect(
        arrangements.add(LevelGenerator.arrangementSignature(data.buses)),
        isTrue,
        reason: 'level $level ki arrangement pehle aa chuki hai',
      );

      // Passengers aur seats ki ginti barabar
      expect(
        data.passengers.length,
        data.buses.fold<int>(0, (s, b) => s + b.capacity),
        reason: 'level $level',
      );

      // Har 4-logon ki qataar ek hi rang ki ho (16, 24, 40 seats ke hisaab se)
      expect(data.passengers.length % 4, 0, reason: 'level $level');
      for (var i = 0; i < data.passengers.length; i += 4) {
        final c = data.passengers[i];
        expect(
          data.passengers.sublist(i, i + 4),
          [c, c, c, c],
          reason: 'level $level idx $i',
        );
      }

      // Har rang: passengers = us rang ki gaadiyon ki seats
      for (var c = 0; c < data.colorCount; c++) {
        final seats = data.buses
            .where((b) => b.color == c)
            .fold<int>(0, (s, b) => s + b.capacity);
        final people = data.passengers.where((p) => p == c).length;
        expect(people, seats, reason: 'level $level rang $c');
      }

      // Rang barabar taqseem
      final perColor = data.buses.length ~/ data.colorCount;
      for (var c = 0; c < data.colorCount; c++) {
        expect(
          data.buses.where((b) => b.color == c).length,
          perColor,
          reason: 'level $level',
        );
      }

      // Gaadiyan board ke andar hon aur ek doosre par na charhen
      final boxes = [for (final b in data.buses) Geo.busBox(b)];
      for (var i = 0; i < boxes.length; i++) {
        expect(
          boxes[i].insideBoard(data.cols, data.rows, pad: 0),
          isTrue,
          reason: 'level $level gaadi $i bahar hai',
        );
        for (var j = i + 1; j < boxes.length; j++) {
          expect(
            boxes[i].overlaps(boxes[j], margin: 0.21),
            isFalse,
            reason: 'level $level gaadi $i aur $j overlap',
          );
        }
      }

      if (!Solver.solveInOrder(data)) failed.add(level);
    }
    expect(failed, isEmpty, reason: 'Yeh levels hal nahi hue: $failed');
  });

  test('Levels 1-300: koi gaadi hamesha ke liye phansi hui nahi', () {
    for (var level = 1; level <= 300; level++) {
      final data = LevelGenerator.generate(level);
      final m = GameModel(data);
      // Hal karne wale order (rakhne ka ulta) mein har gaadi ka rasta
      // us waqt khula hona chahiye
      final order = List.of(m.grid)..sort((a, b) => b.order.compareTo(a.order));
      for (final b in order) {
        expect(
          m.isBlocked(b),
          isFalse,
          reason: 'level $level: gaadi ${b.id} kabhi nahi nikal sakti',
        );
        m.grid.remove(b);
      }
      expect(m.grid, isEmpty);
    }
  });

  test('Ek hi level hamesha ek jaisa banta hai', () {
    for (final level in [1, 7, 42, 150]) {
      final a = LevelGenerator.generate(level);
      final b = LevelGenerator.generate(level);
      expect(a.passengers, b.passengers);
      expect(
        a.buses.map((e) => '${e.cx},${e.cy},${e.angle},${e.color}').toList(),
        b.buses.map((e) => '${e.cx},${e.cy},${e.angle},${e.color}').toList(),
      );
    }
  });

  test('Mushkil dheere dheere badhti hai aur breather aasaan hai', () {
    final l1 = LevelGenerator.generate(1);
    final l2 = LevelGenerator.generate(2);
    final l50 = LevelGenerator.generate(50);
    expect(l1.buses.length, lessThanOrEqualTo(l2.buses.length));
    expect(l50.buses.length, greaterThan(l2.buses.length));
    expect(LevelGenerator.generate(20).isBreather, isTrue);
    expect(
      LevelGenerator.generate(20).buses.length,
      lessThan(LevelGenerator.generate(19).buses.length),
    );
  });

  group('GameModel', () {
    test(
      'Shuffle ke baad har rang ki seats wahi aur level hal ho sakta hai',
      () {
        Map<int, int> seatsPerColor(GameModel m) {
          final out = <int, int>{};
          for (final b in m.grid) {
            out[b.color] = (out[b.color] ?? 0) + b.capacity;
          }
          return out;
        }

        var solved = 0;
        const levels = [5, 25, 45, 77, 123];
        for (final level in levels) {
          final m = GameModel(LevelGenerator.generate(level));
          final before = seatsPerColor(m);
          expect(m.shuffleGridColors(SeededRandom(level)), isTrue);
          expect(seatsPerColor(m), before, reason: 'level $level');
          if (Solver.canSolve(m, nodeLimit: 20000)) solved++;
        }
        expect(solved, levels.length);
      },
    );

    test(
      'Shuffle arrangement har bar gaadiyon ki positions aur angles nayi banata hai, overlap aur deadlock ke baghair',
      () {
        List<String> layoutSignature(GameModel m) {
          final items = [
            for (final b in m.grid)
              '${b.cx.toStringAsFixed(2)},${b.cy.toStringAsFixed(2)},${b.angle.toStringAsFixed(2)},${b.length}',
          ]..sort();
          return items;
        }

        Map<int, int> seatsPerColor(GameModel m) {
          final out = <int, int>{};
          for (final b in m.grid) {
            out[b.color] = (out[b.color] ?? 0) + b.capacity;
          }
          return out;
        }

        const levels = [1, 5, 15, 25, 45, 77];
        for (final level in levels) {
          final m = GameModel(LevelGenerator.generate(level));
          final beforeSeats = seatsPerColor(m);
          final seen = <String>{layoutSignature(m).join('|')};

          for (var step = 1; step <= 3; step++) {
            expect(
              m.shuffleArrangement(SeededRandom(level * 101 + step)),
              isTrue,
              reason: 'level $level step $step',
            );
            expect(
              seatsPerColor(m),
              beforeSeats,
              reason: 'level $level step $step seats change ho gayin',
            );

            // Har bar nayi arrangement honi chahiye
            final sig = layoutSignature(m).join('|');
            expect(
              seen.add(sig),
              isTrue,
              reason: 'level $level step $step purani arrangement dohraayi gayi',
            );

            // Zero overlap & inside board
            final boxes = [for (final b in m.grid) Geo.busBox(b)];
            for (var i = 0; i < boxes.length; i++) {
              expect(
                boxes[i].insideBoard(m.cols, m.rows, pad: 0),
                isTrue,
                reason: 'level $level step $step gaadi $i bahar hai',
              );
              for (var j = i + 1; j < boxes.length; j++) {
                expect(
                  boxes[i].overlaps(boxes[j], margin: 0.21),
                  isFalse,
                  reason: 'level $level step $step gaadi $i aur $j overlap',
                );
              }
            }

            // Koi deadlock nahi aur level solvable hai
            expect(
              Solver.canSolve(m, nodeLimit: 20000),
              isTrue,
              reason: 'level $level step $step solvable nahi',
            );
          }
        }
      },
    );

    test('Band raste wali bus nahi nikalti, khuli wali nikalti hai', () {
      final data = LevelGenerator.generate(30);
      final m = GameModel(data);
      final blocked = m.grid.where(m.isBlocked).toList();
      if (blocked.isNotEmpty) {
        expect(m.launch(blocked.first.id).status, LaunchStatus.blocked);
      }
      final free = m.movableBuses().first;
      expect(m.launch(free.id).status, LaunchStatus.ok);
    });

    test('Saare slots bharne par noSlot aur phans jaane par isStuck', () {
      final data = LevelGenerator.generate(60);
      final m = GameModel(data);
      // Helicopter ki tarah buses utha kar slots bharo, aisi buses jo
      // pehle passenger ke rang ki na hon
      final front = m.frontColor!;
      final others = m.grid.where((b) => b.color != front).toList();
      for (var i = 0; i < m.normalSlotCount; i++) {
        final r = m.launch(others[i].id, ignoreBlock: true);
        expect(r.status, LaunchStatus.ok);
        m.arrive(r.slot);
      }
      final anyBus = m.grid.first;
      expect(
        m.launch(anyBus.id, ignoreBlock: true).status,
        LaunchStatus.noSlot,
      );
      expect(m.isStuck, isTrue);

      // Band slot kholne se phansi khatam
      final locked = m.lockedSlots;
      m.unlockSlot();
      expect(m.lockedSlots, locked - 1);
      expect(m.isStuck, isFalse);
    });

    test('VIP slot: aam chaal wahan nahi jaati, VIP booster jaata hai', () {
      final m = GameModel(LevelGenerator.generate(40));
      expect(m.hasVip, isTrue);
      expect(m.normalSlotCount, 4);
      // Aam chaal: kabhi slot 0 (VIP) nahi
      final free = m.movableBuses().first;
      expect(m.launch(free.id).slot, isNot(0));
      // VIP: band gaadi bhi, aur seedha slot 0
      final blocked = m.grid.firstWhere(m.isBlocked);
      final r = m.launch(blocked.id, ignoreBlock: true, useVip: true);
      expect(r.status, LaunchStatus.ok);
      expect(r.slot, 0);
    });

    test('Mushkil levels: HARD aur SUPER HARD', () {
      expect(LevelGenerator.generate(15).difficulty, 1);
      expect(LevelGenerator.generate(19).difficulty, 2);
      expect(LevelGenerator.generate(20).difficulty, 0);
    });

    test('Sort booster: baith sakne wale passengers aage aa jaate hain', () {
      final data = LevelGenerator.generate(40);
      final m = GameModel(data);
      final before = List<int>.of(m.queue)..sort();
      // Aisi gaadi slot mein lao jis ka rang pehle passenger se alag ho
      final front = m.frontColor!;
      final other = m.grid.firstWhere((b) => b.color != front);
      final r = m.launch(other.id, ignoreBlock: true);
      m.arrive(r.slot);
      expect(m.sortQueue(), isTrue);
      expect(m.frontColor, other.color);
      final after = List<int>.of(m.queue)..sort();
      expect(after, before);
    });

    test('Mukhtalif lambai ki gaadiyan aur seats', () {
      expect(capacityForLength(2), 16);
      expect(capacityForLength(3), 24);
      expect(capacityForLength(4), 40);
      final lengths = <int>{};
      for (var level = 20; level < 60; level++) {
        for (final b in LevelGenerator.generate(level).buses) {
          lengths.add(b.length);
          expect(b.capacity, capacityForLength(b.length));
        }
      }
      expect(lengths, containsAll([2, 3, 4]));
    });

    test(
      'Restart variants: wahi arrangement rehti hai, sirf rang shuffle hote hain aur har variant solvable hai',
      () {
        for (final level in [1, 2, 8, 10, 15, 45]) {
          final base = LevelGenerator.generate(level, variant: 0);
          final baseArr = LevelGenerator.arrangementSignature(base.buses);
          final seenColors = <String>{
            [for (final b in base.buses) '${b.id}:${b.color}'].join(','),
          };
          for (var variant = 1; variant <= 4; variant++) {
            final data = LevelGenerator.generate(level, variant: variant);
            expect(
              LevelGenerator.arrangementSignature(data.buses),
              baseArr,
              reason: 'level $level variant $variant par arrangement badal gayi',
            );
            expect(
              [for (final b in data.buses) b.order],
              [for (final b in base.buses) b.order],
            );
            final colorsSig =
                [for (final b in data.buses) '${b.id}:${b.color}'].join(',');
            expect(
              seenColors.add(colorsSig),
              isTrue,
              reason: 'level $level variant $variant rang shuffle nahi hue',
            );
            expect(
              Solver.solveInOrder(data),
              isTrue,
              reason: 'level $level variant $variant solvable nahi',
            );
          }
        }
      },
    );

    test(
      'Parking bay mein lambi bus ki chaurai aur count badge size chhote nahi hote',
      () {
        final l = GameLayout(
          width: 400,
          height: 800,
          cols: 11,
          rows: 11,
          slotPlaces: 8,
        );
        final u2 = l.slotUnitFor(2);
        final u3 = l.slotUnitFor(3);
        final u4 = l.slotUnitFor(4);
        expect(u3, u2);
        expect(u4, u2);
        expect(l.badgeUnit, greaterThanOrEqualTo(u2));
        final len2 = (2 - 0.12) * l.slotUnitFor(2) * l.slotLengthScale(2);
        final len3 = (3 - 0.12) * l.slotUnitFor(3) * l.slotLengthScale(3);
        final len4 = (4 - 0.12) * l.slotUnitFor(4) * l.slotLengthScale(4);
        expect(len3, greaterThan(len2 * 1.4));
        expect(len4, greaterThan(len3 * 1.25));
        for (final drawnLen in [len2, len3, len4]) {
          expect(drawnLen, lessThanOrEqualTo(l.bayH * 0.97 + 1e-6));
        }
      },
    );
  });
}
