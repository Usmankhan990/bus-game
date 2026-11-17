import 'package:flutter/painting.dart';

import 'package:flame/components.dart';

/// Jab parking slots bhare hon to tap ki gayi gaadi ke paas dikhne wala chhota message bubble
class SlotFullTipComponent extends Component {
  SlotFullTipComponent({
    required this.targetPos,
    required this.unit,
    required this.bounds,
    required this.text,
  }) : super(priority: 25) {
    final fontSize = (unit * 0.34).clamp(11.0, 14.0);
    _tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          fontFamily: 'Lilita',
          shadows: const [
            Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillW = _tp.width + 18;
    final pillH = _tp.height + 10;
    const ptrH = 6.0;
    const ptrHalfW = 5.5;

    final aboveTop = targetPos.dy - unit * 0.68 - ptrH - pillH;
    final placeBelow = aboveTop < bounds.top;

    final cx = targetPos.dx.clamp(
      bounds.left + pillW / 2,
      bounds.right - pillW / 2,
    );
    final pillTop = placeBelow
        ? (targetPos.dy + unit * 0.62 + ptrH).clamp(
            bounds.top,
            bounds.bottom - pillH,
          )
        : aboveTop;

    _pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - pillW / 2, pillTop, pillW, pillH),
      Radius.circular(pillH * 0.45),
    );
    _pivot = Offset(cx, placeBelow ? pillTop - ptrH : pillTop + pillH + ptrH);

    final tipX = targetPos.dx.clamp(
      _pillRect.left + ptrHalfW + 8,
      _pillRect.right - ptrHalfW - 8,
    );
    if (placeBelow) {
      _tail = Path()
        ..moveTo(tipX, pillTop - ptrH)
        ..lineTo(tipX - ptrHalfW, pillTop + 1)
        ..lineTo(tipX + ptrHalfW, pillTop + 1)
        ..close();
    } else {
      final base = _pillRect.bottom - 1;
      _tail = Path()
        ..moveTo(tipX, base + ptrH + 1)
        ..lineTo(tipX - ptrHalfW, base)
        ..lineTo(tipX + ptrHalfW, base)
        ..close();
    }
  }

  final Offset targetPos;
  final double unit;
  final Rect bounds;
  final String text;

  late final TextPainter _tp;
  late final RRect _pillRect;
  late final Path _tail;
  late final Offset _pivot;

  double _t = 0;
  static const double _life = 1.45;

  RRect get pillRect => _pillRect;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (_t / _life).clamp(0.0, 1.0);
    // Shuru mein tezi se pop aur aakhir mein narm fade
    final pop = k < 0.10
        ? 0.65 + 0.42 * (k / 0.10)
        : (k < 0.20 ? 1.07 - 0.07 * ((k - 0.10) / 0.10) : 1.0);
    final alpha = k > 0.72
        ? (1.0 - (k - 0.72) / 0.28).clamp(0.0, 1.0)
        : (k < 0.08 ? k / 0.08 : 1.0);
    final floatY = -unit * 0.12 * (k < 0.25 ? k / 0.25 : 1.0);

    canvas.save();
    canvas.translate(_pivot.dx, _pivot.dy + floatY);
    canvas.scale(pop, pop);
    canvas.translate(-_pivot.dx, -_pivot.dy);

    canvas.drawRRect(
      _pillRect.shift(const Offset(0, 2)),
      Paint()..color = Color.fromRGBO(10, 18, 36, 0.26 * alpha),
    );
    final fill = Paint()..color = Color.fromRGBO(28, 36, 56, 0.94 * alpha);
    final stroke = Paint()
      ..color = Color.fromRGBO(255, 92, 92, alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(_tail, fill);
    canvas.drawRRect(_pillRect, fill);
    canvas.drawRRect(_pillRect, stroke);

    if (alpha >= 0.99) {
      _paintText(canvas);
    } else if (alpha > 0.02) {
      canvas.saveLayer(
        _pillRect.outerRect.inflate(4),
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
      );
      _paintText(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintText(Canvas canvas) {
    _tp.paint(
      canvas,
      Offset(
        _pillRect.left + (_pillRect.width - _tp.width) / 2,
        _pillRect.top + (_pillRect.height - _tp.height) / 2,
      ),
    );
  }
}

