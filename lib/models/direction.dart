import 'dart:math' as math;

/// Bus ka rukh (jidhar us ka agla hissa hai).
/// Grid mein x daayen taraf badhta hai aur y neeche ki taraf.
enum Dir {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Dir(this.dx, this.dy);

  final int dx;
  final int dy;

  /// Canvas par ghumane ka angle (radian). Bus ki drawing "upar" munh karke bani hai.
  double get angle => switch (this) {
    Dir.up => 0,
    Dir.right => math.pi / 2,
    Dir.down => math.pi,
    Dir.left => -math.pi / 2,
  };
}
