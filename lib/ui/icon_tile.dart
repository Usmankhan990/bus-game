import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import 'theme.dart';
import 'game_art.dart';

/// Gol-kinaron wala rangeen tile: bada icon, neeche naam, chahein to
/// laal notification dot ([dot]) ya ginti ka badge ([count]; 0 par hara "+").
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

  /// Chalu halat (maslan VIP chunne ka intezar): laal kinara aur halka jhoomna
  final bool active;
  final Color labelColor;
  final bool enabled;
  final String? art;
  final bool compact;

  @override
  State<IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<IconTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final base = widget.enabled ? widget.color : AppColors.grey;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        AudioService.instance.play(Sfx.button, volume: 0.6);
        HapticService.instance.select();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: s + 10,
              height: s + 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 3D tile: neeche gehra kinara
                  Positioned(
                    left: 5,
                    top: 6,
                    width: s,
                    height: s,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.darker(base, 0.35),
                        borderRadius: BorderRadius.circular(s * 0.3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 5,
                    top: 0,
                    width: s,
                    height: s,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.lighter(base, 0.35), base],
                        ),
                        borderRadius: BorderRadius.circular(s * 0.3),
                        border: Border.all(
                          color: widget.active ? AppColors.red : Colors.white,
                          width: widget.active ? 4 : 3,
                        ),
                      ),
                      child: widget.art != null
                          ? (widget.compact
                                // Booster card: icon upar, neeche naam ke liye jagah
                                ? Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      s * 0.08,
                                      s * 0.02,
                                      s * 0.08,
                                      s * 0.24,
                                    ),
                                    child: Transform.scale(
                                      scale: 1.35,
                                      child: GameArt(
                                        widget.art!,
                                        size: s * 0.74,
                                      ),
                                    ),
                                  )
                                // Home: bara 3D icon, tile se thoda bahar (sticker jaisa)
                                : Transform.translate(
                                    offset: Offset(0, -s * 0.04),
                                    child: Transform.scale(
                                      scale: 1.22,
                                      child: GameArt(
                                        widget.art!,
                                        size: s * 0.9,
                                      ),
                                    ),
                                  ))
                          : Icon(
                              widget.icon,
                              color: Colors.white,
                              size: s * 0.56,
                              shadows: [
                                Shadow(
                                  color: AppColors.darker(base, 0.5),
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (widget.compact)
                    Positioned(
                      left: 5,
                      right: 5,
                      bottom: 5,
                      child: Center(
                        child: Text(
                          widget.label,
                          style: AppText.title(
                            (s * 0.18).clamp(11.0, 14.0),
                            outline: const Color(0xFF36658B),
                          ),
                        ),
                      ),
                    ),
                  if (widget.dot)
                    const Positioned(right: 0, top: -4, child: _Dot()),
                  if (widget.count != null)
                    Positioned(
                      right: -4,
                      top: -6,
                      child: _CountBadge(count: widget.count!),
                    ),
                ],
              ),
            ),
            if (!widget.compact) const SizedBox(height: 2),
            if (!widget.compact)
              Text(
                widget.label,
                maxLines: 1,
                style: AppText.title(
                  (s * 0.22).clamp(11.0, 16.0),
                  color: widget.labelColor,
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
        BoxShadow(color: Color(0x44000000), offset: Offset(0, 1)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: empty ? AppColors.green : AppColors.red,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      alignment: Alignment.center,
      child: empty
          ? const Icon(Icons.add_rounded, color: Colors.white, size: 18)
          : Text('$count', style: AppText.title(14)),
    );
  }
}
