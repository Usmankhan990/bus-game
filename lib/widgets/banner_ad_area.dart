import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import '../services/ad_service.dart';

/// Screen ke bilkul neeche standard 320x50 banner ki alag jagah.
/// Jagah shuru se fix (50 + 12 faasla) rehti hai, is liye ad load hone par
/// game ka layout nahi hilta. Gameplay ko nahi dhaanpta.
class BannerAdArea extends StatefulWidget {
  const BannerAdArea({super.key});

  /// Banner ki kul oonchai (ad 50 + upar 12 ka faasla)
  static const double reservedHeight = 62;

  @override
  State<BannerAdArea> createState() => _BannerAdAreaState();
}

class _BannerAdAreaState extends State<BannerAdArea> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.adsReady.addListener(_tryLoad);
    _tryLoad();
  }

  Future<void> _tryLoad() async {
    if (_requested || !AdService.instance.adsReady.value || !mounted) return;
    _requested = true;
    final ad = BannerAd(
      adUnitId: AdConfig.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner load nahi hua: ${err.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    AdService.instance.adsReady.removeListener(_tryLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ads hi nahi chal sakte (maslan tests) to koi jagah nahi
    if (!AdService.instance.supported) return const SizedBox.shrink();
    final ad = _ad;
    // Upar 12px ka faasla: booster buttons aur ad ke beech, taa ke
    // ghalti se ad par click na ho (AdMob policy)
    return Container(
      height: BannerAdArea.reservedHeight,
      width: double.infinity,
      color: const Color(0xFFCDD4DF),
      padding: const EdgeInsets.only(top: 12),
      alignment: Alignment.center,
      child: _loaded && ad != null
          ? SizedBox(width: 320, height: 50, child: AdWidget(ad: ad))
          : null,
    );
  }
}
