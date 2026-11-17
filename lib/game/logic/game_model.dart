import 'dart:math' as math;

import '../../models/bus_data.dart';
import '../../models/level_data.dart';
import 'geometry.dart';
import 'level_generator.dart';
import 'seeded_random.dart';
import 'solver.dart';

/// Slot mein khadi gaadi ki halat
enum SlotPhase {
  /// Grid se nikal kar slot ki taraf aa rahi hai
  arriving,

  /// Slot mein khadi hai, passengers baith sakte hain
  parked,

  /// Bhar gayi hai aur ja rahi hai
  departing,
}

/// Slot mein khadi ek gaadi
class SlotBus {
  SlotBus(this.bus, this.phase);

  final BusData bus;
  SlotPhase phase;

  /// Kitne passengers baith chuke hain
  int filled = 0;

  /// Kitne passengers raste mein hain (chal kar aa rahe hain)
  int reserved = 0;

  int get color => bus.color;
  int get capacity => bus.capacity;
  int get freeSeats => capacity - filled - reserved;
  bool get hasRoom => freeSeats > 0;

  SlotBus copy() => SlotBus(bus.copy(), phase)
    ..filled = filled
    ..reserved = reserved;
}

/// Tap ka nateeja
enum LaunchStatus { ok, blocked, noSlot, notFound }

/// Game ke saare qawaid (rules) yahan hain. Is mein koi drawing ya animation nahi.
/// Flame wala game isi model ko chalata hai, aur tests/solver bhi isi ko use karte hain,
/// taa ke rules sirf ek jagah likhe hon.
class GameModel {
  GameModel(LevelData level)
    : cols = level.cols,
      rows = level.rows,
      grid = level.buses.map((b) => b.copy()).toList(),
      hasVip = level.hasVip,
      slots = List<SlotBus?>.filled(
        level.slotCount + (level.hasVip ? 1 : 0),
        null,
        growable: true,
      ),
      lockedSlots = level.lockedSlots,
      queue = List<int>.of(level.passengers),
      head = 0,
      _levelNumber = level.level;

  GameModel._raw(
    this.hasVip,
    this.cols,
    this.rows,
    this.grid,
    this.slots,
    this.lockedSlots,
    this.queue,
    this.head,
    this._levelNumber,
    this._lastShufflePattern,
  );

  final int _levelNumber;
  LayoutPattern? _lastShufflePattern;
  final int cols;
  final int rows;

  /// Grid par abhi khadi gaadiyan
  final List<BusData> grid;

  /// Index 0 par sunehri VIP slot hai (agar [hasVip]); sirf VIP booster wahan bhejta hai
  final bool hasVip;

  /// Khule waiting slots (null = khaali). [hasVip] ho to index 0 VIP hai.
  final List<SlotBus?> slots;

  /// Band slots jo abhi nahi khule ("+")
  int lockedSlots;

  /// Passengers ke rang (poori line). [head] se pehle wale ja chuke hain.
  final List<int> queue;
  int head;

  int get slotCount => slots.length;

  /// Aam (VIP ke ilawa) khule slots ki ginti
  int get normalSlotCount => slots.length - (hasVip ? 1 : 0);

  int get _firstNormal => hasVip ? 1 : 0;

  /// VIP slot khaali ho to us ka index (0)
  int? get freeVipSlot => hasVip && slots[0] == null ? 0 : null;

  /// Khule aur band, dono milakar (screen par itni jagahen bani hain)
  int get totalSlotPlaces => slots.length + lockedSlots;
  int get remainingPassengers => queue.length - head;
  int? get frontColor => head < queue.length ? queue[head] : null;

  GameModel clone() => GameModel._raw(
    hasVip,
    cols,
    rows,
    grid.map((b) => b.copy()).toList(),
    slots.map((s) => s?.copy()).toList(),
    lockedSlots,
    List<int>.of(queue),
    head,
    _levelNumber,
    _lastShufflePattern,
  );

  BusData? busById(int id) {
    for (final b in grid) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Board ke kisi nuqte (units mein) par khadi gaadi. Kai hon to jis ka
  /// darmiyan sab se qareeb ho. [slack] = chhoti gaadiyon ko tap karna aasaan rahe.
  BusData? busAtPoint(double px, double py, {double slack = 0.12}) {
    BusData? best;
    var bestD = double.infinity;
    for (final b in grid) {
      if (!Geo.busBox(b, inflate: slack).contains(px, py)) continue;
      final d = (b.cx - px) * (b.cx - px) + (b.cy - py) * (b.cy - py);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best;
  }

  /// [bus] ke chalne ke raste ([extend] tak) mein aane wali gaadiyan
  Iterable<BusData> _hits(BusData bus, double extend) {
    final box = Geo.busBox(bus, extend: extend);
    return grid.where((o) => o.id != bus.id && box.overlaps(Geo.busBox(o)));
  }

  /// Kya gaadi ke aage board ke kinare tak rasta band hai?
  bool isBlocked(BusData bus) =>
      _hits(bus, Geo.exitDistance(bus, cols, rows)).isNotEmpty;

  /// Rukawat se pehle gaadi kitna aage ja sakti hai (units). Takrane ki animation ke liye.
  double freeDistanceAhead(BusData bus) {
    final exit = Geo.exitDistance(bus, cols, rows);
    if (_hits(bus, exit).isEmpty) return exit;
    var lo = 0.0;
    var hi = exit;
    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      if (_hits(bus, mid).isEmpty) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Raste mein sab se pehli rukawat wali gaadi
  BusData? blockerOf(BusData bus) {
    if (!isBlocked(bus)) return null;
    final d = freeDistanceAhead(bus);
    final hits = _hits(bus, d + 0.05);
    return hits.isEmpty ? null : hits.first;
  }

  /// Pehla khaali slot (ya null)
  int? get freeSlot {
    for (var i = _firstNormal; i < slots.length; i++) {
      if (slots[i] == null) return i;
    }
    return null;
  }

  /// Woh gaadiyan jo abhi nikal sakti hain
  List<BusData> movableBuses() => grid.where((b) => !isBlocked(b)).toList();

  /// Gaadi ko grid se nikal kar slot ki taraf bhejna.
  /// [ignoreBlock] = true Lift booster ke liye (rasta band ho tab bhi).
  ({LaunchStatus status, int slot}) launch(
    int busId, {
    bool ignoreBlock = false,
    bool useVip = false,
  }) {
    final bus = busById(busId);
    if (bus == null) return (status: LaunchStatus.notFound, slot: -1);
    if (!ignoreBlock && isBlocked(bus)) {
      return (status: LaunchStatus.blocked, slot: -1);
    }
    final slot = useVip ? (freeVipSlot ?? freeSlot) : freeSlot;
    if (slot == null) return (status: LaunchStatus.noSlot, slot: -1);
    grid.remove(bus);
    slots[slot] = SlotBus(bus, SlotPhase.arriving);
    return (status: LaunchStatus.ok, slot: slot);
  }

  /// Gaadi slot tak pohanch gayi
  void arrive(int slot) {
    slots[slot]?.phase = SlotPhase.parked;
  }

  /// Kisi rang ki khadi gaadi (jis mein jagah ho) dhoondo
  int? findParkedSlotForColor(int color) {
    int? best;
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s == null || s.phase != SlotPhase.parked) continue;
      if (s.color != color || !s.hasRoom) continue;
      // Jo gaadi zyada bhari ho usay pehle bharo
      if (best == null ||
          s.filled + s.reserved > slots[best]!.filled + slots[best]!.reserved) {
        best = i;
      }
    }
    return best;
  }

  /// Khadi gaadi mein is rang ke passenger ki seat reserve karo aur queue se nikal lo
  int? reserveSeatForColor(int color) {
    final slot = findParkedSlotForColor(color);
    if (slot == null) return null;
    final idx = queue.indexOf(color, head);
    if (idx == -1) return null;
    if (idx != head) {
      final c = queue.removeAt(idx);
      queue.insert(head, c);
    }
    slots[slot]!.reserved++;
    head++;
    return slot;
  }

  /// Agar line ka pehla passenger kisi khadi gaadi mein baith sakta hai to
  /// usay line se nikal kar us gaadi ki seat reserve karo aur slot number wapis do.
  int? startBoarding() {
    final c = frontColor;
    if (c == null) return null;
    return reserveSeatForColor(c);
  }

  /// Passenger gaadi tak pohanch kar baith gaya. Agar gaadi bhar gayi to true.
  bool finishBoarding(int slot) {
    final s = slots[slot];
    if (s == null) return false;
    s.reserved--;
    s.filled++;
    if (s.filled >= s.capacity) {
      s.phase = SlotPhase.departing;
      return true;
    }
    return false;
  }

  /// Bhari hui gaadi chali gayi, slot khaali
  void depart(int slot) {
    slots[slot] = null;
  }

  /// Ek band slot kholo. Koi band na ho to naya slot jod do.
  void unlockSlot() {
    if (lockedSlots > 0) lockedSlots--;
    slots.add(null);
  }

  bool get isWon =>
      head >= queue.length && grid.isEmpty && slots.every((s) => s == null);

  /// Kya game phans gayi hai? (jab koi animation na chal rahi ho tab check karein)
  /// Saare khule slots bhare hain aur pehle passenger ke rang ki koi gaadi slot mein nahi.
  bool get isStuck {
    final c = frontColor;
    if (c == null) return false;
    if (freeSlot != null) return false;
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      // Khaali VIP slot aam chaal ke liye kaam ka nahi
      if (s == null && hasVip && i == 0) continue;
      if (s == null) return false;
      if (s.phase == SlotPhase.departing) return false;
      if (s.color == c && s.hasRoom) return false;
    }
    return true;
  }

  /// Solver ke liye: saare passengers fauran bitha do aur bhari gaadiyan rawana kar do
  void settleInstantly() {
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s == null) continue;
      if (s.phase == SlotPhase.arriving) s.phase = SlotPhase.parked;
      // Jo passengers raste mein the unhein bitha do
      while (s.reserved > 0) {
        finishBoarding(i);
      }
      if (s.phase == SlotPhase.departing) depart(i);
    }
    while (true) {
      final slot = startBoarding();
      if (slot == null) break;
      if (finishBoarding(slot)) depart(slot);
    }
  }

  /// Sort booster: jo passengers abhi kisi khadi gaadi mein baith sakte hain
  /// unhein line mein sab se aage le aao (baqi line ka order wahi rehta hai).
  /// Kuch na badle to false.
  bool sortQueue() {
    final room = <int, int>{};
    for (final s in slots) {
      if (s == null || s.phase == SlotPhase.departing) continue;
      room[s.color] = (room[s.color] ?? 0) + s.freeSeats;
    }
    if (room.isEmpty) return false;

    final pick = <int>[];
    final rest = <int>[];
    for (var i = head; i < queue.length; i++) {
      final c = queue[i];
      final r = room[c] ?? 0;
      if (r > 0) {
        room[c] = r - 1;
        pick.add(c);
      } else {
        rest.add(c);
      }
    }
    if (pick.isEmpty) return false;
    final sorted = [...pick, ...rest];
    var changed = false;
    for (var i = 0; i < sorted.length; i++) {
      if (queue[head + i] != sorted[i]) changed = true;
    }
    if (!changed) return false;
    queue.replaceRange(head, queue.length, sorted);
    return true;
  }

  /// Shuffle booster: grid par khadi gaadiyon ke rang aapas mein badal do.
  /// Ginti wahi rehti hai. Koshish hoti hai ke level phir bhi hal ho sake.
  /// Agar rang badalna mumkin na ho to false.
  bool shuffleGridColors(SeededRandom rng) {
    if (grid.length < 2) return false;
    final current = grid.map((b) => b.color).toList();

    // Rang sirf ek jaisi lambai (seats) wali gaadiyon mein badlo,
    // warna kisi rang ki seats aur passengers barabar nahi rahenge
    final groups = <int, List<int>>{};
    for (var i = 0; i < grid.length; i++) {
      groups.putIfAbsent(grid[i].length, () => []).add(i);
    }
    final canChange = groups.values.any(
      (idx) => idx.map((i) => current[i]).toSet().length > 1,
    );
    if (!canChange) return false;

    List<int> randomPerm() {
      final perm = List<int>.of(current);
      for (final idx in groups.values) {
        final colors = idx.map((i) => current[i]).toList();
        rng.shuffle(colors);
        for (var k = 0; k < idx.length; k++) {
          perm[idx[k]] = colors[k];
        }
      }
      return perm;
    }

    bool solvable(List<int> perm, {bool deep = true}) {
      final test = clone();
      for (var i = 0; i < test.grid.length; i++) {
        test.grid[i].color = perm[i];
      }
      if (Solver.solveByOrder(test)) return true;
      return deep && Solver.canSolve(test, nodeLimit: 1500);
    }

    List<int>? fallback;
    for (var attempt = 0; attempt < 20; attempt++) {
      final perm = randomPerm();
      if (_sameList(perm, current)) continue;
      fallback ??= perm;
      if (solvable(perm, deep: attempt < 8)) {
        _applyColors(perm);
        return true;
      }
    }

    // Random se kaam na bana: qareebi gaadiyon (nikalne ke order mein) ke rang
    // aapas mein badlo. Pehle zyada badlaav, phir kam.
    final rank = List<int>.generate(grid.length, (i) => i)
      ..sort((a, b) => grid[b].order.compareTo(grid[a].order));
    for (var swaps = 8; swaps >= 1; swaps--) {
      for (var t = 0; t < 10; t++) {
        final perm = List<int>.of(current);
        var done = 0;
        for (var n = 0; n < swaps * 6 && done < swaps; n++) {
          final p = rng.nextInt(rank.length);
          final q = p + 1 + rng.nextInt(4);
          if (q >= rank.length) continue;
          final a = rank[p];
          final b = rank[q];
          if (grid[a].length != grid[b].length || perm[a] == perm[b]) continue;
          final tmp = perm[a];
          perm[a] = perm[b];
          perm[b] = tmp;
          done++;
        }
        if (done == 0) continue;
        if (solvable(perm, deep: false)) {
          _applyColors(perm);
          return true;
        }
      }
    }

    // Phir bhi nahi: aise rang chuno jo line ki zaroorat ke mutabiq hon
    final smart = _smartColors(current, groups);
    if (smart != null && !_sameList(smart, current) && solvable(smart)) {
      _applyColors(smart);
      return true;
    }

    // Hal hone wala koi order na mila (shayad pehle hi phans chuke hain),
    // phir bhi rang badal do taa ke booster bekaar na jaye
    if (fallback == null) return false;
    _applyColors(fallback);
    return true;
  }

  /// Shuffle booster: grid par khadi gaadiyon ki poori arrangement (positions,
  /// angles, order aur rang) har bar naye layout pattern ke sath badalta hai.
  /// Har rang ki seats aur gaadiyon ki lambai ki ginti barabar rehti hai.
  bool shuffleArrangement(
    SeededRandom rng, {
    ({double left, double top, double right, double bottom})? bounds,
  }) {
    if (grid.length < 2) return false;

    final before = [for (final b in grid) b.copy()];
    // Order ascending (innermost = 0 .. outermost = N-1) taa ke har lambai ka
    // exit sequence queue ke mutabiq mehfooz reh sake
    final beforeOrdered = List<BusData>.of(before)
      ..sort((a, b) => a.order.compareTo(b.order));
    final exactLengths = [for (final b in beforeOrdered) b.length];
    final exactColors = [for (final b in beforeOrdered) b.color];

    // Har lambai ke liye mojooda rangon ke pools (seats barabar rakhne ke liye)
    final colorPools = <int, List<int>>{};
    for (final b in before) {
      colorPools.putIfAbsent(b.length, () => []).add(b.color);
    }

    // Har shuffle par pichhle pattern se mukhtalif layout pattern chunein
    final exclude =
        _lastShufflePattern ?? LevelGenerator.specFor(_levelNumber).pattern;
    final patterns = [
      for (final p in LayoutPattern.values)
        if (p != exclude) p,
    ];
    rng.shuffle(patterns);
    patterns.add(exclude);

    List<BusData>? fallbackPlaced;
    LayoutPattern? fallbackPattern;

    // Pehle exact order lengths (bounds ke andar), phir longestFirst fallback
    final trySpecs =
        <
          (
            LayoutPattern,
            ({double left, double top, double right, double bottom})?,
            bool?,
          )
        >[
          for (var i = 0; i < patterns.length; i++)
            (patterns[i], bounds, null),
          for (var i = 0; i < patterns.length; i++)
            (patterns[i], bounds, true),
          if (bounds != null) ...[
            for (var i = 0; i < patterns.length; i++)
              (patterns[i], null, null),
            for (var i = 0; i < patterns.length; i++)
              (patterns[i], null, true),
          ],
        ];

    for (final (pattern, activeBounds, longestFirst) in trySpecs) {
      final placed = LevelGenerator.arrangeBuses(
        cols: cols,
        rows: rows,
        lengths: exactLengths,
        pattern: pattern,
        rng: rng,
        bounds: activeBounds,
        longestFirst: longestFirst,
      );
      if (placed == null) continue;
      if (!_arrangementDiffers(before, placed)) continue;

      // Placed spots par rang aapas mein mix kar ke solvability check karein
      final spotGroups = <int, List<int>>{};
      for (var i = 0; i < placed.length; i++) {
        spotGroups.putIfAbsent(placed[i].length, () => []).add(i);
      }

      List<int> randomSpotColors() {
        final out = List<int>.filled(placed.length, 0);
        for (final entry in spotGroups.entries) {
          final pool = List<int>.of(colorPools[entry.key]!);
          rng.shuffle(pool);
          final idxs = entry.value;
          for (var k = 0; k < idxs.length; k++) {
            out[idxs[k]] = pool[k];
          }
        }
        return out;
      }

      bool checkPlacedSolvable(
        List<int> spotColors, {
        int nodeLimit = 2500,
      }) {
        final sim = GameModel._raw(
          hasVip,
          cols,
          rows,
          [
            for (var i = 0; i < placed.length; i++)
              placed[i].copy()..color = spotColors[i],
          ],
          slots.map((s) => s?.copy()).toList(),
          lockedSlots,
          List<int>.of(queue),
          head,
          _levelNumber,
          _lastShufflePattern,
        );
        return Solver.canSolve(sim, nodeLimit: nodeLimit);
      }

      for (var attempt = 0; attempt < 5; attempt++) {
        final candColors = randomSpotColors();
        if (fallbackPlaced == null) {
          fallbackPlaced = [
            for (var i = 0; i < placed.length; i++)
              placed[i].copy()..color = candColors[i],
          ];
          fallbackPattern = pattern;
        }
        if (checkPlacedSolvable(candColors, nodeLimit: 1500)) {
          _commitArrangement(placed, candColors, pattern);
          return true;
        }
      }

      // Smart colors try karein agar random rangon se early queue block ho rahi ho
      final smart = _smartColorsFor(placed, spotGroups, colorPools);
      if (smart != null && checkPlacedSolvable(smart, nodeLimit: 5000)) {
        _commitArrangement(placed, smart, pattern);
        return true;
      }

      // Agar lambai aur exit order wahi tha to asal solvable rangon ke sath check karein
      if (longestFirst == null &&
          checkPlacedSolvable(exactColors, nodeLimit: 6000)) {
        _commitArrangement(placed, exactColors, pattern);
        return true;
      }

      if (longestFirst == null) {
        fallbackPlaced = [
          for (var i = 0; i < placed.length; i++)
            placed[i].copy()..color = exactColors[i],
        ];
        fallbackPattern = pattern;
      }
    }

    if (fallbackPlaced != null && fallbackPattern != null) {
      _commitArrangement(
        fallbackPlaced,
        [for (final b in fallbackPlaced) b.color],
        fallbackPattern,
      );
      return true;
    }

    // Aakhri sahara: kam az kam rang shuffle karein
    return shuffleGridColors(rng);
  }

  static bool _arrangementDiffers(List<BusData> before, List<BusData> after) {
    if (before.length != after.length || after.isEmpty) return false;
    var moved = 0;
    var totalDelta = 0.0;
    for (final a in after) {
      var minDelta = double.infinity;
      for (final b in before) {
        if (b.length != a.length) continue;
        final d = math.sqrt(
          (a.cx - b.cx) * (a.cx - b.cx) + (a.cy - b.cy) * (a.cy - b.cy),
        );
        final da = math
            .atan2(math.sin(a.angle - b.angle), math.cos(a.angle - b.angle))
            .abs();
        final delta = d + da * 0.9;
        if (delta < minDelta) minDelta = delta;
      }
      if (minDelta > 0.55) moved++;
      if (minDelta.isFinite) totalDelta += minDelta;
    }
    final minMoved = math.max(1, (after.length * 0.45).ceil());
    return moved >= minMoved && totalDelta / after.length > 0.50;
  }

  void _commitArrangement(
    List<BusData> placed,
    List<int> spotColors,
    LayoutPattern pattern,
  ) {
    // Har mojooda BusData ko usi lambai ke sab se qareebi naye spot se jorein
    final oldByLen = <int, List<BusData>>{};
    final newByLen = <int, List<(BusData, int)>>{};
    for (final b in grid) {
      oldByLen.putIfAbsent(b.length, () => []).add(b);
    }
    for (var i = 0; i < placed.length; i++) {
      newByLen.putIfAbsent(placed[i].length, () => []).add((
        placed[i],
        spotColors[i],
      ));
    }

    for (final len in oldByLen.keys) {
      final olds = oldByLen[len]!;
      final candidates = List<(BusData, int)>.of(newByLen[len]!);
      for (final b in olds) {
        var bestIdx = 0;
        var bestDist = double.infinity;
        for (var i = 0; i < candidates.length; i++) {
          final spot = candidates[i].$1;
          final dx = spot.cx - b.cx;
          final dy = spot.cy - b.cy;
          final d2 = dx * dx + dy * dy;
          if (d2 < bestDist) {
            bestDist = d2;
            bestIdx = i;
          }
        }
        final chosen = candidates.removeAt(bestIdx);
        b.cx = chosen.$1.cx;
        b.cy = chosen.$1.cy;
        b.angle = chosen.$1.angle;
        b.order = chosen.$1.order;
        b.color = chosen.$2;
      }
    }
    _lastShufflePattern = pattern;
  }

  /// Gaadiyan jis order mein nikal sakti hain, usi order mein line ke agle
  /// passengers ke rang do (har lambai ke apne rang ke pool se).
  List<int>? _smartColors(List<int> current, Map<int, List<int>> groups) {
    final pools = <int, List<int>>{
      for (final e in groups.entries)
        e.key: e.value.map((i) => current[i]).toList(),
    };
    return _smartColorsFor(grid, groups, pools);
  }

  List<int>? _smartColorsFor(
    List<BusData> targets,
    Map<int, List<int>> groups,
    Map<int, List<int>> poolSource,
  ) {
    final pools = <int, List<int>>{
      for (final e in poolSource.entries) e.key: List<int>.of(e.value),
    };
    final sim = GameModel._raw(
      hasVip,
      cols,
      rows,
      [for (final b in targets) b.copy()],
      slots.map((s) => s?.copy()).toList(),
      lockedSlots,
      List<int>.of(queue),
      head,
      _levelNumber,
      _lastShufflePattern,
    );
    final result = [for (final b in targets) b.color];
    final order = List<int>.generate(targets.length, (i) => i)
      ..sort((a, b) => targets[b].order.compareTo(targets[a].order));

    for (final i in order) {
      sim.settleInstantly();
      final bus = sim.busById(targets[i].id);
      if (bus == null) return null;
      final pool = pools[bus.length]!;
      // Line mein sab se pehle kis rang ki zaroorat hai (jo slots mein nahi)
      final room = <int, int>{};
      for (final s in sim.slots) {
        if (s != null) room[s.color] = (room[s.color] ?? 0) + s.freeSeats;
      }
      int? pick;
      for (var q = sim.head; q < sim.queue.length && pick == null; q++) {
        final c = sim.queue[q];
        final r = room[c] ?? 0;
        if (r > 0) {
          room[c] = r - 1;
        } else if (pool.contains(c)) {
          pick = c;
        }
      }
      pick ??= pool.first;
      pool.remove(pick);
      result[i] = pick;
      bus.color = pick;
      final r = sim.launch(bus.id, ignoreBlock: true);
      if (r.status != LaunchStatus.ok) return null;
    }
    return result;
  }

  void _applyColors(List<int> colors) {
    for (var i = 0; i < grid.length; i++) {
      grid[i].color = colors[i];
    }
  }

  static bool _sameList(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
