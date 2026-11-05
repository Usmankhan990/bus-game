import 'bus_data.dart';

/// Ek level ki poori maloomat: grid, gaadiyan aur passengers ki line.
class LevelData {
  LevelData({
    required this.level,
    required this.cols,
    required this.rows,
    required this.buses,
    required this.passengers,
    required this.colorCount,
    this.slotCount = 4,
    this.lockedSlots = 3,
    this.hasVip = true,
    this.difficulty = 0,
    this.isBreather = false,
  });

  final int level;
  final int cols;
  final int rows;
  final List<BusData> buses;

  /// Passengers ke rang, line ke order mein (index 0 = sab se aage)
  final List<int> passengers;
  final int colorCount;

  /// Shuru mein khule (aam) slots, VIP ke ilawa
  final int slotCount;

  /// Sunehri VIP slot (sirf VIP booster ke liye) maujood hai?
  final bool hasVip;

  /// 0 = aam, 1 = HARD, 2 = SUPER HARD
  final int difficulty;

  /// Band slots ("+"), jo ad ya coins se khulte hain
  final int lockedSlots;

  /// Har 10 level ke baad aasaan "saans lene wala" level
  final bool isBreather;

  /// Level 1 par tutorial hint dikhana hai
  bool get isTutorial => level == 1;
}
