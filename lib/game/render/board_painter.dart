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
    final half = l.bandWidth / 2;
    // Sadak ke nuqte (faasla naapne ke liye)
    final road = <Offset>[];
    for (final m in l.queueRoad.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        road.add(m.getTangentForOffset(d)!.position);
      }
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
    // Sadak ke dono kinaron par qataar: street light aur shehar ki chhoti cheez
    // baari baari (jaise asli shehar ki sadak)
    final edge = <(Offset, String)>[];
    final small = _edgeKind(city);
    var n = 0;
    for (final m in l.queueRoad.computeMetrics()) {
      for (var d = s * 1.5; d < m.length; d += s * 2.6) {
        final tg = m.getTangentForOffset(d)!;
        final nrm = Offset(-tg.vector.dy, tg.vector.dx);
        for (final side in const [-1.0, 1.0]) {
          final p = tg.position + nrm * side * (half + s * 0.42);
          var ok = !underHud(p) && p.dx > 4 && p.dx < l.width - 4;
          ok = ok && p.dy > 0 && p.dy < l.roadTop - s * 0.3;
          for (final q in road) {
            if ((q - p).distance < half + s * 0.18) {
              ok = false;
              break;
            }
          }
          for (final (c, gr) in l.queueGaps) {
            if ((c - p).distance < gr * 1.4) ok = false;
          }
          if ((l.countPillPos - p).distance < s * 2.2) ok = false;
          for (final (o, _) in edge) {
            if ((o - p).distance < s * 1.3) ok = false;
          }
          if (ok) {
            edge.add((p, n.isEven ? 'lamp' : small));
            n++;
          }
        }
      }
    }
    for (final (p, kind) in edge) {
      spots.add((p, s * 0.5, kind));
    }

    // Upar wali cheezen pehle, neeche wali baad mein (sahi parda)
    spots.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (final (p, r, kind) in spots) {
      _prop(canvas, kind, p, r);
    }
  }

  /// Sadak ke kinare wali chhoti cheez (street light ke saath baari baari)
  static String _edgeKind(City c) => switch (c) {
    City.karachi || City.dubai => 'palm',
    City.tokyo => 'lantern',
    City.paris => 'topiary',
    City.islamabad => 'pine',
    City.lahore => 'flowers',
    City.london || City.newyork => 'bush',
  };

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

  /// Shehar ki zameen, kone mein shehar ki nishani aur darakht, aur saanp
  /// jaisi sleti sadak
  static void _arena(Canvas canvas, GameLayout l, City city) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, l.width, l.roadTop),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [city.ground, city.groundDark],
        ).createShader(Rect.fromLTWH(0, 0, l.width, l.roadTop)),
    );
    _groundTexture(canvas, l, city);
    // Baayen kone mein shehar ki nishani (3D imarat), daayen kone mein darakht
    final landmark = SpriteBank.instance.named('city_${city.id}');
    for (var i = 0; i < l.queueGaps.length; i++) {
      final (c, r) = l.queueGaps[i];
      if (r <= 6) continue;
      if (i == 0 && landmark != null) {
        // Nishani bari: kone ki khaali jagah se bahar sadak ke kinare tak
        final s = math.min(r * 5.2, l.width * 0.34);
        canvas.drawImageRect(
          landmark,
          Rect.fromLTWH(
            0,
            0,
            landmark.width.toDouble(),
            landmark.height.toDouble(),
          ),
          Rect.fromCenter(
            center: c.translate(r * 0.35, -r * 0.9),
            width: s,
            height: s,
          ),
          SpriteBank.paint,
        );
      } else {
        _blossomTree(
          canvas,
          c,
          r * 0.9,
          city == City.tokyo
              ? null
              : const (Color(0xFF5DB84A), Color(0xFF9BDB7A)),
        );
      }
    }

    // Sadak: saaya, safed kinara, phir sleti sadak
    canvas.drawPath(
      l.queueRoad.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.bandWidth + 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      l.queueRoad,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.bandWidth + 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      l.queueRoad,
      Paint()
        ..color = const Color(0xFF898A9B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.bandWidth
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Shehar ki zameen: pakke sheharon mein footpath ki tiles, hare sheharon
  /// mein ghaas ke gucche (ek hi dafa banti hai, static layer)
  static void _groundTexture(Canvas canvas, GameLayout l, City city) {
    final area = Rect.fromLTWH(0, 0, l.width, l.roadTop);
    final grassy = switch (city) {
      City.lahore || City.islamabad || City.london || City.paris => true,
      _ => false,
    };
    final rnd = math.Random(city.index + 5);
    if (grassy) {
      final dark = Paint()..color = city.groundDark.withValues(alpha: 0.9);
      final light = Paint()..color = Colors.white.withValues(alpha: 0.18);
      for (var i = 0; i < 180; i++) {
        final p = Offset(
          rnd.nextDouble() * area.width,
          rnd.nextDouble() * area.height,
        );
        // Chhota ghaas ka guccha: 3 patli patti
        for (var k = -1; k <= 1; k++) {
          canvas.drawLine(
            p,
            p.translate(k * 2.2, -4.5 - rnd.nextDouble() * 2),
            dark..strokeWidth = 1.4,
          );
        }
        if (i % 6 == 0) canvas.drawCircle(p.translate(3, -2), 1.6, light);
      }
    } else {
      // Footpath ki tiles: har doosri qataar aadhi khiski hui (eent jaisi)
      final line = Paint()
        ..color = city.groundDark.withValues(alpha: 0.55)
        ..strokeWidth = 1;
      final tw = l.passengerSize * 1.5;
      final th = tw * 0.6;
      var row = 0;
      for (var y = 0.0; y < area.height; y += th, row++) {
        canvas.drawLine(Offset(0, y), Offset(area.width, y), line);
        final shift = row.isEven ? 0.0 : tw / 2;
        for (var x = shift; x < area.width; x += tw) {
          canvas.drawLine(Offset(x, y), Offset(x, y + th), line);
        }
      }
      // Kuch tiles thodi gehri (asli farsh jaisa farq)
      final spot = Paint()..color = city.groundDark.withValues(alpha: 0.35);
      for (var i = 0; i < 40; i++) {
        final x = (rnd.nextInt((area.width / tw).ceil() + 1)) * tw;
        final r = rnd.nextInt((area.height / th).ceil() + 1);
        final sx = x + (r.isEven ? 0 : tw / 2);
        canvas.drawRect(
          Rect.fromLTWH(sx + 1, r * th + 1, tw - 2, th - 2),
          spot,
        );
      }
    }
  }

  /// Gol darakht: [leaves] na ho to gulabi phoolon wala (Tokyo), warna hara
  static void _blossomTree(
    Canvas canvas,
    Offset c,
    double r, [
    (Color, Color)? leaves,
  ]) {
    canvas.drawCircle(
      c.translate(r * 0.15, r * 0.25),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    // Tana
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, r * 0.45),
          width: r * 0.22,
          height: r * 0.7,
        ),
        Radius.circular(r * 0.1),
      ),
      Paint()..color = const Color(0xFF9A6B4F),
    );
    final pink = Paint()..color = leaves?.$1 ?? const Color(0xFFE98CB5);
    final light = Paint()..color = leaves?.$2 ?? const Color(0xFFFCD7E4);
    canvas.drawCircle(c.translate(-r * 0.4, 0), r * 0.62, pink);
    canvas.drawCircle(c.translate(r * 0.4, 0), r * 0.62, pink);
    canvas.drawCircle(c.translate(0, -r * 0.35), r * 0.7, pink);
    canvas.drawCircle(c.translate(-r * 0.2, -r * 0.45), r * 0.3, light);
    canvas.drawCircle(c.translate(r * 0.3, -r * 0.1), r * 0.22, light);
    final random = math.Random(19);
    for (var i = 0; i < 38; i++) {
      final a = random.nextDouble() * math.pi * 2;
      final d = math.sqrt(random.nextDouble()) * r * 0.86;
      final point = c + Offset(math.cos(a) * d, math.sin(a) * d - r * 0.15);
      canvas.drawCircle(
        point,
        r * (0.06 + random.nextDouble() * 0.06),
        i.isEven ? light : pink,
      );
    }
  }

  /// Kaali sadak aur us par seedhe parking bays. [flash] > 0: slots bhare, laal chamak
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
          colors: [Color(0xFF747688), Color(0xFF85879B)],
        ).createShader(road),
    );
    // Neeche gaadiyon ki lane: safed dashed lakeer (asli sadak jaisi)
    final dash = Paint()
      ..color = const Color(0x8CFFFFFF)
      ..strokeWidth = math.max(2.0, l.cell * 0.06)
      ..strokeCap = StrokeCap.round;
    final dashLen = l.cell * 0.45;
    for (var x = dashLen * 0.5; x < l.width; x += dashLen * 2.2) {
      canvas.drawLine(Offset(x, l.laneY), Offset(x + dashLen, l.laneY), dash);
    }
    final curb = Paint()..color = GamePalette.curb;
    canvas.drawRect(Rect.fromLTWH(0, road.top - 3, l.width, 5), curb);
    canvas.drawRect(Rect.fromLTWH(0, road.bottom - 2, l.width, 5), curb);

    final open = slotUsed.length;
    for (var i = 0; i < l.slotCenters.length; i++) {
      final c = l.slotCenters[i];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(GameLayout.bayAngle);
      final bay = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: l.bayW, height: l.bayH),
        Radius.circular(l.bayW * 0.10),
      );
      final stroke = math.max(2.0, l.bayW * 0.06);
      if (i == 0 && hasVip) {
        // Sunehra VIP bay (sirf VIP booster ke liye)
        canvas.drawRRect(bay, Paint()..color = const Color(0xFF4F4A3A));
        canvas.drawRRect(
          bay,
          Paint()
            ..color = const Color(0xFFFFC23A)
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
            const Color(0xFFFFC23A),
          );
          canvas.restore();
        }
      } else if (i < open) {
        canvas.drawRRect(bay, Paint()..color = const Color(0x11777E95));
        canvas.drawRRect(
          bay,
          Paint()
            ..color = GamePalette.bayLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
      } else {
        // Band bay: hari dashed lakeer aur "+"
        _dashedRRect(
          canvas,
          bay,
          Paint()
            ..color = GamePalette.lockedBay
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
          dash: l.bayW * 0.14,
        );
        text(canvas, '+', Offset.zero, l.bayW * 0.55, GamePalette.lockedBay);
      }
      canvas.restore();
    }

    if (flash > 0) {
      // Slots bhare: poori patti laal chamakti hai (do dafa)
      final a = (math.sin(flash * math.pi * 2)).abs() * 0.45;
      canvas.drawRect(road, Paint()..color = Color.fromRGBO(255, 40, 40, a));
    }
  }

  /// Lot ka panel (halka, kinare ke saath)
  static void _lot(Canvas canvas, GameLayout l, List<BusData> buses) {
    final r = l.boardPanel;
    final c = l.cell;
    // 1) Kinaron par footpath (halki tiles)
    canvas.drawRect(r, Paint()..color = const Color(0xFFDADDE4));
    final tile = Paint()
      ..color = const Color(0x1A5A6378)
      ..strokeWidth = 1;
    final ts = math.max(c * 0.7, 14.0);
    for (var x = r.left; x < r.right; x += ts) {
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), tile);
    }
    for (var y = r.top; y < r.bottom; y += ts) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), tile);
    }

    // 2) Asphalt: gaadiyon ki jagah aur un ke nikalne ki lanes (ring ke bahar
    // tak), upar parking strip se juda hua
    final lot = Rect.fromLTRB(
      math.max(r.left, l.ring.left - c * 0.6),
      r.top,
      math.min(r.right, l.ring.right + c * 0.6),
      math.min(r.bottom, l.ring.bottom + c * 0.6),
    );
    final lotR = RRect.fromRectAndCorners(
      lot,
      bottomLeft: Radius.circular(c * 0.5),
      bottomRight: Radius.circular(c * 0.5),
    );
    // Curb (safed-grey kinara) aur halka saaya
    canvas.drawRRect(
      lotR.inflate(c * 0.12).shift(Offset(0, c * 0.06)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(
      lotR.inflate(c * 0.12),
      Paint()..color = const Color(0xFFF2F3F6),
    );
    canvas.drawRRect(
      lotR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6E7285), Color(0xFF63677A)],
        ).createShader(lot),
    );
    // Asphalt ki khurdari (pakke random nuqte, ek hi dafa banti hai)
    final rnd = math.Random(11);
    final grit = Paint();
    final dots = (lot.width * lot.height / 140).clamp(0, 2600).toInt();
    for (var i = 0; i < dots; i++) {
      grit.color = rnd.nextBool()
          ? const Color(0x14FFFFFF)
          : const Color(0x1A000000);
      canvas.drawCircle(
        Offset(
          lot.left + rnd.nextDouble() * lot.width,
          lot.top + rnd.nextDouble() * lot.height,
        ),
        0.6 + rnd.nextDouble() * 1.1,
        grit,
      );
    }

    // 3) Har gaadi ke neeche us ka parking box (safed lakeerein). Gaadi
    // nikal jaye to khaali box reh jata hai, asli parking jaisa.
    final stall = Paint()
      ..color = const Color(0x8CFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, c * 0.05);
    final stallFill = Paint()..color = const Color(0x12000000);
    for (final b in buses) {
      final p = l.busCenter(b);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(b.angle);
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: c * 0.94,
          height: c * (b.length - 0.04),
        ),
        Radius.circular(c * 0.08),
      );
      canvas.drawRRect(box, stallFill);
      canvas.drawRRect(box, stall);
      canvas.restore();
    }

    // 4) Footpath par gamle (jahan lot ke bahar jagah ho)
    final planter = math.min(c * 0.32, 14.0);
    for (final side in [lot.left - planter * 2.2, lot.right + planter * 2.2]) {
      if (side - planter < r.left || side + planter > r.right) continue;
      for (
        var y = r.top + planter * 3;
        y < r.bottom - planter;
        y += planter * 5
      ) {
        final o = Offset(side, y);
        canvas.drawCircle(
          o.translate(1, 2),
          planter,
          Paint()..color = const Color(0x22000000),
        );
        canvas.drawCircle(o, planter, Paint()..color = const Color(0xFFB98C66));
        canvas.drawCircle(
          o,
          planter * 0.78,
          Paint()..color = const Color(0xFF4FA64A),
        );
        canvas.drawCircle(
          o.translate(-planter * 0.25, -planter * 0.25),
          planter * 0.32,
          Paint()..color = const Color(0xFF8FD47A),
        );
      }
    }

    // Upar kinare par parking strip ka halka saaya
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 14),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x261B3358), Color(0x001B3358)],
        ).createShader(Rect.fromLTWH(r.left, r.top, r.width, 14)),
    );
  }

  /// Upar kul baqi passengers ki ginti
  static void countPill(Canvas canvas, GameLayout l, int remaining) {
    final s = l.passengerSize;
    final c = l.countPillPos;
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: s * 3.2, height: s * 1.25),
      Radius.circular(s * 0.62),
    );
    canvas.drawRRect(
      pill.shift(const Offset(0, 2)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(pill, Paint()..color = Colors.white);
    canvas.drawRRect(
      pill,
      Paint()
        ..color = const Color(0xFFD9C9B0)
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
      Offset(pill.left + s * 1.95, c.dy),
      s * 0.62,
      const Color(0xFF4A3A28),
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
