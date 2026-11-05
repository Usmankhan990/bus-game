import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import 'theme.dart';

/// Popup kholna: peeche screen dim, popup "pop" (chhota se bada) ho kar khule
/// aur band hote waqt wapis chhota ho.
Future<T?> showGamePopup<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool dismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'popup',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, _, _) =>
        Material(type: MaterialType.transparency, child: builder(context)),
    transitionBuilder: (context, a, _, child) {
      final scale = a.status == AnimationStatus.reverse
          ? Curves.easeIn.transform(a.value)
          : Curves.easeOutBack.transform(a.value);
      return Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * scale, child: child),
      );
    },
  );
}

/// Popup ka panel: upar heading ka ribbon, kone par narangi "X",
/// andar halka cream hissa ([children]) aur neeche buttons ([footer]).
class GamePopup extends StatelessWidget {
  const GamePopup({
    super.key,
    required this.title,
    required this.content,
    this.footer = const [],
    this.onClose,
    this.ribbonColor = AppColors.orange,
    this.top,
    this.dim = false,
    this.animate = false,
    this.maxWidth = 380,
    this.panelColor,
    this.contentColor,
  });

  final String title;
  final List<Widget> content;
  final List<Widget> footer;

  /// Diya ho to upar daayen kone par "X"
  final VoidCallback? onClose;
  final Color ribbonColor;

  /// Panel ke upar kuch (maslan stars)
  final Widget? top;

  /// Screen ke andar (dialog ke baghair) dikhana ho to khud peeche dim karo
  final bool dim;

  /// Khud "pop" ho kar aaye (dialog ke baghair istemal par)
  final bool animate;
  final double maxWidth;
  final Color? panelColor;
  final Color? contentColor;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width * 0.9).clamp(260.0, maxWidth);
    Widget panel = SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 26),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              40,
              AppSpace.md,
              AppSpace.md + 2,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.lighter(panelColor ?? AppColors.panel, 0.35),
                  panelColor ?? AppColors.panel,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: panelColor == null
                    ? Colors.white
                    : AppColors.darker(panelColor!, .27),
                width: 3,
              ),
              boxShadow: AppShadows.panel,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: contentColor ?? AppColors.cream,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: contentColor == null
                        ? const [
                            // Andar dhansa hua card (upar halki lakeer)
                            BoxShadow(
                              color: Color(0x225FA3E3),
                              offset: Offset(0, -2),
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: contentColor == null
                          ? AppColors.creamLine
                          : Colors.white.withValues(alpha: .25),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
                if (footer.isNotEmpty) const SizedBox(height: 14),
                ...footer,
              ],
            ),
          ),
          // Heading ka ribbon (tab)
          Container(
            constraints: BoxConstraints(maxWidth: width * 0.78),
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.lighter(ribbonColor, 0.25), ribbonColor],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darker(ribbonColor, 0.4),
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Color(0x330B1E3A),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, maxLines: 1, style: AppText.title(28)),
            ),
          ),
          if (onClose != null)
            Positioned(right: -8, top: 14, child: CloseX(onTap: onClose!)),
        ],
      ),
    );

    if (animate) {
      panel = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + 0.4 * Curves.easeOutBack.transform(v),
            child: child,
          ),
        ),
        child: panel,
      );
    }

    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [?top, panel]),
      ),
    );
    // Material zaroori hai warna text ke neeche peeli lakeerein aati hain
    return Material(
      color: dim ? Colors.black.withValues(alpha: 0.6) : Colors.transparent,
      child: body,
    );
  }
}

/// Laal gol "X" (popup band karne ke liye)
class CloseX extends StatelessWidget {
  const CloseX({super.key, required this.onTap, this.size = 44});
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.play(Sfx.button, volume: 0.6);
        HapticService.instance.select();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF7A80), AppColors.redDark],
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), offset: Offset(0, 3)),
          ],
        ),
        child: Icon(
          Icons.close_rounded,
          color: Colors.white,
          size: size * 0.6,
          shadows: const [
            Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// Popup ke andar ka chhota bayan (beech mein)
class PopupText extends StatelessWidget {
  const PopupText(this.text, {super.key, this.size = 17});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center, style: AppText.text(size));
}
