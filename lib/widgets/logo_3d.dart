import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../ui/theme.dart';
import 'splash_scene.dart';

/// Splash ka 3D logo: har harf mota (andar ki taraf gehrai / extrusion), upar
/// se 3D palat kar girta hai, phir lehar ki tarah halka ghoomta rehta hai aur
/// beech beech mein chamak guzarti hai. Naam AppConfig.appName se aata hai.
class Logo3D extends StatelessWidget {
  const Logo3D({super.key, required this.clock, required this.width});

  final SplashClock clock;
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

  Widget _letter(String ch, int index, double fontSize) => _DroppingLetter(
    clock: clock,
    index: index,
    size: fontSize,
    child: _ExtrudedLetter(
      ch,
      size: fontSize,
      color: _letterColors[index % _letterColors.length],
      tilt: math.sin(index * 1.7) * 0.06,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Teen ya zyada lafz hon to pehle do ek line mein ("Bus Jam" / "Party")
    final all = AppConfig.appName.split(' ');
    final words = all.length >= 3
        ? [all.take(all.length - 1).join(' '), all.last]
        : all;
    final fontSize = width * 0.2;
    var k = 0;
    final letters = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final w in words)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ch in w.split(''))
                  if (ch == ' ')
                    SizedBox(width: fontSize * 0.32)
                  else
                    _letter(ch, k++, fontSize),
              ],
            ),
          ),
        // Extrusion neeche jaati hai, us ke liye jagah
        SizedBox(height: fontSize * 0.18),
      ],
    );

    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: clock,
        child: letters,
        builder: (context, child) {
          final t = clock.time;
          final ex = Curves.easeInBack.transform(clock.exit);
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..translateByDouble(0, -ex * width * 0.9, 0, 1)
            ..rotateX(math.sin(t * 0.7) * 0.10)
            ..rotateY(math.sin(t * 0.5) * 0.16)
            ..scaleByDouble(1 + ex * 0.3, 1 + ex * 0.3, 1, 1);
          // Har 3.4 second baad ek chamak tirchhi guzarti hai
          final sweep = (t % 3.4) / 1.1;
          final pos = -0.3 + sweep * 1.6;
          return Opacity(
            opacity: (1 - clock.exit * 1.4).clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: m,
              child: ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (r) => LinearGradient(
                  begin: const Alignment(-1, -0.6),
                  end: const Alignment(1, 0.6),
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: sweep < 1 ? 0.6 : 0),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: [
                    (pos - 0.12).clamp(0.0, 1.0),
                    pos.clamp(0.0, 1.0),
                    (pos + 0.12).clamp(0.0, 1.0),
                  ],
                ).createShader(r),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Harf upar se 3D palat kar girta hai (rotateX), phir lehar mein rehta hai
class _DroppingLetter extends StatelessWidget {
  const _DroppingLetter({
    required this.clock,
    required this.index,
    required this.size,
    required this.child,
  });

  final SplashClock clock;
  final int index;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Harf ki tasveer ek dafa bane, phir sirf ghoome (dobara paint na ho)
    final cached = RepaintBoundary(child: child);
    return AnimatedBuilder(
      animation: clock,
      child: cached,
      builder: (context, child) {
        final start = 0.30 + index * 0.035;
        final p = ((clock.intro - start) / 0.28).clamp(0.0, 1.0);
        if (p <= 0) return Opacity(opacity: 0, child: child);
        final e = Curves.easeOutBack.transform(p);
        final settle = ((clock.intro - start - 0.28) / 0.3).clamp(0.0, 1.0);
        final t = clock.time;
        final drop = -(1 - e) * size * 2.4;
        final bob = math.sin(t * 3.2 - index * 0.55) * size * 0.035 * settle;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..translateByDouble(0, drop + bob, 0, 1)
          ..rotateX((1 - e) * 1.7)
          ..rotateY(math.sin(t * 2.0 - index * 0.45) * 0.3 * settle);
        return Opacity(
          opacity: (p * 2.5).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: child,
          ),
        );
      },
    );
  }
}

/// Ek harf: neeche gehra saaya, rangeen gehrai (kai tehein), mota safed
/// kinara, upar chamakdar rang aur glossy roshni.
class _ExtrudedLetter extends StatelessWidget {
  const _ExtrudedLetter(
    this.ch, {
    required this.size,
    required this.color,
    required this.tilt,
  });

  final String ch;
  final double size;
  final Color color;
  final double tilt;

  static const int _depth = 4;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppText.display,
      fontSize: size,
      height: 1.05,
    );
    final step = size * 0.035;
    final faceRect = Rect.fromLTWH(0, size * 0.15, size, size * 0.85);
    Paint stroke(double width, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    return Transform.rotate(
      angle: tilt,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size * 0.01),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Zameen par naram saaya
            Transform.translate(
              offset: Offset(size * 0.04, step * _depth + size * 0.07),
              child: Text(
                ch,
                style: base.copyWith(
                  foreground: stroke(size * 0.22, const Color(0x552A1F5C)),
                ),
              ),
            ),
            // Gehra kinara poori gehrai ke gird
            for (var i = _depth; i >= 0; i--)
              Transform.translate(
                offset: Offset(0, step * i),
                child: Text(
                  ch,
                  style: base.copyWith(
                    foreground: stroke(size * 0.25, const Color(0xFF2A1F5C)),
                  ),
                ),
              ),
            // Rangeen gehrai (neeche zyada gehri)
            for (var i = _depth; i >= 1; i--)
              Transform.translate(
                offset: Offset(0, step * i),
                child: Text(
                  ch,
                  style: base.copyWith(
                    foreground: stroke(
                      size * 0.17,
                      AppColors.darker(color, 0.3 + 0.25 * i / _depth),
                    ),
                  ),
                ),
              ),
            // Mota safed kinara
            Text(
              ch,
              style: base.copyWith(
                foreground: stroke(size * 0.16, Colors.white),
              ),
            ),
            // Chehra: upar halka, neeche gehra rang
            Text(
              ch,
              style: base.copyWith(
                foreground: Paint()
                  ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.lighter(color, 0.45),
                      color,
                      AppColors.darker(color, 0.12),
                    ],
                    stops: const [0, 0.55, 1],
                  ).createShader(faceRect),
              ),
            ),
            // Glossy chamak (upar ka aadha)
            Text(
              ch,
              style: base.copyWith(
                foreground: Paint()
                  ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.42, 0.43, 1],
                  ).createShader(faceRect),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
