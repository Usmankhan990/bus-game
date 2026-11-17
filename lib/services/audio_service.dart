import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Game ki saari awaazen. File ka naam `assets/audio/naam.wav` (ya .mp3 / .ogg) hai.
enum Sfx {
  tap('tap'),
  busMove('bus_move'),
  blocked('blocked'),
  hitEffect('hit_effect'),
  board('board'),
  busDepart('bus_depart'),
  levelStart('level_start'),
  carLand('car_land'),
  win('win'),
  fail('fail'),
  button('button'),
  spin('spin_sound'),
  coinsCollect('coins_collect'),
  gift('gift');

  const Sfx(this.fileName);
  final String fileName;
}

/// Sounds chalane wali service. Agar koi file maujood na ho to game crash nahi hoti,
/// bas woh awaaz nahi chalti.
///
/// Chhote sound effects ke liye lowLatency (SoundPool) use hota hai jo instant bajte hain.
/// Lambi victory/fail awaazon ke liye mediaPlayer use hota hai taake Android par 2 second
/// par cut na hon aur poori 6+ second ki awaaz bina rukawat ke baje.
/// audioFocus = none se koi awaaz doosri awaaz ko beech mein band nahi karti.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  /// Ek hi awaaz ek saath zyada se zyada itni dafa baj sakti hai
  static const int _playersPerSound = 3;

  /// Game audio context: koi bhi sound doosri sound ya music ka focus na cheene.
  /// Ambient category iOS par inherently mix karti hai (mixWithOthers pass karne par
  /// audioplayers ka assert fail hota tha jis se focus none apply nahi ho pa raha tha).
  @visibleForTesting
  static AudioContext buildGameContext() => AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
  );

  static final AudioContext _gameContext = buildGameContext();

  /// Settings se sound on/off
  bool enabled = true;

  /// Background music (alag player, loop mein)
  AudioPlayer? _music;
  bool _musicOn = true;

  final Map<Sfx, List<AudioPlayer>> _players = {};
  final Map<Sfx, int> _next = {};

  Future<void> init() async {
    try {
      try {
        await AudioPlayer.global.setAudioContext(_gameContext);
      } catch (_) {}
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      // iPhone .ogg nahi chala sakta, is liye wahan sirf wav/mp3
      final exts = defaultTargetPlatform == TargetPlatform.iOS
          ? ['wav', 'mp3']
          : ['wav', 'mp3', 'ogg'];
      for (final s in Sfx.values) {
        final candidates = [
          s.fileName,
          if (s == Sfx.spin) 'spin',
          if (s == Sfx.coinsCollect) ...['coins', 'coin_collect'],
        ];
        var loaded = false;
        for (final baseName in candidates) {
          if (loaded) break;
          for (final ext in exts) {
            final path = 'audio/$baseName.$ext';
            if (!assets.contains('assets/$path')) continue;
            // Lambi awaazen (win, fail, spin, coinsCollect) MediaPlayer istemal karein taake Android
            // ka SoundPool unhein beech mein na kaate; 2 players taa ke do lambi awaazen sath baj saken
            final isLong = s == Sfx.win ||
                s == Sfx.fail ||
                s == Sfx.spin ||
                s == Sfx.coinsCollect;
            final count = isLong ? 2 : _playersPerSound;
            _players[s] = [
              for (var i = 0; i < count; i++)
                await _makePlayer(path, lowLatency: !isLong),
            ];
            loaded = true;
            break;
          }
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
        try {
          await AudioPlayer.global.setAudioContext(_gameContext);
        } catch (_) {}
        final p = AudioPlayer()..positionUpdater = null;
        try {
          await p.setAudioContext(_gameContext);
        } catch (_) {}
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

  Future<AudioPlayer> _makePlayer(
    String path, {
    bool lowLatency = true,
  }) async {
    final p = AudioPlayer()..positionUpdater = null;
    try {
      await p.setAudioContext(_gameContext);
    } catch (_) {}
    await p.setPlayerMode(
      lowLatency ? PlayerMode.lowLatency : PlayerMode.mediaPlayer,
    );
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setSource(AssetSource(path));
    return p;
  }

  void play(Sfx sfx, {double volume = 0.7}) {
    if (!enabled) return;
    final list = _players[sfx];
    if (list == null || list.isEmpty) return;
    // Pehle khaali player chunein taa ke chal rahi awaaz beech mein band na ho
    final start = _next[sfx] ?? 0;
    var pick = start % list.length;
    for (var step = 0; step < list.length; step++) {
      final candidate = (start + step) % list.length;
      if (list[candidate].state != PlayerState.playing) {
        pick = candidate;
        break;
      }
    }
    _next[sfx] = pick + 1;
    unawaited(_safePlay(list[pick], volume));
  }

  /// Kisi sound ko foran band karna (maslan naya level shuru hote waqt)
  void stop(Sfx sfx) {
    final list = _players[sfx];
    if (list == null) return;
    for (final p in list) {
      unawaited(p.stop());
    }
  }

  Future<void> _safePlay(AudioPlayer p, double volume) async {
    try {
      if (p.state == PlayerState.playing || p.state == PlayerState.paused) {
        await p.stop();
      }
      await p.setVolume(volume);
      await p.resume();
    } catch (e) {
      debugPrint('Sound nahi chali: $e');
    }
  }
}
