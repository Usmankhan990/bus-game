import 'dart:math' as math;
import 'dart:ui';

import '../models/bus_data.dart';

/// Screen par har cheez ki jagah ka hisaab:
///  1) upar gol "arena" jis mein passengers ka hujoom ghoomta hai,
///  2) us ke neeche kaali sadak jis par tirchhe parking bays hain,
///  3) neeche khula board jis par gaadiyan khadi hain.
/// Screen ka size ya slots ki ginti badle to naya layout banta hai.
class GameLayout {
  GameLayout({
    required this.width,
    required this.height,
    required this.cols,
    required this.rows,
    required this.slotPlaces,
    this.topInset = 0,
    this.passengers = 0,
    Rect? content,
  }) {
    // Camera sirf us hisse ko frame kare jahan gaadiyan hain (board units)
    final c = content ?? Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble());
    contentOrigin = c.topLeft;
    pad = width * 0.02;
    // Upar ka bar (Level, buttons) arena ke upar tairta hai, is liye arena
    // us ke neeche tak jaata hai
    final arenaMin = math.max(topInset + 108, height * 0.3);

    // Camera: grid ko jitna ho sake bara dikhao, magar kam az kam [minCols]
    // khanon jitni jagah (chhote levels mein gaadiyan had se zyada bari na hon).
    // Parking strip ki oonchai bhi cell ke hisaab se ([roadCells]) taa ke bay
    // mein khadi bus lot jitni hi bari rahe (chhoti na ho).
    final fitCols = math.max(c.width, minCols) + 0.7;
    final fitRows = math.max(c.height, minCols) + 0.7;
    slotSpacing = (width - 2 * pad) / slotPlaces;
    cell = [
      (width - 2 * pad) / fitCols,
      (height - arenaMin - pad) / (fitRows + roadCells),
      // Park hui gaadi (chaurai 0.8 cell) apne bay mein samaaye
      slotSpacing * 1.08,
    ].reduce(math.min);
    roadH = roadCells * cell;

    // Lot mein grid ke neeche/upar ki faltu khaali jagah ka zyada hissa upar
    // shehar (arena) ko do: kam grey farsh, zyada shehar aur hujoom
    final lotNeed = c.height * cell + cell * 1.4 + pad;
    final spare = height - arenaMin - roadH - lotNeed;
    arenaH = arenaMin + math.max(0.0, spare * 0.65);
    roadTop = arenaH;

    // Parking lot: sadak ke neeche baqi saari jagah, poori chaudai mein
    final boardTop = roadTop + roadH + pad * 0.5;
    final boardH = height - boardTop - pad * 0.5;
    final gridW = c.width * cell;
    final gridH = c.height * cell;
    gridRect = Rect.fromLTWH(
      (width - gridW) / 2,
      boardTop + (boardH - gridH) / 2,
      gridW,
      gridH,
    );
    // Lot ka kinara; nikalti gaadiyan isi kinare ke saath sadak tak jaati hain
    ring = gridRect.inflate(cell * 0.35);
    // Panel hamesha poori chaurai ka (dono taraf sirf [pad])
    boardPanel = Rect.fromLTWH(0, boardTop, width, boardH);

    // Parking bays (khule + band), seedhe
    // Bay mein lambi bus (3.9 cell) poori aaye; chaurai gaadi se thodi zyada
    bayH = cell * 3.75;
    bayW = math.min(cell * 1.0, slotSpacing * 0.92);
    final bayY = roadTop + cell * 0.25 + bayH / 2;
    slotCenters = [
      for (var i = 0; i < slotPlaces; i++)
        Offset(pad + slotSpacing * (i + 0.5), bayY),
    ];
    laneY = roadTop + roadH * 0.9;

    _buildQueue();
  }

  /// Hujoom ki chaurai mein kitne log saath khade hain
  static const int queueLanes = 4;

  /// Lot kam az kam itne khanon jitna chaura maana jata hai (gaadi ka size)
  static const int minCols = 7;

  /// Parking strip kitne cell ooncha (bay + seats ka badge + neeche ki lane)
  static const double roadCells = 5.2;

  /// Parking bays ka jhukao (0 = seedhe, gaadi ka munh upar)
  // Thoda sa tirchha (zyada jhukao se lambi buses saath wale bay par chadhti hain)
  static const double bayAngle = -5 * math.pi / 180;

  final double width;
  final double height;
  final int cols;
  final int rows;

  /// Upar ke bar (aur status bar) ki oonchai; arena us ke peeche se shuru hota hai
  final double topInset;

  /// Level ke kul passengers: kam log hon to faasla thoda zyada (sadak bhari lage)
  final int passengers;

  /// Slots ki kul jagahen (khule + band)
  final int slotPlaces;

  late final double pad;
  late final double arenaH;
  late final double roadH;
  late final double roadTop;
  late final double cell;

  /// Board (khula maidan) screen par
  late final Rect gridRect;

  /// Board ka panel (kinare samait)
  late final Rect boardPanel;

  /// Board ke gird woh lakeer jis par nikalti gaadiyan chalti hain
  late final Rect ring;

  /// Sadak par bays ke neeche chalne wali lakeer
  late final double laneY;

  late final double slotSpacing;
  late final double bayW;
  late final double bayH;
  late final List<Offset> slotCenters;

  // Purane naam (board painter waghera ke liye)
  double get road => cell * 0.5;
  Rect get roadRect => boardPanel;
  double get queueH => arenaH;
  double get slotsH => roadH;

  // ---------------- Passengers ka hujoom (arena) ----------------

  late final double passengerSize;

  /// Hujoom ke raaste ki chaurai
  late final double bandWidth;

  /// Hujoom ki saanp jaisi sadak (painter isi ko draw karta hai)
  late final Path queueRoad;

  /// U-turn ke andar ki khaali jagahen (darakht lagane ke liye): (markaz, radius)
  late final List<(Offset, double)> queueGaps;

  /// Hujoom ki darmiyani lakeer (aakhir = slots ke paas, wahan pehla passenger)
  late final List<Offset> queueLine;
  late final int maxVisiblePassengers;

  /// Kul baqi passengers ki ginti wali pill
  late final Offset countPillPos;

  /// Sadak ka aakhri sira (parking strip ke beech mein)
  late final Offset gate;

  late final List<double> _cum;
  late final double _spacing;

  void _buildQueue() {
    // A continuous sculpted queue: two upper arms, a central island and a
    // rounded lower loop. The exact same path positions passengers and scenery.
    final space = arenaH - topInset;
    passengerSize = math.min(width * 0.064, space / 6.0).clamp(11.0, 30.0);
    final lane = passengerSize * 0.60;
    bandWidth = lane * queueLanes + passengerSize * 0.55;
    final half = bandWidth / 2;
    final cx = width / 2;
    final left = pad + half + width * 0.015;
    final right = width - left;
    final shoulder = topInset + space * 0.25;
    final notch = topInset + space * 0.39;
    final bowl = roadTop - half - 8;
    // One continuous queue with a hidden turn above the screen. The two
    // upper arms and lower horseshoe share the same boarding order.
    queueRoad = Path()
      ..moveTo(width * 0.28, -bandWidth)
      ..cubicTo(
        width * 0.28,
        shoulder * 0.40,
        left,
        shoulder * 0.80,
        left,
        shoulder,
      )
      ..cubicTo(left, bowl, cx * 0.70, notch, cx, notch)
      ..cubicTo(
        cx * 1.22,
        notch,
        width * 0.68,
        shoulder * 0.60,
        width * 0.68,
        -bandWidth,
      )
      ..cubicTo(
        width * 0.68,
        -bandWidth * 2,
        width * 0.86,
        -bandWidth * 2,
        width * 0.86,
        -bandWidth,
      )
      ..cubicTo(
        width * 0.86,
        shoulder * 0.65,
        right,
        shoulder * 0.85,
        right,
        shoulder,
      )
      // Daayen baazu se ek hi narm mod mein beech tak, aur seedha neeche
      // parking strip ki taraf (koi ulta kunda nahi, warna aage wale log
      // ek doosre par dhair ban jaate hain)
      ..cubicTo(
        right,
        roadTop - half * 0.2,
        cx,
        roadTop - bandWidth * 1.3,
        cx,
        roadTop + 2,
      );
    final metric = queueRoad.computeMetrics().first;
    // Line strip se thoda pehle ruke, taa ke log bays ke upar na chadhen
    final lineEnd = metric.length - half * 0.6;
    final pts = <Offset>[];
    for (double d = 0; d < lineEnd; d += 2) {
      pts.add(metric.getTangentForOffset(d)!.position);
    }
    pts.add(metric.getTangentForOffset(lineEnd)!.position);
    queueLine = pts;
    gate = Offset(cx, roadTop);
    queueGaps = [
      (Offset(width * 0.065, roadTop - half * 0.60), half * 0.54),
      (Offset(width * 0.93, roadTop - half * 0.55), half * 0.55),
    ];
    countPillPos = Offset(cx, topInset + passengerSize * 0.60);

    _cum = [0];
    for (var i = 1; i < pts.length; i++) {
      _cum.add(_cum.last + (pts[i] - pts[i - 1]).distance);
    }
    final fill = _cum.last / ((passengers / queueLanes).ceil() + 2);
    _spacing = passengers == 0
        ? passengerSize * 0.6
        : fill.clamp(passengerSize * 0.6, passengerSize * 0.85);
    // Upar screen ke bahar wale hisse ke log bhi gine jaate hain (taa ke line
    // upar se aati lage); bohat zyada log ek saath na banen
    final stations = (_cum.last / _spacing).floor() - 1;
    maxVisiblePassengers = (stations * queueLanes).clamp(queueLanes, 360);
  }

  /// Hujoom ki lakeer par [dist] faasle wala nuqta aur us jagah ka "normal" (side)
  (Offset, Offset) _alongQueue(double dist) {
    final d = dist.clamp(0.0, _cum.last);
    var i = 1;
    while (i < _cum.length - 1 && _cum[i] < d) {
      i++;
    }
    final a = queueLine[i - 1];
    final b = queueLine[i];
    final seg = _cum[i] - _cum[i - 1];
    final t = seg == 0 ? 0.0 : (d - _cum[i - 1]) / seg;
    final p = Offset.lerp(a, b, t)!;
    final dir = b - a;
    final len = dir.distance == 0 ? 1.0 : dir.distance;
    return (p, Offset(-dir.dy / len, dir.dx / len));
  }

  /// Line mein [index] number passenger ki jagah (0 = sab se aage, sadak ke
  /// aakhri sire par slots ke paas). Har "station" par 3 log saath.
  Offset queuePosition(int index) {
    final station = index ~/ queueLanes;
    final lane = index % queueLanes - (queueLanes - 1) / 2;
    final d = _cum.last - (station + 0.8) * _spacing;
    final (p, _) = _alongQueue(d);
    // Qataar ka rukh lambe hisse (aage-peeche ek station) se nikalo, taa ke
    // mod par bhi har qataar ke 4 log seedhe aur barabar faasle par khade hon
    final (ahead, _) = _alongQueue(d + _spacing);
    final (behind, _) = _alongQueue(d - _spacing);
    final dir = ahead - behind;
    final len = dir.distance == 0 ? 1.0 : dir.distance;
    final n = Offset(-dir.dy / len, dir.dx / len);
    return p +
        n * (lane * passengerSize * 0.6) +
        Offset(0, passengerSize * 0.35);
  }

  /// Naye passengers line ke peeche (shuru) se aate hain
  Offset get hiddenBubblePos => queueLine.first;

  // ---------------- Bays ----------------

  /// Bay mein khadi gaadi ka size: lot jitna hi (bay usi hisaab se bana hai)
  double slotUnitFor(int length) => cell;

  /// Bay ka hit-area (tap ke liye thoda bada, seedha rectangle kaafi hai)
  Rect slotRect(int i) => Rect.fromCenter(
    center: slotCenters[i],
    width: slotSpacing * 0.95,
    height: bayH * 1.35,
  );

  /// Screen ke nuqte par kaun sa bay hai (ya null)
  int? slotIndexAt(Offset p) {
    for (var i = 0; i < slotCenters.length; i++) {
      if (slotRect(i).contains(p)) return i;
    }
    return null;
  }

  /// Passenger gaadi ke darwaze tak kahan jaye (bay ka upar wala hissa)
  Offset doorOf(int slot) {
    final up = Offset(math.sin(bayAngle), -math.cos(bayAngle));
    return slotCenters[slot] + up * (bayH * 0.3);
  }

  // ---------------- Board ----------------

  /// Frame kiye hisse ka board units mein kona ([gridRect] isi se shuru)
  late final Offset contentOrigin;

  /// Board ke nuqte (units) ko screen par
  Offset toScreen(double bx, double by) => Offset(
    gridRect.left + (bx - contentOrigin.dx) * cell,
    gridRect.top + (by - contentOrigin.dy) * cell,
  );

  /// Screen ke nuqte ko board units mein (board se bahar ho to null)
  (double, double)? toBoard(Offset p) {
    if (!gridRect.inflate(cell * 0.2).contains(p)) return null;
    return (
      (p.dx - gridRect.left) / cell + contentOrigin.dx,
      (p.dy - gridRect.top) / cell + contentOrigin.dy,
    );
  }

  /// Gaadiyon ka phailao (board units), thoda kinara chhod kar: camera isi
  /// ko frame karta hai. Grid se bahar nahi jaata.
  static Rect contentOf(List<BusData> buses, int cols, int rows) {
    if (buses.isEmpty) {
      return Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble());
    }
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final bus in buses) {
      final s = math.sin(bus.angle).abs(), co = math.cos(bus.angle).abs();
      final hx = s * bus.length / 2 + co * 0.5;
      final hy = co * bus.length / 2 + s * 0.5;
      l = math.min(l, bus.cx - hx);
      r = math.max(r, bus.cx + hx);
      t = math.min(t, bus.cy - hy);
      b = math.max(b, bus.cy + hy);
    }
    const m = 0.25;
    return Rect.fromLTRB(
      math.max(0, l - m),
      math.max(0, t - m),
      math.min(cols.toDouble(), r + m),
      math.min(rows.toDouble(), b + m),
    );
  }

  /// Board par gaadi ka darmiyani nuqta (screen par)
  Offset busCenter(BusData b) => toScreen(b.cx, b.cy);

  /// Board se nikal kar kinare se sadak tak, phir bay tak ka rasta
  List<Offset> routeToSlot(BusData bus, int slot) {
    final start = busCenter(bus);
    final target = slotCenters[slot];
    final pts = <Offset>[start];

    // 1) Seedha aage (gaadi ke rukh mein) board ke kinare ki lakeer tak
    final fx = bus.fx, fy = bus.fy;
    var t = double.infinity;
    var side = 'top';
    if (fx > 1e-9 && (ring.right - start.dx) / fx < t) {
      t = (ring.right - start.dx) / fx;
      side = 'right';
    }
    if (fx < -1e-9 && (ring.left - start.dx) / fx < t) {
      t = (ring.left - start.dx) / fx;
      side = 'left';
    }
    if (fy > 1e-9 && (ring.bottom - start.dy) / fy < t) {
      t = (ring.bottom - start.dy) / fy;
      side = 'bottom';
    }
    if (fy < -1e-9 && (ring.top - start.dy) / fy < t) {
      t = (ring.top - start.dy) / fy;
      side = 'top';
    }
    final exit = Offset(start.dx + fx * t, start.dy + fy * t);
    pts.add(exit);

    // 2) Kinare ke saath upar sadak ki lakeer tak
    switch (side) {
      case 'top':
        pts.add(Offset(exit.dx, laneY));
      case 'left':
        pts.add(Offset(ring.left, laneY));
      case 'right':
        pts.add(Offset(ring.right, laneY));
      case 'bottom':
        // Jo kinara qareeb ho us taraf se upar jao
        final x = exit.dx < gridRect.center.dx ? ring.left : ring.right;
        pts.add(Offset(x, ring.bottom));
        pts.add(Offset(x, laneY));
    }

    // 3) Sadak par bay ke neeche tak, phir tirchha ho kar bay mein
    final down = Offset(-math.sin(bayAngle), math.cos(bayAngle));
    final approach = target + down * (bayH * 0.7);
    pts.add(Offset(approach.dx, laneY));
    pts.add(approach);
    pts.add(target);

    // Zero lambai wale hisse hata do
    final clean = <Offset>[pts.first];
    for (final p in pts.skip(1)) {
      if ((p - clean.last).distance > 0.5) clean.add(p);
    }
    return clean;
  }
}
