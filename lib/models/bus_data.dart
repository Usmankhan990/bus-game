import 'dart:math' as math;

import 'direction.dart';

/// Gaadi ki lambai (size) ke hisaab se seats: chhoti car 16, van 24, lambi bus 40
int capacityForLength(int length) => switch (length) {
  <= 2 => 16,
  3 => 24,
  _ => 40,
};

/// Ek gaadi ka data (sirf maloomat, drawing nahi).
///
/// Board ek khula maidan hai jis ka size [cols] x [rows] "units" hai (1 unit = 1 purana cell).
/// Gaadi kisi bhi angle par khadi ho sakti hai: (cx, cy) us ka darmiyan hai aur
/// [angle] us ka rukh (0 = upar, ghadi ki sui ki taraf badhta hai, radians mein).
class BusData {
  BusData({
    required this.id,
    required this.cx,
    required this.cy,
    required this.angle,
    required this.color,
    required this.order,
    this.length = 2,
  });

  /// Purane grid wale tareeqe se: head cell (x, y), rukh aur lambai
  factory BusData.onGrid({
    required int id,
    required int x,
    required int y,
    required Dir dir,
    required int color,
    required int order,
    int length = 2,
  }) => BusData(
    id: id,
    cx: x + 0.5 - dir.dx * (length - 1) / 2,
    cy: y + 0.5 - dir.dy * (length - 1) / 2,
    angle: dir.angle,
    color: color,
    order: order,
    length: length,
  );

  final int id;
  double cx;
  double cy;
  double angle;

  /// Size: 2 = car, 3 = van, 4 = lambi bus
  final int length;

  /// Rang ka number (GamePalette mein index). Shuffle booster isay badal sakta hai.
  int color;

  /// Level banate waqt gaadi kis number par rakhi gayi.
  /// Bari order wali gaadi pehle nikal sakti hai (hal karne ka order ulta hai).
  int order;

  /// Board par har gaadi ka size chhota aur saaf rakhne ka scale factor
  static const double sizeScale = 0.78;

  /// Gaadi ki asal lambai aur chaurai (units mein)
  static const double bodyWidth = 0.78 * sizeScale;
  double get bodyLength => (length - 0.12) * sizeScale;

  /// Kitni seats hain
  int get capacity => capacityForLength(length);

  /// Aage ki taraf ka unit vector
  double get fx => math.sin(angle);
  double get fy => -math.cos(angle);

  BusData copy() => BusData(
    id: id,
    cx: cx,
    cy: cy,
    angle: angle,
    color: color,
    order: order,
    length: length,
  );
}
