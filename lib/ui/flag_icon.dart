import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/city.dart';

/// Shehar ke mulk ka jhanda, code se bana (emoji har phone par alag dikhta hai).
/// Gol kinaron wala chhota jhanda, safed kinare aur halke saaye ke saath.
class FlagIcon extends StatelessWidget {
  const FlagIcon(this.city, {super.key, this.width = 28});
  final City city;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 2 / 3;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.1),
        child: CustomPaint(painter: _FlagPainter(_countryOf(city))),
      ),
    );
  }

  static _Country _countryOf(City c) => switch (c) {
    City.karachi || City.lahore || City.islamabad => _Country.pk,
    City.dubai => _Country.ae,
    City.london => _Country.gb,
    City.paris => _Country.fr,
    City.newyork => _Country.us,
    City.tokyo => _Country.jp,
  };
}

enum _Country { pk, ae, gb, fr, us, jp }

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.country);
  final _Country country;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    Paint p(int c) => Paint()..color = Color(c);
    switch (country) {
      case _Country.pk:
        canvas.drawRect(Offset.zero & s, p(0xFF01411C));
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.25, h), p(0xFFFFFFFF));
        // Chaand: safed gola, us par hare gole se kaat
        final c = Offset(w * 0.62, h * 0.5);
        canvas.drawCircle(c, h * 0.3, p(0xFFFFFFFF));
        canvas.drawCircle(
          c.translate(h * 0.1, -h * 0.07),
          h * 0.26,
          p(0xFF01411C),
        );
        _star(canvas, c.translate(h * 0.2, -h * 0.13), h * 0.1, p(0xFFFFFFFF));
      case _Country.ae:
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), p(0xFF00732F));
        canvas.drawRect(Rect.fromLTWH(0, h / 3, w, h / 3), p(0xFFFFFFFF));
        canvas.drawRect(Rect.fromLTWH(0, h * 2 / 3, w, h / 3), p(0xFF000000));
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.26, h), p(0xFFFF0000));
      case _Country.gb:
        canvas.drawRect(Offset.zero & s, p(0xFF012169));
        final white = Paint()
          ..color = Colors.white
          ..strokeWidth = h * 0.2;
        final red = Paint()
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = h * 0.08;
        for (final paint in [white, red]) {
          canvas.drawLine(Offset.zero, Offset(w, h), paint);
          canvas.drawLine(Offset(w, 0), Offset(0, h), paint);
        }
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: w,
            height: h * 0.33,
          ),
          p(0xFFFFFFFF),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: h * 0.33,
            height: h,
          ),
          p(0xFFFFFFFF),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: w,
            height: h * 0.2,
          ),
          p(0xFFC8102E),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: h * 0.2,
            height: h,
          ),
          p(0xFFC8102E),
        );
      case _Country.fr:
        canvas.drawRect(Rect.fromLTWH(0, 0, w / 3, h), p(0xFF0055A4));
        canvas.drawRect(Rect.fromLTWH(w / 3, 0, w / 3, h), p(0xFFFFFFFF));
        canvas.drawRect(Rect.fromLTWH(w * 2 / 3, 0, w / 3, h), p(0xFFEF4135));
      case _Country.us:
        canvas.drawRect(Offset.zero & s, p(0xFFFFFFFF));
        for (var i = 0; i < 7; i++) {
          canvas.drawRect(
            Rect.fromLTWH(0, h * i * 2 / 13, w, h / 13),
            p(0xFFB22234),
          );
        }
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w * 0.4, h * 7 / 13),
          p(0xFF3C3B6E),
        );
        // Chhote nuqte (sitaron ki jagah, itne chhote size par yahi saaf dikhte hain)
        final dot = p(0xFFFFFFFF);
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 4; c++) {
            canvas.drawCircle(
              Offset(w * (0.06 + c * 0.09), h * (0.09 + r * 0.16)),
              h * 0.025,
              dot,
            );
          }
        }
      case _Country.jp:
        canvas.drawRect(Offset.zero & s, p(0xFFFFFFFF));
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.3, p(0xFFBC002D));
    }
  }

  /// Paanch kono wala sitara
  static void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.country != country;
}
