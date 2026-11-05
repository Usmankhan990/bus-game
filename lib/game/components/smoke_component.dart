import 'dart:ui';

import 'package:flame/components.dart';

/// Chalti gaadi ke peeche safed dhuaan ka ek gola (phail kar gayab ho jata hai)
class SmokePuff extends Component {
  SmokePuff(this.pos, this.size) : super(priority: 9);

  Offset pos;
  final double size;
  double _t = 0;
  static const double _life = 0.6;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    pos = pos.translate(0, -size * 0.3 * dt);
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (_t / _life).clamp(0.0, 1.0);
    canvas.drawCircle(
      pos,
      size * (0.35 + 0.65 * k),
      Paint()..color = Color.fromRGBO(255, 255, 255, 0.85 * (1 - k)),
    );
  }
}
