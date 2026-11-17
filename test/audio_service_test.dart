import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:bus_jam/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Game audio context bina assertion error ke mix support karta hai', () {
    final ctx = AudioService.buildGameContext();
    expect(ctx.android.audioFocus, AndroidAudioFocus.none);
    expect(ctx.android.usageType, AndroidUsageType.game);
    expect(ctx.iOS.category, AVAudioSessionCategory.ambient);
    expect(ctx.iOS.options, isEmpty);
  });

  test('Ek sath win aur coins play karne par error ya crash nahi hota', () {
    final audio = AudioService.instance;
    audio.enabled = true;
    audio.play(Sfx.win);
    audio.play(Sfx.coinsCollect);
    audio.play(Sfx.board, volume: 0.4);
    audio.play(Sfx.hitEffect, volume: 0.85);
    audio.play(Sfx.levelStart, volume: 0.72);
    audio.play(Sfx.carLand, volume: 0.48);
    audio.play(Sfx.busDepart, volume: 0.6);
    audio.play(Sfx.gift);
    audio.stop(Sfx.win);
    audio.stop(Sfx.levelStart);
    audio.stop(Sfx.carLand);
    audio.stop(Sfx.busDepart);
    audio.stop(Sfx.gift);
  });

  test('Level start, bus depart, gift aur hit effect ki audio files maujood hain', () {
    expect(File('assets/audio/hit_effect.mp3').lengthSync(), greaterThan(1000));
    expect(File('assets/audio/level_start.wav').lengthSync(), greaterThan(10000));
    expect(File('assets/audio/car_land.wav').lengthSync(), greaterThan(5000));
    expect(File('assets/audio/bus_depart.wav').lengthSync(), greaterThan(30000));
    expect(File('assets/audio/gift.wav').lengthSync(), greaterThan(30000));
  });

  test('Win sound sirf level complete par bajta hai, gifts/check-in/garage par nahi', () {
    final homeSrc = File('lib/widgets/home_features.dart').readAsStringSync();
    final garageSrc = File('lib/widgets/garage.dart').readAsStringSync();
    final gameSrc = File('lib/game/bus_jam_game.dart').readAsStringSync();
    expect(homeSrc.contains('Sfx.win'), isFalse);
    expect(homeSrc.contains('Sfx.gift'), isTrue);
    expect(garageSrc.contains('Sfx.win'), isFalse);
    expect(garageSrc.contains('Sfx.gift'), isTrue);
    expect(gameSrc.contains('play(Sfx.win)'), isTrue);
  });
}

