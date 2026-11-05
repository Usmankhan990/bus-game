import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Game ki saari awaazen. File ka naam `assets/audio/naam.wav` (ya .mp3 / .ogg) hai.
enum Sfx {
  tap('tap'),
  busMove('bus_move'),
  blocked('blocked'),
  board('board'),
  busDepart('bus_depart'),
  win('win'),
  fail('fail'),
  button('button');

  const Sfx(this.fileName);
  final String fileName;
}

/// Sounds chalane wali service. Agar koi file maujood na ho to game crash nahi hoti,
/// bas woh awaaz nahi chalti.
///
/// Har awaaz ke liye chhote players pehle se bana kar baar baar istemal hote hain.
/// (Har dafa naya player banane se players jama hote rehte the aur game dheemi hoti.)
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  /// Ek hi awaaz ek saath zyada se zyada itni dafa baj sakti hai
  static const int _playersPerSound = 3;

  /// Settings se sound on/off
  bool enabled = true;

  /// Background music (alag player, loop mein)
  AudioPlayer? _music;
  bool _musicOn = true;

  final Map<Sfx, List<AudioPlayer>> _players = {};
  final Map<Sfx, int> _next = {};

  Future<void> init() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      // iPhone .ogg nahi chala sakta, is liye wahan sirf wav/mp3
      final exts = defaultTargetPlatform == TargetPlatform.iOS
          ? ['wav', 'mp3']
          : ['wav', 'mp3', 'ogg'];
      for (final s in Sfx.values) {
        for (final ext in exts) {
          final path = 'audio/${s.fileName}.$ext';
          if (!assets.contains('assets/$path')) continue;
          _players[s] = [
            for (var i = 0; i < _playersPerSound; i++) await _makePlayer(path),
          ];
          break;
        }
      }
    } catch (e) {
      debugPrint('Sounds load nahi huin: $e');
    }
  }

  /// Music on/off (settings se). On ho to loop mein chalta rehta hai.
  Future<void> setMusic(bool on) async {
    _musicOn = on;
    try {
      if (!on) {
        await _music?.pause();
        return;
      }
      if (_music == null) {
        final p = AudioPlayer()..positionUpdater = null;
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0.35);
        await p.setSource(AssetSource('audio/music.wav'));
        _music = p;
      }
      if (_musicOn) await _music!.resume();
    } catch (e) {
      debugPrint('Music nahi chali: $e');
    }
  }

  /// App background mein jaye to music roko, wapis aaye to chalao
  Future<void> pauseMusic() async => _music?.pause();
  Future<void> resumeMusic() async {
    if (_musicOn) await _music?.resume();
  }

  Future<AudioPlayer> _makePlayer(String path) async {
    final p = AudioPlayer()
      // Position ki khabar ki zaroorat nahi: is se har frame ka kaam bachta hai
      ..positionUpdater = null;
    await p.setPlayerMode(PlayerMode.lowLatency);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setSource(AssetSource(path));
    return p;
  }

  void play(Sfx sfx, {double volume = 0.7}) {
    if (!enabled) return;
    final list = _players[sfx];
    if (list == null || list.isEmpty) return;
    // Baari baari agla player, taa ke tez taps par awaazen ek doosre ko na katen
    final i = (_next[sfx] ?? 0) % list.length;
    _next[sfx] = i + 1;
    unawaited(_safePlay(list[i], volume));
  }

  Future<void> _safePlay(AudioPlayer p, double volume) async {
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    } catch (e) {
      debugPrint('Sound nahi chali: $e');
    }
  }
}
