import 'package:flutter/material.dart';

/// Game ke saare rang ek jagah. Rang badalne hon to sirf yahan badlein.
class GamePalette {
  /// Gaadiyon aur passengers ke rang (index = rang ka number).
  /// Halke (pastel) khilone jaise rang, magar ek doosre se saaf alag.
  /// Blender script (tool/blender/make_sprites.py) ke COLORS jaise hi.
  static const List<Color> busColors = [
    Color(0xFFEF394C), // red
    Color(0xFF329CF5), // blue
    Color(0xFF20BD78), // green
    Color(0xFFFFD21C), // yellow
    Color(0xFF9B35ED), // purple
    Color(0xFFFF8B24), // orange
    Color(0xFFED48BF), // pink
    Color(0xFF22D8D5), // turquoise
  ];

  static Color bus(int index) => busColors[index % busColors.length];

  // Manzar (scene) ke rang: halka farsh, kaali sadak
  static const Color floor = Color(0xFFC6CBD8);
  static const Color floorLine = Color(0xFFCDD4DF);
  static const Color board = Color(0xFFCDD2DF);
  static const Color boardEdge = Color(0xFFC2C9D5);
  static const Color arenaWall = Color(0xFFF7F8FB);
  static const Color arenaWallShade = Color(0xFFB9C1CE);
  static const Color arenaFloor = Color(0xFFE9ECF1);
  static const Color grass = Color(0xFF8CD45E);
  static const Color grassDark = Color(0xFF6DB848);
  static const Color road = Color(0xFF7B7D91);
  static const Color roadLine = Color(0xFFF5F5F5);
  static const Color curb = Color(0xFFEFF1F5);
  static const Color bayLine = Color(0xFFDADDE4);
  static const Color lockedBay = Color(0xFF7BD389);

  // Purane naam (kuch jagah ab bhi istemal hote hain)
  static const Color skyTop = floor;
  static const Color skyBottom = floor;
  static const Color tileLight = board;
  static const Color tileDark = boardEdge;
  static const Color slotBay = road;
  static const Color sidewalk = arenaFloor;
  static const Color sidewalkEdge = arenaWallShade;

  static const Color skin = Color(0xFFFFD7B0);
  static const Color glass = Color(0xFFCFF1FF);
  static const Color tire = Color(0xFF2B2E36);
  static const Color headlight = Color(0xFFFFF59D);

  /// Rang ko thoda gehra karna (border aur saaye ke liye)
  static Color darker(Color c, [double amount = 0.28]) =>
      Color.lerp(c, Colors.black, amount)!;

  /// Rang ko thoda halka karna (chamak ke liye)
  static Color lighter(Color c, [double amount = 0.35]) =>
      Color.lerp(c, Colors.white, amount)!;
}
