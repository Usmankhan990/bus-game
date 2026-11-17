import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bus_painter.dart';
import '../../models/vehicle_skin.dart';
import '../../services/progress_service.dart';
import 'palette.dart';
import 'passenger_painter.dart';

/// 3D se bani tasveerein (sprites) jo `assets/sprites/` mein hain.
/// Blender script (tool/blender/make_sprites.py) inhein banata hai.
/// Agar koi tasveer na mile to painters purani code wali drawing istemal karte hain.
class SpriteBank {
  SpriteBank._();
  static final SpriteBank instance = SpriteBank._();

  /// Har gaadi kitne rukh (directions) mein bani hai (Blender script ke DIRECTIONS)
  static const int directions = 16;

  /// Camera kitna tirchha tha (Blender script ka TILT)
  static const double tilt = 34 * math.pi / 180;

  /// Gaadi ki tasveer kitne board units ki hai: lambai + 0.9 (Blender script jaisa)
  static double vehicleFrameUnits(int length) => length + 0.9;

  final Map<String, ui.Image> _images = {};
  bool _usesNativeVehicles = false;
  bool get usesNativeVehicles => _usesNativeVehicles;

  /// Sprites draw karne ka saada Paint. (Saaye ki halki dhund load ke waqt hi
  /// tasveer se hata di jaati hai, har frame filter lagana GPU par mehnga hai.)
  static final ui.Paint paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium;

  /// Render ke saaye ki bohat halki dhund (jo kinaron par chaukor dhabba
  /// dikhati hai) ek dafa hata do: alpha = alpha * 1.12 - 30
  static Future<ui.Image> _clearHaze(ui.Image img) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return img;
    final px = data.buffer.asUint8List();
    for (var i = 0; i < px.length; i += 4) {
      final previous = px[i + 3];
      final alpha = (previous * 1.12 - 30).round().clamp(0, 255);
      if (previous == alpha) continue;
      // Keep RGB premultiplied when removing the faint render haze. Opaque
      // body pixels and transparent padding need no channel conversion.
      if (alpha == 0) {
        px[i] = px[i + 1] = px[i + 2] = 0;
      } else {
        final ratio = alpha / previous;
        px[i] = (px[i] * ratio).round().clamp(0, alpha);
        px[i + 1] = (px[i + 1] * ratio).round().clamp(0, alpha);
        px[i + 2] = (px[i + 2] * ratio).round().clamp(0, alpha);
      }
      px[i + 3] = alpha;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      px,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    final out = await done.future;
    img.dispose();
    return out;
  }

  bool get hasVehicles => _images.keys.any((k) => k.startsWith('vehicle_'));

  /// Sab sprites memory mein load karo (app shuru hote waqt ek dafa)
  Future<void> load({void Function(double)? onProgress}) async {
    if (hasVehicles) {
      onProgress?.call(1);
      return;
    }
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      final nativeVehicles = assets.any(
        (p) => p.startsWith('assets/sprites_v2/vehicle_'),
      );
      _usesNativeVehicles = nativeVehicles;
      final paths = assets
          .where(
            (p) =>
                (p.startsWith('assets/sprites/') ||
                    p.startsWith('assets/sprites_v2/') ||
                    p.startsWith('assets/people/')) &&
                (!p.split('/').last.startsWith('vehicle_') ||
                    p.startsWith('assets/sprites_v2/')) &&
                // Garage ki gaadiyan sirf zaroorat par (loadSkin), warna memory bharti hai
                !p.split('/').last.startsWith('skin_') &&
                (p.endsWith('.png') || p.endsWith('.webp')),
          )
          .toList();
      // 16-16 tasveerein ek saath (jaldi load hon)
      for (var i = 0; i < paths.length; i += 16) {
        await Future.wait(
          paths.skip(i).take(16).map((path) async {
            final data = await rootBundle.load(path);
            final codec = await ui.instantiateImageCodec(
              data.buffer.asUint8List(),
            );
            final frame = await codec.getNextFrame();
            codec.dispose();
            _images[path
                .split('/')
                .last
                .split('.')
                .first] = path.endsWith('_v2.png')
                ? frame.image
                : await _clearHaze(frame.image);
          }),
        );
        onProgress?.call((i + 16).clamp(0, paths.length) / paths.length * 0.2);
      }
      // Rasterize once: crisp, saturated vehicles with exactly the same frame,
      // projection and directional lookup as the original game sprites.
      const pixelsPerUnit = 72.0;
      var rendered = 0;
      if (!nativeVehicles) {
        for (var length = 2; length <= 4; length++) {
          final size = (vehicleFrameUnits(length) * pixelsPerUnit).ceil();
          for (var color = 0; color < 8; color++) {
            for (var direction = 0; direction < directions; direction++) {
              final recorder = ui.PictureRecorder();
              final canvas = ui.Canvas(recorder)..translate(size / 2, size / 2);
              BusPainter.paintDirectional(
                canvas,
                color: GamePalette.bus(color),
                unit: pixelsPerUnit,
                length: length,
                angle: direction * 2 * math.pi / directions,
              );
              final picture = recorder.endRecording();
              _images['vehicle_${length}_${color}_$direction'] = await picture
                  .toImage(size, size);
              picture.dispose();
              rendered++;
            }
            onProgress?.call(0.2 + 0.8 * rendered / (3 * 8 * directions));
          }
        }
      }
      for (var color = 0; color < 8; color++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)..translate(56, 88);
        PassengerPainter.paint(canvas, color: GamePalette.bus(color), size: 72);
        final picture = recorder.endRecording();
        final person = await picture.toImage(112, 112);
        picture.dispose();
        _images.remove('person_$color')?.dispose();
        _images['person_$color'] = person;
      }
      onProgress?.call(1);
    } catch (e) {
      debugPrint('Sprites load nahi huin: $e');
    }
  }

  /// Gaadi ki tasveer (lambai 2-4, rang 0-7) diye gaye angle ke liye.
  ///
  /// Do tarah ki files chalti hain (assets/sprites mein):
  ///  * `vehicle_<lambai>_<rang>_<rukh>` (16 rukh, Blender wali): sab se sahi
  ///  * `vehicle_<lambai>_<rang>` (ek hi tasveer, gaadi ka munh UPAR): code
  ///    khud ghuma deta hai. Kenney jaisi top-down car tasveerein aise lagti hain.
  ///
  /// Wapsi: tasveer, aur kitna ghumana hai, aur kya yeh 16-rukh wali hai.
  ui.Image? _directionalImage(int length, int color, int idx) {
    final skin = ProgressService.instance.selectedSkins[length];
    if (skin != null) {
      final img = _images['skin_${skin.id}_${color % 8}_$idx'];
      if (img != null) return img;
    }
    return _images['vehicle_${length.clamp(2, 4)}_${color % 8}_$idx'];
  }

  VehicleSprite? vehicle(int length, int color, double angle) {
    const step = 2 * math.pi / directions;
    final a = ((angle % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi);
    final idx = (a / step).round() % directions;
    final img = _directionalImage(length, color, idx);
    if (img != null) {
      var rest = a - idx * step;
      if (rest > math.pi) rest -= 2 * math.pi;
      return VehicleSprite(img, rest, directional: true);
    }
    final single = _images['vehicle_${length.clamp(2, 4)}_${color % 8}'];
    if (single != null) return VehicleSprite(single, angle, directional: false);
    return null;
  }

  final Set<String> _loadedSkins = {};

  Future<void> _loadAsset(String path) async {
    final name = path.split('/').last.split('.').first;
    if (_images.containsKey(name)) return;
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[name] = frame.image;
    } catch (_) {}
  }

  /// Garage ki ek gaadi ki saari tasveerein (8 rang x 16 rukh) load karo
  Future<void> loadSkin(VehicleSkin s) async {
    if (!_loadedSkins.add(s.id)) return;
    await Future.wait([
      for (var c = 0; c < 8; c++)
        for (var d = 0; d < directions; d++)
          _loadAsset('assets/sprites_v2/skin_${s.id}_${c}_$d.webp'),
    ]);
  }

  /// Chuni hui gaadiyan (app shuru par)
  Future<void> loadSelectedSkins() async {
    for (final s in ProgressService.instance.selectedSkins.values) {
      await loadSkin(s);
    }
  }

  /// Garage mein dikhane wali chhoti tasveer (ek rang, tirchha rukh)
  Future<ui.Image?> skinPreview(VehicleSkin s) async {
    final name = 'skin_${s.id}_${s.previewColor}_3';
    await _loadAsset('assets/sprites_v2/$name.webp');
    return _images[name];
  }

  /// Koi bhi tasveer naam se (maslan "home_bg"), na ho to null
  ui.Image? named(String name) => _images[name];

  ui.Image? person(int color) => _images['person_${color % 8}'];

  /// Chalta-phirta 3D insaan (tool/blender/make_people.py): [heading] game ka
  /// angle (0 = upar, ghadi ki sui ki taraf), [frame] 0-3 (0, 2 = khade)
  ui.Image? walker(int color, double heading, int frame) {
    const step = math.pi / 4;
    final d = ((heading % (2 * math.pi)) / step).round() % 8;
    return _images['walker_${color % 8}_${d}_${frame % 4}'];
  }

  /// Home screen ki badi bus
  ui.Image? get homeBus => _images['home_bus'];
}

/// Gaadi ki tasveer aur use kitna ghumana hai
class VehicleSprite {
  const VehicleSprite(this.image, this.rotation, {required this.directional});
  final ui.Image image;
  final double rotation;

  /// true = Blender wali 16-rukh tasveer (chaukor, saaye samait)
  final bool directional;
}
