import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small game illustrations, rendered at device resolution without icon fonts.
class GameArt extends StatelessWidget {
  const GameArt(this.kind, {super.key, this.size = 48});
  final String kind;
  final double size;

  /// In naamon ke 3D icons (Blender: tool/blender/make_icons.py) assets/icons mein hain
  static const _icons = {
    'daily': 'daily',
    'checkin': 'checkin',
    'shop': 'shop',
    'coins': 'shop',
    'supplies': 'supplies',
    'spin': 'spin',
    'noads': 'noads',
    'garage': 'garage',
    'vip': 'vip',
    'sort': 'sort',
    'shuffle': 'shuffle',
  };

  @override
  Widget build(BuildContext context) {
    final drawn = CustomPaint(
      size: Size.square(size),
      painter: _GameArtPainter(kind),
    );
    final icon = _icons[kind];
    if (icon == null) return drawn;
    return Image.asset(
      'assets/icons/$icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // Tasveer na mile (maslan tests) to purani code wali drawing
      errorBuilder: (_, _, _) => drawn,
    );
  }
}

class _GameArtPainter extends CustomPainter {
  const _GameArtPainter(this.kind);
  final String kind;

  void box(Canvas c, Rect r, Color color, [double radius = 7]) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        r.shift(const Offset(0, 3)),
        Radius.circular(radius),
      ),
      Paint()..color = Color.lerp(color, Colors.black, .28)!,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(color, Colors.white, .35)!, color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(r),
    );
  }

  void coin(Canvas c, double x, double y, double r) {
    final p = Offset(x, y);
    c.drawCircle(
      p.translate(1, 2),
      r,
      Paint()..color = const Color(0xFFB86D0A),
    );
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF18A), Color(0xFFFFB914)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    c.drawCircle(
      p,
      r * .74,
      Paint()
        ..color = const Color(0xFFEBA00B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
    final dollar = Path()
      ..moveTo(x + r * .29, y - r * .31)
      ..cubicTo(x - r * .50, y - r * .60, x - r * .50, y + r * .05, x, y)
      ..cubicTo(
        x + r * .50,
        y + r * .03,
        x + r * .45,
        y + r * .63,
        x - r * .30,
        y + r * .30,
      );
    c.drawPath(
      dollar,
      Paint()
        ..color = const Color(0xFFC98900)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .16
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      Offset(x, y - r * .52),
      Offset(x, y + r * .52),
      Paint()
        ..color = const Color(0xFFC98900)
        ..strokeWidth = r * .12,
    );
  }

  void bus(
    Canvas c, {
    Color color = const Color(0xFFFFBD2E),
    bool car = false,
  }) {
    c.save();
    c.translate(2, 5);
    c.rotate(-.13);
    for (final x in [19.0, 47.0]) {
      c.drawCircle(Offset(x, 47), 7, Paint()..color = const Color(0xFF28354D));
      c.drawCircle(Offset(x, 47), 3, Paint()..color = const Color(0xFFB8D4E8));
    }
    box(c, Rect.fromLTWH(8, car ? 27 : 13, 48, car ? 19 : 33), color, 5);
    box(c, Rect.fromLTWH(11, car ? 17 : 16, 36, 17), color, 4);
    for (var i = 0; i < (car ? 2 : 3); i++) {
      box(
        c,
        Rect.fromLTWH(14 + i * 11, car ? 20 : 19, 9, 12),
        const Color(0xFF46B5E4),
        2,
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 39, 40, 3),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white.withValues(alpha: .65),
    );
    c.restore();
  }

  void gift(Canvas c, [bool check = false]) {
    box(c, const Rect.fromLTWH(12, 24, 41, 31), const Color(0xFF9A54E9), 4);
    box(c, const Rect.fromLTWH(8, 20, 49, 11), const Color(0xFFC584FF), 3);
    c.drawRect(
      const Rect.fromLTWH(28, 21, 9, 34),
      Paint()..color = const Color(0xFFFFD948),
    );
    for (final x in [24.0, 41.0]) {
      final oval = Rect.fromCenter(
        center: Offset(x, 17),
        width: 19,
        height: 13,
      );
      c.drawOval(
        oval,
        Paint()
          ..color = const Color(0xFFFFD948)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
    if (check) {
      c.drawCircle(const Offset(45, 44), 14, Paint()..color = Colors.white);
      final tick = Path()
        ..moveTo(37, 44)
        ..lineTo(43, 50)
        ..lineTo(53, 35);
      c.drawPath(
        tick,
        Paint()
          ..color = const Color(0xFF57CE2C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    canvas.drawOval(
      const Rect.fromLTWH(7, 52, 50, 8),
      Paint()..color = const Color(0x250E234B),
    );
    switch (kind) {
      case 'vip':
        bus(canvas, color: const Color(0xFFFFAA24), car: true);
        coin(canvas, 12, 46, 10);
        coin(canvas, 50, 17, 9);
      case 'sort':
        bus(canvas);
        for (var i = 0; i < 3; i++) {
          final p = Offset(10 + i * 10, 49 - i * 4);
          final color = [
            const Color(0xFFFC5278),
            const Color(0xFF35CB95),
            const Color(0xFF4B98F4),
          ][i];
          canvas.drawOval(
            Rect.fromCenter(center: p, width: 10, height: 13),
            Paint()..color = color,
          );
          canvas.drawCircle(p.translate(0, -8), 5, Paint()..color = color);
        }
      case 'shuffle':
      case 'spin':
        final center = const Offset(32, 31);
        final colors = [
          const Color(0xFFFFD342),
          const Color(0xFFFF8C3B),
          const Color(0xFFFA57AD),
          const Color(0xFFB959F1),
          const Color(0xFF52A6F8),
          const Color(0xFF25D5BD),
        ];
        for (var i = 0; i < 6; i++) {
          canvas.drawArc(
            const Rect.fromLTWH(6, 5, 52, 52),
            -math.pi / 2 + i * math.pi / 3,
            math.pi / 3,
            true,
            Paint()..color = colors[i],
          );
        }
        canvas.drawOval(
          const Rect.fromLTWH(6, 5, 52, 52),
          Paint()
            ..color = const Color(0xFF56698B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawOval(
          const Rect.fromLTWH(19, 5, 26, 52),
          Paint()
            ..color = Colors.white.withValues(alpha: .65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawLine(
          const Offset(7, 31),
          const Offset(57, 31),
          Paint()
            ..color = Colors.white.withValues(alpha: .6)
            ..strokeWidth = 1.5,
        );
        canvas.drawOval(
          const Rect.fromLTWH(18, 9, 24, 10),
          Paint()..color = Colors.white.withValues(alpha: .55),
        );
        if (kind == 'spin') {
          canvas.drawCircle(
            center,
            7,
            Paint()..color = const Color(0xFFFFE289),
          );
          final arrow = Path()
            ..moveTo(27, 1)
            ..lineTo(37, 1)
            ..lineTo(32, 13)
            ..close();
          canvas.drawPath(arrow, Paint()..color = Colors.white);
        }
      case 'coins':
      case 'shop':
        if (kind == 'shop') gift(canvas);
        coin(canvas, 22, 43, 14);
        coin(canvas, 43, 40, 13);
        coin(canvas, 33, 23, 14);
      case 'daily':
      case 'checkin':
        gift(canvas, kind == 'checkin');
      case 'supplies':
        bus(canvas, color: const Color(0xFF308AF4));
        coin(canvas, 19, 49, 10);
        coin(canvas, 42, 50, 9);
      case 'noads':
        canvas.drawCircle(
          const Offset(32, 30),
          26,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFFF8A9B), Color(0xFFE51C43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(const Rect.fromLTWH(6, 4, 52, 52)),
        );
        canvas.drawCircle(
          const Offset(32, 30),
          23,
          Paint()
            ..color = const Color(0xFFFFB7C4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        final tp = TextPainter(
          text: const TextSpan(
            text: 'ADS',
            style: TextStyle(
              fontFamily: 'Lilita',
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(32 - tp.width / 2, 30 - tp.height / 2));
        canvas.drawLine(
          const Offset(15, 48),
          const Offset(48, 13),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GameArtPainter oldDelegate) => oldDelegate.kind != kind;
}
