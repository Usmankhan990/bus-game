import 'dart:ui';

/// Safar ke shehar. Har shehar [levelsPerCity] levels ka; aakhri shehar ke baad
/// safar dobara pehle shehar se (agle "tour" mein) shuru hota hai.
/// Jhanda: lib/ui/flag_icon.dart. Nishani ki tasveer: `assets/sprites/city_<id>.png` (Blender:
/// tool/blender/make_landmarks.py)
enum City {
  karachi(
    'karachi',
    'Karachi',
    'Pakistan',
    Color(0xFFF1DFB4),
    Color(0xFFE6CC94),
    Color(0xFF3AA6E0),
  ),
  lahore(
    'lahore',
    'Lahore',
    'Pakistan',
    Color(0xFFCFE8B4),
    Color(0xFFB7DA96),
    Color(0xFFB5523B),
  ),
  islamabad(
    'islamabad',
    'Islamabad',
    'Pakistan',
    Color(0xFFD3EBC0),
    Color(0xFFB9DDA0),
    Color(0xFF2F8F4E),
  ),
  dubai(
    'dubai',
    'Dubai',
    'UAE',
    Color(0xFFF6E4BE),
    Color(0xFFEBD09A),
    Color(0xFF5B8FC9),
  ),
  london(
    'london',
    'London',
    'United Kingdom',
    Color(0xFFC9E3B0),
    Color(0xFFADD08E),
    Color(0xFFE0302F),
  ),
  paris(
    'paris',
    'Paris',
    'France',
    Color(0xFFE3D7F2),
    Color(0xFFCFBFE6),
    Color(0xFF8A6A4A),
  ),
  newyork(
    'newyork',
    'New York',
    'USA',
    Color(0xFFD6DEE8),
    Color(0xFFBFCAD8),
    Color(0xFF3E6FA8),
  ),
  tokyo(
    'tokyo',
    'Tokyo',
    'Japan',
    Color(0xFFF3C9D1),
    Color(0xFFE9B9CA),
    Color(0xFFE8432F),
  );

  const City(
    this.id,
    this.name,
    this.country,
    this.ground,
    this.groundDark,
    this.accent,
  );

  final String id;
  final String name;
  final String country;

  /// Game ke upar wale hisse (hujoom ki zameen) ke rang
  final Color ground;
  final Color groundDark;

  /// Shehar ka khaas rang (map aur popup mein)
  final Color accent;

  static const int levelsPerCity = 20;

  /// Is level ka shehar
  static City of(int level) =>
      values[((level - 1) ~/ levelsPerCity) % values.length];

  /// Kaun sa tour (1 = pehla chakkar)
  static int tourOf(int level) =>
      (level - 1) ~/ (levelsPerCity * values.length) + 1;

  /// Is shehar mein kitne levels ho chuke (0..20)
  static int progressIn(int level) => (level - 1) % levelsPerCity;

  /// Is tour mein yeh shehar kis level se shuru hota hai
  int firstLevel(int tour) =>
      (tour - 1) * levelsPerCity * City.values.length +
      index * levelsPerCity +
      1;

  /// Level [level] is shehar ka pehla level hai?
  static bool startsCity(int level) => (level - 1) % levelsPerCity == 0;
}
