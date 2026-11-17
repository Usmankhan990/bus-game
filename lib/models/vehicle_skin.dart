import 'bus_data.dart';

/// Garage ki khaas gaadiyan. Stars se khulti hain; chuni hui gaadi us lambai
/// ki saari gaadiyon ki jagah levels mein aati hai (rang wahi rehta hai).
/// Tasveerein: `assets/sprites_v2/skin_<id>_<rang>_<rukh>.webp` (Blender:
/// tool/blender/render_reference_sprites.py ... skins)
enum VehicleSkin {
  taxi('taxi', 'Taxi', 2, 45, 3),
  sports('sports', 'Sports Car', 2, 75, 0),
  police('police', 'Police Van', 3, 110, 1),
  icecream('icecream', 'Ice-Cream Van', 3, 150, 6),
  school('school', 'School Bus', 4, 200, 3),
  double('double', 'Double-Decker', 4, 260, 0);

  const VehicleSkin(
    this.id,
    this.title,
    this.length,
    this.cost,
    this.previewColor,
  );

  /// Save aur tasveer ke naam ke liye
  final String id;
  final String title;

  /// 2 = car (16 seats), 3 = van (24), 4 = bus (40)
  final int length;

  /// Kitne stars chahiye
  final int cost;

  /// Garage mein kis rang mein dikhe
  final int previewColor;

  int get seats => capacityForLength(length);

  static VehicleSkin? byId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}
