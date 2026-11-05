/// Garage ki khaas gaadiyan. Stars se khulti hain; chuni hui gaadi us lambai
/// ki saari gaadiyon ki jagah levels mein aati hai (rang wahi rehta hai).
/// Tasveerein: `assets/sprites_v2/skin_<id>_<rang>_<rukh>.webp` (Blender:
/// tool/blender/render_reference_sprites.py ... skins)
enum VehicleSkin {
  taxi('taxi', 'Taxi', 2, 200, 3),
  sports('sports', 'Sports Car', 2, 300, 0),
  police('police', 'Police Van', 3, 400, 1),
  icecream('icecream', 'Ice-Cream Van', 3, 500, 6),
  school('school', 'School Bus', 4, 600, 3),
  double('double', 'Double-Decker', 4, 700, 0);

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

  /// 2 = car (4 seats), 3 = van (6), 4 = bus (10)
  final int length;

  /// Kitne stars chahiye
  final int cost;

  /// Garage mein kis rang mein dikhe
  final int previewColor;

  int get seats => switch (length) {
    2 => 4,
    3 => 6,
    _ => 10,
  };

  static VehicleSkin? byId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}
