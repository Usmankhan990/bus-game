// App ka launcher icon (PNG) banane wala script: assets/app_icons/app_icon_2.png
// se Android adaptive foreground, legacy mipmap PNGs, iOS AppIcon set aur Play Store icon.
// Chalane ka tareeqa (project folder mein):
//   flutter test tool/make_app_icon.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';
const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// mipmap folder aur us ka size (pixels)
const _sizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// iOS icon filenames aur un ke pixel sizes
const _iosSizes = {
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

ui.Image? _art;

void _paintIcon(Canvas c, double s, {required bool rounded}) {
  final art = _art!;
  final r = Offset.zero & Size(s, s);
  if (rounded) {
    c.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.22)));
  }
  c.drawImageRect(
    art,
    Offset.zero & Size(art.width.toDouble(), art.height.toDouble()),
    r,
    Paint()..filterQuality = FilterQuality.high,
  );
}

/// Android 8+ adaptive foreground (432x432): icon ko safe-zone (~80%) mein rakh
/// kar kinaron par halka feather fade lagata hai taa ke cream background seamlessly merge ho.
void _paintAdaptiveForeground(Canvas c, double s) {
  final art = _art!;
  final r = Offset.zero & Size(s, s);
  final pad = s * 0.06;
  final inner = Rect.fromLTRB(pad, pad, s - pad, s - pad);
  c.saveLayer(r, Paint());
  c.drawImageRect(
    art,
    Offset.zero & Size(art.width.toDouble(), art.height.toDouble()),
    inner,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.drawRect(
    r,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const RadialGradient(
        colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
        stops: [0.0, 0.64, 0.86],
      ).createShader(r),
  );
  c.restore();
}

Future<void> _save(
  int size,
  String path,
  void Function(Canvas, double) paint,
) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec), size.toDouble());
  final img = await rec.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('App icon banao', () async {
    final codec = await ui.instantiateImageCodec(
      File('assets/app_icons/app_icon_2.png').readAsBytesSync(),
    );
    _art = (await codec.getNextFrame()).image;
    for (final e in _sizes.entries) {
      await _save(
        e.value,
        '$_res/${e.key}/ic_launcher.png',
        (c, s) => _paintIcon(c, s, rounded: true),
      );
    }
    await _save(
      432,
      '$_res/drawable-nodpi/ic_launcher_art.png',
      _paintAdaptiveForeground,
    );
    await _save(
      512,
      'store_listing/icon_512.png',
      (c, s) => _paintIcon(c, s, rounded: false),
    );
    for (final e in _iosSizes.entries) {
      await _save(
        e.value,
        '$_ios/${e.key}',
        (c, s) => _paintIcon(c, s, rounded: false),
      );
    }
  });
}
