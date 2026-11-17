/// Apna chhota random number generator (mulberry32).
/// Same seed hamesha same numbers deta hai, har phone aur platform par.
/// Is liye level number ko seed bana kar har level hamesha ek jaisa banta hai.
class SeededRandom {
  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  /// 0 se 2^32 tak ka agla number
  int _next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= t + _imul(t ^ (t >> 7), t | 61);
    t &= 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  /// 32-bit guna (JavaScript ke Math.imul jaisa)
  static int _imul(int a, int b) {
    final aHi = (a >> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    return (aLo * bLo + (((aHi * bLo + aLo * bHi) << 16) & 0xFFFFFFFF)) &
        0xFFFFFFFF;
  }

  /// 0 se (max - 1) tak koi number
  int nextInt(int max) => max <= 1 ? 0 : _next() % max;

  /// Aadha-aadha chance (true / false)
  bool nextBool() => nextInt(2) == 0;

  /// 0.0 se 1.0 tak
  double nextDouble() => _next() / 4294967296.0;

  /// List ko jagah par hi shuffle karna (Fisher-Yates)
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}
