import 'package:bus_jam/config/app_config.dart';
import 'package:bus_jam/models/vehicle_skin.dart';
import 'package:bus_jam/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('AppConfig.winStars: boosters, extra slots, revive aur hits ka fair hisab', () {
    // Clean win (2 ghalat taps tak maafi) -> 3 stars
    expect(AppConfig.winStars(boostersUsed: 0), 3);
    expect(AppConfig.winStars(boostersUsed: 0, blockedHits: 2), 3);

    // 1 booster OR 1 extra slot OR 1 revive OR 3-5 blocked hits -> 2 stars
    expect(AppConfig.winStars(boostersUsed: 1), 2);
    expect(AppConfig.winStars(boostersUsed: 0, slotsUnlocked: 1), 2);
    expect(AppConfig.winStars(boostersUsed: 0, revivesUsed: 1), 2);
    expect(AppConfig.winStars(boostersUsed: 0, blockedHits: 3), 2);
    expect(AppConfig.winStars(boostersUsed: 0, blockedHits: 5), 2);

    // 2+ helps ya zyada hits -> 1 star (kabhi 0 nahi)
    expect(AppConfig.winStars(boostersUsed: 2), 1);
    expect(
      AppConfig.winStars(boostersUsed: 1, revivesUsed: 1),
      1,
    );
    expect(
      AppConfig.winStars(boostersUsed: 0, slotsUnlocked: 1, revivesUsed: 1),
      1,
    );
    expect(AppConfig.winStars(boostersUsed: 0, blockedHits: 6), 1);
  });

  test('Garage skins star cost balanced aur ascending order mein hain', () {
    final costs = VehicleSkin.values.map((s) => s.cost).toList();
    expect(VehicleSkin.taxi.cost, lessThanOrEqualTo(60));
    for (var i = 1; i < costs.length; i++) {
      expect(costs[i], greaterThan(costs[i - 1]));
    }
  });
  test(
    'Garage: stars se gaadi khulti, chuni jaati aur save hoti hai',
    () async {
      SharedPreferences.setMockInitialValues({'level': 1});
      final p = ProgressService.instance;
      await p.load();
      expect(p.stars, 0);
      expect(p.unlockSkin(VehicleSkin.taxi), isFalse); // stars kam

      p.addStars(250);
      expect(p.canUnlockSkin, isTrue);
      expect(p.unlockSkin(VehicleSkin.taxi), isTrue);
      expect(p.stars, 250 - VehicleSkin.taxi.cost);
      expect(p.selectedSkins[2], VehicleSkin.taxi);

      // Dobara dabane se wapis aam gaadi
      p.selectSkin(VehicleSkin.taxi);
      expect(p.selectedSkins[2], isNull);
      p.selectSkin(VehicleSkin.taxi);

      // App dobara khulne par bhi yaad rahe
      await p.load();
      expect(p.unlockedSkins, contains(VehicleSkin.taxi));
      expect(p.selectedSkins[2], VehicleSkin.taxi);
      expect(p.stars, 250 - VehicleSkin.taxi.cost);
    },
  );
}
