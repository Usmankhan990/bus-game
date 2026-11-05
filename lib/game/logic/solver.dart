import '../../models/bus_data.dart';
import '../../models/level_data.dart';
import 'game_model.dart';

/// Level hal karne wala computer player.
/// Level generator aur tests is se check karte hain ke level hal ho sakta hai.
class Solver {
  /// Saada solver: buses ko "hal karne wale order" (rakhne ke ulte order) mein
  /// nikalta hai aur passengers bithata hai. Level ban'ne ki guarantee isi se hai.
  static bool solveInOrder(LevelData level) {
    final m = GameModel(level);
    final order = List<BusData>.of(level.buses)
      ..sort((a, b) => b.order.compareTo(a.order));
    var next = 0;
    while (true) {
      m.settleInstantly();
      if (m.isWon) return true;
      if (next >= order.length) return false;
      final r = m.launch(order[next].id);
      if (r.status != LaunchStatus.ok) return false;
      next++;
    }
  }

  /// Kisi bhi halat se: grid ki baqi gaadiyan "hal karne wale order" mein nikalo.
  /// Tez aur pakka check (shuffle ke smart rangon ke liye).
  static bool solveByOrder(GameModel start) {
    final m = start.clone();
    final order = List<BusData>.of(m.grid)
      ..sort((a, b) => b.order.compareTo(a.order));
    var next = 0;
    while (true) {
      m.settleInstantly();
      if (m.isWon) return true;
      if (next >= order.length) return false;
      final r = m.launch(order[next].id, ignoreBlock: true);
      if (r.status != LaunchStatus.ok) return false;
      next++;
    }
  }

  /// Behtar solver (depth-first search) kisi bhi halat se.
  /// Shuffle booster check karta hai ke naye rangon ke saath bhi hal mumkin hai.
  /// [nodeLimit] se zyada koshishen na kare taa ke phone par der na lage.
  static bool canSolve(GameModel start, {int nodeLimit = 2000}) {
    var nodes = 0;

    bool dfs(GameModel s) {
      if (++nodes > nodeLimit) return false;
      s.settleInstantly();
      if (s.isWon) return true;
      if (s.freeSlot == null) return false;

      final movable = s.movableBuses();
      if (movable.isEmpty) return false;
      final need = _firstNeed(s);
      movable.sort((a, b) {
        final na = need[a.color] ?? 1 << 30;
        final nb = need[b.color] ?? 1 << 30;
        if (na != nb) return na.compareTo(nb);
        return b.order.compareTo(a.order);
      });

      // Ek jaise rang aur ek jaisi halat ki buses dobara try na karo
      final tried = <int>{};
      for (final bus in movable) {
        if (!tried.add(bus.color) && movable.length > 3) continue;
        final c = s.clone();
        c.launch(bus.id);
        if (dfs(c)) return true;
        if (nodes > nodeLimit) return false;
      }
      return false;
    }

    return dfs(start.clone());
  }

  /// Har rang ka pehla passenger jis ke liye abhi slot mein jagah nahi
  /// (line mein us ka number). Jis rang ki zaroorat jaldi hai woh bus pehle.
  static Map<int, int> _firstNeed(GameModel s) {
    final room = <int, int>{};
    for (final slot in s.slots) {
      if (slot == null) continue;
      room[slot.color] = (room[slot.color] ?? 0) + slot.freeSeats;
    }
    final need = <int, int>{};
    for (var i = s.head; i < s.queue.length; i++) {
      final c = s.queue[i];
      final r = room[c] ?? 0;
      if (r > 0) {
        room[c] = r - 1;
      } else {
        need.putIfAbsent(c, () => i);
      }
    }
    return need;
  }
}
