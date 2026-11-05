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
}

/// Grid jaise design (shuru ke aasaan levels ke liye)
const _tiltedPatterns = [
  LayoutPattern.diagonal,
  LayoutPattern.fan,
  LayoutPattern.swirl,
];

// Khari aur leti gaadiyan mili hui (video jaisa); sirf ek rukh wale
// "lanes"/"columns" design ek jaise aur khaali lagte the
const _gridPatterns = [
  LayoutPattern.scatter,
  LayoutPattern.burst,
  LayoutPattern.scatter,
  LayoutPattern.rings,
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

/// Levels code se banane wala class. Seed = level number,
/// is liye ek level hamesha ek jaisa banta hai.
class LevelGenerator {
  /// Rangon ki zyada se zyada tadaad (GamePalette mein itne rang hain)
  static const int maxColors = 8;

  /// Shuru mein khule slots
  static const int openSlots = 4;

  /// Level number ke hisaab se mushkil
  static LevelSpec specFor(int level) {
    // Level 1 aur 2: tutorial jaise, bohat aasaan
    if (level <= 1) {
      return const LevelSpec(
        cols: 6,
        rows: 6,
        buses: 4,
        colors: 2,
        shuffle: 0,
        maxLength: 2,
        longChance: 0,
        pattern: LayoutPattern.burst,
      );
    }
    if (level == 2) {
      return const LevelSpec(
        cols: 7,
        rows: 7,
        buses: 9,
        colors: 3,
        shuffle: 0,
        maxLength: 3,
        longChance: 0.2,
        pattern: LayoutPattern.burst,
      );
    }

    // Grid ka size dheere dheere bada
    final (cols, rows, maxBuses) = switch (level) {
      // Lot poori chaudai mein hai, is liye grid takreeban chaukor
      < 6 => (8, 8, 20),
      < 11 => (10, 10, 34),
      < 25 => (11, 11, 44),
      < 45 => (12, 12, 54),
      _ => (13, 13, 64),
    };

    var colors = (3 + (level - 3) ~/ 7).clamp(3, maxColors);
    // Level 10 ke baad lot kaafi bhara hua lage
    var buses = (14 + (level - 3) * 2.2).round().clamp(10, maxBuses);
    var shuffle = (1 + level ~/ 12).clamp(1, 4);
    // Teeno size (car 4, van 6, bus 10) jaldi aa jayen
    final maxLength = level < 4 ? 3 : 4;
    final longChance = (0.3 + level * 0.01).clamp(0.3, 0.5);
    // Zyadatar seedhi qataaron wale (grid) design, saaf aur tidy lagte hain.
    // Har 10 mein se sirf ek level (13, 23, 33...) tirchha design, variety ke liye.
    var pattern = level >= 13 && level % 10 == 3
        ? _tiltedPatterns[(level ~/ 10) % _tiltedPatterns.length]
        : _gridPatterns[level % _gridPatterns.length];
    final breather = level % 10 == 0;
    // Har 10 mein se level 5 HARD aur level 9 SUPER HARD (level 9 se aage)
    final difficulty = breather
        ? 0
        : (level % 10 == 9 ? 2 : (level % 10 == 5 ? 1 : 0));
    if (difficulty > 0) {
      // Mushkil level: zyada mili hui line aur thodi zyada gaadiyan
      shuffle += difficulty;
      buses = (buses * (1 + 0.12 * difficulty)).round().clamp(10, maxBuses);
    }

    if (breather) {
      // Breather level: kam rang, kam gaadiyan, kam shuffle
      colors = (colors - 2).clamp(2, maxColors);
      buses = (buses * 0.55).round();
      shuffle = 1;
      pattern = LayoutPattern.burst;
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

  static LevelData generate(int level) {
    final spec = specFor(level);

    LevelData? best;
    for (var attempt = 0; attempt < 20; attempt++) {
      final rng = SeededRandom(level * 7919 + attempt * 104729 + 17);
      var buses = _placeBuses(spec, rng);

      // Ginti rangon ki tadaad se poori taqseem honi chahiye
      final count = (buses.length ~/ spec.colors) * spec.colors;
      if (count < spec.colors * 2) continue;
      // Aakhri rakhi gaadiyan hatane se baqi gaadiyon ki sharat nahi toot-ti
      buses = buses.sublist(0, count);

      // Rang barabar taqseem karo
      // Ek rang ki 2-3 gaadiyan lagataar (hal karne ke order mein), taa ke
      // hujoom mein rang bade bade guchhon mein nazar aayen
      final perColor = count ~/ spec.colors;
      final chunks = <List<int>>[];
      for (var c = 0; c < spec.colors; c++) {
        var left = perColor;
        while (left > 0) {
          final n = left <= 3 ? left : 2 + rng.nextInt(2);
          chunks.add(List.filled(n, c));
          left -= n;
        }
      }
      rng.shuffle(chunks);
      final colors = [for (final ch in chunks) ...ch];
      for (var i = 0; i < count; i++) {
        buses[i].color = colors[i];
      }

      // Passengers: hal karne wale order (ulta) mein, har gaadi ki seats jitne
      final solveOrder = buses.reversed.toList();
      final base = <int>[
        for (final b in solveOrder)
          for (var s = 0; s < b.capacity; s++) b.color,
      ];

      // Pehle poori shuffle try karo, nakami par kam karte jao
      for (var strength = spec.shuffle; strength >= 0; strength--) {
        for (var tries = 0; tries < (strength == 0 ? 1 : 6); tries++) {
          final queue = List<int>.of(base);
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
          if (Solver.solveInOrder(data)) return data;
          best ??= data;
        }
      }
    }
    // Yahan tak pohanchna nahi chahiye (strength 0 hamesha hal hota hai)
    return best!;
  }

  /// Grid wale design mein kisi cell ka pasandeeda rukh
  static Dir _preferred(LevelSpec s, int x, int y, SeededRandom rng) {
    switch (s.pattern) {
      case LayoutPattern.lanes:
        return y.isEven ? Dir.left : Dir.right;
      case LayoutPattern.columns:
        return x.isEven ? Dir.up : Dir.down;
      case LayoutPattern.burst:
        final dx = x - (s.cols - 1) / 2;
        final dy = y - (s.rows - 1) / 2;
        if (dx.abs() * s.rows > dy.abs() * s.cols) {
          return dx < 0 ? Dir.left : Dir.right;
        }
        return dy < 0 ? Dir.up : Dir.down;
      case LayoutPattern.rings:
        // Kaun si ring (bahar se andar) aur us par ghadi ki sui ka rukh
        final k = [
          x,
          y,
          s.cols - 1 - x,
          s.rows - 1 - y,
        ].reduce((a, b) => a < b ? a : b);
        if (y == k && x < s.cols - 1 - k) return Dir.right;
        if (x == s.cols - 1 - k && y < s.rows - 1 - k) return Dir.down;
        if (y == s.rows - 1 - k && x > k) return Dir.left;
        return Dir.up;
      default:
        return Dir.values[rng.nextInt(4)];
    }
  }

  /// Heading vector (hx, hy) se angle (0 = upar, ghadi ki sui ki taraf)
  static double _angleOf(double hx, double hy) => math.atan2(hx, -hy);

  /// Tirchhe design mein kisi bhi nuqte par gaadi ka rukh (grid design ke liye null)
  static double Function(double, double)? _angleField(
    LevelSpec s,
    SeededRandom rng,
  ) {
    final cols = s.cols.toDouble();
    final rows = s.rows.toDouble();
    switch (s.pattern) {
      case LayoutPattern.fan:
        final fx = cols / 2, fy = rows + 1.2;
        return (px, py) {
          final a = _angleOf(px - fx, py - fy);
          return rng.nextDouble() < 0.8 ? a : a + math.pi;
        };
      case LayoutPattern.swirl:
        final cx = cols / 2, cy = rows / 2;
        return (px, py) {
          final psi = math.atan2(py - cy, px - cx);
          return _angleOf(
            -math.sin(psi) + math.cos(psi) * 0.45,
            math.cos(psi) + math.sin(psi) * 0.45,
          );
        };
      case LayoutPattern.diagonal:
        final base = math.pi / 4;
        return (px, py) => rng.nextInt(2) == 0 ? base : base + math.pi;
      default:
        return null;
    }
  }

  /// Design ke mutabiq gaadiyan rakhne ki mumkina jagahen.
  /// Har jagah ek function hai jo lambai le kar gaadi banata hai.
  static List<BusData Function(int len, int id)> _candidates(
    LevelSpec s,
    SeededRandom rng,
  ) {
    final out = <BusData Function(int, int)>[];
    final cols = s.cols.toDouble();
    final rows = s.rows.toDouble();

    BusData Function(int, int) free(double cx, double cy, double a) =>
        (len, id) => BusData(
          id: id,
          cx: cx,
          cy: cy,
          angle: a,
          color: 0,
          order: id,
          length: len,
        );

    switch (s.pattern) {
      case LayoutPattern.diagonal:
        // 45 degree ki qataaren; har doosri qataar ulti taraf
        final base = math.pi / 4;
        final vx = math.cos(base), vy = math.sin(base); // side
        final ux = math.sin(base), uy = -math.cos(base); // aage
        final reach = (cols + rows).ceil();
        for (var i = -reach; i <= reach; i++) {
          for (var j = -reach * 2; j <= reach * 2; j++) {
            final px = cols / 2 + i * 0.98 * vx + j * 0.5 * ux;
            final py = rows / 2 + i * 0.98 * vy + j * 0.5 * uy;
            if (px < 0 || py < 0 || px > cols || py > rows) continue;
            out.add(free(px, py, i.isEven ? base : base + math.pi));
          }
        }
      case LayoutPattern.fan:
        // Neeche ke ek nuqte se pankhe ki tarah phaili gaadiyan
        final fx = cols / 2, fy = rows + 1.2;
        final maxR = math.sqrt(fx * fx + fy * fy);
        for (var r = 1.6; r < maxR; r += 0.55) {
          final step = 0.98 / r;
          for (var phi = -math.pi; phi < math.pi; phi += step) {
            final px = fx + math.sin(phi) * r;
            final py = fy - math.cos(phi) * r;
            if (px < 0 || py < 0 || px > cols || py > rows) continue;
            // Zyada tar bahar ki taraf, kuch andar ki taraf
            final outward = rng.nextDouble() < 0.8;
            final a = _angleOf(px - fx, py - fy);
            out.add(free(px, py, outward ? a : a + math.pi));
          }
        }
      case LayoutPattern.swirl:
        // Darmiyan ke gird ghoomti (thodi bahar mudti) gaadiyan
        final cx = cols / 2, cy = rows / 2;
        final maxR = math.sqrt(cx * cx + cy * cy);
        const spin = 1.0;
        for (var r = 0.9; r < maxR; r += 0.98) {
          final step = 0.5 / r;
          for (var psi = 0.0; psi < 2 * math.pi; psi += step) {
            final px = cx + math.cos(psi) * r;
            final py = cy + math.sin(psi) * r;
            if (px < 0 || py < 0 || px > cols || py > rows) continue;
            // Tangent + thoda bahar ki taraf jhukao = spiral
            final tx = -math.sin(psi) * spin, ty = math.cos(psi) * spin;
            final hx = tx + math.cos(psi) * 0.45;
            final hy = ty + math.sin(psi) * 0.45;
            out.add(free(px, py, _angleOf(hx, hy)));
          }
        }
      default:
        break;
    }

    // Tirchhe design: khaali jagahen bharne ke liye random nuqte bhi,
    // jin ka rukh usi design ke mutabiq ho
    final field = _angleField(s, rng);
    if (field != null) {
      for (var n = 0; n < s.cols * s.rows * 6; n++) {
        final px = 0.5 + rng.nextDouble() * (cols - 1);
        final py = 0.5 + rng.nextDouble() * (rows - 1);
        out.add(free(px, py, field(px, py)));
      }
      return out;
    }

    switch (s.pattern) {
      default:
        // Grid wale design: har cell ka pasandeeda rukh
        for (var y = 0; y < s.rows; y++) {
          for (var x = 0; x < s.cols; x++) {
            final d = _preferred(s, x, y, rng);
            out.add(
              (len, id) => BusData.onGrid(
                id: id,
                x: x,
                y: y,
                dir: d,
                color: 0,
                order: id,
                length: len,
              ),
            );
          }
        }
    }
    return out;
  }

  /// Gaadiyan ek ek kar ke rakho. Sharat: nayi gaadi ka aage ka rasta (board ke
  /// kinare tak) pehle se rakhi gaadiyon se khaali ho. Is tarah ulte order mein
  /// sab nikal sakti hain, yaani har level ka hal yaqeeni hai.
  static List<BusData> _placeBuses(LevelSpec spec, SeededRandom rng) {
    final placed = <BusData>[];
    final boxes = <Obb>[];

    bool tryPlace(BusData b) {
      final box = Geo.busBox(b);
      if (!box.insideBoard(spec.cols, spec.rows)) return false;
      for (final o in boxes) {
        if (box.overlaps(o, margin: 0.06)) return false;
      }
      final path = Geo.pathBox(b, spec.cols, spec.rows);
      for (final o in boxes) {
        if (path.overlaps(o)) return false;
      }
      placed.add(b);
      boxes.add(box);
      return true;
    }

    /// Is gaadi ki lambai: zyada tar 2, kabhi kabhi lambi
    // Lambi gaadiyan pehle rakhne ki koshish (warna chhoti cars jagah bhar deti hain)
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

    // Pehla daur: design wali jagahen. Jo apne nikalne wale kinare se sab se
    // door ho usay pehle rakho, taa ke qataaren bharen aur gaadiyan ek doosre ko rokein.
    final cands = [
      for (final make in _candidates(spec, rng))
        () {
          final probe = make(2, 0);
          return (
            make,
            Geo.exitDistance(probe, spec.cols, spec.rows) +
                rng.nextDouble() * 2.5,
          );
        }(),
    ];
    cands.sort((a, b) => b.$2.compareTo(a.$2));
    for (final (make, _) in cands) {
      if (placed.length >= spec.buses) break;
      for (final len in lengths()) {
        if (tryPlace(make(len, placed.length))) {
          if (len == 3) vans++;
          if (len == 4) longBuses++;
          break;
        }
      }
    }

    // Doosra daur: khaali jagahen grid ke hisaab se kisi bhi rukh se bharo
    if (placed.length < spec.buses) {
      final all = <(int, int, Dir)>[
        for (var y = 0; y < spec.rows; y++)
          for (var x = 0; x < spec.cols; x++)
            for (final d in Dir.values) (x, y, d),
      ];
      rng.shuffle(all);
      for (final (x, y, d) in all) {
        if (placed.length >= spec.buses) break;
        tryPlace(
          BusData.onGrid(
            id: placed.length,
            x: x,
            y: y,
            dir: d,
            color: 0,
            order: placed.length,
          ),
        );
      }
    }
    return placed;
  }

  /// Line ko thoda sa shuffle karo: qareeb ke passengers ki jagah badlo
  /// Line ko thoda sa shuffle karo, lekin rang guchhon (groups) mein rahen:
  /// har gaadi ke passengers ek saath. Pehle poore guchhe aapas mein jagah
  /// badalte hain, phir sirf saath wale guchhon ke kinaron par thode log mixte hain.
  static void _shuffleQueue(List<int> queue, int strength, SeededRandom rng) {
    if (strength <= 0 || queue.isEmpty) return;
    // Lagataar ek rang wale hisson ko guchhe banao
    final groups = <List<int>>[];
    for (final c in queue) {
      if (groups.isEmpty || groups.last.first != c) {
        groups.add([c]);
      } else {
        groups.last.add(c);
      }
    }
    // Qareeb ke guchhon ki jagah badlo
    final window = 1 + strength;
    for (var n = 0; n < groups.length; n++) {
      final i = rng.nextInt(groups.length);
      final j = i + 1 + rng.nextInt(window);
      if (j >= groups.length) continue;
      final tmp = groups[i];
      groups[i] = groups[j];
      groups[j] = tmp;
    }
    final out = [for (final g in groups) ...g];
    // Guchhon ke kinaron par thoda mixing (sirf 1-2 log)
    var pos = 0;
    for (final g in groups) {
      pos += g.length;
      if (pos >= out.length || rng.nextInt(3) != 0) continue;
      final k = 1 + rng.nextInt(strength.clamp(1, 2));
      for (var m = 0; m < k && pos - 1 - m >= 0 && pos + m < out.length; m++) {
        final tmp = out[pos - 1 - m];
        out[pos - 1 - m] = out[pos + m];
        out[pos + m] = tmp;
      }
    }
    queue
      ..clear()
      ..addAll(out);
  }
}
