import 'dart:math' as math;

import '../../models/bus_data.dart';

/// Ghoomi hui rectangle (oriented box). Gaadiyon ki takkar check karne ke liye.
class Obb {
  Obb(this.cx, this.cy, this.halfW, this.halfL, double angle)
    : ux = math.cos(angle),
      uy = math.sin(angle),
      fx = math.sin(angle),
      fy = -math.cos(angle);

  final double cx;
  final double cy;

  /// Aadhi chaurai (side ki taraf) aur aadhi lambai (aage ki taraf)
  final double halfW;
  final double halfL;

  /// Side wala axis (u) aur aage wala axis (f)
  final double ux;
  final double uy;
  final double fx;
  final double fy;

  List<(double, double)> get corners => [
    for (final s in const [(-1, -1), (1, -1), (1, 1), (-1, 1)])
      (
        cx + ux * halfW * s.$1 + fx * halfL * s.$2,
        cy + uy * halfW * s.$1 + fy * halfL * s.$2,
      ),
  ];

  /// Kisi axis par is rectangle ka "radius" (aadha phailaav)
  double _radiusOn(double ax, double ay) =>
      halfW * (ux * ax + uy * ay).abs() + halfL * (fx * ax + fy * ay).abs();

  /// Do rectangles ek doosre ko chhoo rahi hain? (Separating Axis Test)
  /// [margin] > 0 ho to thoda faasla bhi takkar mana jata hai.
  bool overlaps(Obb o, {double margin = 0}) {
    final dx = o.cx - cx;
    final dy = o.cy - cy;
    for (final (ax, ay) in [(ux, uy), (fx, fy), (o.ux, o.uy), (o.fx, o.fy)]) {
      final dist = (dx * ax + dy * ay).abs();
      if (dist > _radiusOn(ax, ay) + o._radiusOn(ax, ay) + margin) return false;
    }
    return true;
  }

  bool contains(double px, double py) {
    final dx = px - cx;
    final dy = py - cy;
    return (dx * ux + dy * uy).abs() <= halfW &&
        (dx * fx + dy * fy).abs() <= halfL;
  }

  /// Poori rectangle board ke andar hai?
  bool insideBoard(int cols, int rows, {double pad = 0.02}) {
    for (final (x, y) in corners) {
      if (x < pad || y < pad || x > cols - pad || y > rows - pad) return false;
    }
    return true;
  }
}

/// Gaadiyon ki geometry ke madadgar functions
class Geo {
  /// Gaadi ki rectangle. [extend] = aage ki taraf kitna lamba karna hai
  /// (chalti gaadi jitni jagah se guzregi). [inflate] = har taraf thoda bada.
  static Obb busBox(BusData b, {double extend = 0, double inflate = 0}) => Obb(
    b.cx + b.fx * extend / 2,
    b.cy + b.fy * extend / 2,
    BusData.bodyWidth / 2 + inflate,
    b.bodyLength / 2 + extend / 2 + inflate,
    b.angle,
  );

  /// Gaadi ko kitna aage jana hai taa ke poori board se bahar nikal jaye
  static double exitDistance(BusData b, int cols, int rows) {
    var t = double.infinity;
    if (b.fx > 1e-9) t = math.min(t, (cols - b.cx) / b.fx);
    if (b.fx < -1e-9) t = math.min(t, -b.cx / b.fx);
    if (b.fy > 1e-9) t = math.min(t, (rows - b.cy) / b.fy);
    if (b.fy < -1e-9) t = math.min(t, -b.cy / b.fy);
    return t + b.bodyLength / 2 + BusData.bodyWidth;
  }

  /// Nikalte waqt gaadi jis jagah se guzregi (poora rasta)
  static Obb pathBox(BusData b, int cols, int rows) =>
      busBox(b, extend: exitDistance(b, cols, rows));
}
