import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../ui/candy_button.dart';
import '../ui/coin_pill.dart';
import '../ui/game_popup.dart';
import '../ui/theme.dart';
import 'confetti.dart';

/// Jeetne ki screen: stars, confetti, coins (jo ud kar coin pill mein jaate hain),
/// "2x Coins" (rewarded ad) aur "Next Level".
class WinOverlay extends StatefulWidget {
  const WinOverlay({
    super.key,
    required this.level,
    required this.reward,
    required this.stars,
    required this.onDouble,
    required this.onNext,
  });

  final int level;
  final int reward;
  final int stars;

  /// Rewarded ad dikhata hai; inaam mila to true
  final Future<bool> Function() onDouble;
  final VoidCallback onNext;

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay> {
  final _stackKey = GlobalKey();
  final _fromKey = GlobalKey();
  final _toKey = GlobalKey();
  bool _doubled = false;
  bool _busy = false;
  int _flight = 0;

  @override
  void initState() {
    super.initState();
    // Popup khulne ke baad coins udaao
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _flight++);
    });
  }

  Future<void> _double() async {
    setState(() => _busy = true);
    final ok = await widget.onDouble();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _doubled = ok;
      if (ok) _flight++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final coins = widget.reward * (_doubled ? 2 : 1);
    return Material(type: MaterialType.transparency, child: _content(coins));
  }

  Widget _content(int coins) {
    return Stack(
      key: _stackKey,
      children: [
        GamePopup(
          title: 'Level Complete!',
          ribbonColor: AppColors.green,
          dim: true,
          animate: true,
          top: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Positioned(
                top: -70,
                child: IgnorePointer(child: _SunRays(size: 300)),
              ),
              _Stars(count: widget.stars),
            ],
          ),
          content: [
            Text(
              'Level ${widget.level}',
              textAlign: TextAlign.center,
              style: AppText.title(
                22,
                color: AppColors.inkSoft,
                outlined: false,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoinIcon(key: _fromKey, size: 40),
                const SizedBox(width: 8),
                Text(
                  '+$coins',
                  style: AppText.title(34, color: AppColors.coin),
                ),
              ],
            ),
          ],
          footer: [
            ValueListenableBuilder<bool>(
              valueListenable: AdService.instance.rewardedReady,
              builder: (context, ready, _) => CandyButton(
                label: _doubled
                    ? 'Coins doubled!'
                    : _busy
                    ? 'Loading ad...'
                    : ready
                    ? '2x Coins'
                    : 'Ad not available',
                icon: Icons.play_circle_fill_rounded,
                color: AppColors.purple,
                fontSize: 21,
                height: 52,
                onPressed: ready && !_doubled && !_busy ? _double : null,
              ),
            ),
            // Do buttons ke darmiyan kafi faasla (ghalti se click na ho)
            const SizedBox(height: 16),
            CandyButton.primary(
              label: 'Next Level',
              onPressed: _busy ? null : widget.onNext,
              pulse: true,
            ),
          ],
        ),
        const Positioned.fill(child: Confetti()),
        // Upar baayen coin pill (coins yahan ud kar aate hain)
        Positioned(
          left: 12,
          top: MediaQuery.paddingOf(context).top + 8,
          child: CoinPill(iconKey: _toKey),
        ),
        if (_flight > 0)
          Positioned.fill(
            child: _FlyingCoins(
              key: ValueKey(_flight),
              stackKey: _stackKey,
              fromKey: _fromKey,
              toKey: _toKey,
            ),
          ),
      ],
    );
  }
}

/// Sikke [fromKey] se [toKey] tak mud kar udte hain (ek ke baad ek)
class _FlyingCoins extends StatefulWidget {
  const _FlyingCoins({
    super.key,
    required this.stackKey,
    required this.fromKey,
    required this.toKey,
  });

  final GlobalKey stackKey;
  final GlobalKey fromKey;
  final GlobalKey toKey;

  @override
  State<_FlyingCoins> createState() => _FlyingCoinsState();
}

class _FlyingCoinsState extends State<_FlyingCoins>
    with SingleTickerProviderStateMixin {
  static const _count = 10;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();
  Offset? _from;
  Offset? _to;
  int _landed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    _c.addListener(() {
      // Har sikka pohanchne par halki awaaz
      final landed = List.generate(
        _count,
        (i) => _t(i) >= 1,
      ).where((x) => x).length;
      if (landed > _landed) {
        _landed = landed;
        AudioService.instance.play(Sfx.board, volume: 0.3);
      }
    });
  }

  void _measure() {
    final stack =
        widget.stackKey.currentContext?.findRenderObject() as RenderBox?;
    final a = widget.fromKey.currentContext?.findRenderObject() as RenderBox?;
    final b = widget.toKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || a == null || b == null || !mounted) return;
    setState(() {
      _from = stack.globalToLocal(a.localToGlobal(a.size.center(Offset.zero)));
      _to = stack.globalToLocal(b.localToGlobal(b.size.center(Offset.zero)));
    });
  }

  double _t(int i) {
    final start = i * 0.05;
    return ((_c.value - start) / 0.5).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          children: [
            for (var i = 0; i < _count; i++)
              if (_t(i) > 0 && _t(i) < 1)
                () {
                  final t = Curves.easeInOut.transform(_t(i));
                  // Thoda bikhar kar phir mud kar pill ki taraf
                  final spread = Offset(
                    math.cos(i * 1.7) * 60,
                    math.sin(i * 2.3) * 40 - 40,
                  );
                  final ctrl = Offset.lerp(from, to, 0.3)! + spread;
                  final p = Offset(
                    (1 - t) * (1 - t) * from.dx +
                        2 * (1 - t) * t * ctrl.dx +
                        t * t * to.dx,
                    (1 - t) * (1 - t) * from.dy +
                        2 * (1 - t) * t * ctrl.dy +
                        t * t * to.dy,
                  );
                  return Positioned(
                    left: p.dx - 14,
                    top: p.dy - 14,
                    child: Transform.scale(
                      scale: 1.1 - 0.35 * t,
                      child: const CoinIcon(size: 28),
                    ),
                  );
                }(),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + i * 250),
              curve: Interval(i * 0.3, 1, curve: Curves.elasticOut),
              builder: (context, v, _) => Transform.scale(
                scale: v,
                child: Padding(
                  padding: EdgeInsets.only(bottom: i == 1 ? 18 : 0),
                  child: Icon(
                    Icons.star_rounded,
                    size: i == 1 ? 88 : 68,
                    color: i < count ? AppColors.coin : Colors.white24,
                    shadows: const [
                      Shadow(color: Color(0xFFB87800), offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Haarne ki screen: Continue (ad: +1 slot), Retry, Home
class FailOverlay extends StatefulWidget {
  const FailOverlay({
    super.key,
    required this.onContinue,
    required this.onRetry,
    required this.onHome,
  });

  /// Rewarded ad dikhata hai; inaam mila to true (game khud continue karti hai)
  final Future<bool> Function() onContinue;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  State<FailOverlay> createState() => _FailOverlayState();
}

class _FailOverlayState extends State<FailOverlay> {
  bool _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    await widget.onContinue();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return GamePopup(
      title: 'Out of Space!',
      ribbonColor: AppColors.red,
      dim: true,
      animate: true,
      content: [
        const Center(child: Text('😫', style: TextStyle(fontSize: 54))),
        const SizedBox(height: 6),
        const PopupText(
          'All parking spots are full.\nGet one more spot and keep playing?',
        ),
      ],
      footer: [
        ValueListenableBuilder<bool>(
          valueListenable: AdService.instance.rewardedReady,
          builder: (context, ready, _) => CandyButton(
            label: _busy
                ? 'Loading ad...'
                : ready
                ? 'Continue  +1 Spot'
                : 'Ad not available',
            icon: Icons.play_circle_fill_rounded,
            color: AppColors.purple,
            fontSize: 20,
            height: 54,
            onPressed: ready && !_busy ? _continue : null,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CandyButton.secondary(
                label: 'Home',
                height: 54,
                fontSize: 22,
                onPressed: _busy ? null : widget.onHome,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CandyButton.primary(
                label: 'Retry',
                height: 54,
                fontSize: 22,
                onPressed: _busy ? null : widget.onRetry,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stars ke peeche aahista ghoomti sunehri roshni ki kirnein
class _SunRays extends StatefulWidget {
  const _SunRays({required this.size});
  final double size;

  @override
  State<_SunRays> createState() => _SunRaysState();
}

class _SunRaysState extends State<_SunRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: RotationTransition(
      turns: _c,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _RaysPainter(),
      ),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.gold.withValues(alpha: 0.55),
          AppColors.gold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    const n = 12;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.12), c.dy + r * math.sin(a - 0.12))
        ..lineTo(c.dx + r * math.cos(a + 0.12), c.dy + r * math.sin(a + 0.12))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}
