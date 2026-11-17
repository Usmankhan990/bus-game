import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

/// AdMob ka saara kaam: consent (UMP), interstitial aur rewarded ads.
/// Banner ka widget widgets/banner_ad_area.dart mein hai.
///
/// Policy ke qawaid:
///  - Ads sirf consent ke baad load hote hain.
///  - Interstitial sirf "Next Level" dabane ke baad, qawaid ke mutabiq.
///  - Rewarded sirf jab user khud button dabaye, inaam sirf poora dekhne par.
///  - Ad na ho to app atakti nahi, bas false wapis aata hai.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  /// Tests mein ads band karne ke liye
  static bool enabled = true;

  /// Is device par ads chal sakte hain (Android/iOS, tests mein nahi)
  bool get supported => _supported;

  bool get _supported =>
      enabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Consent mil gaya aur SDK chal gaya (banner isay sunta hai)
  final ValueNotifier<bool> adsReady = ValueNotifier(false);

  /// Rewarded ad dikhane ke liye tayyar hai?
  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  /// Kya privacy settings ka button dikhana zaroori hai? (EU waghera)
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  bool _started = false;
  bool _consentAsked = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  int _interstitialRetries = 0;
  int _rewardedRetries = 0;
  DateTime? _lastInterstitial;
  int _levelsSinceInterstitial = 1;

  /// App shuru hone par (pehli screen dikhne ke baad) chalayein
  Future<void> initialize() async {
    if (!_supported || _consentAsked) return;
    _consentAsked = true;
    try {
      // Pichli dafa consent mil chuka ho to fauran ads shuru kar do
      if (await ConsentInformation.instance.canRequestAds()) {
        unawaited(_startSdk());
      }

      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          // Zaroorat ho to Google ka consent form dikhao
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
              if (e != null) debugPrint('Consent form: ${e.message}');
              if (!done.isCompleted) done.complete();
            });
          } catch (e) {
            if (!done.isCompleted) done.complete();
          }
        },
        (FormError e) {
          debugPrint('Consent update nahi hua: ${e.message}');
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      await _startSdk();
      await _updatePrivacyStatus();
    } catch (e) {
      debugPrint('AdMob consent masla: $e');
    }
  }

  Future<void> _startSdk() async {
    if (_started) return;
    try {
      if (!await ConsentInformation.instance.canRequestAds()) return;
      _started = true;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      await MobileAds.instance.initialize();
      adsReady.value = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      _started = false;
      debugPrint('AdMob shuru nahi hua: $e');
    }
  }

  Future<void> _updatePrivacyStatus() async {
    try {
      final s = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      privacyOptionsRequired.value =
          s == PrivacyOptionsRequirementStatus.required;
    } catch (_) {}
  }

  /// Home screen ke "Privacy" button se: user apna consent badal sake
  Future<void> showPrivacyOptions() async {
    if (!_supported) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? e) {
        if (e != null) debugPrint('Privacy form: ${e.message}');
        unawaited(_startSdk());
      });
    } catch (e) {
      debugPrint('Privacy form nahi khula: $e');
    }
  }

  // ---------------- Interstitial ----------------

  void _loadInterstitial() {
    if (!AdConfig.hasInterstitial) return;
    if (!_started || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialRetries = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingInterstitial = false;
          debugPrint('Interstitial load nahi hua: ${err.message}');
          _retry(() => _interstitialRetries++, _loadInterstitial);
        },
      ),
    );
  }

  /// "Next Level" dabane ke baad bulayein. Qawaid poore hon aur ad tayyar ho
  /// to dikhata hai, aur ad band hone tak intezar karta hai. Warna fauran wapis.
  Future<void> maybeShowInterstitial({required int completedLevel}) async {
    _levelsSinceInterstitial++;
    if (!_supported) return;
    if (completedLevel < AdConfig.interstitialFromLevel) return;
    if (_levelsSinceInterstitial < AdConfig.interstitialEveryLevels) return;
    final last = _lastInterstitial;
    if (last != null &&
        DateTime.now().difference(last) < AdConfig.interstitialMinGap) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
        _loadInterstitial();
      },
    );
    _lastInterstitial = DateTime.now();
    _levelsSinceInterstitial = 0;
    try {
      await ad.show();
    } catch (e) {
      if (!closed.isCompleted) closed.complete();
    }
    await closed.future;
  }

  // ---------------- Rewarded ----------------

  void _loadRewarded() {
    if (!AdConfig.hasRewarded) return;
    if (!_started || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewardedRetries = 0;
          _rewarded = ad;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (err) {
          _loadingRewarded = false;
          debugPrint('Rewarded load nahi hua: ${err.message}');
          _retry(() => _rewardedRetries++, _loadRewarded);
        },
      ),
    );
  }

  /// Rewarded ad dikhao. Sirf tab true jab user ne ad poora dekh kar inaam kamaya.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (!_supported || ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    rewardedReady.value = false;

    var earned = false;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        // Kabhi kabhi inaam ka paigham band hone ke foran baad aata hai
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (!closed.isCompleted) closed.complete(earned);
        });
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete(false);
        _loadRewarded();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (e) {
      if (!closed.isCompleted) closed.complete(false);
    }
    return closed.future;
  }

  /// Load fail ho to thodi der baad dobara (har dafa zyada intezar)
  void _retry(int Function() bump, void Function() load) {
    final n = bump();
    final seconds = (10 * (1 << n.clamp(0, 5))).clamp(10, 300);
    Timer(Duration(seconds: seconds), load);
  }
}
