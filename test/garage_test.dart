import 'package:bus_jam/models/vehicle_skin.dart';
import 'package:bus_jam/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
