import 'package:flutter/material.dart';

/// Poori game ke rang ek jagah. Kuch badalna ho to sirf yahan badlein.
class AppColors {
  // Candy buttons (upar ka rang, neeche ka gehra kinara)
  static const Color green = Color(0xFF38C978);
  static const Color greenDark = Color(0xFF22965A);
  static const Color orange = Color(0xFFFFAD32);
  static const Color orangeDark = Color(0xFFE07A0E);
  static const Color blue = Color(0xFF2389E8);
  static const Color blueDark = Color(0xFF1563B3);
  static const Color cyan = Color(0xFF76D5FF);
  static const Color purple = Color(0xFF8655EA);
  static const Color purpleDark = Color(0xFF5B33B5);
  static const Color red = Color(0xFFF2545B);
  static const Color redDark = Color(0xFFC0303A);
  static const Color pink = Color(0xFFFF6FB5);
  static const Color pinkDark = Color(0xFFC93E86);
  static const Color teal = Color(0xFF26C6BA);
  static const Color tealDark = Color(0xFF128F86);
  static const Color grey = Color(0xFFB9C3D1);
  static const Color greyDark = Color(0xFF8592A6);

  // Popups: halka neela frame, andar safed card
  static const Color panel = Color(0xFFCFE6FB);
  static const Color panelBorder = Color(0xFF5FA3E3);
  static const Color cream = Color(0xFFFFFFFF);
  static const Color creamLine = Color(0xFFD9E6F2);
  static const Color background = Color(0xFFF3F8FC);

  // Text
  static const Color ink = Color(0xFF22344D);
  static const Color inkSoft = Color(0xFF4F6280);
  static const Color inkMuted = Color(0xFF7D8BA0);
  static const Color outline = Color(0xFF2B3A55);

  static const Color coin = Color(0xFFFFC542);
  static const Color coinDark = Color(0xFFE09B00);
  static const Color gold = Color(0xFFFFC542);

  /// Kisi rang ka gehra (kinare wala) roop
  static Color darker(Color c, [double t = 0.32]) =>
      Color.lerp(c, Colors.black, t)!;

  static Color lighter(Color c, [double t = 0.35]) =>
      Color.lerp(c, Colors.white, t)!;
}

/// Faasle (padding/margin) ek hi paimane par
class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Kinaron ki golai
class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
}

/// Saaye (gehrai) — har card/panel yahi istemal kare
class AppShadows {
  /// Chhote card ke neeche halka saaya
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x1F1B3358), blurRadius: 8, offset: Offset(0, 3)),
  ];

  /// Popup panel ka gehra, naram saaya
  static const List<BoxShadow> panel = [
    BoxShadow(color: Color(0x4D0B1E3A), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x330B1E3A), blurRadius: 2, offset: Offset(0, 4)),
  ];

  /// Upar tairte HUD (level badge, coin pill)
  static const List<BoxShadow> hud = [
    BoxShadow(color: Color(0x332B3A55), blurRadius: 6, offset: Offset(0, 3)),
  ];
}

/// Text ke styles. Headings aur buttons: Lilita (mota cartoon), baqi: Fredoka.
class AppText {
  static const String display = 'Lilita';
  static const String body = 'Fredoka';

  /// Mota cartoon text, gehre kinare (outline) aur neeche saaye ke saath
  static TextStyle title(
    double size, {
    Color color = Colors.white,
    Color outline = AppColors.outline,
    bool outlined = true,
  }) {
    final o = (size * 0.07).clamp(1.2, 3.0);
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      color: color,
      height: 1.1,
      letterSpacing: 0.3,
      shadows: outlined
          ? [
              for (final d in const [
                Offset(1, 0),
                Offset(-1, 0),
                Offset(0, 1),
                Offset(0, -1),
                Offset(0.7, 0.7),
                Offset(-0.7, 0.7),
                Offset(0.7, -0.7),
                Offset(-0.7, -0.7),
              ])
                Shadow(color: outline, offset: d * o),
              Shadow(color: outline, offset: Offset(0, o * 1.8)),
            ]
          : const [],
    );
  }

  /// Saada parhne wala text (popup ke andar)
  static TextStyle text(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontFamily: body,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.2,
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: AppText.body,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xE6302010),
    ),
  );
}
