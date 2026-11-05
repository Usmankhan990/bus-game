import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/render/palette.dart';

/// Jeetne par girne wale rangeen kaghaz ke tukre (celebration)
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();

  late final List<_Piece> _pieces = () {
    final r = math.Random();
    return List.generate(70, (i) {
      return _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        speed: 0.7 + r.nextDouble() * 0.6,
        sway: r.nextDouble() * 2 * math.pi,
        spin: (r.nextDouble() - 0.5) * 14,
        color: GamePalette.busColors[i % GamePalette.busColors.length],
        size: 6 + r.nextDouble() * 6,
      );
    });
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.sway,
    required this.spin,
    required this.color,
    required this.size,
  });

  final double x;
  final double delay;
  final double speed;
  final double sway;
  final double spin;
  final Color color;
  final double size;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = p.x * size.width + math.sin(p.sway + local * 8) * 22;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - local * 0.6).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.55,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
