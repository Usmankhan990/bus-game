import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/booster_type.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../services/shop_service.dart';
import '../ui/candy_button.dart';
import '../ui/coin_pill.dart';
import '../ui/game_popup.dart';
import '../ui/theme.dart';
import 'booster_bar.dart';

/// Aaj ki tareekh "2026-10-25" ki shakal mein (device ki date se)
String _today([int addDays = 0]) {
  final d = DateTime.now().add(Duration(days: addDays));
  return '${d.year}-${d.month}-${d.day}';
}

ProgressService get _p => ProgressService.instance;

// =====================================================================
// Inaam (coins aur/ya boosters)
// =====================================================================

class Reward {
  const Reward({this.coins = 0, this.booster, this.boosterCount = 1});

  final int coins;
  final BoosterType? booster;
  final int boosterCount;

  String get label => [
    if (coins > 0) '$coins coins',
    if (booster != null) '${booster!.title} x$boosterCount',
  ].join(' + ');

  void give() {
    if (coins > 0) _p.addCoins(coins);
    if (booster != null) _p.addBooster(booster!, boosterCount);
  }
}

/// Inaam ki chhoti tasveer: sikkon ka dher aur/ya booster tile
class RewardIcon extends StatelessWidget {
  const RewardIcon(this.reward, {super.key, this.size = 40});
  final Reward reward;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (reward.coins > 0) {
      parts.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size * 1.2,
              height: size,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: CoinIcon(size: size * 0.7),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CoinIcon(size: size * 0.7),
                  ),
                  Positioned(
                    left: size * 0.25,
                    top: 0,
                    child: CoinIcon(size: size * 0.75),
                  ),
                ],
              ),
            ),
            Text('${reward.coins}', style: AppText.title(size * 0.42)),
          ],
        ),
      );
    }
    if (reward.booster != null) {
      if (parts.isNotEmpty) {
        parts.add(Text(' + ', style: AppText.title(size * 0.5)));
      }
      final b = reward.booster!;
      parts.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: boosterColor(b),
                borderRadius: BorderRadius.circular(size * 0.28),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                boosterIcon(b),
                color: Colors.white,
                size: size * 0.6,
              ),
            ),
            Text('x${reward.boosterCount}', style: AppText.title(size * 0.42)),
          ],
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
  }
}

/// Inaam milne ka chhota popup
Future<void> showRewardPopup(
  BuildContext context,
  Reward r, {
  String title = 'You Got!',
}) {
  AudioService.instance.play(Sfx.win);
  return showGamePopup<void>(
    context,
    (context) => GamePopup(
      title: title,
      ribbonColor: AppColors.green,
      content: [
        const SizedBox(height: 6),
        Center(child: RewardIcon(r, size: 64)),
        const SizedBox(height: 6),
      ],
      footer: [
        CandyButton.primary(
          label: 'Great!',
          height: 54,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// Ek din (Day 1..7) ka box
class _DayBox extends StatelessWidget {
  const _DayBox({
    required this.day,
    required this.reward,
    required this.done,
    required this.today,
    this.wide = false,
  });

  final int day;
  final Reward reward;
  final bool done;
  final bool today;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final header = today
        ? AppColors.green
        : (wide ? AppColors.orange : const Color(0xFFC9DBEC));
    Widget box = Container(
      height: wide ? 96 : 92,
      decoration: BoxDecoration(
        color: today ? const Color(0xFFE3F8EC) : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: today ? AppColors.green : AppColors.creamLine,
          width: today ? 3 : 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: header,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Day $day',
              style: AppText.title(
                15,
                outlined: today || wide,
                color: today || wide ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.green,
                      size: 44,
                      shadows: [
                        Shadow(
                          color: AppColors.greenDark,
                          offset: Offset(0, 2),
                        ),
                      ],
                    )
                  : RewardIcon(reward, size: wide ? 40 : 32),
            ),
          ),
        ],
      ),
    );
    if (today) {
      // Aaj ka din: halka sa chamakna
      box = _Glow(child: box);
    }
    return box;
  }
}

/// Halki dhadakti chamak (aaj ka inaam)
class _Glow extends StatefulWidget {
  const _Glow({required this.child});
  final Widget child;
  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.25 + 0.45 * _c.value),
            blurRadius: 6 + 10 * _c.value,
            spreadRadius: 1 + 2 * _c.value,
          ),
        ],
      ),
      child: child,
    ),
    child: widget.child,
  );
}

// =====================================================================
// Daily Bonus (7 din)
// =====================================================================

class DailyBonus {
  static const rewards = [
    Reward(coins: 50),
    Reward(booster: BoosterType.vip),
    Reward(coins: 100),
    Reward(booster: BoosterType.sort),
    Reward(coins: 150),
    Reward(booster: BoosterType.shuffle),
    Reward(coins: 400, booster: BoosterType.vip),
  ];

  static String? get _last => _p.prefs?.getString('daily_last');
  static int get _streak => _p.prefs?.getInt('daily_streak') ?? 0;

  static bool get canClaim => _last != _today();

  /// Aaj kaun sa din (0-6). Ek din chhoot jaye to silsila Day 1 se.
  static int get todayIndex {
    if (_last == _today(-1)) return _streak % 7;
    if (_last == _today()) return (_streak - 1) % 7;
    return 0;
  }

  static Reward claim() {
    final idx = todayIndex;
    final r = rewards[idx];
    r.give();
    _p.prefs?.setString('daily_last', _today());
    _p.prefs?.setInt('daily_streak', idx + 1);
    return r;
  }
}

Future<void> showDailyBonus(BuildContext context) =>
    showGamePopup<void>(context, (context) => const _DailyBonusPopup());

class _DailyBonusPopup extends StatefulWidget {
  const _DailyBonusPopup();
  @override
  State<_DailyBonusPopup> createState() => _DailyBonusPopupState();
}

class _DailyBonusPopupState extends State<_DailyBonusPopup> {
  @override
  Widget build(BuildContext context) {
    final today = DailyBonus.todayIndex;
    final can = DailyBonus.canClaim;
    Widget day(int i, {bool wide = false}) => _DayBox(
      day: i + 1,
      reward: DailyBonus.rewards[i],
      done: i < today || (i == today && !can),
      today: i == today && can,
      wide: wide,
    );
    return GamePopup(
      title: 'Daily Bonus',
      onClose: () => Navigator.of(context).pop(),
      content: [
        for (final row in const [
          [0, 1, 2],
          [3, 4, 5],
        ]) ...[
          Row(
            children: [
              for (final i in row) ...[
                Expanded(child: day(i)),
                if (i != row.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        day(6, wide: true),
      ],
      footer: [
        CandyButton.primary(
          label: can ? 'Claim' : 'Come back tomorrow',
          fontSize: can ? 26 : 20,
          height: 56,
          pulse: can,
          onPressed: can
              ? () async {
                  final r = DailyBonus.claim();
                  setState(() {});
                  await showRewardPopup(context, r);
                }
              : null,
        ),
      ],
    );
  }
}

// =====================================================================
// Free Coins (rows: pehli timer se free, baqi ad dekh kar, ek ke baad ek)
// =====================================================================

class FreeCoins {
  /// Pehli row: har itne waqt baad bilkul free
  static const timerGap = Duration(hours: 1);
  static const timerCoins = 20;

  /// Ad wali rows (din mein har ek dafa, ek ke baad ek khulti hain)
  static const adRows = [50, 70, 100];

  static DateTime? get _lastTimer {
    final ms = _p.prefs?.getInt('free_timer_last');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Duration get timerLeft {
    final last = _lastTimer;
    if (last == null) return Duration.zero;
    final left = timerGap - DateTime.now().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  static bool get timerReady => timerLeft == Duration.zero;

  static void claimTimer() {
    _p.addCoins(timerCoins);
    _p.prefs?.setInt('free_timer_last', DateTime.now().millisecondsSinceEpoch);
  }

  /// Aaj kitni ad rows le li gayi
  static int get adClaimed {
    if (_p.prefs?.getString('free_ad_day') != _today()) return 0;
    return _p.prefs?.getInt('free_ad_count') ?? 0;
  }

  static void claimAdRow() {
    final n = adClaimed;
    _p.addCoins(adRows[n]);
    _p.prefs?.setString('free_ad_day', _today());
    _p.prefs?.setInt('free_ad_count', n + 1);
  }

  static bool get anythingReady => timerReady;
}

Future<void> showFreeCoins(BuildContext context) =>
    showGamePopup<void>(context, (context) => const _FreeCoinsPopup());

class _FreeCoinsPopup extends StatefulWidget {
  const _FreeCoinsPopup();
  @override
  State<_FreeCoinsPopup> createState() => _FreeCoinsPopupState();
}

class _FreeCoinsPopupState extends State<_FreeCoinsPopup> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:'
      '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _ad() async {
    setState(() => _busy = true);
    final ok = await AdService.instance.showRewarded();
    if (!mounted) return;
    if (ok) {
      final coins = FreeCoins.adRows[FreeCoins.adClaimed];
      FreeCoins.claimAdRow();
      await showRewardPopup(context, Reward(coins: coins));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final claimed = FreeCoins.adClaimed;
    return GamePopup(
      title: 'Bus Supplies',
      ribbonColor: const Color(0xFF5965C9),
      panelColor: const Color(0xFFAC85EB),
      contentColor: const Color(0xFF9773DC),
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      content: [
        _coinRow(
          FreeCoins.timerCoins,
          FreeCoins.timerReady
              ? CandyButton.primary(
                  label: 'Free',
                  fontSize: 18,
                  height: 42,
                  onPressed: () async {
                    FreeCoins.claimTimer();
                    setState(() {});
                    await showRewardPopup(
                      context,
                      const Reward(coins: FreeCoins.timerCoins),
                    );
                  },
                )
              : CandyButton(
                  label: _fmt(FreeCoins.timerLeft),
                  color: AppColors.blue,
                  fontSize: 17,
                  height: 42,
                  onPressed: null,
                ),
        ),
        for (var i = 0; i < FreeCoins.adRows.length; i++)
          _coinRow(
            FreeCoins.adRows[i],
            ValueListenableBuilder<bool>(
              valueListenable: AdService.instance.rewardedReady,
              builder: (context, ready, _) {
                final done = i < claimed;
                final locked = i > claimed;
                return CandyButton.primary(
                  label: done ? 'Done' : (locked ? '' : 'Free'),
                  icon: done
                      ? Icons.check_rounded
                      : (locked
                            ? Icons.lock_rounded
                            : Icons.play_arrow_rounded),
                  fontSize: 18,
                  height: 42,
                  onPressed: !done && !locked && ready && !_busy ? _ad : null,
                );
              },
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Watch a short video to grab your free coins!',
          textAlign: TextAlign.center,
          style: AppText.text(14, color: Colors.white),
        ),
      ],
    );
  }

  Widget _coinRow(int coins, Widget button) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9394F0), Color(0xFF777BE0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC3B5F9), width: 1.5),
      ),
      child: Row(
        children: [
          const CoinIcon(size: 34),
          const SizedBox(width: 8),
          Text('x$coins', style: AppText.title(22, color: AppColors.coin)),
          const Spacer(),
          SizedBox(width: 120, child: button),
        ],
      ),
    ),
  );
}

// =====================================================================
// Lucky Spin
// =====================================================================

class LuckySpin {
  static const segments = [
    Reward(coins: 20),
    Reward(booster: BoosterType.vip),
    Reward(coins: 50),
    Reward(booster: BoosterType.shuffle),
    Reward(coins: 100),
    Reward(booster: BoosterType.sort),
    Reward(coins: 30),
    Reward(coins: 200),
  ];

  static bool get freeSpinReady => _p.prefs?.getString('spin_last') != _today();
  static void markFreeUsed() => _p.prefs?.setString('spin_last', _today());
}

Future<void> showLuckySpin(BuildContext context) =>
    showGamePopup<void>(context, (context) => const _SpinPopup());

class _SpinPopup extends StatefulWidget {
  const _SpinPopup();
  @override
  State<_SpinPopup> createState() => _SpinPopupState();
}

class _SpinPopupState extends State<_SpinPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  double _from = 0;
  double _to = 0;
  bool _spinning = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _spin({required bool free}) async {
    if (_spinning) return;
    if (!free) {
      final ok = await AdService.instance.showRewarded();
      if (!ok || !mounted) return;
    } else {
      LuckySpin.markFreeUsed();
    }
    final n = LuckySpin.segments.length;
    final pick = math.Random().nextInt(n);
    final seg = 2 * math.pi / n;
    // Teer upar hai: jeetne wala hissa upar aa kar ruke. Kam az kam 6 chakkar.
    _from = _to % (2 * math.pi);
    final target = 2 * math.pi - (pick + 0.5) * seg;
    var delta = target - _from;
    while (delta < 0) {
      delta += 2 * math.pi;
    }
    _to = _from + 6 * 2 * math.pi + delta;
    setState(() => _spinning = true);
    AudioService.instance.play(Sfx.busMove);
    await _c.forward(from: 0);
    if (!mounted) return;
    final r = LuckySpin.segments[pick];
    r.give();
    setState(() => _spinning = false);
    await showRewardPopup(context, r, title: 'You Won!');
  }

  @override
  Widget build(BuildContext context) {
    final free = LuckySpin.freeSpinReady;
    final wheel = math.min(MediaQuery.sizeOf(context).width * 0.62, 240.0);
    return GamePopup(
      title: 'Lucky Spin',
      ribbonColor: AppColors.purple,
      onClose: _spinning ? null : () => Navigator.of(context).pop(),
      content: [
        SizedBox(
          height: wheel + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  // Tez shuru, aahista aahista rukna
                  final e = Curves.easeOutQuart.transform(_c.value);
                  return Transform.rotate(
                    angle: _from + (_to - _from) * e,
                    child: CustomPaint(
                      size: Size(wheel, wheel),
                      painter: const _WheelPainter(),
                    ),
                  );
                },
              ),
              // Beech ka button aur upar ka teer
              Container(
                width: wheel * 0.2,
                height: wheel * 0.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
              Positioned(
                top: 0,
                child: CustomPaint(
                  size: const Size(34, 36),
                  painter: _PointerPainter(),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: [
        if (free)
          CandyButton.primary(
            label: 'Free Spin',
            height: 56,
            pulse: !_spinning,
            onPressed: _spinning ? null : () => _spin(free: true),
          )
        else
          ValueListenableBuilder<bool>(
            valueListenable: AdService.instance.rewardedReady,
            builder: (context, ready, _) => CandyButton(
              label: ready ? 'Spin' : 'Ad not available',
              icon: Icons.play_circle_fill_rounded,
              color: AppColors.purple,
              height: 56,
              onPressed: ready && !_spinning ? () => _spin(free: false) : null,
            ),
          ),
      ],
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawPath(path, Paint()..color = AppColors.red);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final segs = LuckySpin.segments;
    final seg = 2 * math.pi / segs.length;
    const fills = [
      Color(0xFFFFC542),
      Color(0xFF2389E8),
      Color(0xFFFF9A2E),
      Color(0xFF8655EA),
      Color(0xFF38C978),
      Color(0xFF26C6BA),
      Color(0xFFFF6FB5),
      Color(0xFFF2545B),
    ];
    canvas.drawCircle(
      c.translate(0, 4),
      r,
      Paint()..color = const Color(0x44000000),
    );
    canvas.drawCircle(c, r, Paint()..color = AppColors.panelBorder);
    for (var i = 0; i < segs.length; i++) {
      final start = -math.pi / 2 + i * seg;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 7),
        start,
        seg,
        true,
        Paint()..color = fills[i % fills.length],
      );
      final mid = start + seg / 2;
      canvas.save();
      canvas.translate(
        c.dx + math.cos(mid) * r * 0.62,
        c.dy + math.sin(mid) * r * 0.62,
      );
      canvas.rotate(mid + math.pi / 2);
      final reward = segs[i];
      final tp = TextPainter(
        text: TextSpan(
          text: reward.booster == null
              ? '${reward.coins}'
              : reward.booster!.title,
          style: AppText.title(r * 0.13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    // Kinare par chhote bulb
    for (var i = 0; i < segs.length * 2; i++) {
      final a = i * seg / 2;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (r - 3.5),
        2.6,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

// =====================================================================
// Check-in: har 4 ghante baad ek free gift
// =====================================================================

class CheckIn {
  static const gap = Duration(hours: 4);

  static Duration get left {
    final ms = _p.prefs?.getInt('gift_last');
    if (ms == null) return Duration.zero;
    final l =
        gap -
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    return l.isNegative ? Duration.zero : l;
  }

  static bool get ready => left == Duration.zero;

  static Reward claim() {
    final r = math.Random().nextBool()
        ? const Reward(coins: 40)
        : Reward(
            coins: 20,
            booster: BoosterType.values[math.Random().nextInt(3)],
          );
    r.give();
    _p.prefs?.setInt('gift_last', DateTime.now().millisecondsSinceEpoch);
    return r;
  }
}

Future<void> showCheckIn(BuildContext context) =>
    showGamePopup<void>(context, (context) => const _CheckInPopup());

class _CheckInPopup extends StatefulWidget {
  const _CheckInPopup();
  @override
  State<_CheckInPopup> createState() => _CheckInPopupState();
}

class _CheckInPopupState extends State<_CheckInPopup> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = CheckIn.ready;
    final l = CheckIn.left;
    return GamePopup(
      title: 'Check-in',
      ribbonColor: AppColors.teal,
      onClose: () => Navigator.of(context).pop(),
      content: [
        const Center(child: Text('🎁', style: TextStyle(fontSize: 72))),
        const SizedBox(height: 6),
        PopupText(
          ready
              ? 'Your free gift is ready!'
              : 'Next gift in ${l.inHours}h ${l.inMinutes % 60}m ${l.inSeconds % 60}s',
        ),
      ],
      footer: [
        CandyButton.primary(
          label: ready ? 'Open Gift' : 'Come back later',
          height: 56,
          fontSize: ready ? 24 : 20,
          pulse: ready,
          onPressed: ready
              ? () async {
                  final r = CheckIn.claim();
                  setState(() {});
                  await showRewardPopup(context, r);
                }
              : null,
        ),
      ],
    );
  }
}

// =====================================================================
// Shop aur No Ads (asli payment abhi nahi: "Coming Soon")
// =====================================================================

Future<void> showShop(BuildContext context) =>
    showGamePopup<void>(context, (context) => const _ShopPopup());

class _ShopPopup extends StatelessWidget {
  const _ShopPopup();

  @override
  Widget build(BuildContext context) {
    return GamePopup(
      title: 'Shop',
      ribbonColor: AppColors.blue,
      onClose: () => Navigator.of(context).pop(),
      content: [
        _ProductCard(ShopService.noAds),
        for (final p in ShopService.coinPacks) _ProductCard(p),
        const SizedBox(height: 4),
        Text(
          'Boosters',
          textAlign: TextAlign.center,
          style: AppText.title(18, color: AppColors.inkSoft, outlined: false),
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: _p,
          builder: (context, _) => Row(
            children: [
              for (final t in BoosterType.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        RewardIcon(
                          Reward(booster: t, boosterCount: _p.boosterCount(t)),
                          size: 40,
                        ),
                        const SizedBox(height: 4),
                        CandyButton.secondary(
                          label: '${t.price}',
                          leading: const CoinIcon(size: 18),
                          fontSize: 16,
                          height: 36,
                          onPressed: _p.coins >= t.price
                              ? () {
                                  if (_p.spendCoins(t.price)) _p.addBooster(t);
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(this.product);
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              color: p.removesAds
                  ? const Color(0xFFFFE1E1)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: p.removesAds
                    ? const Color(0xFFF2A3A3)
                    : AppColors.creamLine,
                width: 2,
              ),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                if (p.removesAds)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  )
                else
                  RewardIcon(Reward(coins: p.coins), size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.title,
                    style: AppText.title(
                      19,
                      color: AppColors.inkSoft,
                      outlined: false,
                    ),
                  ),
                ),
                SizedBox(
                  width: 112,
                  child: CandyButton.primary(
                    label: ShopService.available ? p.price : 'Coming Soon',
                    fontSize: 15,
                    height: 40,
                    onPressed: ShopService.available
                        ? () => ShopService.buy(p)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (p.badge != null)
            Positioned(
              left: 8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(p.badge!, style: AppText.title(11)),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showNoAds(BuildContext context) => showGamePopup<void>(
  context,
  (context) => GamePopup(
    title: 'No Ads',
    ribbonColor: AppColors.red,
    onClose: () => Navigator.of(context).pop(),
    content: [
      const Center(
        child: Icon(Icons.block_rounded, size: 72, color: AppColors.red),
      ),
      const SizedBox(height: 6),
      const PopupText('Remove all banner and video ads forever.'),
      const SizedBox(height: 10),
      _ProductCard(ShopService.noAds),
    ],
  ),
);
