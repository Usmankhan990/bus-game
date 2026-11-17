import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import 'theme.dart';

/// "Candy" 3D button: gol kinare, chamakdar 3D gradient, glossy shimmer sweep,
/// springy press bounce, aur optional gentle pulse animation.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    this.label = '',
    required this.onPressed,
    this.color = AppColors.green,
    this.icon,
    this.leading,
    this.fontSize = 24,
    this.height = 60,
    this.width,
    this.pulse = false,
    this.shimmer = false,
    this.radius,
  });

  /// Hara (primary) CTA button
  const CandyButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.fontSize = 24,
    this.height = 60,
    this.width,
    this.pulse = false,
    this.shimmer = true,
  }) : color = AppColors.green,
       radius = null;

  /// Narangi (secondary) button
  const CandyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.fontSize = 24,
    this.height = 60,
    this.width,
    this.pulse = false,
    this.shimmer = true,
  }) : color = AppColors.orange,
       radius = null;

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final Widget? leading;
  final double fontSize;
  final double height;
  final double? width;
  final bool pulse;
  final bool shimmer;
  final double? radius;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool get _wantsAnim =>
      widget.onPressed != null && (widget.pulse || widget.shimmer);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnimation());
  }

  @override
  void didUpdateWidget(CandyButton old) {
    super.didUpdateWidget(old);
    if (old.pulse != widget.pulse ||
        old.shimmer != widget.shimmer ||
        (old.onPressed == null) != (widget.onPressed == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnimation());
    }
  }

  void _syncAnimation() {
    if (!mounted) return;
    if (_wantsAnim) {
      if (!_anim.isAnimating) _anim.repeat();
    } else if (_anim.isAnimating) {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.onPressed == null) return;
    AudioService.instance.play(Sfx.button, volume: 0.6);
    HapticService.instance.select();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = enabled ? widget.color : AppColors.grey;
    final top = Color.lerp(base, Colors.white, 0.28)!;
    final bottom = Color.lerp(base, Colors.black, 0.08)!;
    final lip = Color.lerp(base, Colors.black, 0.30)!;
    final r = widget.radius ?? widget.height / 2;
    const depth = 5.0;
    final offset = _down ? depth - 1 : 0.0;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          if (widget.label.isNotEmpty) const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            color: Colors.white,
            size: widget.fontSize * 1.08,
            shadows: const [
              Shadow(color: Color(0x45000000), offset: Offset(0, 1.5)),
            ],
          ),
          if (widget.label.isNotEmpty) const SizedBox(width: 8),
        ],
        if (widget.label.isNotEmpty)
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(
                widget.fontSize,
                outlined: widget.fontSize >= 18,
              ),
            ),
          ),
      ],
    );

    Widget buildBody(double shimmerPhase) {
      return SizedBox(
        width: widget.width,
        height: widget.height + depth,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bottom 3D lip + soft ambient glow
            Positioned(
              left: 0,
              right: 0,
              top: depth,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: lip,
                  borderRadius: BorderRadius.circular(r),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: Color.lerp(
                              lip,
                              Colors.black,
                              0.25,
                            )!.withValues(alpha: 0.34),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            // Top glossy cap
            AnimatedPositioned(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              top: offset,
              height: widget.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [top, base, bottom],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.42),
                          width: 1.4,
                        ),
                      ),
                    ),
                    // Top specular glaze
                    Positioned(
                      left: r * 0.25,
                      right: r * 0.25,
                      top: 3,
                      height: widget.height * 0.34,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.38),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Glossy diagonal shimmer sweep
                    if (enabled && widget.shimmer && shimmerPhase >= 0)
                      FractionallySizedBox(
                        widthFactor: 0.42,
                        alignment: Alignment(
                          -1.8 + shimmerPhase * 3.6,
                          0,
                        ),
                        child: Transform.rotate(
                          angle: 0.38,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.34),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: row,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Widget button = _wantsAnim
        ? AnimatedBuilder(
            animation: _anim,
            builder: (_, _) {
              final v = _anim.value;
              final shimmerPhase = v < 0.48 ? v / 0.48 : -1.0;
              final pulseScale = widget.pulse
                  ? 1.0 + 0.045 * math.sin(v * math.pi * 2)
                  : 1.0;
              return Transform.scale(
                scale: pulseScale,
                child: buildBody(shimmerPhase),
              );
            },
          )
        : buildBody(-1.0);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: _tap,
        child: AnimatedScale(
          scale: _down ? 0.91 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutBack,
          child: button,
        ),
      ),
    );
  }
}

/// Gol-kinaron wala chhota icon button (top bar reset / pause waghera) —
/// shimmer sweep + spring bounce ke sath.
class CandyIconButton extends StatelessWidget {
  const CandyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.blue,
    this.size = 50,
    this.shimmer = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final bool shimmer;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    child: CandyButton(
      icon: icon,
      onPressed: onPressed,
      color: color,
      height: size,
      fontSize: size * 0.48,
      radius: size * 0.32,
      shimmer: shimmer,
    ),
  );
}
