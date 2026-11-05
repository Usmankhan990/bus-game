// Play Store listing ki tasveerein banane wala script:
//  * 5 marketing screenshots (1080x1920): rangeen background, bari heading,
//    aur phone frame mein game ka ASLI screenshot
//  * feature graphic (1024x500): logo, tagline, 3D van aur game ki gaadiyan
//
// Pehle emulator/phone se asli screenshots lein (ads ke baghair build):
//   flutter build apk --debug --dart-define=STORE_SHOTS=true
// aur unhein ek folder mein rakhein: home.png, play_start.png, play_board.png,
// play_dense.png, play_tilted.png (1080 chaude, status bar samait).
// Phir (project folder mein):
//   flutter test tool/make_store_listing.dart --dart-define=RAW=C:/raw/folder
// Files store_listing/ mein ban jaati hain.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _raw = String.fromEnvironment('RAW');
const _out = 'store_listing';

/// (asli screenshot, heading ki do lines, background ke do rang)
const _slides = [
  (
    'home',
    'Fun Bus Puzzle',
    'Adventure!',
    Color(0xFF2F8BEA),
    Color(0xFF6ED3F0),
  ),
  (
    'play_start',
    'Tap a Vehicle',
    'Clear the Jam!',
    Color(0xFFFF8A3D),
    Color(0xFFFFC94A),
  ),
  (
    'play_board',
    'Match Colors',
    'Fill Every Seat!',
    Color(0xFF8E5CF0),
    Color(0xFFE07BE0),
  ),
  (
    'play_dense',
    'Hundreds of',
    'Tricky Levels',
    Color(0xFF1FB57A),
    Color(0xFF8BE07A),
  ),
  (
    'play_tilted',
    'Smart Boosters',
    'Help You Win!',
    Color(0xFFEF4C68),
    Color(0xFFFF9E7A),
  ),
];

Future<ui.Image> _loadFile(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<void> _loadFonts() async {
  Future<ByteData> f(String p) async =>
      ByteData.sublistView(File(p).readAsBytesSync());
  await (FontLoader(
    'Lilita',
  )..addFont(f('assets/fonts/LilitaOne-Regular.ttf'))).load();
}

/// Mota safed text, gehra kinara aur neeche saaya (game ki style)
void _title(
  Canvas c,
  String text,
  Offset center,
  double size, {
  Color fill = Colors.white,
  Color edge = const Color(0xFF2A1F5C),
}) {
  TextPainter tp(Paint? stroke, Color? color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Lilita',
        fontSize: size,
        color: color,
        foreground: stroke,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final outline = tp(
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.16
      ..strokeJoin = StrokeJoin.round
      ..color = edge,
    null,
  );
  final o = center - Offset(outline.width / 2, outline.height / 2);
  outline.paint(c, o + Offset(0, size * 0.08));
  outline.paint(c, o);
  tp(null, fill).paint(c, o);
}

void _sparkles(Canvas c, Size s, int seed) {
  final rnd = math.Random(seed);
  for (var i = 0; i < 26; i++) {
    final p = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height);
    c.drawCircle(
      p,
      3 + rnd.nextDouble() * 9,
      Paint()
        ..color = Colors.white.withValues(
          alpha: 0.10 + rnd.nextDouble() * 0.12,
        ),
    );
  }
}

/// Ek marketing screenshot
void _slide(
  Canvas c,
  Size s,
  ui.Image shot,
  String line1,
  String line2,
  Color top,
  Color bottom,
  int seed,
) {
  final r = Offset.zero & s;
  c.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(r),
  );
  // Halki shuaayen (rays) upar se
  c.save();
  c.translate(s.width / 2, -80);
  for (var i = 0; i < 12; i++) {
    c.rotate(math.pi / 12);
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(-90, 2400)
        ..lineTo(90, 2400)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
  }
  c.restore();
  _sparkles(c, s, seed);

  _title(c, line1, Offset(s.width / 2, 150), 104);
  _title(
    c,
    line2,
    Offset(s.width / 2, 272),
    112,
    fill: const Color(0xFFFFE15A),
  );

  // Phone frame: screenshot ka upar ka hissa (neeche ki nav patti ke baghair)
  final srcH = math.min(shot.height.toDouble(), shot.width * 2.03);
  final src = Rect.fromLTWH(0, 0, shot.width.toDouble(), srcH);
  const phoneTop = 380.0;
  final phoneH = s.height - phoneTop + 140; // neeche thoda bahar nikle
  final phoneW = phoneH * src.width / src.height;
  final screen = Rect.fromLTWH(
    (s.width - phoneW) / 2,
    phoneTop,
    phoneW,
    phoneH,
  );
  const bezel = 18.0;
  final body = RRect.fromRectAndRadius(
    screen.inflate(bezel),
    const Radius.circular(70),
  );
  c.drawRRect(
    body.shift(const Offset(0, 22)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
  );
  c.drawRRect(body, Paint()..color = const Color(0xFF1C1F2A));
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(screen, const Radius.circular(54)));
  c.drawImageRect(
    shot,
    src,
    screen,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
}

/// Feature graphic (1024x500)
void _feature(Canvas c, Size s, ui.Image van, List<ui.Image> cars) {
  final r = Offset.zero & s;
  c.drawRect(
    r,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2F8BEA), Color(0xFF4FC3E8), Color(0xFF1A7AC6)],
      ).createShader(r),
  );
  c.save();
  c.translate(760, -60);
  for (var i = 0; i < 14; i++) {
    c.rotate(math.pi / 14);
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(-60, 1400)
        ..lineTo(60, 1400)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );
  }
  c.restore();
  _sparkles(c, s, 9);

  // Neeche sadak ki patti par game ki chhoti gaadiyan
  c.drawRect(
    Rect.fromLTWH(0, 410, s.width, 90),
    Paint()..color = const Color(0xFF5C6270),
  );
  c.drawRect(
    Rect.fromLTWH(0, 404, s.width, 8),
    Paint()..color = const Color(0xFFEFF1F5),
  );
  for (var i = 0; i < cars.length; i++) {
    final img = cars[i];
    final w = 150.0;
    final dst = Rect.fromCenter(
      center: Offset(40 + i * 128.0, 450),
      width: w,
      height: w * img.height / img.width,
    );
    c.drawImageRect(
      img,
      Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  // Bari 3D van daayen taraf
  c.drawImageRect(
    van,
    Offset.zero & Size(van.width.toDouble(), van.height.toDouble()),
    Rect.fromCenter(center: const Offset(770, 225), width: 470, height: 470),
    Paint()..filterQuality = FilterQuality.high,
  );

  // Logo (har harf alag rang) aur tagline
  const colors = [
    Color(0xFFFF5252),
    Color(0xFFFFA22B),
    Color(0xFFFFD23F),
    Color(0xFF5BD43F),
    Color(0xFF2ED3C6),
    Color(0xFF4DA3FF),
    Color(0xFFB073FF),
    Color(0xFFFF6FB5),
  ];
  var k = 0;
  void word(String w, Offset start, double size) {
    var x = start.dx;
    for (final ch in w.split('')) {
      final tp = TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(fontFamily: 'Lilita', fontSize: size),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _title(
        c,
        ch,
        Offset(x + tp.width / 2, start.dy),
        size,
        fill: colors[k++ % colors.length],
      );
      x += tp.width + size * 0.02;
    }
  }

  word('Bus Jam', const Offset(60, 120), 112);
  word('Party', const Offset(60, 240), 112);
  _title(c, 'Tap  •  Park  •  Board!', const Offset(265, 345), 40);
}

Future<void> _save(
  int w,
  int h,
  String path,
  void Function(Canvas) draw,
) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  testWidgets('store listing', (tester) async {
    await tester.runAsync(() async {
      await _loadFonts();
      if (_raw.isNotEmpty) {
        var n = 0;
        for (var i = 0; i < _slides.length; i++) {
          final (name, l1, l2, top, bottom) = _slides[i];
          // Jo asli screenshot na ho (ya khaali ho) usay chhor do
          final file = File('$_raw/$name.png');
          if (!file.existsSync() || file.lengthSync() == 0) continue;
          final shot = await _loadFile(file.path);
          n++;
          await _save(
            1080,
            1920,
            '$_out/screenshots/${n}_$name.png',
            (c) =>
                _slide(c, const Size(1080, 1920), shot, l1, l2, top, bottom, i),
          );
        }
      }
      final van = await _loadFile('tool/art/splash_bus.png');
      final cars = <ui.Image>[
        for (final (len, col) in [
          (2, 0),
          (3, 1),
          (2, 3),
          (4, 2),
          (2, 4),
          (3, 5),
          (2, 6),
          (3, 7),
          (2, 1),
        ])
          await _loadFile('assets/sprites_v2/vehicle_${len}_${col}_4.webp'),
      ];
      await _save(
        1024,
        500,
        '$_out/feature_graphic_1024x500.png',
        (c) => _feature(c, const Size(1024, 500), van, cars),
      );
    });
  });
}
