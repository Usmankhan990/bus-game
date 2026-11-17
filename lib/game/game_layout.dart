import 'dart:math' as math;
import 'dart:ui';

import '../models/bus_data.dart';

/// Upar arena ke track ki shakal (har level / restart par badalti hai)
enum QueueShape {
  circle,
  oval,
  square,
  rectangle,
  hexagon,
  diamond,
  heart,
}

/// Screen par har cheez ki jagah ka hisaab:
///  1) upar arena track jis mein passengers ka hujoom ghoomta hai,
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
    this.queueShape = QueueShape.circle,
    Rect? content,
  }) {
    // Camera sirf us hisse ko frame kare jahan gaadiyan hain (board units)
    final c = content ?? Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble());
    contentOrigin = c.topLeft;
    pad = width * 0.02;
    // Upar ka bar (Level, buttons) arena ke upar tairta hai, is liye arena
    // us ke neeche tak jaata hai. Compact arena jahan circle zyada bada na ho
    final arenaMin = math.max(topInset + 148, height * 0.365);

    // Camera: grid ko jitna ho sake bara dikhao, magar kam az kam [minCols]
    // khanon jitni jagah (chhote levels mein gaadiyan had se zyada bari na hon).
    // Parking strip ki oonchai bhi cell ke hisaab se ([roadCells]) taa ke bay
    // mein khadi bus lot jitni hi bari rahe (chhoti na ho).
    final fitCols = math.max(c.width, minCols) + 0.7;
    final fitRows = math.max(c.height, minCols) + 0.7;
    const pillLaneH = 0.0;
    slotSpacing = (width - 2 * pad) / slotPlaces;
    cell = [
      (width - 2 * pad) / fitCols,
      (height - arenaMin - pad - pillLaneH) / (fitRows + roadCells),
      // Park hui gaadi (chaurai 0.8 cell) apne bay mein samaaye
      slotSpacing * 1.08,
    ].reduce(math.min);
    roadH = roadCells * cell;

    // Lot mein grid ke neeche/upar ki faltu khaali jagah ka hissa upar
    // shehar (arena) ko do:
    final lotNeed = c.height * cell + cell * 1.4 + pad + pillLaneH;
    final spare = height - arenaMin - roadH - lotNeed;
    arenaH = arenaMin + math.max(0.0, spare * 0.62);
    roadTop = arenaH;

    // Parking lot: sadak ke neeche pillLaneH jagah chhod kar gaadiyan rakhein taa ke 100 pill na takraye
    final boardTop = roadTop + roadH + pad * 0.5;
    final boardH = height - boardTop - pad * 0.5;
    final gridW = c.width * cell;
    final gridH = c.height * cell;
    gridRect = Rect.fromLTWH(
      (width - gridW) / 2,
      boardTop + pillLaneH + math.max(0.0, (boardH - pillLaneH - gridH) / 2),
      gridW,
      gridH,
    );
    // Lot ka kinara; nikalti gaadiyan isi kinare ke saath sadak tak jaati hain
    ring = gridRect.inflate(cell * 0.35);
    // Panel hamesha poori chaurai ka (dono taraf sirf [pad])
    boardPanel = Rect.fromLTWH(0, boardTop, width, boardH);

    // Parking bays (khule + band): upar-neeche se barabar faasle mein center
    bayH = cell * 3.15;
    bayW = math.min(cell * 1.0, slotSpacing * 0.92);
    final bayY = roadTop + roadH / 2;
    slotCenters = [
      for (var i = 0; i < slotPlaces; i++)
        Offset(pad + slotSpacing * (i + 0.5), bayY),
    ];
    laneY = roadTop + roadH * 0.90;

    _buildQueue();
  }

  /// Hujoom ki chaurai mein kitne log saath khade hain
  static const int queueLanes = 4;

  /// Lot kam az kam itne khanon jitna chaura maana jata hai (gaadi ka size)
  static const int minCols = 7;

  /// Parking strip kitne cell ooncha (40-seat lambi bus bhi bina chhoti hue poori samaye)
  static const double roadCells = 3.90;

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

  /// Arena track ki shakal aur us ke paths
  final QueueShape queueShape;
  late final Offset roundaboutCenter;
  late final double roundaboutRadius;
  late final int stationsAroundRing;
  late final double shapeHalfW;
  late final double shapeHalfH;

  late final Path queueFeetPath;
  late final PathMetric queueFeetMetric;
  late final PathMetric queueRoadMetric;
  late final Path innerIslandPath;
  late final List<Offset> _loopPts;
  late final List<Offset> _loopSmoothNormals;

  late final Path leftFeeder;
  late final Path rightFeeder;
  late final PathMetric leftFeederMetric;
  late final PathMetric rightFeederMetric;

  static const int maxCirclePassengers = 104;
  static const int circleLanes = 4;
  static const int circleStations = 26;
  static const double _ryRatio = 0.84;
  static const double _laneFactor = 0.41;
  static const int _loopSamples = 180;
  static const double _gateThreshold = math.pi / circleStations * 1.14;

  void _buildQueue() {
    final space = arenaH - topInset;
    // Bary shapes aur darmiyan mein wazeh khali space ke liye compact log aur wide arena
    passengerSize = math.min(
      width * 0.044,
      math.max(9.5, (space - 4) / 10.6),
    ).clamp(9.5, 18.2);
    // Track covers inner curb (-1.03*s from road) to outer curb (+1.12*s from road)
    bandWidth = passengerSize * 2.24;
    final half = bandWidth / 2;
    final cx = width / 2;
    final cy = topInset + 3 + (space - 4) * (5.45 / 10.6);
    final ringR = passengerSize * 4.82;

    roundaboutCenter = Offset(cx, cy);
    roundaboutRadius = ringR;
    gate = Offset(cx, roadTop);

    // "100" count pill ko right side par parking sadak ke upar rakhein
    final pillS = math.max(18.0, passengerSize);
    final pillW = pillS * 3.4;
    final pillX = width - pad - pillW * 0.5 - 6;
    final pillY = roadTop - pillS * 0.75 - 6.0;
    countPillPos = Offset(pillX, pillY);

    // Uniform C² smooth centerline sampled equidistantly from bottom center (d=0, clockwise)
    final s = passengerSize;
    final rawPts = _rawShapeSamples(queueShape, roundaboutCenter, s);
    _loopPts = _resampleClosedLoop(rawPts, _loopSamples);
    final normals = _computeLoopNormals(_loopPts);
    _loopSmoothNormals = _smoothNormals(_loopPts, normals, s * 1.45);

    double maxDx = 0, maxDy = 0;
    for (final p in _loopPts) {
      maxDx = math.max(maxDx, (p.dx - cx).abs());
      maxDy = math.max(maxDy, (p.dy - cy).abs());
    }
    shapeHalfW = maxDx;
    shapeHalfH = maxDy;

    // 1) Smooth closed paths: feet centerline (0), asphalt road (+0.11*s), inner hole (-1.03*s)
    queueFeetPath = _catmullPathFromLoop(_loopPts);
    queueFeetMetric = queueFeetPath.computeMetrics().first;
    queueRoad = _catmullPathFromLoop(
      _offsetLoopPoints(_loopPts, normals, s * 0.11),
    );
    queueRoadMetric = queueRoad.computeMetrics().first;
    innerIslandPath = _catmullPathFromLoop(
      _offsetLoopPoints(_loopPts, normals, -s * 1.03),
    );

    // 2) Bilkul corner-tucked symmetrical Side Feeder Chutes (zyada center area khali rahe)
    final roadLen = queueRoadMetric.length;
    final dockT = leftDockU;

    final leftT = queueRoadMetric.getTangentForOffset(roadLen * dockT)!;
    final leftOut = Offset(leftT.vector.dy, -leftT.vector.dx);
    final leftMouth = leftT.position + leftOut * (half * 0.36);

    leftFeeder = Path()
      ..moveTo(-chuteBandWidth * 0.85, topInset + space * 0.02)
      ..cubicTo(
        width * 0.04,
        topInset + space * 0.24,
        leftMouth.dx - width * 0.06,
        leftMouth.dy - space * 0.08,
        leftMouth.dx,
        leftMouth.dy,
      );
    leftFeederMetric = leftFeeder.computeMetrics().first;

    final rightT = queueRoadMetric.getTangentForOffset(
      roadLen * (1.0 - dockT),
    )!;
    final rightOut = Offset(rightT.vector.dy, -rightT.vector.dx);
    final rightMouth = rightT.position + rightOut * (half * 0.36);

    rightFeeder = Path()
      ..moveTo(width + chuteBandWidth * 0.85, topInset + space * 0.02)
      ..cubicTo(
        width * 0.96,
        topInset + space * 0.24,
        rightMouth.dx + width * 0.06,
        rightMouth.dy - space * 0.08,
        rightMouth.dx,
        rightMouth.dy,
      );
    rightFeederMetric = rightFeeder.computeMetrics().first;

    final pts = <Offset>[];
    for (double d = 0; d < roadLen; d += 4) {
      pts.add(queueRoadMetric.getTangentForOffset(d)!.position);
    }
    queueLine = pts;

    queueGaps = [
      (Offset(cx - (maxDx + half + s), cy + maxDy * 0.75), half * 0.6),
      (Offset(cx + (maxDx + half + s), cy + maxDy * 0.75), half * 0.6),
      (Offset(cx, cy), math.min(maxDx, maxDy) * 0.7),
    ];

    stationsAroundRing = circleStations;
    maxVisiblePassengers = 200;
  }

  /// Har shape ki smooth C² contour points (bottom center d=0 se clockwise)
  static List<Offset> _rawShapeSamples(QueueShape shape, Offset c, double s) {
    final cx = c.dx, cy = c.dy;
    switch (shape) {
      case QueueShape.circle:
        return _superellipse(c, 4.82 * s, 4.82 * _ryRatio * s, 2.0);
      case QueueShape.oval:
        return _superellipse(c, 5.65 * s, 3.45 * s, 2.0);
      case QueueShape.square:
        return _superellipse(c, 4.30 * s, 3.85 * s, 3.2);
      case QueueShape.rectangle:
        return _superellipse(c, 5.35 * s, 3.30 * s, 3.0);
      case QueueShape.hexagon:
        final sideW = 5.55 * s, flatW = 2.95 * s, hh = 3.85 * s;
        return _chaikinSmoothLoop(
          [
            Offset(cx, cy + hh),
            Offset(cx - flatW, cy + hh),
            Offset(cx - sideW, cy),
            Offset(cx - flatW, cy - hh),
            Offset(cx + flatW, cy - hh),
            Offset(cx + sideW, cy),
            Offset(cx + flatW, cy + hh),
          ],
          firstCut: 0.24,
          rounds: 3,
          bottomCenterX: cx,
        );
      case QueueShape.diamond:
        final hw = 6.05 * s, hh = 4.30 * s;
        return _chaikinSmoothLoop(
          [
            Offset(cx, cy + hh),
            Offset(cx - hw, cy),
            Offset(cx, cy - hh),
            Offset(cx + hw, cy),
          ],
          firstCut: 0.20,
          rounds: 2,
          bottomCenterX: cx,
        );
      case QueueShape.heart:
        return _heartSamples(c, s);
    }
  }

  /// Smooth C² superellipse (t=0 bottom center se clockwise)
  static List<Offset> _superellipse(Offset c, double a, double b, double p) {
    const steps = 360;
    final exp = 2.0 / p;
    final pts = <Offset>[];
    for (var i = 0; i < steps; i++) {
      final t = math.pi / 2 + (2 * math.pi * i) / steps;
      final ct = math.cos(t);
      final st = math.sin(t);
      final x = c.dx + a * ct.sign * math.pow(ct.abs(), exp).toDouble();
      final y = c.dy + b * st.sign * math.pow(st.abs(), exp).toDouble();
      pts.add(Offset(x, y));
    }
    return pts;
  }

  /// Smooth C² Chaikin B-spline polygon corners starting strictly at bottom center
  static List<Offset> _chaikinSmoothLoop(
    List<Offset> verts, {
    required double firstCut,
    required int rounds,
    required double bottomCenterX,
  }) {
    List<Offset> cut(List<Offset> poly, double ratio) {
      final out = <Offset>[];
      final n = poly.length;
      for (var i = 0; i < n; i++) {
        final a = poly[i];
        final b = poly[(i + 1) % n];
        out.add(Offset.lerp(a, b, ratio)!);
        out.add(Offset.lerp(a, b, 1.0 - ratio)!);
      }
      return out;
    }

    var pts = cut(verts, firstCut);
    for (var r = 0; r < rounds; r++) {
      pts = cut(pts, 0.25);
    }

    // Rotate sequence so point 0 sits strictly at bottom center (bottomCenterX)
    int bestIdx = 0;
    Offset bestPt = pts[0];
    double bestScore = double.infinity;
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % n];
      if ((a.dx >= bottomCenterX && b.dx <= bottomCenterX) &&
          (a.dy + b.dy) * 0.5 > verts.first.dy * 0.5) {
        final denom = (a.dx - b.dx).abs();
        final t = denom < 1e-6 ? 0.5 : (a.dx - bottomCenterX) / (a.dx - b.dx);
        final hit = Offset.lerp(a, b, t.clamp(0.0, 1.0))!;
        if (hit.dy > verts[0].dy - 1000) {
          bestIdx = (i + 1) % n;
          bestPt = hit;
          bestScore = 0;
          break;
        }
      }
      final d = (a.dx - bottomCenterX).abs();
      if (d < bestScore) {
        bestScore = d;
        bestIdx = i;
        bestPt = Offset(bottomCenterX, a.dy);
      }
    }
    return [
      bestPt,
      for (var k = 0; k < n; k++) pts[(bestIdx + k) % n],
    ];
  }

  /// Symmetric Image-2-style wide, hollow smooth Heart loop (bottom center d=0, clockwise)
  static List<Offset> _heartSamples(Offset c, double s) {
    final p0 = Offset(0, 3.75 * s);
    final p1 = Offset(-5.35 * s, -0.45 * s);
    final p2 = Offset(-3.05 * s, -3.55 * s);
    final p3 = Offset(0, -2.05 * s);
    final p4 = Offset(3.05 * s, -3.55 * s);
    final p5 = Offset(5.35 * s, -0.45 * s);

    final segments = <(Offset, Offset, Offset, Offset)>[
      (p0, p0 + Offset(-1.60 * s, 0), p1 + Offset(0.90 * s, 1.85 * s), p1),
      (p1, p1 + Offset(-0.60 * s, -1.50 * s), p2 + Offset(-1.80 * s, 0), p2),
      (p2, p2 + Offset(1.42 * s, 0), p3 + Offset(-1.42 * s, 0), p3),
      (p3, p3 + Offset(1.42 * s, 0), p4 + Offset(-1.42 * s, 0), p4),
      (p4, p4 + Offset(1.80 * s, 0), p5 + Offset(0.60 * s, -1.50 * s), p5),
      (p5, p5 + Offset(-0.90 * s, 1.85 * s), p0 + Offset(1.60 * s, 0), p0),
    ];

    const perSeg = 60;
    final pts = <Offset>[];
    for (final (a, c1, c2, b) in segments) {
      for (var i = 0; i < perSeg; i++) {
        final t = i / perSeg;
        final u = 1.0 - t;
        final pt = a * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            b * (t * t * t);
        pts.add(c + pt);
      }
    }
    return pts;
  }

  static List<Offset> _resampleClosedLoop(List<Offset> raw, int count) {
    final n = raw.length;
    final cum = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      cum[i + 1] = cum[i] + (raw[(i + 1) % n] - raw[i]).distance;
    }
    final total = cum[n];
    final out = <Offset>[];
    var seg = 0;
    for (var k = 0; k < count; k++) {
      final target = (total * k) / count;
      while (seg < n - 1 && cum[seg + 1] < target) {
        seg++;
      }
      final segLen = cum[seg + 1] - cum[seg];
      final t = segLen < 1e-6 ? 0.0 : (target - cum[seg]) / segLen;
      out.add(Offset.lerp(raw[seg], raw[(seg + 1) % n], t)!);
    }
    return out;
  }

  static List<Offset> _computeLoopNormals(List<Offset> pts) {
    final n = pts.length;
    return List<Offset>.generate(n, (i) {
      final v = pts[(i + 1) % n] - pts[(i - 1 + n) % n];
      final d = v.distance;
      if (d < 1e-6) return const Offset(0, -1);
      final t = v / d;
      return Offset(t.dy, -t.dx);
    });
  }

  static List<Offset> _smoothNormals(
    List<Offset> pts,
    List<Offset> normals,
    double windowArc,
  ) {
    final n = pts.length;
    double peri = 0;
    for (var i = 0; i < n; i++) {
      peri += (pts[(i + 1) % n] - pts[i]).distance;
    }
    final step = peri / n;
    final halfW = math.max(1, (windowArc / step).round());
    final sigma = math.max(1.0, halfW * 0.45);
    return List<Offset>.generate(n, (i) {
      double nx = 0, ny = 0;
      for (var k = -halfW; k <= halfW; k++) {
        final w = math.exp(-0.5 * (k / sigma) * (k / sigma));
        final m = normals[(i + k + n * 4) % n];
        nx += m.dx * w;
        ny += m.dy * w;
      }
      final len = math.sqrt(nx * nx + ny * ny);
      return len < 1e-6 ? normals[i] : Offset(nx / len, ny / len);
    });
  }

  static List<Offset> _offsetLoopPoints(
    List<Offset> pts,
    List<Offset> normals,
    double offset,
  ) {
    final n = pts.length;
    final shifted = List<Offset>.generate(n, (i) => pts[i] + normals[i] * offset);
    if (offset == 0) return shifted;
    // Slight Laplacian smoothing on offset contour so concave regions (e.g. heart cleft)
    // remain crease-free without sharp pinches
    var curr = shifted;
    for (var pass = 0; pass < 2; pass++) {
      curr = List<Offset>.generate(n, (i) {
        final a = curr[(i - 1 + n) % n];
        final b = curr[i];
        final c = curr[(i + 1) % n];
        return b * 0.6 + (a + c) * 0.2;
      });
    }
    return curr;
  }

  static Path _catmullPathFromLoop(List<Offset> pts) {
    final n = pts.length;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  (Offset, Offset) _sampleLoopAndNormal(double u) {
    final n = _loopPts.length;
    final f = (u % 1.0) * n;
    final i0 = f.floor() % n;
    final i1 = (i0 + 1) % n;
    final t = f - f.floor();
    final pos = Offset.lerp(_loopPts[i0], _loopPts[i1], t)!;
    final n0 = _loopSmoothNormals[i0];
    final n1 = _loopSmoothNormals[i1];
    final nr = Offset.lerp(n0, n1, t)!;
    final len = nr.distance;
    return (pos, len < 1e-6 ? n0 : nr / len);
  }

  /// Asphalt road centerline radius (feet midpoint 2.74*s -> asphalt midpoint 2.85*s)
  double get trackMidRadius => roundaboutRadius + passengerSize * 0.11;

  /// Feeder chutes ki chaurai
  double get chuteBandWidth => passengerSize * 2.55;

  /// Track par [slot] number passenger ki position (0..59: 15 stations x 4 lanes)
  Offset circlePosition(int slot, double flow) {
    final station = slot ~/ circleLanes;
    final lane = slot % circleLanes;
    final laneOffset = lane - 1.5; // -1.5, -0.5, 0.5, 1.5

    final u = ((flow / (2 * math.pi)) - (station / circleStations)) % 1.0;
    final (pos, outward) = _sampleLoopAndNormal(u);
    final dr = laneOffset * passengerSize * _laneFactor;
    return pos + outward * dr;
  }

  /// Track par [slot] number passenger ke munh ka rukh (clockwise tangent)
  double circleHeading(int slot, double flow) {
    final station = slot ~/ circleLanes;
    final u = ((flow / (2 * math.pi)) - (station / circleStations)) % 1.0;
    final (_, outward) = _sampleLoopAndNormal(u);
    // outward = (tan.dy, -tan.dx) => tan = (-outward.dy, outward.dx)
    return math.atan2(-outward.dy, -outward.dx);
  }

  /// Side feeder chute par passenger ki position (4 log barabar chalte hain)
  /// [rank]: 0..3 row 0, 4..7 row 1, etc.
  Offset chutePosition(int chute, int rank) {
    final metric = chute == 0 ? leftFeederMetric : rightFeederMetric;
    final row = rank ~/ 4;
    final lane = rank % 4;
    final laneOffset = lane - 1.5; // -1.5, -0.5, 0.5, 1.5

    final spacing = passengerSize * 0.88;
    // Rank 0 waits cleanly outside the track outer curb (1.95*s back from junction)
    final d = (metric.length - passengerSize * 1.95 - row * spacing).clamp(
      0.0,
      metric.length,
    );
    final tangent = metric.getTangentForOffset(d);
    if (tangent == null) return hiddenBubblePos;
    final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
    return tangent.position + normal * (laneOffset * passengerSize * 0.56);
  }

  /// Side chute ke upar naye passengers ke aane ka nuqta
  Offset chuteSpawnPos(int chute) {
    final metric = chute == 0 ? leftFeederMetric : rightFeederMetric;
    return metric.getTangentForOffset(0)?.position ?? hiddenBubblePos;
  }

  /// Side chute par passenger ke munh ka rukh (path tangent ke mutabiq)
  double chuteHeading(int chute, int rank) {
    final metric = chute == 0 ? leftFeederMetric : rightFeederMetric;
    final row = rank ~/ 4;
    final spacing = passengerSize * 0.88;
    final d = (metric.length - passengerSize * 1.95 - row * spacing).clamp(
      0.0,
      metric.length,
    );
    final tangent = metric.getTangentForOffset(d);
    if (tangent == null) return 0.0;
    return math.atan2(tangent.vector.dx, -tangent.vector.dy);
  }

  /// Line mein [index] number passenger ki jagah
  Offset queuePosition(int index, [double flow = 0]) {
    if (index < maxCirclePassengers) {
      return circlePosition(index, flow);
    }
    final chuteIdx = (index - maxCirclePassengers) % 2;
    final rank = (index - maxCirclePassengers) ~/ 2;
    return chutePosition(chuteIdx, rank);
  }

  /// Arena shape ki vertical half-height
  double get roundaboutRy => shapeHalfH;

  /// Khule gate ki dehleez (track ke bottom gate edge par)
  Offset get gateThreshold {
    final t = queueRoadMetric.getTangentForOffset(0);
    if (t == null) {
      return Offset(roundaboutCenter.dx, roundaboutCenter.dy + shapeHalfH);
    }
    return t.position.translate(0, bandWidth * 0.25);
  }

  /// Gate se bahar nikalne ka aakhri nuqta (sadak ki patti par)
  Offset get gateRoad => Offset(roundaboutCenter.dx, roadTop);

  /// Khule gate ki aadha chaurai (painter ke saath bilkul barabar)
  double get gateHalfWidth => passengerSize * 1.35;

  /// Kya passenger bilkul khule gate ke darmiyan / samne khada hai
  bool isInGateZone(Offset pos) {
    final dy = pos.dy - roundaboutCenter.dy;
    final dx = (pos.dx - roundaboutCenter.dx).abs();
    if (dy < shapeHalfH * 0.58) return false;
    return dx <= gateHalfWidth;
  }

  /// Left aur right side roads circle ke jis hisse (u = 0..1) par milti hain
  double get leftDockU => queueShape == QueueShape.heart ? 0.29 : 0.28;
  double get rightDockU => 1.0 - leftDockU;

  /// Station ki current position 0..1 loop par (0 = bottom gate, clockwise)
  double stationU(int station, double flow) =>
      ((flow / (2 * math.pi)) - (station / circleStations)) % 1.0;

  /// Loop par [fromU] se [toU] tak sab se chhota signed farq (-0.5 .. 0.5)
  static double signedLoopDelta(double fromU, double toU) {
    var d = (toU - fromU) % 1.0;
    if (d > 0.5) d -= 1.0;
    if (d < -0.5) d += 1.0;
    return d;
  }

  /// Side road ke shuru se circle ke [circleSlot] tak kul rasta (px)
  double introPathLength(int chute, int circleSlot, double flow) {
    final metric = chute == 0 ? leftFeederMetric : rightFeederMetric;
    final dockU = chute == 0 ? leftDockU : rightDockU;
    final targetU = stationU(circleSlot ~/ circleLanes, flow);
    final arcDelta = signedLoopDelta(dockU, targetU).abs();
    return metric.length + arcDelta * queueFeetMetric.length;
  }

  /// Level start animation ke liye side road se circle slot tak smooth rasta
  ({Offset pos, double heading}) introTrackSample(
    int chute,
    int circleSlot,
    double flow,
    double progress,
  ) {
    final metric = chute == 0 ? leftFeederMetric : rightFeederMetric;
    final feederLen = metric.length;
    final dockU = chute == 0 ? leftDockU : rightDockU;
    final station = circleSlot ~/ circleLanes;
    final lane = circleSlot % circleLanes;
    final laneOffset = lane - 1.5;

    final targetU = stationU(station, flow);
    final arcDelta = signedLoopDelta(dockU, targetU);
    final arcLen = arcDelta.abs() * queueFeetMetric.length;
    final totalLen = feederLen + arcLen;
    final dist = progress.clamp(0.0, 1.0) * totalLen;

    final (dockPos, dockOut) = _sampleLoopAndNormal(dockU);
    final pCircleDock =
        dockPos + dockOut * (laneOffset * passengerSize * _laneFactor);

    if (dist <= feederLen) {
      final t = metric.getTangentForOffset(dist);
      if (t == null) return (pos: chuteSpawnPos(chute), heading: 0.0);
      final n = Offset(-t.vector.dy, t.vector.dx);
      final feederLaneOffset = chute == 1 ? -laneOffset : laneOffset;
      final pFeeder =
          t.position + n * (feederLaneOffset * passengerSize * 0.56);
      final blendWindow = passengerSize * 2.4;
      final rawBlend =
          ((dist - (feederLen - blendWindow)) / blendWindow).clamp(0.0, 1.0);
      final smoothBlend = rawBlend * rawBlend * (3.0 - 2.0 * rawBlend);
      return (
        pos: Offset.lerp(pFeeder, pCircleDock, smoothBlend)!,
        heading: math.atan2(t.vector.dx, -t.vector.dy),
      );
    }

    final arcFrac =
        arcLen <= 1e-4 ? 1.0 : ((dist - feederLen) / arcLen).clamp(0.0, 1.0);
    final u = (dockU + arcDelta * arcFrac) % 1.0;
    final (cPos, outward) = _sampleLoopAndNormal(u);
    final pos = cPos + outward * (laneOffset * passengerSize * _laneFactor);
    final cwH = math.atan2(-outward.dy, -outward.dx);
    final walkH = arcDelta >= 0 ? cwH : cwH + math.pi;
    final hBlend = ((arcFrac - 0.85) / 0.15).clamp(0.0, 1.0);
    final diff = math.atan2(math.sin(cwH - walkH), math.cos(cwH - walkH));
    return (pos: pos, heading: walkH + diff * hBlend);
  }

  /// Kya khali [station] abhi left road ke muhane ke paas pohanch gayi hai
  bool isStationAtLeftDock(int station, double flow) {
    final d = (stationU(station, flow) - leftDockU + 0.5) % 1.0 - 0.5;
    return d.abs() <= (0.55 / circleStations);
  }

  /// Kya khali [station] abhi right road ke muhane ke paas pohanch gayi hai
  bool isStationAtRightDock(int station, double flow) {
    final d = (stationU(station, flow) - rightDockU + 0.5) % 1.0 - 0.5;
    return d.abs() <= (0.55 / circleStations);
  }

  /// [station] gate ke darmiyan se kitne radians-equivalent door hai
  double stationGateDelta(int station, double flow) {
    final u = stationU(station, flow);
    final signed = u > 0.5 ? u - 1.0 : u;
    return (signed * 2 * math.pi).abs();
  }

  /// Kya poori 4-logon ki [station] gate zone ke andar hai (sab 4 ek sath chadhen)
  bool isStationInGateZone(int station, double flow) =>
      stationGateDelta(station, flow) <= _gateThreshold;

  /// Clockwise chalte hue [station] gate se kitni door (radians-equivalent) peeche hai
  double stationAheadAngle(int station, double flow) {
    final u = ((flow / (2 * math.pi)) - (station / circleStations)) % 1.0;
    const gateHalf = _gateThreshold / (2 * math.pi);
    return ((gateHalf - u) % 1.0) * 2 * math.pi;
  }

  /// Har passenger ke munh ka rukh (tangent ke mutabiq)
  double queueHeading(int index, [double flow = 0]) {
    if (index < maxCirclePassengers) {
      return circleHeading(index, flow);
    }
    final chuteIdx = (index - maxCirclePassengers) % 2;
    final rank = (index - maxCirclePassengers) ~/ 2;
    return chuteHeading(chuteIdx, rank);
  }

  /// Naye passengers track ke upar se aate hain
  Offset get hiddenBubblePos {
    final t = queueFeetMetric.getTangentForOffset(queueFeetMetric.length * 0.5);
    return t?.position ?? roundaboutCenter.translate(0, -shapeHalfH);
  }

  // ---------------- Bays ----------------

  /// Bay mein khadi gaadi ka width scale: chhoti ho ya lambi bus, chaurai ek jaisi mazboot rahe
  double slotUnitFor(int length) {
    final wUnit = (bayW * 0.86) / 0.78;
    return math.min(cell * 0.82, wUnit);
  }

  /// Lambi bus ya van bay ki unchai mein fit aaye (40 bus 24 van se wazeh lambi rahe)
  double slotLengthScale(int length) {
    final u = slotUnitFor(length);
    final naturalLen = math.max(1.0, length - 0.12) * u;
    final maxLen = bayH * 0.97;
    return naturalLen <= maxLen ? 1.0 : maxLen / naturalLen;
  }

  /// Har bay ke neeche seats ki ginti ka ek-jaisa bada size
  double get badgeUnit => math.min(cell, slotSpacing * 0.94);

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
    final approach = target + down * (bayH * 0.65);
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
