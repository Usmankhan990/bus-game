import 'dart:math' as math;

import '../../models/bus_data.dart';
import '../../models/direction.dart';
import '../../models/level_data.dart';
import 'geometry.dart';
import 'seeded_random.dart';
import 'solver.dart';

/// Board ka design: gaadiyon ke rukh kis tarah bichaye jayen
enum LayoutPattern {
  /// Har cell ka rukh random
  scatter,

  /// Gol chakkar (spiral) jaisa: har ring par gaadiyan ghadi ki sui ki taraf
  rings,

  /// Qataaren: ek qataar baayen, agli daayen
  lanes,

  /// Columns: ek upar, agla neeche
  columns,

  /// Darmiyan se bahar ki taraf
  burst,

  /// Pankha: neeche ek nuqte se bahar ki taraf tirchhi gaadiyan
  fan,

  /// 45 degree tirchhi qataaren (ek idhar, agli udhar)
  diagonal,

  /// Ghoomta hua bhanwar (darmiyan ke gird mudti gaadiyan)
  swirl,

  /// Mili-juli symmetric (seedhi + aadi + tirchhi pankhe jaisi) arrangement
  mosaic,
}

/// Har level ki shakal (outer silhouette) alag dikhne ke liye 7 board masks
/// (beech se khokhle holes nahi kaat-ta taa ke cars mein bade gaps na paden)
enum _BoardShape { full, diamond, oval, octagon, chamfer, shield, wedge }

/// Saare diverse layout designs — har level alag angle/flow ke sath aaye
const _levelPatterns = [
  LayoutPattern.mosaic,
  LayoutPattern.fan,
  LayoutPattern.diagonal,
  LayoutPattern.swirl,
  LayoutPattern.rings,
  LayoutPattern.lanes,
  LayoutPattern.columns,
  LayoutPattern.burst,
  LayoutPattern.scatter,
];

/// Breather levels bhi ek hi pattern na dohraayen
const _breatherPatterns = [
  LayoutPattern.burst,
  LayoutPattern.rings,
  LayoutPattern.fan,
  LayoutPattern.lanes,
  LayoutPattern.columns,
  LayoutPattern.diagonal,
];

/// Ek level ki mushkil ki settings
class LevelSpec {
  const LevelSpec({
    required this.cols,
    required this.rows,
    required this.buses,
    required this.colors,
    required this.shuffle,
    required this.maxLength,
    required this.longChance,
    required this.pattern,
    this.breather = false,
    this.difficulty = 0,
  });

  final int cols;
  final int rows;

  /// Kitni gaadiyan rakhni hain (koshish)
  final int buses;
  final int colors;

  /// Passengers ki line kitni shuffle ho (0 = bilkul nahi)
  final int shuffle;

  /// Sab se lambi gaadi kitne cells ki ho sakti hai (2-4)
  final int maxLength;

  /// Lambi gaadi aane ka chance (0..1)
  final double longChance;
  final LayoutPattern pattern;
  final bool breather;

  /// 0 = aam, 1 = HARD, 2 = SUPER HARD
  final int difficulty;
}

/// Levels code se banane wala class.
/// Har level ki apni unique arrangement hoti hai; restart par ([variant] > 0)
/// wahi arrangement rehti hai aur sirf rang shuffle hote hain.
class LevelGenerator {
  /// Rangon ki zyada se zyada tadaad (GamePalette mein itne rang hain)
  static const int maxColors = 8;

  /// Shuru mein khule slots
  static const int openSlots = 4;

  static int _imul32(int a, int b) {
    final aHi = (a >> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    return (aLo * bLo + (((aHi * bLo + aLo * bHi) << 16) & 0xFFFFFFFF)) &
        0xFFFFFFFF;
  }

  static int _mixSeed(int x) {
    var h = x & 0xFFFFFFFF;
    h ^= h >> 16;
    h = _imul32(h, 0x7FEB352D);
    h ^= h >> 15;
    h = _imul32(h, 0x846CA68B);
    h ^= h >> 16;
    return h & 0xFFFFFFFF;
  }

  /// Gaadiyon ki khalis arrangement signature (rang ke baghair): positions, angles aur lambai
  static String arrangementSignature(List<BusData> buses) {
    const twoPi = math.pi * 2;
    final items = [
      for (final b in buses)
        () {
          final a = ((b.angle % twoPi) + twoPi) % twoPi;
          return '${b.cx.toStringAsFixed(2)},${b.cy.toStringAsFixed(2)},${a.toStringAsFixed(2)},${b.length}';
        }(),
    ]..sort();
    return items.join('|');
  }

  static _BoardShape _shapeFor(int level) => level <= 2
      ? _BoardShape.full
      : _BoardShape.values[(level - 3) % _BoardShape.values.length];

  static int _symmetryFor(int level, LayoutPattern pattern) {
    if (level <= 1) return 0;
    final raw = _mixSeed(level * 3571 + 11) & 7;
    if (pattern == LayoutPattern.lanes || pattern == LayoutPattern.columns) {
      return raw & 3;
    }
    return raw;
  }

  /// Level number ke hisaab se mushkil
  static LevelSpec specFor(int level) {
    // Level 1 aur 2: aasaan shuruat, dono ki shakal aur pattern alag
    if (level <= 1) {
      return const LevelSpec(
        cols: 8,
        rows: 8,
        buses: 16,
        colors: 4,
        shuffle: 0,
        maxLength: 2,
        longChance: 0,
        pattern: LayoutPattern.mosaic,
      );
    }
    if (level == 2) {
      return const LevelSpec(
        cols: 9,
        rows: 9,
        buses: 25,
        colors: 5,
        shuffle: 1,
        maxLength: 3,
        longChance: 0.25,
        pattern: LayoutPattern.fan,
      );
    }

    // Grid ka size dheere dheere bada (16/24/40 seats ke sath zyada gaadiyan aur log)
    final (cols, rows, maxBuses) = switch (level) {
      // Lot poori chaudai mein hai, is liye grid takreeban chaukor
      < 6 => (10, 10, 35),
      < 11 => (11, 11, 44),
      < 25 => (12, 12, 56),
      < 45 => (13, 13, 68),
      _ => (14, 14, 80),
    };

    // Level 3 se hi yellow, purple, pink samait 7-8 rang shuru hon
    var colors = (6 + (level - 2) ~/ 3).clamp(7, maxColors);
    if (level == 3) colors = 7;
    // Shuru se hi lot bhara hua aur zyada gaadiyan/passengers hon
    var buses = (28 + (level - 3) * 2.6).round().clamp(28, maxBuses);
    var shuffle = (2 + level ~/ 10).clamp(2, 5);
    // Teeno size (car 16, van 24, bus 40) jaldi aa jayen
    final maxLength = level < 4 ? 3 : 4;
    final longChance = (0.3 + level * 0.01).clamp(0.3, 0.5);
    var pattern = _levelPatterns[(level - 3) % _levelPatterns.length];
    final breather = level % 10 == 0;
    // Har 10 mein se level 5 HARD aur level 9 SUPER HARD (level 9 se aage)
    final difficulty = breather
        ? 0
        : (level % 10 == 9 ? 2 : (level % 10 == 5 ? 1 : 0));
    if (difficulty > 0) {
      // Mushkil level: zyada mili hui line aur thodi zyada gaadiyan
      shuffle += difficulty;
      buses = (buses * (1 + 0.12 * difficulty)).round().clamp(28, maxBuses);
    }

    if (breather) {
      // Breather level: kam rang, kam gaadiyan, kam shuffle, magar har breather alag design
      colors = (colors - 3).clamp(3, maxColors);
      buses = (buses * 0.45).round();
      shuffle = 1;
      pattern =
          _breatherPatterns[((level ~/ 10) - 1).abs() %
              _breatherPatterns.length];
    }

    // Har rang ki gaadiyan barabar hon
    buses = (buses ~/ colors) * colors;
    if (buses < colors * 2) buses = colors * 2;

    return LevelSpec(
      cols: cols,
      rows: rows,
      buses: buses,
      colors: colors,
      shuffle: shuffle,
      maxLength: maxLength,
      longChance: longChance.toDouble(),
      pattern: pattern,
      breather: breather,
      difficulty: difficulty,
    );
  }

  static LevelData generate(int level, {int variant = 0}) {
    final spec = specFor(level);
    final base = _generateBase(level, spec);
    if (variant == 0) return base;
    return _withShuffledColors(level, spec, base, variant);
  }

  /// Level ki apni fixed aur unique physical arrangement banana
  static LevelData _generateBase(int level, LevelSpec spec) {
    final shape = _shapeFor(level);
    final sym = _symmetryFor(level, spec.pattern);

    LevelData? best;
    for (var attempt = 0; attempt < 20; attempt++) {
      final rng = SeededRandom(
        _mixSeed(level * 7919 + attempt * 104729 + 17),
      );
      var buses = _placeBuses(spec, rng, sym: sym, shape: shape);

      // Ginti rangon ki tadaad se poori taqseem honi chahiye
      final count = (buses.length ~/ spec.colors) * spec.colors;
      if (count < spec.colors * 2) continue;
      // Aakhri rakhi gaadiyan hatane se baqi gaadiyon ki sharat nahi toot-ti
      buses = buses.sublist(0, count);

      // Rang barabar taqseem karo
      final perColor = count ~/ spec.colors;
      final colors = <int>[
        for (var i = 0; i < perColor; i++)
          for (var c = 0; c < spec.colors; c++) c,
      ];
      rng.shuffle(colors);
      for (var i = 0; i < count; i++) {
        buses[i].color = colors[i];
      }

      final built = _buildSolvableData(level, spec, buses, rng);
      if (built.solved) return built.data;
      best ??= built.data;
    }
    return best!;
  }

  /// Restart par: gaadiyon ki positions, angles, lambai aur order bilkul wahi
  /// rakho, sirf unke rang aur matching passengers shuffle karo.
  static LevelData _withShuffledColors(
    int level,
    LevelSpec spec,
    LevelData base,
    int variant,
  ) {
    final baseColors = [for (final b in base.buses) b.color];
    if (baseColors.toSet().length < 2) return base;

    bool sameColors(List<int> c) {
      for (var i = 0; i < c.length; i++) {
        if (c[i] != baseColors[i]) return false;
      }
      return true;
    }

    LevelData? fallback;
    for (var attempt = 0; attempt < 24; attempt++) {
      final rng = SeededRandom(
        _mixSeed(level * 7919 ^ (variant * 1000003) + attempt * 104729 + 31),
      );
      final colors = List<int>.of(baseColors);
      rng.shuffle(colors);
      if (sameColors(colors)) continue;

      final buses = [
        for (var i = 0; i < base.buses.length; i++)
          base.buses[i].copy()..color = colors[i],
      ];
      final built = _buildSolvableData(level, spec, buses, rng);
      if (built.solved) return built.data;
      fallback ??= built.data;
    }
    return fallback ?? base;
  }

  static ({LevelData data, bool solved}) _buildSolvableData(
    int level,
    LevelSpec spec,
    List<BusData> buses,
    SeededRandom rng,
  ) {
    final solveOrder = buses.reversed.toList();
    final baseQueue = <int>[
      for (final b in solveOrder)
        for (var s = 0; s < b.capacity; s++) b.color,
    ];

    LevelData? fallback;
    for (var strength = spec.shuffle; strength >= 0; strength--) {
      for (var tries = 0; tries < (strength == 0 ? 1 : 6); tries++) {
        final queue = List<int>.of(baseQueue);
        _shuffleQueue(queue, strength, rng);
        final data = LevelData(
          level: level,
          cols: spec.cols,
          rows: spec.rows,
          buses: buses,
          passengers: queue,
          colorCount: spec.colors,
          slotCount: openSlots,
          isBreather: spec.breather,
          difficulty: spec.difficulty,
        );
        if (Solver.solveInOrder(data)) return (data: data, solved: true);
        fallback ??= data;
      }
    }
    return (data: fallback!, solved: false);
  }

  static bool _inShape(
    double px,
    double py,
    int cols,
    int rows,
    _BoardShape shape,
  ) {
    if (shape == _BoardShape.full) return true;
    final nx = (px - cols / 2) / math.max(1.0, cols / 2);
    final ny = (py - rows / 2) / math.max(1.0, rows / 2);
    return switch (shape) {
      _BoardShape.full => true,
      _BoardShape.diamond => nx.abs() + ny.abs() <= 1.38,
      _BoardShape.oval => nx * nx + ny * ny <= 1.12,
      _BoardShape.octagon =>
        nx.abs() + ny.abs() <= 1.50 && nx.abs() <= 0.96 && ny.abs() <= 0.96,
      _BoardShape.chamfer =>
        (nx.abs() - ny.abs()).abs() <= 1.15 && nx.abs() + ny.abs() <= 1.48,
      _BoardShape.shield =>
        ny >= -0.96 && (ny <= 0.25 || nx.abs() <= 1.24 - ny * 0.44),
      _BoardShape.wedge => nx.abs() + ny * 0.28 <= 1.04,
    };
  }

  /// Square board par 8 symmetries (ghoomana aur palatna) taa ke ek hi design har
  /// level par bilkul alag disha aur shakal mein dikhe.
  static (double, double, double) _transform(
    double px,
    double py,
    double angle,
    double cols,
    double rows,
    int sym,
  ) {
    var x = px;
    var y = py;
    var a = angle;
    if ((sym & 1) != 0) {
      x = cols - x;
      a = -a;
    }
    if ((sym & 2) != 0) {
      y = rows - y;
      a = math.pi - a;
    }
    if ((sym & 4) != 0 && (cols - rows).abs() < 1e-6) {
      final t = x;
      x = y;
      y = t;
      a = -math.pi / 2 - a;
    }
    return (x, y, a);
  }

  /// Grid wale design mein kisi cell ka pasandeeda rukh
  static Dir _preferred(
    LevelSpec s,
    int x,
    int y,
    SeededRandom rng, {
    int strip = 1,
    bool flip = false,
    bool cw = true,
    bool ringAlt = false,
  }) {
    switch (s.pattern) {
      case LayoutPattern.lanes:
        final e = ((y ~/ strip).isEven) ^ flip;
        return e ? Dir.left : Dir.right;
      case LayoutPattern.columns:
        final e = ((x ~/ strip).isEven) ^ flip;
        return e ? Dir.up : Dir.down;
      case LayoutPattern.burst:
        final dx = x - (s.cols - 1) / 2;
        final dy = y - (s.rows - 1) / 2;
        if (dx.abs() * s.rows > dy.abs() * s.cols) {
          return dx < 0 ? Dir.left : Dir.right;
        }
        return dy < 0 ? Dir.up : Dir.down;
      case LayoutPattern.rings:
        // Kaun si ring (bahar se andar) aur us par ghadi ki sui / ulat rukh
        final k = [
          x,
          y,
          s.cols - 1 - x,
          s.rows - 1 - y,
        ].reduce((a, b) => a < b ? a : b);
        final dirCw = ringAlt && k.isOdd ? !cw : cw;
        if (y == k && x < s.cols - 1 - k) return dirCw ? Dir.right : Dir.left;
        if (x == s.cols - 1 - k && y < s.rows - 1 - k) {
          return dirCw ? Dir.down : Dir.up;
        }
        if (y == s.rows - 1 - k && x > k) return dirCw ? Dir.left : Dir.right;
        return dirCw ? Dir.up : Dir.down;
      default:
        return Dir.values[rng.nextInt(4)];
    }
  }

  /// Heading vector (hx, hy) se angle (0 = upar, ghadi ki sui ki taraf)
  static double _angleOf(double hx, double hy) => math.atan2(hx, -hy);

  /// Mixed mosaic angle: center spine, horizontal belts, aur symmetric tirchhi wings
  static double _mosaicAngle(
    double cols,
    double rows,
    double px,
    double py,
    int variant, {
    double tilt = 0.29 * math.pi,
    double beltSplit = 0.0,
  }) {
    final cx = cols / 2, cy = rows / 2;
    final dx = px - cx, dy = py - cy;
    final ny = dy / math.max(1.0, cy) - beltSplit;
    final side = dx < 0 ? -1.0 : 1.0;

    if (dx.abs() < 1.15) return ny < -0.5 ? 0.0 : math.pi;
    if (ny < -0.66) return dx < 0 ? -math.pi / 2 : math.pi / 2;
    if (ny.abs() < 0.14) return variant.isEven ? math.pi / 2 : -math.pi / 2;
    if (ny > 0.72) {
      return dx.abs() > cx * 0.42 ? -math.pi / 2 : math.pi / 2;
    }
    if (ny < 0) {
      return variant.isEven ? side * tilt : side * (math.pi / 2);
    }
    return variant.isEven ? side * (math.pi - tilt) : side * (math.pi / 2);
  }

  /// Design ke mutabiq gaadiyan rakhne ki mumkina jagahen.
  /// Har jagah ek function hai jo lambai le kar gaadi banata hai.
  static List<BusData Function(int len, int id)> _candidates(
    LevelSpec s,
    SeededRandom rng, {
    int sym = 0,
  }) {
    const laneStep = 0.88;
    const microStep = 0.44;
    final out = <BusData Function(int, int)>[];
    final cols = s.cols.toDouble();
    final rows = s.rows.toDouble();

    BusData Function(int, int) free(double cx, double cy, double a) {
      final (tx, ty, ta) = _transform(cx, cy, a, cols, rows, sym);
      return (len, id) => BusData(
        id: id,
        cx: tx,
        cy: ty,
        angle: ta,
        color: 0,
        order: id,
        length: len,
      );
    }

    // Har level par sub-pattern ke narm farq (bina gap ya overlap paida kiye)
    final ox = (rng.nextDouble() - 0.5) * 0.14;
    final oy = (rng.nextDouble() - 0.5) * 0.14;
    final strip = 1 + rng.nextInt(2);
    final flip = rng.nextBool();
    final cw = rng.nextBool();
    final ringAlt = rng.nextBool();

    switch (s.pattern) {
      case LayoutPattern.diagonal:
        const diagChoices = [
          math.pi / 4,
          math.pi / 5,
          3 * math.pi / 8,
          math.pi / 3,
        ];
        final base = diagChoices[rng.nextInt(diagChoices.length)];
        final vx = math.cos(base), vy = math.sin(base); // side
        final ux = math.sin(base), uy = -math.cos(base); // aage
        final reach = (cols + rows).ceil();
        for (var i = -reach; i <= reach; i++) {
          for (var j = -reach * 2; j <= reach * 2; j++) {
            final px = cols / 2 + ox + i * laneStep * vx + j * microStep * ux;
            final py = rows / 2 + oy + i * laneStep * vy + j * microStep * uy;
            if (px < 0.35 || py < 0.35 || px > cols - 0.35 || py > rows - 0.35) {
              continue;
            }
            final forward = ((i ~/ strip).isEven) ^ flip;
            out.add(free(px, py, forward ? base : base + math.pi));
          }
        }
        return out;
      case LayoutPattern.fan:
        final fx = cols / 2 + ox;
        final fy = rows + 0.8 + rng.nextDouble() * 1.4;
        final outProb = 0.72 + rng.nextDouble() * 0.18;
        final maxR = math.sqrt(fx * fx + fy * fy);
        for (var r = 1.6; r < maxR; r += microStep) {
          final step = laneStep / r;
          for (var phi = -math.pi; phi < math.pi; phi += step) {
            final px = fx + math.sin(phi) * r;
            final py = fy - math.cos(phi) * r;
            if (px < 0.35 || py < 0.35 || px > cols - 0.35 || py > rows - 0.35) {
              continue;
            }
            final outward = rng.nextDouble() < outProb;
            final a = _angleOf(px - fx, py - fy);
            out.add(free(px, py, outward ? a : a + math.pi));
          }
        }
        return out;
      case LayoutPattern.swirl:
        final cx = cols / 2 + ox, cy = rows / 2 + oy;
        final spin = rng.nextBool() ? 1.0 : -1.0;
        final radialPush = 0.30 + rng.nextDouble() * 0.25;
        final psi0 = rng.nextDouble() * math.pi;
        final maxR = math.sqrt(cols * cols + rows * rows) * 0.56;
        for (var r = 0.9; r < maxR; r += laneStep) {
          final step = microStep / r;
          for (var psi = psi0; psi < psi0 + 2 * math.pi; psi += step) {
            final px = cx + math.cos(psi) * r;
            final py = cy + math.sin(psi) * r;
            if (px < 0.35 || py < 0.35 || px > cols - 0.35 || py > rows - 0.35) {
              continue;
            }
            final tx = -math.sin(psi) * spin, ty = math.cos(psi) * spin;
            final hx = tx + math.cos(psi) * radialPush;
            final hy = ty + math.sin(psi) * radialPush;
            out.add(free(px, py, _angleOf(hx, hy)));
          }
        }
        return out;
      case LayoutPattern.mosaic:
        final cx = cols / 2;
        final tilt = (0.22 + rng.nextDouble() * 0.14) * math.pi;
        final beltSplit = (rng.nextDouble() - 0.5) * 0.20;
        for (var y = 0.65; y <= rows - 0.65; y += microStep) {
          out.add(
            free(
              cx,
              y,
              _mosaicAngle(
                cols,
                rows,
                cx,
                y,
                0,
                tilt: tilt,
                beltSplit: beltSplit,
              ),
            ),
          );
          for (var dx = laneStep; dx <= cx - 0.50; dx += laneStep) {
            final v = ((dx + y).round()) & 1;
            out.add(
              free(
                cx - dx,
                y,
                _mosaicAngle(
                  cols,
                  rows,
                  cx - dx,
                  y,
                  v,
                  tilt: tilt,
                  beltSplit: beltSplit,
                ),
              ),
            );
            out.add(
              free(
                cx + dx,
                y,
                _mosaicAngle(
                  cols,
                  rows,
                  cx + dx,
                  y,
                  v,
                  tilt: tilt,
                  beltSplit: beltSplit,
                ),
              ),
            );
          }
        }
        return out;
      default:
        break;
    }

    final nx = ((cols - 0.85) / laneStep).floor();
    final ny = ((rows - 0.85) / laneStep).floor();
    final startX = (cols - nx * laneStep) / 2 + ox;
    final startY = (rows - ny * laneStep) / 2 + oy;
    for (var iy = 0; iy <= ny; iy++) {
      final basePy = startY + iy * laneStep;
      for (var ix = 0; ix <= nx; ix++) {
        final basePx = startX + ix * laneStep;
        final px = s.pattern == LayoutPattern.scatter
            ? (basePx + (rng.nextDouble() - 0.5) * 0.16).clamp(0.45, cols - 0.45)
            : basePx;
        final py = s.pattern == LayoutPattern.scatter
            ? (basePy + (rng.nextDouble() - 0.5) * 0.16).clamp(0.45, rows - 0.45)
            : basePy;
        final gx = (px - 0.5).round().clamp(0, s.cols - 1);
        final gy = (py - 0.5).round().clamp(0, s.rows - 1);
        final angle = s.pattern == LayoutPattern.scatter
            ? rng.nextInt(8) * math.pi / 4
            : _preferred(
                s,
                gx,
                gy,
                rng,
                strip: strip,
                flip: flip,
                cw: cw,
                ringAlt: ringAlt,
              ).angle;
        out.add(free(px, py, angle));
      }
    }
    return out;
  }

  static bool _insideBoundsOrBoard(
    Obb box,
    int cols,
    int rows,
    ({double left, double top, double right, double bottom})? bounds,
  ) {
    if (!box.insideBoard(cols, rows)) return false;
    if (bounds == null) return true;
    const pad = 0.02;
    for (final (x, y) in box.corners) {
      if (x < bounds.left + pad ||
          y < bounds.top + pad ||
          x > bounds.right - pad ||
          y > bounds.bottom - pad) {
        return false;
      }
    }
    return true;
  }

  /// Har gaadi ke beech saaf ek jaisa margin (3D roof overhang aur mirrors ke liye)
  static const double _busClearance = 0.22;

  static bool _tryPlaceBus(
    BusData b,
    int cols,
    int rows,
    List<BusData> placed,
    List<Obb> boxes, {
    ({double left, double top, double right, double bottom})? bounds,
  }) {
    final box = Geo.busBox(b);
    if (!_insideBoundsOrBoard(box, cols, rows, bounds)) return false;
    for (final o in boxes) {
      if (box.overlaps(o, margin: _busClearance)) return false;
    }
    final path = Geo.pathBox(b, cols, rows);
    for (final o in boxes) {
      if (path.overlaps(o)) return false;
    }
    placed.add(b);
    boxes.add(box);
    return true;
  }

  /// Diye gaye [lengths] wali gaadiyon ko naye [pattern] mein bina takkar aur
  /// bina kisi gaadi ko hamesha ke liye phansaye board par naye siray se rakho.
  /// Agar [longestFirst] null ho to [lengths] ka diya hua order barqarar rehta hai.
  static List<BusData>? arrangeBuses({
    required int cols,
    required int rows,
    required List<int> lengths,
    required LayoutPattern pattern,
    required SeededRandom rng,
    ({double left, double top, double right, double bottom})? bounds,
    bool? longestFirst = true,
  }) {
    if (lengths.isEmpty) return const [];
    final maxLen = lengths.reduce(math.max);
    final spec = LevelSpec(
      cols: cols,
      rows: rows,
      buses: lengths.length,
      colors: maxColors,
      shuffle: 0,
      maxLength: maxLen,
      longChance: 0.4,
      pattern: pattern,
    );

    final orderedLengths = List<int>.of(lengths);
    if (longestFirst == true) {
      orderedLengths.sort((a, b) => b.compareTo(a));
    } else if (longestFirst == false) {
      rng.shuffle(orderedLengths);
    }

    final placed = <BusData>[];
    final boxes = <Obb>[];
    final cands = [
      for (final make in _candidates(spec, rng, sym: rng.nextInt(8)))
        () {
          final probe = make(2, 0);
          return (
            make,
            Geo.exitDistance(probe, cols, rows) + rng.nextDouble() * 0.9,
          );
        }(),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    var idx = 0;
    for (final (make, _) in cands) {
      if (idx >= orderedLengths.length) break;
      final len = orderedLengths[idx];
      if (_tryPlaceBus(
        make(len, idx),
        cols,
        rows,
        placed,
        boxes,
        bounds: bounds,
      )) {
        idx++;
      }
    }

    // Agar baqi gaadiyan bachi hon to grid ke sub-cell points aur 8 angles try karo
    for (final offsets in const [
      [0.5],
      [0.25, 0.75],
    ]) {
      if (idx >= orderedLengths.length) break;
      final extra = <(double, double, double, double)>[];
      for (final off in offsets) {
        for (var y = 0; y < rows; y++) {
          for (var x = 0; x < cols; x++) {
            for (var k = 0; k < 8; k++) {
              final px = x + off;
              final py = y + off;
              final a = k * math.pi / 4;
              final probe = BusData(
                id: 0,
                cx: px,
                cy: py,
                angle: a,
                color: 0,
                order: 0,
              );
              final score =
                  Geo.exitDistance(probe, cols, rows) + rng.nextDouble() * 1.2;
              extra.add((px, py, a, score));
            }
          }
        }
      }
      extra.sort((a, b) => b.$4.compareTo(a.$4));
      for (final (px, py, a, _) in extra) {
        if (idx >= orderedLengths.length) break;
        final len = orderedLengths[idx];
        if (_tryPlaceBus(
          BusData(
            id: idx,
            cx: px,
            cy: py,
            angle: a,
            color: 0,
            order: idx,
            length: len,
          ),
          cols,
          rows,
          placed,
          boxes,
          bounds: bounds,
        )) {
          idx++;
        }
      }
    }

    return placed.length == orderedLengths.length ? placed : null;
  }

  /// Gaadiyan ek ek kar ke rakho. Sharat: nayi gaadi ka aage ka rasta (board ke
  /// kinare tak) pehle se rakhi gaadiyon se khaali ho. Is tarah ulte order mein
  /// sab nikal sakti hain, yaani har level ka hal yaqeeni hai.
  static List<BusData> _placeBuses(
    LevelSpec spec,
    SeededRandom rng, {
    int sym = 0,
    _BoardShape shape = _BoardShape.full,
  }) {
    final placed = <BusData>[];
    final boxes = <Obb>[];

    bool tryPlace(BusData b) =>
        _tryPlaceBus(b, spec.cols, spec.rows, placed, boxes);

    /// Is gaadi ki lambai: zyada tar 2, kabhi kabhi lambi
    var vans = 0;
    var longBuses = 0;
    List<int> lengths() {
      // Hadaf: ~30% van aur ~15% bus (jitni [longChance] ijazat de)
      final n = placed.length + 1;
      var len = 2;
      if (spec.maxLength >= 4 && longBuses < n * spec.longChance * 0.35) {
        len = 4;
      } else if (spec.maxLength >= 3 && vans < n * spec.longChance * 0.7) {
        len = 3;
      } else if (rng.nextDouble() < spec.longChance * 0.3) {
        len = math.min(3, spec.maxLength);
      }
      return [for (var l = len; l >= 2; l--) l];
    }

    // Pehla daur: design wali jagahen (kam jitter taa ke darmiyan mein bade gaps na paden)
    final jitterAmp = 0.65 + rng.nextDouble() * 0.45;
    final cands = [
      for (final make in _candidates(spec, rng, sym: sym))
        () {
          final probe = make(2, 0);
          return (
            make,
            probe,
            Geo.exitDistance(probe, spec.cols, spec.rows) +
                rng.nextDouble() * jitterAmp,
          );
        }(),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    for (final (make, probe, _) in cands) {
      if (placed.length >= spec.buses) break;
      if (!_inShape(probe.cx, probe.cy, spec.cols, spec.rows, shape)) continue;
      for (final len in lengths()) {
        if (tryPlace(make(len, placed.length))) {
          if (len == 3) vans++;
          if (len == 4) longBuses++;
          break;
        }
      }
    }

    // Doosra daur: pehle bache hue slots ko seedhe pattern/grid mein bharo,
    // zaroorat par hi general 8-angle sub-grid try karein
    void fillGrid({required bool strictShape, required int target}) {
      if (placed.length >= target) return;
      final extra = <(double, double, double, double)>[];
      for (final off in const [0.44, 0.88]) {
        for (var y = 0; y < spec.rows; y++) {
          for (var x = 0; x < spec.cols; x++) {
            final px = x + off;
            final py = y + off;
            if (px < 0.45 ||
                py < 0.45 ||
                px > spec.cols - 0.45 ||
                py > spec.rows - 0.45) {
              continue;
            }
            if (strictShape &&
                !_inShape(px, py, spec.cols, spec.rows, shape)) {
              continue;
            }
            for (var k = 0; k < 8; k++) {
              final a = k * math.pi / 4;
              final probe = BusData(
                id: 0,
                cx: px,
                cy: py,
                angle: a,
                color: 0,
                order: 0,
              );
              final score =
                  Geo.exitDistance(probe, spec.cols, spec.rows) +
                  rng.nextDouble() * 0.9;
              extra.add((px, py, a, score));
            }
          }
        }
      }
      extra.sort((a, b) => b.$4.compareTo(a.$4));
      for (final (px, py, a, _) in extra) {
        if (placed.length >= target) break;
        tryPlace(
          BusData(
            id: placed.length,
            cx: px,
            cy: py,
            angle: a,
            color: 0,
            order: placed.length,
          ),
        );
      }
    }

    fillGrid(strictShape: true, target: spec.buses);
    final minTarget = math.max(spec.colors * 2, (spec.buses * 0.85).ceil());
    fillGrid(strictShape: false, target: minTarget);
    return placed;
  }

  /// Line ko achhe se mix karo taa ke ek hi rang ke 60-80 log ek saath na aayen,
  /// balki 4-12 ke chhote hisson mein alag-alag rang aayen aur har 4-row ek hi rang ki rahe.
  static void _shuffleQueue(List<int> queue, int strength, SeededRandom rng) {
    if (strength <= 0 || queue.isEmpty) return;

    // 1) Poori line ko chhote 4- ya 8-logon ke chunks mein baantein (har chunk ek hi rang ka)
    final chunks = <List<int>>[];
    var i = 0;
    while (i < queue.length) {
      final c = queue[i];
      final maxTake = rng.nextInt(3) == 0 ? 8 : 4;
      var len = 0;
      while (len < maxTake && i + len < queue.length && queue[i + len] == c) {
        len++;
      }
      chunks.add(queue.sublist(i, i + len));
      i += len;
    }

    // 2) Qareeb ke chunks ko mazbooti se aapas mein mix karo taa ke bade mono-color blocks toot jayen
    final window = 3 + strength * 2;
    final passes = 2 + strength;
    for (var pass = 0; pass < passes; pass++) {
      for (var idx = 0; idx < chunks.length - 1; idx++) {
        final j = idx + 1 + rng.nextInt(window);
        if (j >= chunks.length) continue;
        final tmp = chunks[idx];
        chunks[idx] = chunks[j];
        chunks[j] = tmp;
      }
    }

    queue
      ..clear()
      ..addAll([for (final ch in chunks) ...ch]);
  }
}
