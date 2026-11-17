import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Splash ka waqt (timeline). Ek hi Ticker isay chalata hai aur saare
/// painters / widgets isi ko sunte hain (setState ki zaroorat nahi).
class SplashClock extends ChangeNotifier {
  /// Intro (camera neeche aana, bus ka aana, logo girna) kitni der
  static const double introSeconds = 2.6;

  /// Jaate waqt bus camera ke paas se zoom kar ke guzarti hai
  static const double exitSeconds = 1.0;

  /// Screen khule kitne second hue
  double time = 0;

  /// Duniya kitni door chal chuki (sadak ki pattiyan, imaaratein)
  double scroll = 0;

  /// 0..1 intro ka hissa
  double intro = 0;

  /// 0..1 exit ka hissa
  double exit = 0;

  /// Progress bar (naram tareeqe se asal progress ki taraf barhta hai)
  double progress = 0;

  double? _introStart;
  double? _exitStart;

  bool get introStarted => _introStart != null;
  bool get introDone => intro >= 1;
  bool get exitStarted => _exitStart != null;
  bool get exitDone => exit >= 1;

  void startIntro() => _introStart ??= time;
  void startExit() => _exitStart ??= time;

  /// Camera kitni tezi se peeche hat'ta hai (bus ke saath saath)
  double get speed {
    final settle = (intro / 0.6).clamp(0.0, 1.0);
    return 8 + 10 * (1 - Curves.easeOut.transform(settle)) + 18 * exit;
  }

  void advance(double now, double targetProgress) {
    final dt = (now - time).clamp(0.0, 0.1);
    time = now;
    if (_introStart != null) {
      intro = ((time - _introStart!) / introSeconds).clamp(0.0, 1.0);
    }
    if (_exitStart != null) {
      exit = ((time - _exitStart!) / exitSeconds).clamp(0.0, 1.0);
    }
    scroll += speed * dt;
    progress += (targetProgress - progress) * math.min(1.0, dt * 5);
    if ((targetProgress - progress).abs() < 0.002) progress = targetProgress;
    notifyListeners();
  }
}

class _Building {
  const _Building({
    required this.offset,
    required this.len,
    required this.depth,
    required this.height,
    required this.color,
    required this.awning,
    required this.left,
    required this.gable,
    required this.seed,
  });
  final double offset, len, depth, height;
  final Color color, awning;
  final bool left, gable;
  final int seed;
}

class _Prop {
  const _Prop(this.offset, {required this.left, required this.tree});
  final double offset;
  final bool left, tree;
}

/// Asal 3D manzar: perspective camera, sadak, footpath, 3D imaaratein, darakht,
/// lamp, aasman, aur samne se aati hui badi bus. Sab kuch code se (koi video nahi).
///
/// Duniya ke units: y upar, z camera se door, x daayen. Camera bus ke aage
/// peeche ki taraf chalta hai, is liye cheezein paas se nikal kar ufaq ki
/// taraf jaati hain aur bus samne se aati dikhti hai.
class SplashScenePainter extends CustomPainter {
  SplashScenePainter(this.clock, this.bus) : super(repaint: clock);

  final SplashClock clock;
  final ui.Image? bus;

  // Duniya ka naap
  static const double _road = 2.6;
  static const double _curb = 0.22;
  static const double _walk = 1.9;
  static const double _inner = _road + _curb + _walk + 0.35;
  static const double _busWidth = 2.5;
  static const double _zIdle = 4.0;
  static const double _floorH = 1.0;
  static const double _loop = 64.0;
  static const double _zMin = -4.0;
  static const double _zFar = _loop + _zMin;

  /// Ufaq ki garm dhund (door ki cheezein is rang mein ghul jaati hain)
  static const Color _fog = Color(0xFFFFE7C9);

  static const List<Color> _palette = [
    Color(0xFFFFC387),
    Color(0xFFFF9EAE),
    Color(0xFF8CCBFF),
    Color(0xFFC3A8FF),
    Color(0xFF9BE3B0),
    Color(0xFFFFE08A),
    Color(0xFFF6D6B5),
    Color(0xFFFFB3D9),
  ];

  static const List<Color> _awnings = [
    Color(0xFFEF5350),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
  ];

  static final List<_Building> _buildings = _makeBuildings();
  static final List<_Prop> _props = [
    for (final left in const [true, false])
      for (var i = 0; i < 16; i++)
        _Prop(i * 4.0 + (left ? 0.0 : 2.0), left: left, tree: i.isEven),
  ];
  static final List<(double, double, double, int)> _skyline = _makeSkyline();

  static List<_Building> _makeBuildings() {
    final out = <_Building>[];
    for (final left in const [true, false]) {
      final r = math.Random(left ? 11 : 29);
      var pos = r.nextDouble() * 2;
      while (true) {
        final len = 2.4 + r.nextDouble() * 1.8;
        if (pos + len > _loop - 0.6) break;
        final gable = r.nextDouble() < 0.35;
        out.add(
          _Building(
            offset: pos,
            len: len,
            depth: 2.6 + r.nextDouble() * 2.2,
            height: gable
                ? 2.8 + r.nextDouble() * 2.0
                : 3.0 + r.nextDouble() * 4.6,
            color: _palette[r.nextInt(_palette.length)],
            awning: _awnings[r.nextInt(_awnings.length)],
            left: left,
            gable: gable,
            seed: r.nextInt(1 << 20),
          ),
        );
        pos += len + 0.5 + r.nextDouble() * 0.9;
      }
    }
    return out;
  }

  /// Door shehar ki parchhaaiyan: (x, chaurai, oonchai, layer)
  static List<(double, double, double, int)> _makeSkyline() {
    final r = math.Random(7);
    final out = <(double, double, double, int)>[];
    for (final layer in const [0, 1]) {
      var x = -0.1;
      while (x < 1.1) {
        final w = 0.03 + r.nextDouble() * 0.05;
        final h = layer == 0
            ? 0.04 + r.nextDouble() * 0.12
            : 0.02 + r.nextDouble() * 0.06;
        out.add((x, w, h, layer));
        x += w + r.nextDouble() * 0.012;
      }
    }
    return out;
  }

  late double _w, _h, _cx, _hy, _f, _camX, _camH;

  /// 3D nuqta screen par
  Offset _p(double x, double y, double z) =>
      Offset(_cx + (x - _camX) * _f / z, _hy + (_camH - y) * _f / z);

  double _fogK(double z) => ((z - 5) / 50).clamp(0.0, 1.0) * 0.92;

  @override
  void paint(Canvas canvas, Size size) {
    _w = size.width;
    _h = size.height;
    final t = clock.time;
    final img = bus;
    final ar = img == null ? 1.25 : img.height / img.width;

    // Camera aisa rakho ke rukti hui bus screen par sahi jagah aur naap ki ho
    final busW = math.min(_w * 0.62, _h * 0.36 / ar);
    _f = busW * _zIdle / _busWidth;
    _hy = _h * 0.665 - 1.5 * busW / _busWidth;
    _cx = _w / 2;
    // Shuru mein camera upar (imaaraton ki chhatein dikhti hain), phir neeche
    final crane =
        1 -
        Curves.easeInOutCubic.transform((clock.intro / 0.55).clamp(0.0, 1.0));
    _camH = 1.5 + 5.5 * crane + math.sin(t * 2.1) * 0.025;
    _camX = math.sin(t * 0.45) * 0.35;
    if (clock.exit > 0) {
      // Bus paas se guzre to camera halka sa kaanpe
      final s = clock.exit * _w * 0.006;
      _cx += math.sin(t * 71) * s;
      _hy += math.cos(t * 63) * s;
    }

    _sky(canvas, t);
    _skylineLayer(canvas);
    _ground(canvas);
    _objects(canvas);
    _speedLines(canvas, t);
    _drawBus(canvas, t, ar);
    _vignette(canvas);
  }

  // ---------------------------------------------------------------- Aasman

  void _sky(Canvas canvas, double t) {
    final sky = Rect.fromLTWH(0, 0, _w, _hy + 2);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, _hy),
          const [
            Color(0xFF2456D6),
            Color(0xFF3F92F2),
            Color(0xFF9BD6FF),
            Color(0xFFFFE3B3),
          ],
          const [0, 0.45, 0.82, 1],
        ),
    );

    canvas.save();
    canvas.clipRect(sky);
    // Ufaq se nikalti ghoomti roshni ki kirnein
    final vp = Offset(_cx, _hy);
    final rad = _h * 1.1;
    final rays = Path();
    const n = 18;
    final rot = t * 0.06;
    for (var i = 0; i < n; i++) {
      final a0 = rot + i * 2 * math.pi / n;
      final a1 = a0 + math.pi / n * 0.55;
      rays
        ..moveTo(vp.dx, vp.dy)
        ..lineTo(vp.dx + math.cos(a0) * rad, vp.dy + math.sin(a0) * rad)
        ..lineTo(vp.dx + math.cos(a1) * rad, vp.dy + math.sin(a1) * rad)
        ..close();
    }
    canvas.drawPath(
      rays,
      Paint()
        ..shader = ui.Gradient.radial(vp, rad * 0.75, [
          Colors.white.withValues(alpha: 0.26),
          Colors.white.withValues(alpha: 0),
        ]),
    );
    // Sooraj ki chamak
    final glowR = _w * 0.75;
    canvas.drawCircle(
      vp,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(vp, glowR, const [
          Color(0xDDFFF6D8),
          Color(0x00FFF6D8),
        ]),
    );

    // Baadal: upar wale bade (paas), neeche wale chhote (door)
    const clouds = [
      (0.10, 0.16, 1.25, 0.010),
      (0.64, 0.09, 0.95, 0.007),
      (0.88, 0.36, 1.05, 0.012),
      (0.36, 0.50, 0.75, 0.006),
      (0.04, 0.64, 0.60, 0.009),
      (0.70, 0.72, 0.50, 0.005),
    ];
    for (final (x, y, s, speed) in clouds) {
      final cx = ((x + t * speed) % 1.4 - 0.2) * _w - _camX * _f * 0.03 * s;
      _cloud(canvas, Offset(cx, _hy * y), _w * 0.12 * s);
    }

    // Udte parinde
    final bird = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x992A3A66);
    for (var i = 0; i < 3; i++) {
      final s = _w * 0.018 * (1 - i * 0.18);
      final bx = ((0.08 + i * 0.07 + t * 0.03) % 1.3 - 0.15) * _w;
      final by = _hy * (0.30 + i * 0.06) + math.sin(t * 1.5 + i) * 4;
      final flap = math.sin(t * 9 + i * 2.1);
      bird.strokeWidth = s * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(bx - s, by - s * 0.55 * flap)
          ..quadraticBezierTo(bx - s * 0.45, by - s * 0.35, bx, by)
          ..quadraticBezierTo(
            bx + s * 0.45,
            by - s * 0.35,
            bx + s,
            by - s * 0.55 * flap,
          ),
        bird,
      );
    }

    // Timtimaate sitare (chamak)
    final r = math.Random(21);
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < 7; i++) {
      final sx = r.nextDouble() * _w;
      final sy = r.nextDouble() * _hy * 0.55;
      final tw = (math.sin(t * 2.6 + i * 1.9) + 1) / 2;
      final s = _w * 0.018 * tw;
      if (s < 0.5) continue;
      star.color = Colors.white.withValues(alpha: 0.85 * tw);
      canvas.drawPath(
        Path()
          ..moveTo(sx, sy - s)
          ..quadraticBezierTo(sx, sy, sx + s, sy)
          ..quadraticBezierTo(sx, sy, sx, sy + s)
          ..quadraticBezierTo(sx, sy, sx - s, sy)
          ..quadraticBezierTo(sx, sy, sx, sy - s)
          ..close(),
        star,
      );
    }
    canvas.restore();
  }

  void _cloud(Canvas canvas, Offset o, double s) {
    const puffs = [
      (-0.70, 0.05, 0.50),
      (-0.20, -0.30, 0.68),
      (0.45, -0.15, 0.58),
      (0.95, 0.10, 0.42),
    ];
    final shade = Paint()..color = const Color(0xFFD3E4F8);
    final white = Paint()..color = Colors.white;
    // Neeche ka saaya pehle (is se baadal phoola hua 3D lagta hai)
    canvas.drawOval(
      Rect.fromCenter(
        center: o.translate(0.1 * s, s * 0.26),
        width: s * 2.5,
        height: s * 0.72,
      ),
      shade,
    );
    for (final (dx, dy, r) in puffs) {
      canvas.drawCircle(o.translate(dx * s, dy * s + s * 0.1), r * s, shade);
    }
    for (final (dx, dy, r) in puffs) {
      canvas.drawCircle(o.translate(dx * s, dy * s), r * s, white);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: o.translate(0.1 * s, 0.1 * s),
        width: s * 2.3,
        height: s * 0.56,
      ),
      white,
    );
  }

  void _skylineLayer(Canvas canvas) {
    for (final layer in const [0, 1]) {
      final shift = -_camX * _f * (layer == 0 ? 0.004 : 0.012);
      final path = Path();
      for (final (x, w, h, l) in _skyline) {
        if (l != layer) continue;
        final left = x * _w + shift;
        final top = _hy - h * _w;
        path.addRect(Rect.fromLTRB(left, top, left + w * _w, _hy + 1));
        if (h > 0.12) {
          // Oonchi imaarat par antenna
          path.addRect(
            Rect.fromLTWH(
              left + w * _w * 0.45,
              top - 0.03 * _w,
              w * _w * 0.1,
              0.03 * _w,
            ),
          );
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = layer == 0
              ? const Color(0xFFC4D3F3)
              : const Color(0xFFAABEEB),
      );
    }
    // Ufaq par dhund ki patti
    final haze = Rect.fromLTRB(0, _hy - _w * 0.08, _w, _hy + 1);
    canvas.drawRect(
      haze,
      Paint()
        ..shader = ui.Gradient.linear(haze.topCenter, haze.bottomCenter, [
          _fog.withValues(alpha: 0),
          _fog.withValues(alpha: 0.85),
        ]),
    );
  }

  // ---------------------------------------------------------------- Zameen

  void _quad(Path p, double x1, double x2, double za, double zb) {
    p.addPolygon([
      _p(x1, 0, za),
      _p(x2, 0, za),
      _p(x2, 0, zb),
      _p(x1, 0, zb),
    ], true);
  }

  void _ground(Canvas canvas) {
    // Screen ke bilkul neeche wala z (thoda aur paas taake kinara na dikhe)
    final zNear = _camH * _f / (_h - _hy) * 0.85;
    canvas.drawRect(
      Rect.fromLTRB(0, _hy, _w, _h),
      Paint()..color = const Color(0xFF79CF57),
    );
    final vp = Offset(_cx, _hy);
    void band(double x1, double x2, Paint paint) {
      canvas.drawPath(
        Path()..addPolygon([vp, _p(x1, 0, zNear), _p(x2, 0, zNear)], true),
        paint,
      );
    }

    const outer = _road + _curb + _walk;
    band(-outer, outer, Paint()..color = const Color(0xFFF3DDB8));
    band(-(_road + _curb), _road + _curb, Paint()..color = Colors.white);
    band(
      -_road,
      _road,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, _hy), Offset(0, _h), const [
          Color(0xFF9295AD),
          Color(0xFF51576D),
        ]),
    );
    final edge = Paint()..color = Colors.white.withValues(alpha: 0.9);
    band(-_road + 0.15, -_road + 0.27, edge);
    band(_road - 0.27, _road - 0.15, edge);

    // Chalti pattiyan: laal-safed kinara, beech ki dash, ghaas ki dhaariyan
    const seg = 1.6;
    final phase = clock.scroll % (2 * seg);
    final red = Path();
    final dash = Path();
    final grass = Path();
    final joints = Path();
    for (var i = 0; ; i++) {
      final za = i * seg + phase - 2 * seg;
      if (za > 70) break;
      final zb = za + seg;
      if (zb <= zNear) continue;
      final a = math.max(za, zNear);
      if (i.isEven) {
        _quad(red, _road, _road + _curb, a, zb);
        _quad(red, -_road - _curb, -_road, a, zb);
        _quad(dash, -0.09, 0.09, a, zb);
        _quad(grass, outer, 60, a, zb);
        _quad(grass, -60, -outer, a, zb);
      }
      if (za >= zNear) {
        _quad(joints, -outer, -_road - _curb, za, za + 0.07);
        _quad(joints, _road + _curb, outer, za, za + 0.07);
      }
    }
    canvas.drawPath(grass, Paint()..color = const Color(0xFF68BD48));
    canvas.drawPath(joints, Paint()..color = const Color(0xFFDCC197));
    canvas.drawPath(red, Paint()..color = const Color(0xFFEF4B4B));
    canvas.drawPath(
      dash,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // Door ki zameen dhund mein
    final hz = Rect.fromLTRB(0, _hy, _w, _hy + (_h - _hy) * 0.35);
    canvas.drawRect(
      hz,
      Paint()
        ..shader = ui.Gradient.linear(hz.topCenter, hz.bottomCenter, [
          _fog.withValues(alpha: 0.95),
          _fog.withValues(alpha: 0),
        ]),
    );
  }

  // ---------------------------------------------------------- Imaaratein

  double _zOf(double offset) => (offset + clock.scroll) % _loop + _zMin;

  void _objects(Canvas canvas) {
    // Door se paas (painter's algorithm). Footpath ki cheezein hamesha
    // imaaraton ke aage hoti hain, is liye woh baad mein.
    final bs = <(double, _Building)>[
      for (final b in _buildings) (_zOf(b.offset), b),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (z, b) in bs) {
      _building(canvas, b, z);
    }
    final ps = <(double, _Prop)>[for (final p in _props) (_zOf(p.offset), p)]
      ..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (z, p) in ps) {
      _prop(canvas, p, z);
    }
  }

  void _building(Canvas canvas, _Building b, double z0) {
    const zc = 0.35;
    final z1 = z0 + b.len;
    if (z1 <= zc || z0 >= _zFar) return;
    final fade = ((_zFar - z0) / 10).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final za = math.max(z0, zc);
    final fog = _fogK(za);
    Color tint(Color c) => Color.lerp(c, _fog, fog)!.withValues(alpha: fade);

    final s = b.left ? -1.0 : 1.0;
    final xi = s * _inner; // sadak wali deewar
    final xo = s * (_inner + b.depth);
    final h = b.height;
    final floors = (h / _floorH).floor();
    final paint = Paint();
    final body = b.color;
    // Baayen deewarein dhoop mein, daayen saaye mein
    final sideColor = AppColors.darker(body, b.left ? 0.08 : 0.24);

    // --- Side deewar
    canvas.drawPath(
      Path()..addPolygon([
        _p(xi, 0, za),
        _p(xi, h, za),
        _p(xi, h, z1),
        _p(xi, 0, z1),
      ], true),
      paint..color = tint(sideColor),
    );
    if (z0 < 34) {
      final win = Path();
      final shop = Path();
      final nz = math.max(1, (b.len / 1.1).floor());
      for (var fl = 1; fl < floors; fl++) {
        final y0 = fl * _floorH + 0.28;
        final y1 = y0 + 0.5;
        for (var k = 0; k < nz; k++) {
          final wa = z0 + (k + 0.25) * b.len / nz;
          final wb = z0 + (k + 0.75) * b.len / nz;
          if (wa < zc) continue;
          win.addPolygon([
            _p(xi, y0, wa),
            _p(xi, y1, wa),
            _p(xi, y1, wb),
            _p(xi, y0, wb),
          ], true);
        }
      }
      final sa = math.max(z0 + 0.25, zc);
      final sb = z1 - 0.25;
      if (sb > sa) {
        shop.addPolygon([
          _p(xi, 0.12, sa),
          _p(xi, 0.72, sa),
          _p(xi, 0.72, sb),
          _p(xi, 0.12, sb),
        ], true);
      }
      canvas.drawPath(
        win,
        paint..color = tint(AppColors.darker(const Color(0xFF9CCBF0), 0.08)),
      );
      canvas.drawPath(shop, paint..color = tint(const Color(0xFF6FA8D8)));
      // Shamiyana (awning) aur upar ki patti
      canvas.drawPath(
        Path()..addPolygon([
          _p(xi, 0.8, za),
          _p(xi, 1.02, za),
          _p(xi, 1.02, z1),
          _p(xi, 0.8, z1),
        ], true),
        paint..color = tint(b.awning),
      );
    }
    if (!b.gable) {
      canvas.drawPath(
        Path()..addPolygon([
          _p(xi, h - 0.22, za),
          _p(xi, h, za),
          _p(xi, h, z1),
          _p(xi, h - 0.22, z1),
        ], true),
        paint..color = tint(AppColors.lighter(body, 0.3)),
      );
    }

    // --- Chhat (sirf jab camera upar ho)
    if (!b.gable && _camH > h + 0.05) {
      canvas.drawPath(
        Path()..addPolygon([
          _p(xo, h, za),
          _p(xi, h, za),
          _p(xi, h, z1),
          _p(xo, h, z1),
        ], true),
        paint..color = tint(Color.lerp(body, const Color(0xFF8C90A8), 0.55)!),
      );
    }
    final xm = (xi + xo) / 2;
    const rh = 1.0;
    final roof = AppColors.darker(b.awning, 0.05);
    if (b.gable) {
      canvas.drawPath(
        Path()..addPolygon([
          _p(xi, h, za),
          _p(xm, h + rh, za),
          _p(xm, h + rh, z1),
          _p(xi, h, z1),
        ], true),
        paint..color = tint(roof),
      );
    }

    // --- Saamne ki deewar
    if (z0 < zc) return;
    final u = _f / z0;
    final r = Rect.fromPoints(_p(xo, h, z0), _p(xi, 0, z0));
    canvas.drawRect(r, paint..color = tint(body));
    if (r.width > 5) {
      final cols = math.max(1, (b.depth / 1.0).floor());
      final cw = r.width / cols;
      final glass = Path();
      final lit = Path();
      for (var fl = 1; fl < floors; fl++) {
        final top = r.bottom - (fl * _floorH + 0.78) * u;
        for (var col = 0; col < cols; col++) {
          final wr = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              r.left + cw * col + cw * 0.22,
              top,
              cw * 0.56,
              0.5 * u,
            ),
            Radius.circular(u * 0.06),
          );
          ((b.seed + fl * 7 + col * 13) % 5 == 0 ? lit : glass).addRRect(wr);
        }
      }
      canvas.drawPath(glass, paint..color = tint(const Color(0xFF8EC6F0)));
      canvas.drawPath(lit, paint..color = tint(const Color(0xFFFFE89A)));
      // Neeche dukaan ka sheesha aur darwaza
      canvas.drawRect(
        Rect.fromLTWH(
          r.left + r.width * 0.1,
          r.bottom - 0.74 * u,
          r.width * 0.8,
          0.62 * u,
        ),
        paint..color = tint(const Color(0xFF6FA8D8)),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          r.left + r.width * 0.42,
          r.bottom - 0.74 * u,
          r.width * 0.16,
          0.74 * u,
        ),
        paint..color = tint(AppColors.darker(body, 0.4)),
      );
      // Dhaari daar shamiyana
      final aw = Rect.fromLTWH(
        r.left + r.width * 0.05,
        r.bottom - 1.06 * u,
        r.width * 0.9,
        0.28 * u,
      );
      canvas.drawRect(aw, paint..color = tint(Colors.white));
      const stripes = 6;
      final sw = aw.width / stripes;
      final st = Path();
      for (var i = 0; i < stripes; i += 2) {
        st.addRect(Rect.fromLTWH(aw.left + i * sw, aw.top, sw, aw.height));
      }
      canvas.drawPath(st, paint..color = tint(b.awning));
      canvas.drawRect(
        Rect.fromLTWH(aw.left, aw.bottom, aw.width, aw.height * 0.35),
        paint..color = Colors.black.withValues(alpha: 0.12 * fade),
      );
      if (!b.gable) {
        canvas.drawRect(
          Rect.fromLTWH(r.left - 0.08 * u, r.top, r.width + 0.16 * u, 0.24 * u),
          paint..color = tint(AppColors.lighter(body, 0.35)),
        );
      }
    }
    if (b.gable) {
      canvas.drawPath(
        Path()..addPolygon([
          _p(xo + s * 0.15, h, z0),
          _p(xi - s * 0.15, h, z0),
          _p(xm, h + rh + 0.08, z0),
        ], true),
        paint..color = tint(roof),
      );
      canvas.drawPath(
        Path()..addPolygon([
          _p(xo - s * 0.1, h, z0),
          _p(xi + s * 0.1, h, z0),
          _p(xm, h + rh - 0.12, z0),
        ], true),
        paint..color = tint(AppColors.lighter(body, 0.2)),
      );
    }
    // Kone par roshni ki lakeer (3D kinara saaf dikhe)
    canvas.drawLine(
      _p(xi, 0, z0),
      _p(xi, h, z0),
      Paint()
        ..color = tint(AppColors.lighter(body, 0.45))
        ..strokeWidth = math.max(1.0, 0.06 * u),
    );
  }

  void _prop(Canvas canvas, _Prop pr, double z) {
    if (z < 0.6 || z >= _zFar) return;
    final fade = ((_zFar - z) / 10).clamp(0.0, 1.0);
    final fog = _fogK(z);
    Color tint(Color c) => Color.lerp(c, _fog, fog)!.withValues(alpha: fade);
    final u = _f / z;
    final s = pr.left ? -1.0 : 1.0;

    if (pr.tree) {
      final x = s * (_road + _curb + _walk - 0.6);
      final base = _p(x, 0, z);
      canvas.drawOval(
        Rect.fromCenter(center: base, width: 1.3 * u, height: 0.28 * u),
        Paint()..color = Colors.black.withValues(alpha: 0.16 * fade),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: base.translate(0, -0.5 * u),
          width: 0.18 * u,
          height: 1.0 * u,
        ),
        Paint()..color = tint(const Color(0xFF8A5A3C)),
      );
      final top = _p(x, 1.9, z);
      final leaf = Paint()
        ..shader = ui.Gradient.radial(
          top.translate(-0.25 * u, -0.25 * u),
          1.3 * u,
          [
            tint(const Color(0xFFB2F07F)),
            tint(const Color(0xFF4CAF50)),
            tint(const Color(0xFF2E7D32)),
          ],
          const [0, 0.55, 1],
        );
      for (final (dx, dy, r) in const [
        (0.0, 1.25, 0.5),
        (-0.38, 1.38, 0.46),
        (0.38, 1.42, 0.48),
        (0.0, 1.78, 0.62),
      ]) {
        canvas.drawCircle(_p(x + dx, dy, z), r * u, leaf);
      }
    } else {
      final x = s * (_road + _curb + 0.4);
      final pole = Paint()
        ..color = tint(const Color(0xFF41506E))
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        _p(x, 0, z),
        _p(x, 3.0, z),
        pole..strokeWidth = math.max(1.0, 0.08 * u),
      );
      canvas.drawLine(
        _p(x, 2.92, z),
        _p(x - s * 0.55, 3.05, z),
        pole..strokeWidth = math.max(1.0, 0.06 * u),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: _p(x, 0.12, z),
          width: 0.2 * u,
          height: 0.24 * u,
        ),
        Paint()..color = tint(const Color(0xFF41506E)),
      );
      final head = _p(x - s * 0.62, 2.98, z);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: head, width: 0.34 * u, height: 0.14 * u),
          Radius.circular(0.07 * u),
        ),
        Paint()..color = tint(const Color(0xFF41506E)),
      );
      final bulb = head.translate(0, 0.09 * u);
      canvas.drawCircle(
        bulb,
        0.6 * u,
        Paint()
          ..shader = ui.Gradient.radial(bulb, 0.6 * u, [
            Color.fromRGBO(255, 243, 176, 0.45 * fade),
            const Color(0x00FFF3B0),
          ]),
      );
      canvas.drawCircle(
        bulb,
        0.08 * u,
        Paint()..color = tint(const Color(0xFFFFF3B0)),
      );
    }
  }

  // ---------------------------------------------------------------- Bus

  void _drawBus(Canvas canvas, double t, double ar) {
    final img = bus;
    if (img == null || !clock.introStarted) return;
    // Ufaq se aakar camera ke aage rukti hai, phir jaate waqt paas se zoom
    final arrive = Curves.easeOutCubic.transform(
      (clock.intro / 0.62).clamp(0.0, 1.0),
    );
    var z = 48 + (_zIdle - 48) * arrive;
    final ex = Curves.easeInCubic.transform(clock.exit);
    z += (0.6 - z) * ex;
    final alpha = (arrive * 5).clamp(0.0, 1.0);
    final bx = math.sin(t * 0.45 + 0.7) * 0.22;
    final u = _f / z;
    final w = _busWidth * u;
    final h = w * ar;
    final base = _p(bx, 0, z);
    final tilt = math.cos(t * 0.45 + 0.7) * 0.02 + math.sin(t * 1.9) * 0.006;
    final bounce =
        (math.sin(t * 7.0).abs() * 0.010 + math.sin(t * 37) * 0.0025) * h;

    // Zameen par saaya
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -h * 0.01),
        width: w * 1.12,
        height: w * 0.17,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34 * alpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.0, w * 0.03),
        ),
    );

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    // Nayi splash bus (splash_bus_hero) ya purani home_bus ke mutabiq pahiye aur battiyan
    final isHeroCoach = ar < 1.22;
    final groundK = isHeroCoach ? 0.988 : 0.955;
    final dst = Rect.fromLTWH(-w / 2, -h * groundK - bounce, w, h);

    // Pahiyon se udti dhool (peeche ki taraf)
    final dust = Paint();
    final wheelPositions = isHeroCoach
        ? const [(0.233, -1.0, 0.985), (0.767, 1.0, 0.985)]
        : const [(0.235, -1.0, 0.94), (0.765, 1.0, 0.94)];
    for (final (wx, side, wy) in wheelPositions) {
      final wheel = Offset(
        dst.left + dst.width * wx,
        dst.top + dst.height * wy,
      );
      for (var i = 0; i < 6; i++) {
        final ph = (t * 1.3 + i / 6) % 1.0;
        dust.color = Color.fromRGBO(241, 227, 200, 0.45 * (1 - ph) * alpha);
        canvas.drawCircle(
          wheel.translate(side * ph * w * 0.3, -ph * h * 0.07),
          w * (0.025 + 0.05 * ph),
          dust,
        );
      }
    }

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );

    // Jalti hui headlights aur chamak ki lakeer
    final glow = (0.75 + 0.25 * math.sin(t * 5)) * alpha;
    final headLights = isHeroCoach
        ? const [(0.281, 0.653), (0.741, 0.657)]
        : const [(0.262, 0.775), (0.722, 0.775)];
    for (final (hx, hy) in headLights) {
      final c = Offset(dst.left + dst.width * hx, dst.top + dst.height * hy);
      final r = w * (isHeroCoach ? 0.16 : 0.20);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            Color.fromRGBO(255, 244, 200, 0.75 * glow),
            const Color(0x00FFF4C8),
          ]),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * 0.5, height: w * 0.035),
        Paint()
          ..shader = ui.Gradient.radial(c, w * 0.25, [
            Colors.white.withValues(alpha: 0.75 * glow),
            Colors.white.withValues(alpha: 0),
          ]),
      );
    }
    canvas.restore();
  }

  void _speedLines(Canvas canvas, double t) {
    final k = Curves.easeIn.transform(clock.exit);
    if (k <= 0.01) return;
    final vp = Offset(_cx, _hy);
    final maxR = math.sqrt(_w * _w + _h * _h);
    final r = math.Random(5);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 40; i++) {
      final a = r.nextDouble() * 2 * math.pi;
      final sp = 0.6 + r.nextDouble();
      final ph = (r.nextDouble() + t * sp * 1.6) % 1.0;
      final r0 = maxR * (0.12 + ph * 0.9);
      final len = maxR * (0.08 + 0.25 * ph) * k;
      final d = Offset(math.cos(a), math.sin(a));
      paint
        ..color = Colors.white.withValues(alpha: 0.55 * k * ph)
        ..strokeWidth = 1.5 + 3 * ph;
      canvas.drawLine(vp + d * r0, vp + d * (r0 + len), paint);
    }
  }

  void _vignette(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _w, _h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(_w / 2, _h * 0.45),
          math.max(_w, _h) * 0.75,
          const [Color(0x00000000), Color(0x40061848)],
          const [0.55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(SplashScenePainter old) =>
      old.bus != bus || old.clock != clock;
}

/// Sab se upar: shuru mein native splash ke neele rang se naram fade-in,
/// aur aakhir mein bus guzarne par safed chamak.
class SplashFlashPainter extends CustomPainter {
  SplashFlashPainter(this.clock) : super(repaint: clock);
  final SplashClock clock;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fadeIn = 1 - (clock.time / 0.45).clamp(0.0, 1.0);
    if (fadeIn > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF308CE8).withValues(alpha: fadeIn),
      );
    }
    final flash = ((clock.exit - 0.6) / 0.4).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: flash * flash),
      );
    }
  }

  @override
  bool shouldRepaint(SplashFlashPainter old) => old.clock != clock;
}
