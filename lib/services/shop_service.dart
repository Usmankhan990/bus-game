/// Dukaan (Shop) ki cheezen. Abhi asli payment nahi lagi: [ShopService.buy]
/// hamesha "abhi nahi" (false) deta hai aur buttons par "Coming Soon" dikhta hai.
///
/// Baad mein asli payment (Google Play / App Store) lagane ka tareeqa:
///  1. pubspec.yaml mein `in_app_purchase` package jodein.
///  2. Play Console > Monetize > Products mein neeche wali [ShopProduct.id]
///     wali products banayein.
///  3. [ShopService.available] ko true karein aur [ShopService.buy] ke andar
///     InAppPurchase.instance.buyConsumable / buyNonConsumable chalayein;
///     purchase kamyab ho to [ShopProduct.coins] de dein ya ads band kar dein.
class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.title,
    required this.price,
    this.coins = 0,
    this.removesAds = false,
    this.badge,
  });

  /// Store mein product ka ID (Play Console mein bilkul yahi)
  final String id;
  final String title;

  /// Dikhane wali qeemat (asli qeemat store se aayegi)
  final String price;
  final int coins;
  final bool removesAds;

  /// Kone par chhota label (maslan "BEST")
  final String? badge;
}

class ShopService {
  /// Asli payment lagne ke baad true karein
  static const bool available = false;

  static const List<ShopProduct> coinPacks = [
    ShopProduct(
      id: 'coins_500',
      title: '500 Coins',
      price: '\$0.99',
      coins: 500,
    ),
    ShopProduct(
      id: 'coins_1500',
      title: '1,500 Coins',
      price: '\$2.49',
      coins: 1500,
      badge: 'POPULAR',
    ),
    ShopProduct(
      id: 'coins_5000',
      title: '5,000 Coins',
      price: '\$6.99',
      coins: 5000,
      badge: 'BEST',
    ),
  ];

  static const ShopProduct noAds = ShopProduct(
    id: 'no_ads',
    title: 'No Ads',
    price: '\$2.99',
    removesAds: true,
  );

  /// Khareedna. Abhi payment nahi lagi, is liye false.
  static Future<bool> buy(ShopProduct product) async => false;
}
