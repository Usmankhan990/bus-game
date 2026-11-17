/// App ki aam settings ek jagah.
class AppConfig {
  /// Game ka naam (Home screen par). Final original naam yahan badlein.
  /// Phone par icon ke neeche wala naam:
  ///   Android: android/app/build.gradle.kts mein manifestPlaceholders["appName"]
  ///   iOS: ios/Runner/Info.plist mein CFBundleDisplayName
  static const String appName = 'City Bus Jam';

  /// Game banane wali company (loading screen aur settings mein)
  static const String studioName = 'CodedHouse';

  /// Settings mein dikhne wala version (pubspec.yaml ke version jaisa rakhein)
  static const String version = '1.4.1';

  /// Play Store ke screenshots lene ke liye build (ads band):
  ///   flutter build apk --debug --dart-define=STORE_SHOTS=true
  static const bool storeShots = bool.fromEnvironment('STORE_SHOTS');

  /// Naye player ko shuru mein kitne coins milte hain
  static const int startingCoins = 100;

  /// Har booster shuru mein kitne free
  static const int startingBoosters = 2;

  /// Level jeetne par coins ka inaam
  static int winReward(int level) => 20 + (level ~/ 5) * 2;

  /// Kitne ghalat (blocked) taps bina star kaate maafi milte hain
  static const int freeBlockedHits = 2;

  /// Level jeetne par kitne stars (1..3):
  /// - Boosters (`VIP`, `Sort`, `Shuffle`), khole gaye extra `+` slots aur
  ///   revive (fail ke baad continue) har ek 1 help count hota hai.
  /// - [freeBlockedHits] (2) tak ghalat taps maaf hain; 3-5 par +1 aur
  ///   6+ par +2 penalty lagti hai.
  /// - 0 total penalty = 3 stars, 1 = 2 stars, 2+ = 1 star.
  static int winStars({
    required int boostersUsed,
    int slotsUnlocked = 0,
    int revivesUsed = 0,
    int blockedHits = 0,
  }) {
    final hitPenalty = blockedHits <= freeBlockedHits
        ? 0
        : (blockedHits <= freeBlockedHits + 3 ? 1 : 2);
    final penalty = boostersUsed + slotsUnlocked + revivesUsed + hitPenalty;
    if (penalty <= 0) return 3;
    if (penalty == 1) return 2;
    return 1;
  }
}
