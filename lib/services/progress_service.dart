import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/booster_type.dart';
import '../models/vehicle_skin.dart';
import 'audio_service.dart';
import 'haptic_service.dart';

/// Player ka saara save hone wala data (shared_preferences mein).
/// Level, coins, boosters, sound aur vibration. App band karke kholne par wahin se shuru.
class ProgressService extends ChangeNotifier {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  static const _kLevel = 'level';
  static const _kCoins = 'coins';
  static const _kSound = 'sound_on';
  static const _kMusic = 'music_on';
  static const _kVibration = 'vibration_on';
  static const _kStars = 'stars';
  static const _kSkins = 'skins_unlocked';
  static String _skinKey(int length) => 'skin_for_$length';
  static String _boosterKey(BoosterType t) => 'booster_${t.key}';

  SharedPreferences? _prefs;

  /// Daily inaam, spin waghera apna chhota data yahin rakhte hain
  SharedPreferences? get prefs => _prefs;

  int level = 1;
  int coins = AppConfig.startingCoins;
  bool soundOn = true;
  bool musicOn = true;
  bool vibrationOn = true;

  /// Jeete hue levels ke kul stars (Garage mein gaadiyan kholne ke liye)
  int stars = 0;
  final Set<VehicleSkin> unlockedSkins = {};

  /// Har lambai (2, 3, 4) ke liye chuni hui khaas gaadi (na ho to aam gaadi)
  final Map<int, VehicleSkin> selectedSkins = {};
  final Map<BoosterType, int> _boosters = {
    for (final t in BoosterType.values) t: AppConfig.startingBoosters,
  };

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      level = p.getInt(_kLevel) ?? 1;
      coins = p.getInt(_kCoins) ?? AppConfig.startingCoins;
      soundOn = p.getBool(_kSound) ?? true;
      musicOn = p.getBool(_kMusic) ?? true;
      vibrationOn = p.getBool(_kVibration) ?? true;
      // Purane players: pehle se jeete levels ke andaze se stars
      stars = p.getInt(_kStars) ?? (level - 1) * 2;
      for (final id in p.getStringList(_kSkins) ?? const <String>[]) {
        final s = VehicleSkin.byId(id);
        if (s != null) unlockedSkins.add(s);
      }
      for (final len in const [2, 3, 4]) {
        final s = VehicleSkin.byId(p.getString(_skinKey(len)));
        if (s != null && unlockedSkins.contains(s)) selectedSkins[len] = s;
      }
      for (final t in BoosterType.values) {
        _boosters[t] = p.getInt(_boosterKey(t)) ?? AppConfig.startingBoosters;
      }
    } catch (e) {
      debugPrint('Save data load nahi hua: $e');
    }
    AudioService.instance.enabled = soundOn;
    HapticService.instance.enabled = vibrationOn;
    notifyListeners();
  }

  int boosterCount(BoosterType t) => _boosters[t] ?? 0;

  /// Level jeet liya: agla level khol do aur coins do
  void completeLevel(int finished, int reward) {
    if (finished >= level) level = finished + 1;
    coins += reward;
    _prefs?.setInt(_kLevel, level);
    _prefs?.setInt(_kCoins, coins);
    notifyListeners();
  }

  void addStars(int n) {
    stars += n;
    _prefs?.setInt(_kStars, stars);
    notifyListeners();
  }

  /// Koi aisi gaadi jo stars se khul sakti hai magar abhi band hai
  bool get canUnlockSkin => VehicleSkin.values.any(
    (s) => !unlockedSkins.contains(s) && stars >= s.cost,
  );

  /// Stars kharch kar ke gaadi kholo (aur fauran chun lo). Kam hon to false.
  bool unlockSkin(VehicleSkin s) {
    if (unlockedSkins.contains(s)) return true;
    if (stars < s.cost) return false;
    stars -= s.cost;
    unlockedSkins.add(s);
    _prefs?.setInt(_kStars, stars);
    _prefs?.setStringList(_kSkins, [for (final u in unlockedSkins) u.id]);
    selectSkin(s);
    return true;
  }

  /// Gaadi chuno; [s] pehle se chuni ho to wapis aam gaadi
  void selectSkin(VehicleSkin s) {
    if (selectedSkins[s.length] == s) {
      selectedSkins.remove(s.length);
      _prefs?.remove(_skinKey(s.length));
    } else {
      selectedSkins[s.length] = s;
      _prefs?.setString(_skinKey(s.length), s.id);
    }
    notifyListeners();
  }

  void addCoins(int amount) {
    coins += amount;
    _prefs?.setInt(_kCoins, coins);
    notifyListeners();
  }

  /// Coins kharch karna. Kafi na hon to false.
  bool spendCoins(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    _prefs?.setInt(_kCoins, coins);
    notifyListeners();
    return true;
  }

  void addBooster(BoosterType t, [int n = 1]) {
    _boosters[t] = boosterCount(t) + n;
    _prefs?.setInt(_boosterKey(t), _boosters[t]!);
    notifyListeners();
  }

  /// Ek booster istemal karna. Na ho to false.
  bool useBooster(BoosterType t) {
    final n = boosterCount(t);
    if (n <= 0) return false;
    _boosters[t] = n - 1;
    _prefs?.setInt(_boosterKey(t), n - 1);
    notifyListeners();
    return true;
  }

  void setSound(bool on) {
    soundOn = on;
    AudioService.instance.enabled = on;
    _prefs?.setBool(_kSound, on);
    notifyListeners();
  }

  void setMusic(bool on) {
    musicOn = on;
    AudioService.instance.setMusic(on);
    _prefs?.setBool(_kMusic, on);
    notifyListeners();
  }

  void setVibration(bool on) {
    vibrationOn = on;
    HapticService.instance.enabled = on;
    _prefs?.setBool(_kVibration, on);
    notifyListeners();
  }
}
