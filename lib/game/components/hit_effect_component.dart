import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

class _Spark {
  const _Spark(this.angle, this.speed, this.length, this.width);
  final double angle;
  final double speed;
  final double length;
  final double width;
}

/// Do gaadiyon ke takrane par dikhne wala impact burst aur spark animation
class HitEffectComponent extends Component {
  HitEffectComponent({
    required this.pos,
    required this.unit,
    required this.dir,
  }) : super(priority: 15) {
    final baseAngle = math.atan2(dir.dy, dir.dx) + math.pi / 2;
    const count = 8;
    _sparks = List.generate(count, (i) {
      final spread = (i / count) * math.pi * 2 + (i.isEven ? 0.14 : -0.14);
      final speed = 0.55 + (i % 3) * 0.22;
      final len = 0.24 + (i % 2) * 0.12;
      final w = i.isEven ? 0.085 : 0.06;
      return _Spark(baseAngle + spread, speed, len, w);
    });
  }

  final Offset pos;
  final double unit;
  final Offset dir;
  late final List<_Spark> _sparks;

  double _t = 0;
  static const double _life = 0.34;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (_t / _life).clamp(0.0, 1.0);
    final ease = 1.0 - (1.0 - k) * (1.0 - k);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // 1) Bahar phailti hui chamakdar shockwave ring
    final ringAlpha = ((1.0 - k) * 0.85).clamp(0.0, 1.0);
    if (ringAlpha > 0.01) {
      final ringR = unit * (0.14 + 0.72 * ease);
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..color = Color.fromRGBO(255, 200, 64, ringAlpha * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.16 * (1.0 - k * 0.65),
      );
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.075 * (1.0 - k * 0.7),
      );
    }

    // 2) Takrao ke nuqte par tez sitara / impact flash
    if (k < 0.65) {
      final flashK = k < 0.18 ? k / 0.18 : 1.0 - (k - 0.18) / 0.47;
      final starR = unit * 0.42 * flashK.clamp(0.0, 1.0);
      if (starR > 0.5) {
        final star = Path();
        const tips = 6;
        final rot = math.atan2(dir.dy, dir.dx);
        for (var i = 0; i < tips * 2; i++) {
          final a = rot + i * math.pi / tips;
          final r = i.isEven ? starR : starR * 0.40;
          final px = math.cos(a) * r;
          final py = math.sin(a) * r;
          if (i == 0) {
            star.moveTo(px, py);
          } else {
            star.lineTo(px, py);
          }
        }
        star.close();
        canvas.drawPath(
          star,
          Paint()..color = Color.fromRGBO(255, 178, 36, 0.92 * flashK),
        );
        canvas.save();
        canvas.scale(0.68);
        canvas.drawPath(
          star,
          Paint()..color = Color.fromRGBO(255, 255, 255, flashK),
        );
        canvas.restore();
      }
    }

    // 3) Charon taraf bikharne wali chingariyan (sparks) aur halka dhuaan
    final sparkAlpha = (1.0 - math.pow(k, 1.5)).clamp(0.0, 1.0);
    if (sparkAlpha > 0.01) {
      for (var i = 0; i < _sparks.length; i++) {
        final s = _sparks[i];
        final d0 = unit * (0.10 + s.speed * 0.58 * ease);
        final d1 = d0 + unit * s.length * (1.0 - k * 0.72);
        final p0 = Offset(math.cos(s.angle) * d0, math.sin(s.angle) * d0);
        final p1 = Offset(math.cos(s.angle) * d1, math.sin(s.angle) * d1);

        canvas.drawLine(
          p0,
          p1,
          Paint()
            ..color = Color.fromRGBO(
              255,
              i.isEven ? 215 : 245,
              i.isEven ? 75 : 190,
              sparkAlpha,
            )
            ..strokeWidth = unit * s.width * (1.0 - k * 0.55)
            ..strokeCap = StrokeCap.round,
        );

        if (i.isEven) {
          final puffD = unit * (0.14 + 0.36 * ease);
          final puffPos = Offset(
            math.cos(s.angle + 0.35) * puffD,
            math.sin(s.angle + 0.35) * puffD - unit * 0.10 * k,
          );
          canvas.drawCircle(
            puffPos,
            unit * (0.07 + 0.08 * k),
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.65 * sparkAlpha),
          );
        }
      }
    }

    canvas.restore();
  }
}

