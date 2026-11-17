import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/bus_data.dart';
import '../../models/city.dart';
import '../game_layout.dart';
import 'palette.dart';
import 'sprite_bank.dart';

/// Manzar (farsh, passengers ki sadak, parking strip, lot) ko code se draw karna.
/// Baad mein images lagani hon to sirf yeh file badlein.
class BoardPainter {
  /// Jo hissa kabhi nahi badalta (farsh, bagh, sadak, lot). BoardComponent isay
  /// ek dafa draw kar ke yaad rakhta hai, taa ke har frame dobara na banana pade.
  static void paintStatic(
    Canvas canvas,
    GameLayout l, {
    City city = City.tokyo,
    List<BusData> buses = const [],
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, l.width, l.height),
      Paint()..color = GamePalette.floor,
    );
    _arena(canvas, l, city);
    _decor(canvas, l, city);
    _lot(canvas, l, buses);
  }

  /// Arena par guzarte baadalon ke halke saaye (har frame; sirf 2 gradient)
  static void paintClouds(Canvas canvas, GameLayout l, double time) {
    final area = Rect.fromLTWH(0, 0, l.width, l.roadTop);
    canvas.save();
    canvas.clipRect(area);
    for (var i = 0; i < 2; i++) {
      final w = l.width * (0.55 + i * 0.2);
      final span = l.width + w;
      final x = (time * l.width * (0.018 + i * 0.008) + i * span * 0.55) % span;
      final c = Offset(x - w / 2, l.roadTop * (0.35 + i * 0.3));
      final r = Rect.fromCenter(center: c, width: w, height: w * 0.42);
      canvas.drawOval(
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x14000000), Color(0x00000000)],
          ).createShader(r),
      );
    }
    canvas.restore();
  }

  /// Har shehar ki apni chhoti decoration (sadak aur nishani se door, khaali
  /// zameen par). Jagahen har shehar ke liye pakki (seeded random).
  static void _decor(Canvas canvas, GameLayout l, City city) {
    final s = l.passengerSize;
    final half = math.max(l.bandWidth, l.chuteBandWidth) / 2;
    // Sadak (roundabout + side chutes + gate) ke nuqte (faasla naapne ke liye)
    final road = <Offset>[];
    for (final path in [l.queueRoad, l.leftFeeder, l.rightFeeder]) {
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 6) {
          road.add(m.getTangentForOffset(d)!.position);
        }
      }
    }
    for (var y = l.roundaboutCenter.dy + l.roundaboutRy; y <= l.roadTop; y += 6) {
      road.add(Offset(l.roundaboutCenter.dx, y));
    }
    final rnd = math.Random(city.index * 7 + 3);
    final kinds = _decorKinds(city);
    final step = s * 2.3;
    // (jagah, size, qism)
    final spots = <(Offset, double, String)>[];
    // Upar ka bar shafaf hai: us ke peeche bhi decoration (sirf buttons, level
    // badge aur status bar ki jagah chhod kar)
    final barTop = l.topInset - 54;
    bool underHud(Offset p) =>
        p.dy < barTop + 8 ||
        (p.dy < l.topInset + s * 0.4 &&
            (p.dx < 62 ||
                p.dx > l.width - 62 ||
                (p.dx - l.width / 2).abs() < 86));
    for (var y = barTop + s * 0.9; y < l.roadTop - s * 0.9; y += step) {
      for (var x = s; x < l.width - s * 0.6; x += step) {
        final p = Offset(
          x + (rnd.nextDouble() - .5) * step * .6,
          y + (rnd.nextDouble() - .5) * step * .5,
        );
        final r = s * (0.45 + rnd.nextDouble() * 0.3);
        final clear = half + r * 0.9 + 3;
        var ok = !underHud(p);
        for (final q in road) {
          if ((q - p).distanceSquared < clear * clear) {
            ok = false;
            break;
          }
        }
        // Nishani aur darakht wale kone, aur ginti wali pill khaali rahe
        for (final (c, gr) in l.queueGaps) {
          if ((c - p).distance < gr * 1.7 + r) ok = false;
        }
        if ((l.countPillPos - p).distance < s * 2.2) ok = false;
        for (final (o, orr, _) in spots) {
          if ((o - p).distance < (orr + r) * 1.05) ok = false;
        }
        if (ok) spots.add((p, r, kinds[rnd.nextInt(kinds.length)]));
      }
    }
    // Upar wali cheezen pehle, neeche wali baad mein (sahi parda)
    spots.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (final (p, r, kind) in spots) {
      _prop(canvas, kind, p, r);
    }
  }

  static List<String> _decorKinds(City c) => switch (c) {
    City.karachi => ['palm', 'palm', 'lamp', 'umbrella', 'bush'],
    City.lahore => ['tree', 'flowers', 'lamp', 'tree', 'bush'],
    City.islamabad => ['pine', 'pine', 'tree', 'flowers', 'bench'],
    City.dubai => ['palm', 'fountain', 'lamp', 'palm', 'flowers'],
    City.london => ['tree', 'phone', 'lamp', 'bench', 'bush'],
    City.paris => ['topiary', 'cafe', 'lamp', 'flowers', 'topiary'],
    City.newyork => ['tree', 'hydrant', 'lamp', 'bench', 'bush'],
    City.tokyo => ['blossom', 'lantern', 'blossom', 'bench', 'bush'],
  };

  /// Ek chhoti cheez (darakht, lamp, bench...) [c] par, size [r]
  static void _prop(Canvas canvas, String kind, Offset c, double r) {
    Paint p(int color) => Paint()..color = Color(color);
    // Zameen par saaya
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(r * 0.15, r * 0.3),
        width: r * 1.4,
        height: r * 0.6,
      ),
      p(0x22000000),
    );
    switch (kind) {
      case 'palm':
        canvas.drawLine(
          c.translate(0, r * 0.3),
          c.translate(r * 0.1, -r * 0.6),
          p(0xFF9A7246)
            ..strokeWidth = r * 0.18
            ..strokeCap = StrokeCap.round,
        );
        final top = c.translate(r * 0.1, -r * 0.65);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + 0.3;
          final tip = top + Offset(math.cos(a), math.sin(a) * 0.6) * r * 0.85;
          canvas.drawLine(
            top,
            tip,
            p(i.isEven ? 0xFF3E9E45 : 0xFF5CBF5A)
              ..strokeWidth = r * 0.22
              ..strokeCap = StrokeCap.round,
          );
        }
      case 'pine':
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, -r * 0.35),
            width: r * 0.9,
            height: r * 1.7,
          ),
          p(0xFF2F7A45),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(-r * 0.12, -r * 0.55),
            width: r * 0.4,
            height: r * 0.9,
          ),
          p(0xFF4C9A5C),
        );
      case 'tree' || 'bush' || 'topiary' || 'blossom':
        final k = kind == 'bush' ? 0.7 : 1.0;
        final (dark, light) = switch (kind) {
          'blossom' => (0xFFE98CB5, 0xFFFCD7E4),
          'topiary' => (0xFF3F8F4A, 0xFF6DBE6A),
          _ => (0xFF4FA64A, 0xFF8FD47A),
        };
        if (kind != 'bush') {
          canvas.drawRect(
            Rect.fromCenter(
              center: c.translate(0, r * 0.1),
              width: r * 0.16,
              height: r * 0.5,
            ),
            p(0xFF8A5E43),
          );
        }
        final cc = c.translate(0, kind == 'bush' ? 0 : -r * 0.35);
        if (kind == 'topiary') {
          canvas.drawCircle(cc, r * 0.55, p(dark));
          canvas.drawCircle(
            cc.translate(-r * 0.15, -r * 0.18),
            r * 0.25,
            p(light),
          );
        } else {
          canvas.drawCircle(
            cc.translate(-r * 0.3 * k, 0),
            r * 0.45 * k,
            p(dark),
          );
          canvas.drawCircle(
            cc.translate(r * 0.3 * k, 0),
            r * 0.45 * k,
            p(dark),
          );
          canvas.drawCircle(
            cc.translate(0, -r * 0.25 * k),
            r * 0.5 * k,
            p(dark),
          );
          canvas.drawCircle(
            cc.translate(-r * 0.15 * k, -r * 0.35 * k),
            r * 0.2 * k,
            p(light),
          );
        }
      case 'flowers':
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 1.5, height: r * 0.8),
          p(0xFF5DAA4E),
        );
        const petals = [0xFFFF5B6E, 0xFFFFD34D, 0xFFFFFFFF, 0xFFB57BFF];
        final rnd = math.Random(c.dx.toInt());
        for (var i = 0; i < 7; i++) {
          canvas.drawCircle(
            c +
                Offset(
                  (rnd.nextDouble() - .5) * r * 1.1,
                  (rnd.nextDouble() - .5) * r * 0.5,
                ),
            r * 0.12,
            p(petals[i % 4]),
          );
        }
      case 'lamp' || 'lantern':
        canvas.drawLine(
          c.translate(0, r * 0.3),
          c.translate(0, -r * 0.9),
          p(0xFF3A4152)
            ..strokeWidth = r * 0.1
            ..strokeCap = StrokeCap.round,
        );
        final head = c.translate(0, -r * 0.95);
        if (kind == 'lantern') {
          canvas.drawOval(
            Rect.fromCenter(center: head, width: r * 0.45, height: r * 0.6),
            p(0xFFE8432F),
          );
        } else {
          canvas.drawCircle(head, r * 0.28, p(0x55FFE58A));
          canvas.drawCircle(head, r * 0.16, p(0xFFFFF2B0));
        }
      case 'bench':
        final seat = Rect.fromCenter(
          center: c,
          width: r * 1.3,
          height: r * 0.35,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(seat, Radius.circular(r * 0.08)),
          p(0xFFB07A4F),
        );
        canvas.drawRect(
          Rect.fromLTWH(seat.left, seat.top - r * 0.22, seat.width, r * 0.12),
          p(0xFF8C5E3C),
        );
      case 'umbrella' || 'cafe':
        if (kind == 'cafe') canvas.drawCircle(c, r * 0.3, p(0xFFFFFFFF));
        final top = c.translate(0, -r * 0.4);
        canvas.drawCircle(
          top,
          r * 0.62,
          p(kind == 'cafe' ? 0xFFD94848 : 0xFFFFC542),
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: top, radius: r * 0.62),
            i * math.pi / 2,
            math.pi / 4,
            true,
            p(0xFFFFFFFF),
          );
        }
      case 'fountain':
        canvas.drawCircle(c, r * 0.7, p(0xFFE6E2D6));
        canvas.drawCircle(c, r * 0.55, p(0xFF5CC3EE));
        canvas.drawCircle(
          c.translate(-r * 0.15, -r * 0.12),
          r * 0.15,
          p(0xAAFFFFFF),
        );
      case 'phone':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(0, -r * 0.3),
              width: r * 0.55,
              height: r * 1.1,
            ),
            Radius.circular(r * 0.1),
          ),
          p(0xFFD7282F),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: c.translate(0, -r * 0.35),
            width: r * 0.35,
            height: r * 0.55,
          ),
          p(0xFF9FD3F0),
        );
      case 'hydrant':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(0, -r * 0.15),
              width: r * 0.4,
              height: r * 0.7,
            ),
            Radius.circular(r * 0.15),
          ),
          p(0xFFE53935),
        );
        canvas.drawCircle(c.translate(0, -r * 0.5), r * 0.22, p(0xFFFFC542));
    }
  }

  /// Har frame badalne wala hissa: parking strip (bays)
  static void paintDynamic(
    Canvas canvas,
    GameLayout l, {
    required List<bool> slotUsed,
    required bool hasVip,
    required double stripFlash,
  }) {
    _road(canvas, l, slotUsed, hasVip, stripFlash);
  }

  /// Shehar ki zameen, beech mein gool roundabout plaza aur open-gate sadak (Image 2 jaisa)
  static void _arena(Canvas canvas, GameLayout l, City city) {
    final area = Rect.fromLTWH(0, 0, l.width, l.roadTop);
    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [city.ground, city.groundDark],
        ).createShader(area),
    );
    _groundTexture(canvas, l, city);

    final c = l.roundaboutCenter;
    final bw = l.bandWidth;
    final gateHalfW = l.gateHalfWidth;
    final roadMetric = l.queueRoadMetric;
    final roadLen = roadMetric.length;
    final openD = (gateHalfW + 2).clamp(4.0, roadLen * 0.16);
    final openTrack = roadMetric.extractPath(openD, roadLen - openD);
    final gatePos =
        roadMetric.getTangentForOffset(0)?.position ??
        Offset(c.dx, c.dy + l.shapeHalfH);

    final chuteBw = l.chuteBandWidth;
    final chuteShadow = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = chuteBw + 8
      ..strokeCap = StrokeCap.round;
    final chuteCurb = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = chuteBw + 7
      ..strokeCap = StrokeCap.round;
    final chuteRoad = Paint()
      ..color = const Color(0xFF86889B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = chuteBw
      ..strokeCap = StrokeCap.round;

    final shadowStroke = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw + 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final curbStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw + 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final roadStroke = Paint()
      ..color = const Color(0xFF86889B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final leftFeeder = l.leftFeeder;
    final rightFeeder = l.rightFeeder;

    // 1) Sab se pehle saaye aur safed kinare (feeders + loop track) taa ke junction seamless bane
    canvas.drawPath(leftFeeder.shift(const Offset(0, 3)), chuteShadow);
    canvas.drawPath(rightFeeder.shift(const Offset(0, 3)), chuteShadow);
    canvas.drawPath(openTrack.shift(const Offset(0, 3)), shadowStroke);

    canvas.drawPath(leftFeeder, chuteCurb);
    canvas.drawPath(rightFeeder, chuteCurb);
    canvas.drawPath(openTrack, curbStroke);

    // 2) Open gate corridor neeche sadak ki taraf (curb se shuru, logon se door)
    final gateTop = gatePos.dy;
    final gateRect = Rect.fromLTWH(
      c.dx - gateHalfW,
      gateTop,
      gateHalfW * 2,
      l.roadTop - gateTop + 2,
    );
    canvas.drawRect(gateRect, Paint()..color = const Color(0xFF86889B));

    // 3) Sleti sadak (feeders + loop track) ek sath upar paint
    canvas.drawPath(leftFeeder, chuteRoad);
    canvas.drawPath(rightFeeder, chuteRoad);
    canvas.drawPath(openTrack, roadStroke);

    // Gate corridor ke side curbs aur zebra stripes (outer curb ke bahar)
    final curbTop = math.min(l.roadTop - 6, gatePos.dy + bw * 0.5 - 1);
    final curbEdge = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(gateRect.left, curbTop),
      Offset(gateRect.left, gateRect.bottom),
      curbEdge,
    );
    canvas.drawLine(
      Offset(gateRect.right, curbTop),
      Offset(gateRect.right, gateRect.bottom),
      curbEdge,
    );

    final stripe = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 2.2;
    for (var y = curbTop + 4; y < l.roadTop - 2; y += 5) {
      canvas.drawLine(
        Offset(c.dx - gateHalfW * 0.72, y),
        Offset(c.dx + gateHalfW * 0.72, y),
        stripe,
      );
    }

    // 4) Beech ka 3D shape island / hole (har shakal ke mutabiq)
    final island = l.innerIslandPath;
    canvas.drawPath(
      island.shift(const Offset(0, 2)),
      Paint()..color = const Color(0x28000000),
    );
    canvas.drawPath(island, Paint()..color = const Color(0xFFEEF1F8));
    canvas.save();
    canvas.clipPath(island);
    canvas.drawPath(
      island.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x181B2745)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.restore();
    canvas.drawPath(
      island,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round,
    );

    // 5) Track ke dono konon par do gol darakht/bushes (har shakal se bahar)
    final bushSize = l.passengerSize * 0.9;
    final bushX = math.min(
      l.width * 0.44,
      l.shapeHalfW + bw * 0.5 + bushSize * 1.15,
    );
    final bushY = math.min(
      l.roadTop - bushSize * 1.1,
      c.dy + (l.shapeHalfH + bw * 0.5) * 0.75,
    );
    _prop(canvas, 'topiary', Offset(c.dx - bushX, bushY), bushSize);
    _prop(canvas, 'topiary', Offset(c.dx + bushX, bushY), bushSize);
  }

  /// Shehar ki zameen: clean checkered tiles (Image 2 reference jaisa)
  static void _groundTexture(Canvas canvas, GameLayout l, City city) {
    final area = Rect.fromLTWH(0, 0, l.width, l.roadTop);
    final tw = l.passengerSize * 1.6;
    final th = tw;
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.035);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.04);
    var row = 0;
    for (var y = 0.0; y < area.height; y += th, row++) {
      var col = 0;
      for (var x = 0.0; x < area.width; x += tw, col++) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, tw, th),
          (row + col).isEven ? dark : light,
        );
      }
    }
  }

  /// Pyari sadak aur compact parking bays. [flash] > 0: slots bhare, laal chamak
  static void _road(
    Canvas canvas,
    GameLayout l,
    List<bool> slotUsed,
    bool hasVip,
    double flash,
  ) {
    final road = Rect.fromLTWH(0, l.roadTop, l.width, l.roadH);
    canvas.drawRect(
      road,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF53586E),
            Color(0xFF666B83),
            Color(0xFF5B6077),
          ],
        ).createShader(road),
    );
    // Upar ki taraf halki andaruni gehrai aur chamak
    canvas.drawRect(
      Rect.fromLTWH(0, road.top + 3, l.width, 7),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x280E1324), Color(0x000E1324)],
        ).createShader(Rect.fromLTWH(0, road.top + 3, l.width, 7)),
    );
    // 3D double-tone curbs (upar aur neeche)
    final curb = Paint()..color = GamePalette.curb;
    final curbShade = Paint()..color = const Color(0xFFB3BCCB);
    canvas.drawRect(Rect.fromLTWH(0, road.top - 3.5, l.width, 5.5), curb);
    canvas.drawRect(Rect.fromLTWH(0, road.top + 1.5, l.width, 2), curbShade);
    canvas.drawRect(Rect.fromLTWH(0, road.bottom - 2.5, l.width, 5.5), curb);
    canvas.drawRect(Rect.fromLTWH(0, road.bottom + 2, l.width, 2), curbShade);

    final open = slotUsed.length;
    for (var i = 0; i < l.slotCenters.length; i++) {
      final c = l.slotCenters[i];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(GameLayout.bayAngle);
      final bayRect = Rect.fromCenter(
        center: Offset.zero,
        width: l.bayW,
        height: l.bayH,
      );
      final bay = RRect.fromRectAndRadius(
        bayRect,
        Radius.circular(l.bayW * 0.14),
      );
      final stroke = math.max(1.8, l.bayW * 0.055);
      // Bay ke upar wheel-stop line (halka sa 3D look)
      final stopBar = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -l.bayH * 0.39),
          width: l.bayW * 0.62,
          height: math.max(2.2, l.bayW * 0.08),
        ),
        Radius.circular(l.bayW * 0.04),
      );

      if (i == 0 && hasVip) {
        // Sunehra 3D VIP bay
        canvas.drawRRect(
          bay,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3E3420), Color(0xFF56472B)],
            ).createShader(bayRect),
        );
        canvas.drawRRect(
          stopBar,
          Paint()..color = const Color(0x88FFD54F),
        );
        canvas.drawRRect(
          bay,
          Paint()
            ..color = const Color(0xFFFFCA3A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 1.3,
        );
        if (!slotUsed[0]) {
          canvas.save();
          canvas.rotate(math.pi / 2);
          text(
            canvas,
            'VIP',
            Offset.zero,
            l.bayW * 0.42,
            const Color(0xFFFFD54F),
          );
          canvas.restore();
        }
      } else if (i < open) {
        canvas.drawRRect(bay, Paint()..color = const Color(0x38202434));
        canvas.drawRRect(
          stopBar,
          Paint()..color = const Color(0x55FFFFFF),
        );
        canvas.drawRRect(
          bay,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.78)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
        if (!slotUsed[i]) {
          text(
            canvas,
            'P',
            Offset(0, l.bayH * 0.05),
            l.bayW * 0.42,
            Colors.white.withValues(alpha: 0.24),
          );
        }
      } else {
        // Band bay: emerald tinted pad, dashed border aur saaf "+" badge
        canvas.drawRRect(bay, Paint()..color = const Color(0x2238D989));
        _dashedRRect(
          canvas,
          bay,
          Paint()
            ..color = const Color(0xFF7AEFA8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
          dash: l.bayW * 0.14,
        );
        canvas.drawCircle(
          Offset.zero,
          l.bayW * 0.24,
          Paint()..color = const Color(0x447AEFA8),
        );
        text(
          canvas,
          '+',
          Offset.zero,
          l.bayW * 0.46,
          const Color(0xFFA8F7C6),
        );
      }
      canvas.restore();
    }

    if (flash > 0) {
      // Slots bhare: poori patti laal chamakti hai (do dafa)
      final a = (math.sin(flash * math.pi * 2)).abs() * 0.45;
      canvas.drawRect(road, Paint()..color = Color.fromRGBO(255, 40, 40, a));
    }
  }

  /// Lot ka panel: pyara modern courtyard / parking island design
  static void _lot(Canvas canvas, GameLayout l, List<BusData> buses) {
    final r = l.boardPanel;
    // 1) Clean soft courtyard gradient (bina kisi white box ke)
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD5DEF0), Color(0xFFE3EAF7), Color(0xFFCDD8EC)],
        ).createShader(r),
    );

    // 2) Halka architectural stone tile weave (bohat subtle taa-ke cars pop karein)
    final tw = math.max(24.0, l.cell * 0.95);
    final tileDark = Paint()..color = const Color(0x051A2B4C);
    final tileLight = Paint()..color = const Color(0x07FFFFFF);
    var row = 0;
    for (var y = r.top; y < r.bottom; y += tw, row++) {
      var col = 0;
      for (var x = r.left; x < r.right; x += tw, col++) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, tw, tw),
          (row + col).isEven ? tileDark : tileLight,
        );
      }
    }

    // 3) Maidan ke bahari konon mein chhote bushes/planters (agar jagah khali ho)
    final pSize = l.cell * 0.52;
    if (l.ring.left > pSize * 2.2) {
      _prop(
        canvas,
        'bush',
        Offset(l.ring.left * 0.45, l.ring.top + pSize),
        pSize,
      );
      _prop(
        canvas,
        'bush',
        Offset(l.width - l.ring.left * 0.45, l.ring.bottom - pSize),
        pSize,
      );
    }

    // 4) Parking road ke bilkul neeche halka sa shadow band
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 16),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x221B2745), Color(0x001B2745)],
        ).createShader(Rect.fromLTWH(r.left, r.top, r.width, 16)),
    );
  }

  /// Kul baqi passengers ki ginti (parking ke thora neeche right side par)
  static void countPill(Canvas canvas, GameLayout l, int remaining) {
    final s = math.max(18.0, l.passengerSize);
    final c = l.countPillPos;
    final wide = remaining >= 1000;
    final pillW = wide ? s * 4.1 : s * 3.4;
    final pillH = s * 1.25;
    final right = c.dx + s * 1.7;
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTRB(right - pillW, c.dy - pillH / 2, right, c.dy + pillH / 2),
      Radius.circular(s * 0.62),
    );
    canvas.drawRRect(
      pill.shift(const Offset(0, 2.5)),
      Paint()..color = const Color(0x35000000),
    );
    canvas.drawRRect(pill, Paint()..color = Colors.white);
    canvas.drawRRect(
      pill,
      Paint()
        ..color = const Color(0xFFD0D5E2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final img = SpriteBank.instance.person(1);
    final iconC = Offset(pill.left + s * 0.62, c.dy);
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: iconC, width: s * 1.15, height: s * 1.15),
        SpriteBank.paint,
      );
    } else {
      canvas.drawCircle(iconC, s * 0.3, Paint()..color = GamePalette.bus(1));
    }
    text(
      canvas,
      '$remaining',
      Offset(pill.left + s * 1.15 + (pillW - s * 1.2) * 0.5, c.dy),
      wide ? s * 0.54 : s * 0.62,
      const Color(0xFF2A364E),
    );
  }

  static void _dashedRRect(
    Canvas canvas,
    RRect r,
    Paint paint, {
    required double dash,
  }) {
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash * 2;
      }
    }
  }

  /// Darmiyan mein text likhna (hint waghera ke liye bahar se bhi)
  static void text(
    Canvas canvas,
    String s,
    Offset center,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontFamily: 'Lilita'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
