// App ka launcher icon (PNG) banane wala script: neela gradient aur 3D peeli
// car (Blender se bani, tool/art/icon_bus.png).
// Android 8+ adaptive icon XML wala use karta hai; yeh PNG purane Android
// (7) aur Play Store (512x512) ke liye hain.
// Chalane ka tareeqa (project folder mein):
//   flutter test tool/make_app_icon.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// mipmap folder aur us ka size (pixels)
const _sizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// Icon draw karo. [rounded] = kone gol (launcher PNG); Play Store icon
/// chaukor hota hai (Google khud gol karta hai).
void _paintIcon(Canvas c, double s, {required bool rounded}) {
  final r = Offset.zero & Size(s, s);
  final bg = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF308CE8), Color(0xFF4FB8E0), Color(0xFF1A7AC6)],
    ).createShader(r);
  if (rounded) {
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.22)), bg);
  } else {
    c.drawRect(r, bg);
  }
  // 3D peeli car (Blender: tool/art/icon_bus.png), icon ka zyada hissa le
  final van = _van!;
  final vs = s * 1.08;
  c.drawImageRect(
    van,
    Offset.zero & Size(van.width.toDouble(), van.height.toDouble()),
    Rect.fromCenter(center: Offset(s * 0.5, s * 0.49), width: vs, height: vs),
    Paint()..filterQuality = FilterQuality.high,
  );
}

ui.Image? _van;

Future<void> _save(int size, String path, {required bool rounded}) async {
  final rec = ui.PictureRecorder();
  _paintIcon(Canvas(rec), size.toDouble(), rounded: rounded);
  final img = await rec.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('App icon banao', () async {
    final codec = await ui.instantiateImageCodec(
      File('tool/art/icon_bus.png').readAsBytesSync(),
    );
    _van = (await codec.getNextFrame()).image;
    for (final e in _sizes.entries) {
      await _save(e.value, '$_res/${e.key}/ic_launcher.png', rounded: true);
    }
    await _save(512, 'store_listing/icon_512.png', rounded: false);
  });
}
