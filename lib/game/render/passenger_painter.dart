import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';
import 'sprite_bank.dart';

/// Passenger ko code se draw karna: chamakdar gol jism aur upar gol sar
/// (dono ek hi rang ke, khilone jaise). (0,0) pairon ke paas hai. [size] = passenger ka size.
/// Baad mein image lagani ho to sirf yeh file badlein.
class PassengerPainter {
  /// 3D insaan ki ek world unit screen par passenger size ka kitna guna
  static const double _walkerScale = 1.55;

  /// Logon ki tasveerein kis zaviye se bani (make_people.py ka TILT)
  static const double _walkerTilt = 45 * math.pi / 180;

  static void paint(
    Canvas canvas, {
    required Color color,
    required double size,
    double bob = 0,
    int colorIndex = -1,
    double heading = 0,
    int frame = 0,
  }) {
    final s = size;
    // Chalta-phirta 3D insaan (rukh aur qadam ke saath), ho to wohi
    final walker = colorIndex >= 0
        ? SpriteBank.instance.walker(colorIndex, heading, frame)
        : null;
    if (walker != null) {
      // Tasveer 1.2 world units ki; camera 0.55 oonchai par nishana leta hai,
      // is liye pair (z = 0) beech se 0.55 * sin(tilt) neeche (make_people.py)
      final w = s * _walkerScale * 1.2;
      final feet = 0.5 + 0.55 * math.sin(_walkerTilt) / 1.2;
      final top = -w * feet - bob * s * 0.06;
      canvas.drawImageRect(
        walker,
        Rect.fromLTWH(0, 0, walker.width.toDouble(), walker.height.toDouble()),
        Rect.fromLTWH(-w / 2, top, w, w),
        SpriteBank.paint,
      );
      return;
    }
    // 3D tasveer (sprite) maujood ho to wohi
    final img = colorIndex >= 0 ? SpriteBank.instance.person(colorIndex) : null;
    if (img != null) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.05, -s * 0.12),
          width: s * 0.8,
          height: s * 0.36,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.16),
      );
      // Tasveer mein insaan beech ka hissa leta hai, is liye thoda bara draw
      final dst = Rect.fromLTWH(
        -s * 0.7,
        -s * 1.22 - bob * s * 0.1,
        s * 1.4,
        s * 1.4,
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        SpriteBank.paint,
      );
      return;
    }
    final dark = GamePalette.darker(color, 0.25);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.35);

    // Zameen par saaya
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.05, -s * 0.12),
        width: s * 0.82,
        height: s * 0.4,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    canvas.save();
    canvas.translate(0, -bob * s * 0.1);

    for (final x in [-s * .13, s * .13]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, -s * .11),
          width: s * .22,
          height: s * .29,
        ),
        Paint()..color = dark,
      );
    }

    // Jism (gol)
    final bodyC = Offset(0, -s * 0.36);
    final bodyR = s * 0.36;
    canvas.drawCircle(
      bodyC.translate(0, s * 0.04),
      bodyR,
      Paint()..color = dark,
    );
    canvas.drawOval(
      Rect.fromCenter(center: bodyC, width: s * .63, height: s * .72),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.5, -.6),
          colors: [GamePalette.lighter(color, .30), color, dark],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: bodyC, radius: bodyR)),
    );

    // Sar (jism ke upar, thoda chhota)
    final headC = Offset(0, -s * 0.78);
    final headR = s * 0.30;
    canvas.drawCircle(
      headC.translate(0, s * 0.03),
      headR,
      Paint()..color = dark,
    );
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          colors: [GamePalette.lighter(color, .42), color, dark],
          stops: const [0, .62, 1],
        ).createShader(Rect.fromCircle(center: headC, radius: headR)),
    );

    // Chamak (glossy)
    canvas.drawCircle(
      headC.translate(-headR * 0.35, -headR * 0.35),
      headR * 0.28,
      shine,
    );
    canvas.drawCircle(
      bodyC.translate(-bodyR * 0.4, -bodyR * 0.3),
      bodyR * 0.22,
      shine,
    );

    canvas.restore();
  }
}
