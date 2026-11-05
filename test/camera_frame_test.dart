import 'package:bus_jam/game/game_layout.dart';
import 'package:bus_jam/game/logic/level_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Camera frame: board <-> screen ka hisaab wapis wahi aaye', () {
    for (final lvl in [1, 7, 45, 120]) {
      final level = LevelGenerator.generate(lvl);
      final content = GameLayout.contentOf(level.buses, level.cols, level.rows);
      // Frame grid ke andar aur har gaadi ko gher le
      expect(content.left, greaterThanOrEqualTo(0));
      expect(content.right, lessThanOrEqualTo(level.cols.toDouble()));
      for (final b in level.buses) {
        expect(content.contains(Offset(b.cx, b.cy)), isTrue);
      }
      final l = GameLayout(
        width: 400,
        height: 820,
        cols: level.cols,
        rows: level.rows,
        slotPlaces: 8,
        topInset: 60,
        passengers: level.passengers.length,
        content: content,
      );
      for (final b in level.buses) {
        final s = l.busCenter(b);
        final back = l.toBoard(s)!;
        expect(back.$1, closeTo(b.cx, 1e-6));
        expect(back.$2, closeTo(b.cy, 1e-6));
        // Gaadi screen ke andar (lot mein) dikhe
        expect(l.boardPanel.contains(s), isTrue);
      }
    }
  });
}
