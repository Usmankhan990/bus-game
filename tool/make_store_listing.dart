// Play Store listing ki tasveerein banane wala script:
// ignore_for_file: invalid_use_of_visible_for_testing_member
//  * 5 marketing screenshots (1080x1920): rangeen background, bari heading,
//    aur phone frame mein game ka ASLI screenshot
//  * feature graphic (1024x500): logo, tagline, 3D van aur game ki gaadiyan
//
// Bina kisi argument ke chalayen to app ki asal screens khud capture karta hai:
//   flutter test tool/make_store_listing.dart
// Ya agar emulator/phone se RAW screenshots liye hon to unhein bhi frame kar sakta hai:
//   flutter test tool/make_store_listing.dart --dart-define=RAW=C:/raw/folder
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bus_jam/game/bus_jam_game.dart';
import 'package:bus_jam/game/render/sprite_bank.dart';
import 'package:bus_jam/screens/game_screen.dart';
import 'package:bus_jam/screens/home_screen.dart';
import 'package:bus_jam/services/ad_service.dart';
import 'package:bus_jam/services/progress_service.dart';
import 'package:bus_jam/ui/theme.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _raw = String.fromEnvironment('RAW');
const _out = 'store_listing';

/// (asli screenshot, heading ki do lines, background ke do rang)
const _slides = [
  (
    'home',
    'City Bus Jam',
    'World Tour!',
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

const _assetImages = [
  'assets/icons/checkin.png',
  'assets/icons/daily.png',
  'assets/icons/garage.png',
  'assets/icons/noads.png',
  'assets/icons/shop.png',
  'assets/icons/shuffle.png',
  'assets/icons/sort.png',
  'assets/icons/spin.png',
  'assets/icons/supplies.png',
  'assets/icons/vip.png',
  'assets/sprites/city_karachi.png',
  'assets/sprites/city_lahore.png',
  'assets/sprites/city_islamabad.png',
  'assets/sprites/city_dubai.png',
  'assets/sprites/city_london.png',
  'assets/sprites/city_paris.png',
  'assets/sprites/city_newyork.png',
  'assets/sprites/city_tokyo.png',
];

Future<ui.Image> _loadFile(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Directory? _findMaterialFontsDir() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory(
      '${dir.path}/artifacts/material_fonts',
    );
    if (candidate.existsSync()) return candidate;
    final binCache = Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    );
    if (binCache.existsSync()) return binCache;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

Future<void> _loadFonts() async {
  Future<ByteData> f(String p) async =>
      ByteData.sublistView(File(p).readAsBytesSync());
  await (FontLoader(
    'Lilita',
  )..addFont(f('assets/fonts/LilitaOne-Regular.ttf'))).load();
  await (FontLoader(
    'Fredoka',
  )..addFont(f('assets/fonts/Fredoka-Variable.ttf'))).load();

  final materialDir = _findMaterialFontsDir();
  if (materialDir != null) {
    final icons = File('${materialDir.path}/materialicons-regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(f(icons.path))).load();
    }
    final roboto = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      final rf = File('${materialDir.path}/$name');
      if (rf.existsSync()) roboto.addFont(f(rf.path));
    }
    await roboto.load();
  }
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

  // Poora phone frame slide ke andar (Home dock aur Booster bar bilkul saaf dikhein)
  final srcH = math.min(shot.height.toDouble(), shot.width * 2.03);
  final src = Rect.fromLTWH(0, 0, shot.width.toDouble(), srcH);
  const phoneTop = 356.0;
  const phoneBottomMargin = 34.0;
  final phoneH = s.height - phoneTop - phoneBottomMargin;
  final phoneW = phoneH * src.width / src.height;
  final screen = Rect.fromLTWH(
    (s.width - phoneW) / 2,
    phoneTop,
    phoneW,
    phoneH,
  );
  const bezel = 16.0;
  final body = RRect.fromRectAndRadius(
    screen.inflate(bezel),
    const Radius.circular(62),
  );
  c.drawRRect(
    body.shift(const Offset(0, 20)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
  );
  c.drawRRect(body, Paint()..color = const Color(0xFF1C1F2A));
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(screen, const Radius.circular(48)));
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

  word('City Bus', const Offset(60, 120), 112);
  word('Jam', const Offset(60, 240), 112);
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

Future<void> _pumpSec(WidgetTester t, double s) async {
  for (var i = 0; i < (s / 0.05).round(); i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Widget _app(GlobalKey key, Widget home) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    home: home,
  ),
);

Future<ui.Image> _captureBoundary(WidgetTester t, GlobalKey key) async {
  late ui.Image img;
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    img = await b.toImage(pixelRatio: 2.625);
  });
  return img;
}

Future<Map<String, ui.Image>> _captureLiveShots(WidgetTester t) async {
  AdService.enabled = false;
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global/events'),
    (_) async => null,
  );
  SharedPreferences.setMockInitialValues({
    'level': 15,
    'coins': 1250,
    'stars': 28,
    'booster_vip': 3,
    'booster_sort': 3,
    'booster_shuffle': 3,
  });
  await ProgressService.instance.load();
  await t.runAsync(SpriteBank.instance.load);

  const dpr = 2.625;
  t.view.physicalSize = const Size(1080, 2192);
  t.view.devicePixelRatio = dpr;
  t.view.padding = const FakeViewPadding(top: 18 * dpr, bottom: 0);
  addTearDown(t.view.reset);

  final key = GlobalKey();
  // Precache UI icons and city landmarks before capturing any screen.
  await t.pumpWidget(_app(key, const SizedBox()));
  final ctx = t.element(find.byType(SizedBox));
  await t.runAsync(() async {
    for (final path in _assetImages) {
      await precacheImage(AssetImage(path), ctx);
    }
  });

  final shots = <String, ui.Image>{};

  // 1) HomeScreen (Level 15 - Karachi roundabout)
  await t.pumpWidget(_app(key, const HomeScreen(key: ValueKey('home_15'))));
  await _pumpSec(t, 0.8);
  shots['home'] = await _captureBoundary(t, key);

  // 2) Play Start (Level 12 - Karachi sunny beach fresh puzzle)
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('level', 12);
  await ProgressService.instance.load();
  await t.pumpWidget(_app(key, const GameScreen(key: ValueKey('lvl_12'))));
  await _pumpSec(t, 1.0);
  shots['play_start'] = await _captureBoundary(t, key);

  // 3) Play Board (Level 142 - Tokyo sakura, active parked vehicles & boarding)
  await prefs.setInt('level', 142);
  await ProgressService.instance.load();
  await t.pumpWidget(_app(key, const GameScreen(key: ValueKey('lvl_142'))));
  await _pumpSec(t, 2.5);
  {
    final g = t
        .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
        .game!;
    final front = g.model.frontColor;
    // Pehle 1-2 doosre rang ki khuli gaadiyan normal slots mein bhejein
    for (final b in g.model.movableBuses().where((b) => b.color != front).take(2)) {
      await t.tapAt(g.layout.busCenter(b));
      await _pumpSec(t, 0.25);
    }
    // Phir frontColor wali gaadi bhejein (seedha ya VIP se) taa ke musafir live chadhte dikhein
    final matchingMov = g.model
        .movableBuses()
        .where((b) => b.color == front)
        .toList();
    if (matchingMov.isNotEmpty) {
      await t.tapAt(g.layout.busCenter(matchingMov.first));
    } else {
      final matchingAny = g.model.grid
          .where((b) => b.color == front)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      if (matchingAny.isNotEmpty) {
        g.vipMode = true;
        await t.tapAt(g.layout.busCenter(matchingAny.first));
      }
    }
    await _pumpSec(t, 0.9);
  }
  shots['play_board'] = await _captureBoundary(t, key);

  // 4) Play Dense (Level 139 - New York dense level)
  await prefs.setInt('level', 139);
  await ProgressService.instance.load();
  await t.pumpWidget(_app(key, const GameScreen(key: ValueKey('lvl_139'))));
  await _pumpSec(t, 2.6);
  shots['play_dense'] = await _captureBoundary(t, key);

  // 5) Smart Boosters (Level 84 - London green park, VIP booster active + boarding)
  await prefs.setInt('level', 84);
  await ProgressService.instance.load();
  await t.pumpWidget(_app(key, const GameScreen(key: ValueKey('lvl_84'))));
  await _pumpSec(t, 2.6);
  {
    final g = t
        .widget<GameWidget<BusJamGame>>(find.byType(GameWidget<BusJamGame>))
        .game!;
    final front = g.model.frontColor;
    final mov = g.model.movableBuses().where((b) => b.color == front).toList();
    final pick = mov.isNotEmpty
        ? mov.first
        : g.model.movableBuses().firstOrNull;
    if (pick != null) {
      await t.tapAt(g.layout.busCenter(pick));
      await _pumpSec(t, 0.7);
    }
    await t.tap(find.text('VIP'));
    await _pumpSec(t, 0.25);
  }
  shots['play_tilted'] = await _captureBoundary(t, key);

  await t.pumpWidget(const SizedBox());
  await _pumpSec(t, 0.2);
  return shots;
}

void main() {
  testWidgets('store listing', (tester) async {
    await tester.runAsync(_loadFonts);

    final liveShots = _raw.isEmpty
        ? await _captureLiveShots(tester)
        : <String, ui.Image>{};

    await tester.runAsync(() async {
      var n = 0;
      for (var i = 0; i < _slides.length; i++) {
        final (name, l1, l2, top, bottom) = _slides[i];
        ui.Image? shot = liveShots[name];
        if (shot == null && _raw.isNotEmpty) {
          final file = File('$_raw/$name.png');
          if (file.existsSync() && file.lengthSync() > 0) {
            shot = await _loadFile(file.path);
          }
        }
        if (shot == null) continue;
        n++;
        await _save(
          1080,
          1920,
          '$_out/screenshots/${n}_$name.png',
          (c) => _slide(
            c,
            const Size(1080, 1920),
            shot!,
            l1,
            l2,
            top,
            bottom,
            i,
          ),
        );
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
