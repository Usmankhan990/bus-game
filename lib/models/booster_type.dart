/// Teen qisam ke boosters (neeche isi tarteeb mein dikhte hain)
enum BoosterType {
  /// Koi bhi gaadi utha kar seedha sunehri VIP slot mein (rasta band ho tab bhi)
  vip('vip', 'VIP', 120),

  /// Jo passengers abhi kisi khadi gaadi mein baith sakte hain unhein line mein aage lao
  sort('sort', 'Sort', 100),

  /// Grid par khadi gaadiyon ke rang aapas mein badal do
  shuffle('shuffle', 'Shuffle', 80);

  const BoosterType(this.key, this.title, this.price);

  /// Save karne ke liye naam
  final String key;

  /// Screen par dikhne wala naam
  final String title;

  /// Coins mein qeemat
  final int price;
}
