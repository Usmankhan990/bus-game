import 'package:flutter/foundation.dart';

/// Saare AdMob IDs ek hi jagah.
///
/// ABHI YEH GOOGLE KE TEST IDs HAIN. Test IDs par click karne se koi nuqsan nahi.
/// Development ke dauran kabhi bhi apne asli ads par click na karein, warna
/// AdMob account band ho sakta hai.
///
/// Asli IDs kab aur kahan lagani hain (release se pehle):
///  1. AdMob console (https://apps.admob.com) mein app add karein (Android aur iOS alag).
///  2. Har app ke liye 3 ad units banayein: Banner, Interstitial, Rewarded.
///  3. Neeche ke "asli" wale strings mein woh unit IDs (ca-app-pub-xxx/yyy) lagayein
///     aur [useTestAds] ko false kar dein.
///  4. App ID (ca-app-pub-xxx~yyy) yahan NAHI lagti, balke:
///       Android: android/app/src/main/AndroidManifest.xml (APPLICATION_ID)
///       iOS:     ios/Runner/Info.plist (GADApplicationIdentifier)
class AdConfig {
  /// true = Google ke test ads, false = asli (live) ads.
  /// Live ads par apne phone se KABHI click na karein (account band ho sakta hai).
  static const bool useTestAds = false;

  // ---------- Google ke TEST IDs (inhein mat badlein) ----------
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2435281174';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // ---------- ASLI IDs (release se pehle yahan apni IDs lagayein) ----------
  static const String _realBannerAndroid =
      'ca-app-pub-3328067470794492/1588150424';
  static const String _realBannerIos = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  static const String _realInterstitialAndroid =
      'ca-app-pub-3328067470794492/2397280151';
  static const String _realInterstitialIos =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  static const String _realRewardedAndroid =
      'ca-app-pub-3328067470794492/6813544029';
  static const String _realRewardedIos =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// Asli ID ki jagah abhi placeholder ya khaali ho to woh ad band rakho
  static bool _usable(String id) => id.isNotEmpty && !id.contains('XXXX');

  static String get bannerId => useTestAds
      ? (_isIos ? _testBannerIos : _testBannerAndroid)
      : (_isIos ? _realBannerIos : _realBannerAndroid);

  static String get interstitialId => useTestAds
      ? (_isIos ? _testInterstitialIos : _testInterstitialAndroid)
      : (_isIos ? _realInterstitialIos : _realInterstitialAndroid);

  static String get rewardedId => useTestAds
      ? (_isIos ? _testRewardedIos : _testRewardedAndroid)
      : (_isIos ? _realRewardedIos : _realRewardedAndroid);

  static bool get hasBanner => _usable(bannerId);
  static bool get hasInterstitial => _usable(interstitialId);
  static bool get hasRewarded => _usable(rewardedId);

  // ---------- Interstitial ke qawaid (AdMob policy ke mutabiq) ----------
  /// Is level ke baad se interstitial shuru
  static const int interstitialFromLevel = 3;

  /// Har itne levels ke baad ek
  static const int interstitialEveryLevels = 2;

  /// Do interstitials ke darmiyan kam az kam itna waqt
  static const Duration interstitialMinGap = Duration(seconds: 60);
}
