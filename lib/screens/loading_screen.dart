import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/render/sprite_bank.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../config/app_config.dart';
import '../ui/theme.dart';
import '../widgets/logo_3d.dart';
import '../widgets/splash_scene.dart';
import 'home_screen.dart';

/// App khulte hi pehli screen: poora 3D animated splash.
///  * Camera upar se neeche aata hai, sadak par 3D imaaratein, darakht aur
///    lamp paas se guzar kar ufaq ki taraf jaate hain
///  * Badi bus ufaq se aakar samne rukti hai (headlights, dhool, saaya)
///  * Logo ke harf 3D palat kar girte hain aur lehar mein ghoomte hain
///  * Neeche 3D progress bar jis par chhoti bus chalti hai
/// Peeche tasveerein aur awaazen load hoti hain; tayyar hone par bus camera ke
/// paas se zoom kar ke guzarti hai aur Home screen khulti hai.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  final SplashClock _clock = SplashClock();
  late final Ticker _ticker = createTicker(_onTick);
  double _progress = 0;
  bool _loaded = false;
  bool _leaving = false;
  ui.Image? _bus;
  bool _ownsBus = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _loadBus();
    _load();
  }

  void _onTick(Duration elapsed) {
    _clock.advance(elapsed.inMicroseconds / 1e6, _progress);
    // Bus ki tasveer der se aaye to bhi intro ruke nahi
    if (!_clock.introStarted && _clock.time > 0.9) _clock.startIntro();
    if (_loaded && _clock.introDone && !_clock.exitStarted) {
      _clock.startExit();
      AudioService.instance.play(Sfx.busDepart, volume: 0.6);
    }
    if (_clock.exitDone && !_leaving) {
      _leaving = true;
      _goHome();
    }
  }

  /// Hero bus ki tasveer: splash_bus_hero ko tarjeeh do, na mile to home_bus_v2
  Future<void> _loadBus() async {
    var img = SpriteBank.instance.named('splash_bus_hero');
    if (img == null) {
      try {
        final data = await rootBundle.load(
          'assets/sprites/splash_bus_hero.png',
        );
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 640,
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        img = frame.image;
        _ownsBus = true;
      } catch (_) {
        // Fallback agar splash_bus_hero kisi wajah se na mile
        try {
          final data = await rootBundle.load('assets/sprites/home_bus_v2.png');
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 640,
          );
          final frame = await codec.getNextFrame();
          codec.dispose();
          img = frame.image;
          _ownsBus = true;
        } catch (e) {
          debugPrint('Splash bus load nahi hui: $e');
        }
      }
    }
    if (!mounted) {
      if (_ownsBus) img?.dispose();
      return;
    }
    setState(() => _bus = img);
    _clock.startIntro();
  }

  Future<void> _load() async {
    _progress = 0.05;
    await SpriteBank.instance.load(
      onProgress: (f) => _progress = 0.05 + 0.8 * f,
    );
    await SpriteBank.instance.loadSelectedSkins();
    if (!mounted) return;
    await AudioService.instance.init();
    unawaited(AudioService.instance.setMusic(ProgressService.instance.musicOn));
    if (!mounted) return;
    _progress = 1;
    _loaded = true;
  }

  void _goHome() {
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    if (_ownsBus) _bus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF308CE8),
      body: Stack(
        children: [
          // Poora 3D manzar (alag layer, baqi UI dobara draw na ho)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: SplashScenePainter(_clock, _bus)),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => Column(
                children: [
                  SizedBox(height: c.maxHeight * 0.03),
                  Logo3D(
                    clock: _clock,
                    width: math.min(c.maxWidth * 0.84, 380),
                  ),
                  const Spacer(),
                  _BottomHud(clock: _clock, width: c.maxWidth),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: SplashFlashPainter(_clock)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Neeche ka hissa: 3D progress bar, "Loading..." aur studio ka naam.
/// Intro mein neeche se upar aata hai, jaate waqt gaayab.
class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.clock, required this.width});
  final SplashClock clock;
  final double width;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.1),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: CustomPaint(painter: _ProgressPainter(clock)),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: clock,
          builder: (context, _) {
            final ready = clock.progress >= 0.999;
            final dots = '.' * ((clock.time * 2.5).floor() % 4);
            return Text(
              ready ? "Let's Go!" : 'Loading$dots',
              style: AppText.title(18),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          'by ${AppConfig.studioName}',
          style: AppText.text(15, color: Colors.white.withValues(alpha: 0.9))
              .copyWith(
                shadows: const [
                  Shadow(color: Color(0x88061848), blurRadius: 4),
                ],
              ),
        ),
        const SizedBox(height: 16),
      ],
    );
    return AnimatedBuilder(
      animation: clock,
      child: content,
      builder: (context, child) {
        final inT = Curves.easeOutCubic.transform(
          ((clock.intro - 0.12) / 0.3).clamp(0.0, 1.0),
        );
        final out = clock.exit;
        return Opacity(
          opacity: (inT * (1 - out * 1.6)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - inT) * 60 + out * 40),
            child: child,
          ),
        );
      },
    );
  }
}

/// Mota 3D progress bar: gehra track, chamakdar peela-narangi bharav
/// chalti dhaariyon ke saath, beech mein %, aur kinare par chhoti bus.
class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.clock) : super(repaint: clock);
  final SplashClock clock;

  int _lastPct = -1;
  TextPainter? _stroke;
  TextPainter? _fill;

  @override
  void paint(Canvas canvas, Size size) {
    const barH = 26.0;
    final t = clock.time;
    final v = clock.progress.clamp(0.0, 1.0);
    final bar = Rect.fromLTWH(0, size.height - barH - 4, size.width, barH);
    final outer = RRect.fromRectAndRadius(bar, const Radius.circular(barH / 2));

    // Neeche ka gehra kinara (3D mota pan)
    canvas.drawRRect(
      outer.shift(const Offset(0, 4)),
      Paint()..color = const Color(0xFF15306E),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(bar.topCenter, bar.bottomCenter, const [
          Color(0xFF1B2A5A),
          Color(0xFF2C4A8E),
        ]),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );

    // Bharav
    final inner = bar.deflate(4);
    final fillW = math.max(inner.height, inner.width * v);
    final fill = RRect.fromRectAndRadius(
      Rect.fromLTWH(inner.left, inner.top, fillW, inner.height),
      Radius.circular(inner.height / 2),
    );
    canvas.drawRRect(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          inner.topCenter,
          inner.bottomCenter,
          const [Color(0xFFFFF07A), Color(0xFFFFC21F), Color(0xFFFF8A1F)],
          const [0, 0.5, 1],
        ),
    );
    canvas.save();
    canvas.clipRRect(fill);
    // Tirchhi chalti dhaariyan
    final stripe = Path();
    const gap = 14.0;
    final off = (t * 30) % (gap * 2);
    for (var x = inner.left - gap * 2 + off; x < inner.right; x += gap * 2) {
      stripe.addPolygon([
        Offset(x, inner.bottom),
        Offset(x + gap, inner.bottom),
        Offset(x + gap + inner.height, inner.top),
        Offset(x + inner.height, inner.top),
      ], true);
    }
    canvas.drawPath(
      stripe,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    // Upar glossy chamak
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inner.left + 4,
          inner.top + 2,
          fillW - 8,
          inner.height * 0.32,
        ),
        Radius.circular(inner.height * 0.2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.restore();

    // Percentage beech mein (safed, gehra kinara)
    final pct = (v * 100).round();
    if (pct != _lastPct) {
      _lastPct = pct;
      TextPainter make(TextStyle s) => TextPainter(
        text: TextSpan(text: '$pct%', style: s),
        textDirection: TextDirection.ltr,
      )..layout();
      const base = TextStyle(fontFamily: AppText.display, fontSize: 16);
      _stroke = make(
        base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeJoin = StrokeJoin.round
            ..color = AppColors.outline,
        ),
      );
      _fill = make(base.copyWith(color: Colors.white));
    }
    final tp = _fill!;
    final at = Offset(
      bar.center.dx - tp.width / 2,
      bar.center.dy - tp.height / 2,
    );
    _stroke!.paint(canvas, at);
    tp.paint(canvas, at);

    // Bar ke upar chalti chhoti bus
    final busX = (inner.left + fillW).clamp(20.0, size.width - 20.0);
    _miniBus(canvas, Offset(busX, bar.top + 3), t);
  }

  void _miniBus(Canvas canvas, Offset bottomCenter, double t) {
    const w = 38.0;
    const h = 22.0;
    final hop = (math.sin(t * 16)).abs() * 1.6;
    final o = bottomCenter.translate(-w / 2, -h - hop);

    // Peeche dhuain ke chhote gole
    for (var i = 0; i < 3; i++) {
      final ph = (t * 1.8 + i / 3) % 1.0;
      canvas.drawCircle(
        Offset(o.dx - 3 - ph * 16, o.dy + h * 0.72 - ph * 8),
        2.5 + ph * 4,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * (1 - ph)),
      );
    }

    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(o.dx, o.dy, w, h * 0.78),
      topLeft: const Radius.circular(5),
      bottomLeft: const Radius.circular(4),
      topRight: const Radius.circular(9),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 2.5)),
      Paint()..color = const Color(0xFF2A1F5C),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, o.dy),
          Offset(0, o.dy + h * 0.78),
          const [Color(0xFFFFE066), Color(0xFFFFB400)],
        ),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white,
    );
    final win = Paint()..color = const Color(0xFF7FD3FF);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o.dx + 4 + i * 8.5, o.dy + 3.5, 6.5, 6),
          const Radius.circular(1.5),
        ),
        win,
      );
    }
    // Aage ka sheesha
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(o.dx + w - 9, o.dy + 3.5, 6, 7),
        topRight: const Radius.circular(5),
        topLeft: const Radius.circular(1.5),
        bottomLeft: const Radius.circular(1.5),
        bottomRight: const Radius.circular(1.5),
      ),
      win,
    );
    canvas.drawRect(
      Rect.fromLTWH(o.dx + 2, o.dy + h * 0.52, w - 4, 2.2),
      Paint()..color = const Color(0xFFFF7A1F),
    );
    // Ghoomte pahiye
    final spin = clock.scroll * 3;
    for (final wx in const [9.0, 29.0]) {
      final c = Offset(o.dx + wx, o.dy + h * 0.8);
      canvas.drawCircle(c, 4.6, Paint()..color = const Color(0xFF2B2E36));
      canvas.drawCircle(c, 2.2, Paint()..color = const Color(0xFFDDDDDD));
      canvas.drawLine(
        c + Offset(math.cos(spin), math.sin(spin)) * 3.6,
        c - Offset(math.cos(spin), math.sin(spin)) * 3.6,
        Paint()
          ..color = const Color(0xFF8A8F99)
          ..strokeWidth = 1.2,
      );
    }
    // Headlight
    canvas.drawCircle(
      Offset(o.dx + w - 1.5, o.dy + h * 0.6),
      1.8,
      Paint()..color = const Color(0xFFFFF6C2),
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => old.clock != clock;
}
