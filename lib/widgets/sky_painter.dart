import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Aasman: neela gradient, chalte baadal, aur (chahein to) dhuaan chhodta jahaz.
/// [t] 0..1 animation ka waqt.
class SkyPainter extends CustomPainter {
  SkyPainter(this.t, {this.plane = false});

  final double t;
  final bool plane;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5AA9F0), Color(0xFFA9D8FF)],
        ).createShader(r),
    );

    // Baadal: alag alag raftaar se daayen taraf
    const clouds = [
      // Upar baayen kone mein baadal nahi (wahan coins ki pill hai)
      (0.55, 0.22, 0.8, 0.030),
      (0.25, 0.42, 1.2, 0.015),
      (0.80, 0.55, 0.7, 0.025),
      (0.40, 0.72, 1.1, 0.018),
      (0.05, 0.86, 0.9, 0.022),
    ];
    for (final (x, y, s, speed) in clouds) {
      final cx = ((x + t * speed * 10) % 1.3 - 0.15) * size.width;
      _cloud(canvas, Offset(cx, y * size.height), size.width * 0.13 * s);
    }

    if (plane) {
      final px = size.width * (1.1 - (t * 1.4) % 1.4);
      final py = size.height * 0.22 + math.sin(t * 6) * 6;
      final trail = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(px + 14, py + 4),
        Offset(px + size.width * 0.35, py + 30),
        trail,
      );
      _plane(canvas, Offset(px, py), size.width * 0.06);
    }
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final shade = Paint()..color = const Color(0xFFDDEBFA);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, s * 0.18),
        width: s * 2.4,
        height: s * 0.7,
      ),
      shade,
    );
    canvas.drawCircle(c.translate(-s * 0.6, 0), s * 0.5, p);
    canvas.drawCircle(c.translate(0, -s * 0.25), s * 0.7, p);
    canvas.drawCircle(c.translate(s * 0.65, 0.05 * s), s * 0.48, p);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, s * 0.12),
        width: s * 2.3,
        height: s * 0.6,
      ),
      p,
    );
  }

  void _plane(Canvas canvas, Offset c, double s) {
    final body = Paint()..color = const Color(0xFF3F6FB5);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 2.2, height: s * 0.42),
        Radius.circular(s * 0.21),
      ),
      body,
    );
    final wing = Path()
      ..moveTo(-s * 0.1, 0)
      ..lineTo(s * 0.35, -s * 0.9)
      ..lineTo(s * 0.6, -s * 0.9)
      ..lineTo(s * 0.4, 0)
      ..close();
    canvas.drawPath(wing, body);
    canvas.drawPath(
      wing
          .shift(Offset(0, 0))
          .transform(Matrix4.diagonal3Values(1, -1, 1).storage),
      body,
    );
    final tail = Path()
      ..moveTo(s * 0.8, 0)
      ..lineTo(s * 1.15, -s * 0.55)
      ..lineTo(s * 1.15, 0)
      ..close();
    canvas.drawPath(tail, body);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.t != t;
}
