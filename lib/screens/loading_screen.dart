import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/render/sprite_bank.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../config/app_config.dart';
import '../ui/theme.dart';
import '../widgets/game_logo.dart';
import 'home_screen.dart';

/// App khulte hi pehli screen: rangeen background, game ka logo (code se bana),
/// aur neeche gol progress bar percentage ke saath.
/// Peeche tasveerein aur awaazen load hoti hain, phir Home screen khulti hai.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final started = DateTime.now();
    setState(() => _progress = 0.05);
    await SpriteBank.instance.load(
      onProgress: (f) {
        if (mounted) setState(() => _progress = 0.05 + 0.8 * f);
      },
    );
    await SpriteBank.instance.loadSelectedSkins();
    if (!mounted) return;
    await AudioService.instance.init();
    unawaited(AudioService.instance.setMusic(ProgressService.instance.musicOn));
    if (!mounted) return;
    setState(() => _progress = 1);
    // Screen kam az kam thodi der dikhe (jhatka na lage)
    final spent = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 1400);
    if (spent < minShow) await Future<void>.delayed(minShow - spent);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).round();
    final hero = SpriteBank.instance.named('home_bus_v2');
    return Scaffold(
      body: Stack(
        children: [
          // Rangeen background: jamni-neela gradient aur ghoomte rangeen gole
          // Alag layer: chalta background baqi screen ko dobara draw na karaye
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) =>
                    CustomPaint(painter: _LoadingBgPainter(_anim.value)),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => Column(
                children: [
                  const Spacer(flex: 1),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + 0.03 * math.sin(_anim.value * 2 * math.pi * 3),
                      child: child,
                    ),
                    child: GameLogo(width: math.min(c.maxWidth * 0.7, 320)),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    flex: 6,
                    child: RepaintBoundary(
                      child: hero != null
                          ? RawImage(image: hero, fit: BoxFit.contain)
                          : Image.asset(
                              'assets/sprites/home_bus_v2.png',
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: c.maxWidth * 0.12,
                    ),
                    child: _ProgressBar(value: _progress),
                  ),
                  const SizedBox(height: 10),
                  Text('Loading... $pct%', style: AppText.title(18)),
                  const SizedBox(height: 22),
                  Text(
                    'by ${AppConfig.studioName}',
                    style: AppText.text(
                      15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 15,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF6BC8F4), width: 1.5),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 300),
          widthFactor: value.clamp(0.04, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB5F4FF), Color(0xFF27B8F2)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBgPainter extends CustomPainter {
  _LoadingBgPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF308CE8), Color(0xFF61D7D8), Color(0xFF1A7AC6)],
        ).createShader(r),
    );
    // Beech mein halki roshni (logo aur bus ke peeche)
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.42),
      size.width * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width / 2, size.height * 0.42),
                radius: size.width * 0.75,
              ),
            ),
    );
    // Chhote halke safed bulbule dheere dheere upar jaate hue
    final rnd = math.Random(3);
    for (var i = 0; i < 14; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.3 + rnd.nextDouble() * 0.7;
      final y = (rnd.nextDouble() - t * speed) % 1.0 * size.height;
      final rad = 4 + rnd.nextDouble() * 12;
      canvas.drawCircle(
        Offset(x, y),
        rad,
        Paint()..color = Colors.white.withValues(alpha: 0.10 + (i % 3) * 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(_LoadingBgPainter old) => old.t != t;
}
