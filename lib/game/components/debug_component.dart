import 'dart:ui';

import 'package:flame/components.dart';

import '../bus_jam_game.dart';
import '../logic/geometry.dart';

/// Sirf debug build: har gaadi ka tap-hitbox (hara: zameen, peela: chhat)
/// aur nikalne ka rasta (neela; laal agar rasta band ho) dikhata hai.
/// Game screen ke upar "bug" button se chalu/band hota hai.
class DebugHitboxComponent extends Component with HasGameReference<BusJamGame> {
  DebugHitboxComponent() : super(priority: 100);

  @override
  void render(Canvas canvas) {
    if (!game.showHitboxes) return;
    final l = game.layout;
    final m = game.model;
    Offset toScreen((double, double) p, {double lift = 0, double cy = 0}) {
      // Tasveer ki tarah: upar-neeche chapta, chhat [lift] upar
      final y = cy + (p.$2 - cy) * BusJamGame.squash - lift;
      return l.toScreen(p.$1, y);
    }

    void poly(List<Offset> pts, Paint paint) {
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, paint);
    }

    final ground = Paint()
      ..color = const Color(0xFF00C853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final roof = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final b in m.grid) {
      final slack = b.length <= 2 ? 0.22 : 0.14;
      final box = Geo.busBox(b, inflate: slack);
      poly([for (final c in box.corners) toScreen(c, cy: b.cy)], ground);
      poly([
        for (final c in box.corners)
          toScreen(c, cy: b.cy, lift: BusJamGame.roofLift),
      ], roof);
      final blocked = m.isBlocked(b);
      final path = Geo.pathBox(b, m.cols, m.rows);
      poly(
        [for (final c in path.corners) l.toScreen(c.$1, c.$2)],
        Paint()
          ..color = blocked ? const Color(0x66FF1744) : const Color(0x332979FF)
          ..style = PaintingStyle.fill,
      );
    }
  }
}
