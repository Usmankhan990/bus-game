import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Level shuru hote hi screen ke beech se guzarti patti ("HARD" / "EASY").
/// Taps ko nahi rokti (IgnorePointer).
class LevelBanner extends StatefulWidget {
  const LevelBanner({
    super.key,
    required this.text,
    required this.color,
    this.onFinished,
  });

  final String text;
  final Color color;
  final VoidCallback? onFinished;

  @override
  State<LevelBanner> createState() => _LevelBannerState();
}

class _LevelBannerState extends State<LevelBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          // 0-0.2: andar aao, 0.2-0.8: ruko, 0.8-1: bahar jao
          final double dx;
          if (t < 0.2) {
            dx = 1 - Curves.easeOutBack.transform(t / 0.2);
          } else if (t < 0.8) {
            dx = 0;
          } else {
            dx = -Curves.easeIn.transform((t - 0.8) / 0.2);
          }
          if (t >= 1) return const SizedBox.shrink();
          return FractionalTranslation(
            translation: Offset(dx, 0),
            child: child,
          );
        },
        child: Center(
          child: Container(
            height: 92,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.color,
              border: const Border.symmetric(
                horizontal: BorderSide(color: Color(0xFFFFD54A), width: 6),
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), offset: Offset(0, 6)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.text,
              style: AppText.title(
                46,
                color: const Color(0xFFFFE27A),
                outline: const Color(0xFF5A1010),
              ).copyWith(letterSpacing: 2),
            ),
          ),
        ),
      ),
    );
  }
}
