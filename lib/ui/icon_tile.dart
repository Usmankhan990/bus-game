import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import 'game_art.dart';
import 'theme.dart';

/// Gol-kinaron wala rangeen tile: chamakdar 3D surface, gentle floating art,
/// glossy shimmer sweep, notification dot ([dot]) ya count badge ([count]).
class IconTile extends StatefulWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.dot = false,
    this.count,
    this.size = 64,
    this.active = false,
    this.labelColor = Colors.white,
    this.enabled = true,
    this.art,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool dot;

  /// Booster ki ginti (null = badge nahi)
  final int? count;
  final double size;

  /// Chalu halat (maslan VIP chunne ka intezar): chamakdar kinara aur pulse
  final bool active;
  final Color labelColor;
  final bool enabled;
  final String? art;
  final bool compact;

  @override
  State<IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<IconTile>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnim());
  }

  @override
  void didUpdateWidget(IconTile old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled || old.active != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnim());
    }
  }

  void _syncAnim() {
    if (!mounted) return;
    if (widget.enabled) {
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

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final base = widget.enabled ? widget.color : AppColors.grey;
    final top = Color.lerp(base, Colors.white, 0.32)!;
    final bottom = Color.lerp(base, Colors.black, 0.08)!;
    final lip = Color.lerp(base, Colors.black, 0.30)!;
    final r = s * 0.28;
    const depth = 4.5;
    final phase = (widget.label.hashCode % 628) / 100.0;

    Widget buildTile(double t) {
      final bobY = widget.enabled
          ? math.sin(t * math.pi * 2 + phase) * 1.8
          : 0.0;
      final activeScale = widget.active
          ? 1.0 + 0.045 * math.sin(t * math.pi * 4)
          : 1.0;
      // Offset shimmer sweep per button so all 3 boosters don't flash at once
      final shifted = (t + (widget.label.hashCode % 5) * 0.16) % 1.0;
      final shimmerPhase = shifted < 0.42 ? shifted / 0.42 : -1.0;

      final artWidget = widget.art != null
          ? (widget.compact
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      4,
                      3,
                      4,
                      math.max(13, s * 0.25),
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Transform.scale(
                        scale: 1.35,
                        child: GameArt(widget.art!, size: s * 0.74),
                      ),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.contain,
                    child: Transform.scale(
                      scale: 1.22,
                      child: GameArt(widget.art!, size: s * 0.9),
                    ),
                  ))
          : Icon(
              widget.icon,
              color: Colors.white,
              size: s * 0.56,
              shadows: const [
                Shadow(color: Color(0x40000000), offset: Offset(0, 1.5)),
              ],
            );

      return Transform.scale(
        scale: activeScale,
        child: SizedBox(
          width: s + 10,
          height: s + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 3D bottom lip + colored glow shadow
              Positioned(
                left: 5,
                top: 4 + depth,
                width: s,
                height: s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: lip,
                    borderRadius: BorderRadius.circular(r),
                    boxShadow: widget.enabled
                        ? [
                            BoxShadow(
                              color:
                                  (widget.active
                                          ? const Color(0xFFFF6D00)
                                          : base)
                                      .withValues(
                                        alpha: widget.active ? 0.52 : 0.34,
                                      ),
                              blurRadius: widget.active ? 12 : 7,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Main animated tile face
              AnimatedPositioned(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutCubic,
                left: 5,
                top: _down ? 4.0 + depth - 1.0 : 4.0,
                width: s,
                height: s,
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
                            stops: const [0.0, 0.52, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(r),
                          border: Border.all(
                            color: widget.active
                                ? const Color(0xFFFFEB3B)
                                : Colors.white.withValues(alpha: 0.72),
                            width: widget.active ? 2.6 : 1.5,
                          ),
                        ),
                      ),
                      // Top glass reflection
                      Positioned(
                        left: 4,
                        right: 4,
                        top: 3,
                        height: s * 0.36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r * 0.8),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.36),
                                Colors.white.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Diagonal glossy shimmer sweep
                      if (widget.enabled && shimmerPhase >= 0)
                        FractionallySizedBox(
                          widthFactor: 0.45,
                          alignment: Alignment(
                            -1.8 + shimmerPhase * 3.6,
                            0,
                          ),
                          child: Transform.rotate(
                            angle: 0.42,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.32),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Floating inner art / icon
                      Transform.translate(
                        offset: Offset(0, _down ? 1.0 : bobY),
                        child: Center(child: artWidget),
                      ),
                      if (widget.compact)
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(
                                (s * 0.22).clamp(9.5, 12.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.dot) const Positioned(right: 0, top: 0, child: _Dot()),
              if (widget.count != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: _CountBadge(count: widget.count!),
                ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        AudioService.instance.play(Sfx.button, volume: 0.6);
        HapticService.instance.select();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.87 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.enabled
                ? AnimatedBuilder(
                    animation: _anim,
                    builder: (_, _) => buildTile(_anim.value),
                  )
                : buildTile(0.0),
            if (!widget.compact) const SizedBox(height: 2),
            if (!widget.compact)
              Text(
                widget.label,
                maxLines: 1,
                style: AppText.title(
                  14,
                  color: widget.labelColor,
                  outlined: widget.labelColor == Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: AppColors.red,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: const [
        BoxShadow(color: Color(0x30000000), blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: empty ? AppColors.green : AppColors.red,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: empty
          ? const Icon(Icons.add_rounded, color: Colors.white, size: 15)
          : Text('$count', style: AppText.title(14)),
    );
  }
}
