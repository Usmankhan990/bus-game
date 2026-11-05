import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Gaadi ko code se draw karne wala class (khilone jaisa, thoda 3D andaz).
/// Baad mein images lagani hon to sirf is file ko badal dein (ya canvas.drawImage use karein).
///
/// Gaadi (0,0) par darmiyan mein banti hai aur us ka agla hissa UPAR (-y) hota hai.
/// [unit] = board ka ek unit. [length] units lambi aur ~0.8 unit chaudi.
class BusPainter {
  static const double widthFactor = 0.8;

  /// Fixed camera projection, shared by cached sprites and their hit regions.
  static void paintDirectional(
    Canvas canvas, {
    required Color color,
    required double unit,
    required int length,
    required double angle,
  }) {
    canvas.save();
    canvas.translate(unit * 0.04, unit * 0.10);
    canvas.scale(1, math.cos(24 * math.pi / 180));
    canvas.rotate(angle);
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: unit * 0.86,
      height: bodyLength(unit, length),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(unit * 0.16)),
      Paint()
        ..color = const Color(0x300D1631)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.07),
    );
    canvas.restore();
    // Extruded side walls keep the camera depth fixed as the vehicle turns.
    final w = unit * widthFactor;
    final lengthPx = bodyLength(unit, length);
    Offset project(double x, double y, double lift) => Offset(
      x * math.cos(angle) - y * math.sin(angle),
      (x * math.sin(angle) + y * math.cos(angle)) *
              math.cos(24 * math.pi / 180) -
          lift,
    );
    final corners = [
      Offset(-w / 2, -lengthPx / 2),
      Offset(w / 2, -lengthPx / 2),
      Offset(w / 2, lengthPx / 2),
      Offset(-w / 2, lengthPx / 2),
    ];
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final pa = project(a.dx, a.dy, unit * .24);
      final pb = project(b.dx, b.dy, unit * .24);
      if (pb.dx >= pa.dx) continue;
      final qa = project(a.dx, a.dy, -unit * .10);
      final qb = project(b.dx, b.dy, -unit * .10);
      final side = Path()
        ..moveTo(pa.dx, pa.dy)
        ..lineTo(pb.dx, pb.dy)
        ..lineTo(qb.dx, qb.dy)
        ..lineTo(qa.dx, qa.dy)
        ..close();
      canvas.drawPath(
        side,
        Paint()
          ..shader = LinearGradient(
            colors: [
              GamePalette.lighter(color, .08),
              GamePalette.darker(color, .32),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(side.getBounds()),
      );
      final count = i.isOdd ? math.max(3, length * 2) : 2;
      for (var k = 0; k < count; k++) {
        final t0 = (k + .18) / count;
        final t1 = (k + .82) / count;
        final p0 = Offset.lerp(pa, pb, t0)!;
        final p1 = Offset.lerp(pa, pb, t1)!;
        final window = Path()
          ..moveTo(p0.dx, p0.dy + unit * .04)
          ..lineTo(p1.dx, p1.dy + unit * .04)
          ..lineTo(p1.dx, p1.dy + unit * .17)
          ..lineTo(p0.dx, p0.dy + unit * .17)
          ..close();
        canvas.drawPath(window, Paint()..color = const Color(0xFF244C60));
      }
      canvas.drawLine(
        qa.translate(0, -unit * .035),
        qb.translate(0, -unit * .035),
        Paint()
          ..color = GamePalette.lighter(color, .40)
          ..strokeWidth = unit * .035,
      );
      if (i.isOdd) {
        for (final t in [.18, .82]) {
          final wheel = Offset.lerp(qa, qb, t)!;
          canvas.drawOval(
            Rect.fromCenter(
              center: wheel.translate(0, unit * .01),
              width: unit * .21,
              height: unit * .15,
            ),
            Paint()..color = const Color(0xFF263747),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: wheel.translate(0, unit * .01),
              width: unit * .09,
              height: unit * .07,
            ),
            Paint()..color = const Color(0xFFB6CFD8),
          );
        }
      }
    }
    canvas.save();
    canvas.translate(0, -unit * 0.24);
    canvas.scale(1, math.cos(24 * math.pi / 180));
    canvas.rotate(angle);
    paint(canvas, color: color, unit: unit, length: length);
    canvas.restore();
  }

  /// Gaadi ki lambai (pixels)
  static double bodyLength(double unit, int length) => unit * (length - 0.12);

  static void paint(
    Canvas canvas, {
    required Color color,
    required double unit,
    int length = 2,
    int capacity = 4,
    int filled = 0,
    bool showSeats = false,
    double rotorAngle = -1,
    int colorIndex = -1,
  }) {
    final w = unit * widthFactor;
    final l = bodyLength(unit, length);
    final dark = GamePalette.darker(color, 0.38);
    final light = GamePalette.lighter(color, 0.24);
    final radius = Radius.circular(w * 0.19);
    final depth = w * 0.16;

    final body = Rect.fromCenter(
      center: Offset(0, -depth / 2),
      width: w,
      height: l - depth,
    );

    // Zameen par saaya
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.translate(w * 0.06, depth * 1.4), radius),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    // Pahiye (sirf kinaron se thode nazar aate hain)
    final tire = Paint()..color = GamePalette.tire;
    for (final fy in [body.top + w * 0.42, body.bottom - w * 0.3]) {
      for (final fx in [-w / 2 - w * 0.02, w / 2 + w * 0.02]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(fx, fy + depth * 0.6),
              width: w * 0.14,
              height: w * 0.32,
            ),
            Radius.circular(w * 0.06),
          ),
          tire,
        );
      }
    }

    // 3D kinara (body ka neeche wala gehra hissa)
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.translate(0, depth), radius),
      Paint()..color = dark,
    );
    // Body ka upar wala hissa
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, radius),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [light, color, GamePalette.darker(color, 0.12)],
          stops: const [0, 0.38, 1],
        ).createShader(body),
    );
    // Thin trim gives the body a crisp silhouette at small game sizes.
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.deflate(w * 0.025), radius),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025,
    );
    // Halki chamak baayen kinare par
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + w * 0.06,
          body.top + w * 0.2,
          w * 0.1,
          body.height - w * 0.4,
        ),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = light.withValues(alpha: 0.8),
    );

    // Agla sheesha (windshield): saaf nazar aata hai ke munh kidhar hai
    final ws = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        body.left + w * 0.12,
        body.top + w * 0.08,
        w * 0.76,
        w * 0.32,
      ),
      topLeft: Radius.circular(w * 0.2),
      topRight: Radius.circular(w * 0.2),
      bottomLeft: Radius.circular(w * 0.05),
      bottomRight: Radius.circular(w * 0.05),
    );
    canvas.drawRRect(
      ws,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9CE6F5), Color(0xFF23516D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(ws.outerRect),
    );
    canvas.drawLine(
      Offset(ws.left + w * 0.10, ws.top + w * 0.08),
      Offset(ws.right - w * 0.22, ws.top + w * 0.08),
      Paint()
        ..color = const Color(0xAFFFFFFF)
        ..strokeWidth = w * 0.035,
    );

    // Chhat (thodi halki) aur dono taraf khidkiyon ki patti
    final roof = Rect.fromLTRB(
      body.left + w * 0.14,
      ws.bottom + w * 0.06,
      body.right - w * 0.14,
      body.bottom - w * 0.14,
    );
    if (roof.height > 0) {
      final glass = Paint()..color = const Color(0xFF224859);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(body.left + w * 0.04, roof.top, w * 0.07, roof.height),
          Radius.circular(w * 0.03),
        ),
        glass,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(body.right - w * 0.11, roof.top, w * 0.07, roof.height),
          Radius.circular(w * 0.03),
        ),
        glass,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(roof, Radius.circular(w * 0.14)),
        Paint()
          ..shader = LinearGradient(
            colors: [GamePalette.lighter(color, 0.22), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(roof),
      );
      // Window pillars and a small roof hatch distinguish a bus from a box.
      for (var y = roof.top + w * 0.24; y < roof.bottom; y += w * 0.42) {
        canvas.drawLine(
          Offset(body.left + w * 0.035, y),
          Offset(body.left + w * 0.115, y),
          Paint()
            ..color = light
            ..strokeWidth = w * 0.045,
        );
        canvas.drawLine(
          Offset(body.right - w * 0.115, y),
          Offset(body.right - w * 0.035, y),
          Paint()
            ..color = light
            ..strokeWidth = w * 0.045,
        );
      }
      final hatch = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, roof.bottom - w * 0.28),
          width: w * 0.38,
          height: w * 0.30,
        ),
        Radius.circular(w * 0.04),
      );
      canvas.drawRRect(hatch, Paint()..color = dark.withValues(alpha: 0.35));
      canvas.drawRRect(
        hatch.shift(Offset(0, -w * 0.025)),
        Paint()..color = light,
      );
    }

    // Silver bumpers and rear lamps stay legible without an oversized arrow.
    for (final y in [body.top + w * 0.025, body.bottom - w * 0.035]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, y),
            width: w * 0.64,
            height: w * 0.065,
          ),
          Radius.circular(w * 0.03),
        ),
        Paint()..color = const Color(0xFFD7E0E7),
      );
    }
    for (final x in [-w * 0.31, w * 0.31]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, body.bottom - w * 0.12),
            width: w * 0.13,
            height: w * 0.07,
          ),
          Radius.circular(w * 0.02),
        ),
        Paint()..color = const Color(0xFFFFE0C3),
      );
    }

    // Headlights
    final lightPaint = Paint()..color = GamePalette.headlight;
    canvas.drawCircle(
      Offset(-w * 0.32, body.top + w * 0.04),
      w * 0.07,
      lightPaint,
    );
    canvas.drawCircle(
      Offset(w * 0.32, body.top + w * 0.04),
      w * 0.07,
      lightPaint,
    );

    if (showSeats) {
      _seats(canvas, w, roof.top, roof.bottom, capacity, filled, dark, light);
    } else {
      _arrow(canvas, w, roof);
    }

    // Lift booster ke dauran ghoomta hua rotor
    if (rotorAngle >= 0) rotor(canvas, w, l, rotorAngle);
  }

  static void rotor(Canvas canvas, double w, double l, double rotorAngle) {
    final rotor = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    final r = math.max(l * 0.55, w * 1.1);
    for (var k = 0; k < 2; k++) {
      final a = rotorAngle + k * math.pi / 2;
      final d = Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(-d, d, rotor);
    }
    canvas.drawCircle(Offset.zero, w * 0.12, Paint()..color = Colors.black54);
  }

  /// Chhat par bada safed teer (gehre kinare ke saath): gaadi kis taraf jayegi
  static void _arrow(Canvas canvas, double w, Rect roof) {
    final mid = roof.top + math.min(roof.height * 0.42, w * 0.56);
    final h = math.min(roof.height * 0.58, w * 0.90);
    final aw = w * 0.39;
    final path = Path()
      ..moveTo(0, mid - h / 2)
      ..lineTo(aw / 2, mid - h * 0.02)
      ..lineTo(aw * 0.17, mid - h * 0.02)
      ..lineTo(aw * 0.17, mid + h / 2)
      ..lineTo(-aw * 0.17, mid + h / 2)
      ..lineTo(-aw * 0.17, mid - h * 0.02)
      ..lineTo(-aw / 2, mid - h * 0.02)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3A3F4B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  /// Seats (2 columns). Bhari seat par passenger ka sar nazar aata hai.
  static void _seats(
    Canvas canvas,
    double w,
    double top,
    double bottom,
    int capacity,
    int filled,
    Color dark,
    Color light,
  ) {
    final rowsCount = (capacity / 2).ceil();
    final step = (bottom - top) / rowsCount;
    if (step <= 0) return;
    final seatR = math.min(w * 0.15, step * 0.4);
    for (var i = 0; i < capacity; i++) {
      final row = i ~/ 2;
      final col = i % 2;
      final p = Offset(
        (col == 0 ? -1 : 1) * w * 0.19,
        top + step * (row + 0.5),
      );
      if (i < filled) {
        canvas.drawCircle(p, seatR * 1.1, Paint()..color = dark);
        canvas.drawCircle(p, seatR * 0.92, Paint()..color = light);
        canvas.drawCircle(
          p.translate(-seatR * 0.3, -seatR * 0.3),
          seatR * 0.3,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
      } else {
        canvas.drawCircle(
          p,
          seatR,
          Paint()..color = dark.withValues(alpha: 0.45),
        );
      }
    }
  }
}
