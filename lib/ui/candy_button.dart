import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import 'theme.dart';

/// "Candy" 3D button: gol kinare, upar chamakdar gradient, neeche gehra mota
/// kinara (utha hua lagta hai). Dabane par neeche dabta hai, tap sound + haptic.
/// [onPressed] null ho to grey (band).
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
    this.radius,
  });

  /// Hara (main) button
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
  }) : color = AppColors.orange,
       radius = null;

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  /// Icon ki jagah koi widget (maslan sikka)
  final Widget? leading;
  final double fontSize;
  final double height;
  final double? width;

  /// Halka sa saans lena (Play button ke liye)
  final bool pulse;
  final double? radius;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  void _tap() {
    AudioService.instance.play(Sfx.button, volume: 0.6);
    HapticService.instance.select();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = enabled ? widget.color : AppColors.grey;
    final edge = AppColors.darker(base, 0.35);
    final h = widget.height;
    final depth = (h * 0.11).clamp(4.0, 8.0);
    final r = widget.radius ?? h * 0.36;
    final push = _down ? depth * 0.75 : 0.0;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leading != null) widget.leading!,
        if (widget.icon != null)
          Icon(
            widget.icon,
            color: Colors.white,
            size: widget.fontSize * 1.1,
            shadows: const [
              Shadow(color: Color(0x66000000), offset: Offset(0, 2)),
            ],
          ),
        if ((widget.icon != null || widget.leading != null) &&
            widget.label.isNotEmpty)
          SizedBox(width: widget.fontSize * 0.3),
        if (widget.label.isNotEmpty)
          Text(
            widget.label,
            maxLines: 1,
            style: AppText.title(
              widget.fontSize,
              outline: AppColors.darker(base, 0.5),
            ),
          ),
      ],
    );

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              _tap();
            }
          : null,
      child: SizedBox(
        width: widget.width,
        height: h + depth,
        child: Stack(
          children: [
            // Neeche ka gehra kinara (3D)
            Positioned.fill(
              top: depth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: edge,
                  borderRadius: BorderRadius.circular(r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330B1E3A),
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              left: 0,
              right: 0,
              top: push,
              height: h,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.lighter(base, 0.3), base],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Upar ki chamak ki patti
                    Positioned(
                      left: r * 0.5,
                      right: r * 0.5,
                      top: h * 0.08,
                      height: h * 0.2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(h),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.label.isEmpty ? 4 : 14,
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final pulse = _pulse;
    if (pulse != null && enabled) {
      button = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.045 * math.sin(pulse.value * math.pi),
          child: child,
        ),
        child: button,
      );
    }
    return button;
  }
}

/// Chhota gol-kinaron wala sirf-icon candy button (pause, restart, settings)
class CandyIconButton extends StatelessWidget {
  const CandyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.blue,
    this.size = 50,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    child: CandyButton(
      icon: icon,
      onPressed: onPressed,
      color: color,
      height: size,
      fontSize: size * 0.48,
      radius: size * 0.3,
    ),
  );
}
