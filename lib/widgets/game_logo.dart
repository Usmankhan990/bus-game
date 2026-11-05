import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../ui/theme.dart';

/// Game ka logo (code se bana): har harf alag rang ka, mota safed kinara,
/// aur upar ek chhoti bus ka icon. Naam AppConfig.appName se aata hai.
class GameLogo extends StatelessWidget {
  const GameLogo({super.key, required this.width});
  final double width;

  static const _letterColors = [
    Color(0xFFFF5252),
    Color(0xFFFFA22B),
    Color(0xFFFFD23F),
    Color(0xFF5BD43F),
    Color(0xFF2ED3C6),
    Color(0xFF4DA3FF),
    Color(0xFFB073FF),
    Color(0xFFFF6FB5),
  ];

  @override
  Widget build(BuildContext context) {
    // Teen ya zyada lafz hon to pehle do ek line mein ("Bus Jam" / "Party")
    final all = AppConfig.appName.split(' ');
    final words = all.length >= 3
        ? [all.take(all.length - 1).join(' '), all.last]
        : all;
    final fontSize = width * 0.2;
    var k = 0;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(width * 0.36, width * 0.2),
            painter: _MiniBusPainter(),
          ),
          SizedBox(height: width * 0.02),
          for (final w in words)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ch in w.split(''))
                    if (ch == ' ')
                      // Lafzon ke beech saaf khaali jagah
                      SizedBox(width: fontSize * 0.32)
                    else
                      Transform.rotate(
                        angle: math.sin(k * 1.7) * 0.06,
                        child: _OutlinedLetter(
                          ch,
                          size: fontSize,
                          color: _letterColors[k++ % _letterColors.length],
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OutlinedLetter extends StatelessWidget {
  const _OutlinedLetter(this.ch, {required this.size, required this.color});
  final String ch;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppText.display,
      fontSize: size,
      height: 1.05,
    );
    return Stack(
      children: [
        // Neeche gehra saaya
        Transform.translate(
          offset: Offset(0, size * 0.08),
          child: Text(
            ch,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.2
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF2A1F5C),
            ),
          ),
        ),
        // Mota safed kinara
        Text(
          ch,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
        ),
        Text(ch, style: base.copyWith(color: color)),
      ],
    );
  }
}

/// Logo ke upar chhoti cartoon bus (code se)
class _MiniBusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.08, w, h * 0.72),
      Radius.circular(h * 0.2),
    );
    canvas.drawRRect(
      body.shift(Offset(0, h * 0.08)),
      Paint()..color = const Color(0xFF2A1F5C),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFFC928));
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.06,
    );
    // Khidkiyan
    final win = Paint()..color = const Color(0xFF7FD3FF);
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * (0.07 + i * 0.2), h * 0.18, w * 0.15, h * 0.26),
          Radius.circular(h * 0.06),
        ),
        win,
      );
    }
    // Neeche patti
    canvas.drawRect(
      Rect.fromLTWH(w * 0.04, h * 0.52, w * 0.92, h * 0.06),
      Paint()..color = const Color(0xFFFF8A1F),
    );
    // Pahiye
    for (final x in [w * 0.22, w * 0.78]) {
      canvas.drawCircle(
        Offset(x, h * 0.82),
        h * 0.16,
        Paint()..color = const Color(0xFF2B2E36),
      );
      canvas.drawCircle(
        Offset(x, h * 0.82),
        h * 0.07,
        Paint()..color = const Color(0xFFDDDDDD),
      );
    }
  }

  @override
  bool shouldRepaint(_MiniBusPainter old) => false;
}
