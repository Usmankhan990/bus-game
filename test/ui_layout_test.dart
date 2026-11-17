// Har screen aur popup ko chhoti (720x1280) aur lambi (1080x2400) screen par
// khol kar check karta hai ke koi overflow (peeli-kaali patti) ya error na ho.
// SHOT_DIR diya ho to har screen ki tasveer bhi save hoti hai:
//   flutter test test/ui_layout_test.dart --dart-define=SHOT_DIR=C:/temp/shots
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bus_jam/game/bus_jam_game.dart';
import 'package:bus_jam/game/render/sprite_bank.dart';
import 'package:bus_jam/screens/game_screen.dart';
import 'package:bus_jam/models/city.dart';
import 'package:bus_jam/screens/home_screen.dart';
import 'package:bus_jam/screens/journey_screen.dart';
import 'package:bus_jam/screens/loading_screen.dart';
import 'package:bus_jam/services/ad_service.dart';
import 'package:bus_jam/services/progress_service.dart';
import 'package:bus_jam/ui/theme.dart';
import 'package:bus_jam/widgets/booster_shop_dialog.dart';
import 'package:bus_jam/models/booster_type.dart';
import 'package:bus_jam/widgets/garage.dart';
import 'package:bus_jam/widgets/home_features.dart';
import 'package:bus_jam/widgets/overlays.dart';
import 'package:bus_jam/widgets/settings_panel.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _flutterFonts = 'C:/dev/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> f(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  await (FontLoader(
    'Lilita',
  )..addFont(f('assets/fonts/LilitaOne-Regular.ttf'))).load();
  await (FontLoader(
    'Fredoka',
  )..addFont(f('assets/fonts/Fredoka-Variable.ttf'))).load();
  final icons = File('$_flutterFonts/materialicons-regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(f(icons.path))).load();
  }
}

Future<void> _run(WidgetTester t, double s) async {
  for (var i = 0; i < (s / 0.05).round(); i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

final _key = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  if (_shotDir.isEmpty) return;
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.5);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _app(Widget home) => RepaintBoundary(
  key: _key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    home: home,
  ),
);

/// Home kholo aur us par ek popup chalao
Future<void> _homePopup(
  WidgetTester t,
  String name,
  Future<void> Function(BuildContext) show,
) async {
  await t.pumpWidget(_app(const HomeScreen()));
  await _run(t, 0.4);
  final ctx = t.element(find.byType(HomeScreen));
  show(ctx);
  await _run(t, 0.6);
  await _shot(t, name);
  Navigator.of(ctx).pop();
  await _run(t, 0.4);
}

void main() {
  for (final (label, size, dpr) in const [
    ('small', Size(720, 1280), 2.0),
    ('tall', Size(1080, 2400), 2.625),
  ]) {
    testWidgets('Saari screens bina overflow ke: $label', (t) async {
      AdService.enabled = false;
      // Layout tests do not install native audio plugins. A fast sprite cache
      // can finish loading before this screenshot, so isolate its event stream.
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null,
      );
      SharedPreferences.setMockInitialValues({'level': 15, 'coins': 1250});
      await ProgressService.instance.load();
      await t.runAsync(_loadFonts);
      await t.runAsync(SpriteBank.instance.load);
      expect(SpriteBank.instance.named('home_bg_v2'), isNotNull);
      expect(SpriteBank.instance.named('home_bus_v2'), isNotNull);
      expect(SpriteBank.instance.usesNativeVehicles, isTrue);
      for (var length = 2; length <= 4; length++) {
        for (var color = 0; color < 8; color++) {
          for (var direction = 0; direction < 16; direction++) {
            expect(
              SpriteBank.instance.named(
                'vehicle_${length}_${color}_$direction',
              ),
              isNotNull,
            );
          }
        }
      }
      t.view.physicalSize = size;
      t.view.devicePixelRatio = dpr;
      t.view.padding = FakeViewPadding(top: 24 * dpr, bottom: 16 * dpr);
      addTearDown(t.view.reset);

      await t.pumpWidget(_app(const LoadingScreen()));
      await _run(t, 0.3);
      await _shot(t, '${label}_00_loading');

      await t.pumpWidget(_app(const HomeScreen()));
      await _run(t, 0.6);
      await _shot(t, '${label}_01_home');

      await _homePopup(t, '${label}_02_daily', showDailyBonus);
      await _homePopup(t, '${label}_03_freecoins', showFreeCoins);
      await _homePopup(t, '${label}_04_spin', showLuckySpin);
      await _homePopup(t, '${label}_05_shop', showShop);
      await _homePopup(t, '${label}_06_noads', showNoAds);
      await _homePopup(t, '${label}_07_checkin', showCheckIn);
      await _homePopup(t, '${label}_08_settings', showSettings);
      await _homePopup(
        t,
        '${label}_09_booster',
        (c) => showBoosterShop(c, BoosterType.vip),
      );

      await _homePopup(t, '${label}_09b_garage', showGarage);
      await _homePopup(
        t,
        '${label}_09c_welcome',
        (c) => showWelcomeCity(c, City.lahore),
      );

      // Safar ka map
      await t.pumpWidget(_app(const JourneyScreen()));
      await _run(t, 0.6);
      await _shot(t, '${label}_09d_journey');

      // Game screen (HARD level 15) kuch chalon ke baad
      await t.pumpWidget(_app(const GameScreen()));
      await _run(t, 2.5);
      await _shot(t, '${label}_10_game');

      // Game ke andar settings, win aur fail
      await t.pumpWidget(
        _app(
          Stack(
            children: [
              const GameScreen(),
              SettingsPanel(
                inline: true,
                onClose: () {},
                onHome: () {},
                onRestart: () {},
              ),
            ],
          ),
        ),
      );
      await _run(t, 0.6);
      await _shot(t, '${label}_11_pause');

      await t.pumpWidget(
        _app(
          Stack(
            children: [
              const GameScreen(),
              WinOverlay(
                level: 15,
                reward: 40,
                stars: 3,
                onDouble: () async => false,
                onNext: () {},
              ),
            ],
          ),
        ),
      );
      await _run(t, 1.2);
      await _shot(t, '${label}_12_win');

      await t.pumpWidget(
        _app(
          Stack(
            children: [
              const GameScreen(),
              FailOverlay(
                onContinue: () async => false,
                onRetry: () {},
                onHome: () {},
              ),
            ],
          ),
        ),
      );
      await _run(t, 0.6);
      await _shot(t, '${label}_13_fail');

      // Match the reference video's level as well as the smaller HARD board.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('level', 139);
      await ProgressService.instance.load();
      await t.pumpWidget(_app(const HomeScreen()));
      await _run(t, .6);
      await _shot(t, '${label}_14_reference_home');
      await t.tap(find.text('Play'));
      await _run(t, 2.5);
      expect(find.text('Level 139'), findsOneWidget);
      await _shot(t, '${label}_15_reference_game');

      if (_shotDir.isNotEmpty) {
        final gw = t.widget<GameWidget<BusJamGame>>(
          find.byType(GameWidget<BusJamGame>),
        );
        final g = gw.game!;
        final front = g.model.frontColor;
        // Ek lambi bus (40) VIP se Slot 0 mein, aur alag rang ki 1-2 khuli gaadiyan slots mein
        final b4 = g.model.grid.firstWhere(
          (b) => b.length >= 4 && b.color != front,
          orElse: () => g.model.grid.first,
        );
        g.vipMode = true;
        await t.tapAt(g.layout.busCenter(b4));
        await _run(t, 0.4);
        for (final targetLen in [3, 2]) {
          final mov = g.model
              .movableBuses()
              .where((b) => b.length == targetLen && b.color != front)
              .toList();
          final pick = mov.isNotEmpty
              ? mov.first
              : g.model.movableBuses().firstWhere(
                  (b) => b.color != front,
                  orElse: () => g.model.movableBuses().first,
                );
          await t.tapAt(g.layout.busCenter(pick));
          await _run(t, 0.4);
        }
        await _run(t, 1.5);
        await _shot(t, '${label}_16_parked_slots');
      }

      await t.pumpWidget(const SizedBox());
      await _run(t, 0.2);
    });
  }
}
