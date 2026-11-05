/// App ki aam settings ek jagah.
class AppConfig {
  /// Game ka naam (Home screen par). Final original naam yahan badlein.
  /// Phone par icon ke neeche wala naam:
  ///   Android: android/app/build.gradle.kts mein manifestPlaceholders["appName"]
  ///   iOS: ios/Runner/Info.plist mein CFBundleDisplayName
  static const String appName = 'Bus Jam Party';

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
}
