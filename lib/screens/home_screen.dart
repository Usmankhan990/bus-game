import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/logic/level_generator.dart';
import '../game/render/palette.dart';
import '../game/render/sprite_bank.dart';
import '../services/ad_service.dart';
import '../services/progress_service.dart';
import '../ui/candy_button.dart';
import '../ui/coin_pill.dart';
import '../ui/icon_tile.dart';
import '../ui/theme.dart';
import '../widgets/garage.dart';
import 'journey_screen.dart';
import '../widgets/home_features.dart';
import '../widgets/settings_panel.dart';
import '../widgets/sky_painter.dart';
import 'game_screen.dart';

/// Pehli screen: shehar ki sadak, beech mein badi bus (LEVEL X ke board ke saath),
/// dono taraf feature icons, upar coins aur settings, neeche bada Play.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    // Laal dots ke timers (free coins, gift) khatam hon to dot khud aa jaye
    _dotTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    // Screen dikhne ke baad consent form aur ads shuru karo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.instance.initialize();
    });
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const GameScreen(),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openJourney() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const JourneyScreen()));
    if (mounted) setState(() {});
  }

  /// Popup kholo, band hone par laal dots dobara check karo
  Future<void> _open(Future<void> Function(BuildContext) show) async {
    await show(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final tile = (w * 0.13).clamp(42.0, 62.0);
          // Bus sadak ke beech, saamne se seedhi (bus stop par)
          final busW = math.min(w * 0.53, h * 0.29);
          final busH = busW * 1408 / 1152;
          final busCx = w * 0.60;
          final busBottom = h * 0.70;
          return Stack(
            children: [
              // Manzar: aasman, imaraten, sadak, log
              // Na badalne wala hissa sirf ek dafa draw hota hai
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _HomeScenePainter(0)),
                ),
              ),
              // Sirf hilne wali cheezen (sadak ki lakeerein, log) har frame
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => CustomPaint(
                      painter: _HomeScenePainter(_anim.value, moving: true),
                    ),
                  ),
                ),
              ),
              // Badi bus (halki si upar neeche hilti hui)
              Positioned(
                left: busCx - busW / 2,
                top: busBottom - busH,
                width: busW,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      math.sin(_anim.value * 2 * math.pi * 10) * busW * 0.008,
                    ),
                    child: child,
                  ),
                  // Apni alag layer: hilne par badi tasveer dobara draw nahi hoti
                  child: RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: progress,
                      builder: (context, _) =>
                          _HeroBus(width: busW, level: progress.level),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: ListenableBuilder(
                  listenable: progress,
                  builder: (context, _) => Stack(
                    children: [
                      Positioned(
                        left: 10,
                        top: 8,
                        child: CoinPill(onPlus: () => _open(showShop)),
                      ),
                      // Mojooda shehar; dabane par safar ka map
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 64,
                        child: Center(child: CityChip(onTap: _openJourney)),
                      ),
                      Positioned(
                        right: 10,
                        top: 6,
                        child: CandyIconButton(
                          icon: Icons.settings_rounded,
                          size: 46,
                          onPressed: () => _open(showSettings),
                        ),
                      ),
                      // Baayen taraf
                      Positioned(
                        left: 6,
                        top: h * 0.1,
                        child: _column([
                          IconTile(
                            icon: Icons.calendar_month_rounded,
                            label: 'Daily Bonus',
                            art: 'daily',
                            color: AppColors.green,
                            size: tile,
                            dot: DailyBonus.canClaim,
                            onTap: () => _open(showDailyBonus),
                          ),
                          IconTile(
                            icon: Icons.block_rounded,
                            label: 'No Ads',
                            art: 'noads',
                            color: AppColors.red,
                            size: tile,
                            onTap: () => _open(showNoAds),
                          ),
                          IconTile(
                            icon: Icons.directions_bus_rounded,
                            label: 'Garage',
                            art: 'garage',
                            color: AppColors.teal,
                            size: tile,
                            dot: progress.canUnlockSkin,
                            onTap: () => _open(showGarage),
                          ),
                          IconTile(
                            icon: Icons.storefront_rounded,
                            label: 'Shop',
                            art: 'shop',
                            color: AppColors.blue,
                            size: tile,
                            onTap: () => _open(showShop),
                          ),
                        ]),
                      ),
                      // Daayen taraf
                      Positioned(
                        right: 6,
                        top: h * 0.1,
                        child: _column([
                          IconTile(
                            icon: Icons.monetization_on_rounded,
                            label: 'Supplies',
                            art: 'supplies',
                            color: AppColors.orange,
                            size: tile,
                            dot: FreeCoins.anythingReady,
                            onTap: () => _open(showFreeCoins),
                          ),
                          IconTile(
                            icon: Icons.casino_rounded,
                            label: 'Spin',
                            art: 'spin',
                            color: AppColors.purple,
                            size: tile,
                            dot: LuckySpin.freeSpinReady,
                            onTap: () => _open(showLuckySpin),
                          ),
                          IconTile(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Check-in',
                            art: 'checkin',
                            color: AppColors.teal,
                            size: tile,
                            dot: CheckIn.ready,
                            onTap: () => _open(showCheckIn),
                          ),
                        ]),
                      ),
                      // Neeche Play
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: h * 0.16,
                        child: Column(
                          children: [
                            Center(
                              child: CandyButton.primary(
                                label: 'Play',
                                width: math.min(w * 0.56, 260),
                                height: 60,
                                fontSize: 34,
                                pulse: true,
                                onPressed: _play,
                              ),
                            ),
                            // Consent badalne ka button (sirf jahan zaroori ho)
                            ValueListenableBuilder<bool>(
                              valueListenable:
                                  AdService.instance.privacyOptionsRequired,
                              builder: (context, required, _) => required
                                  ? TextButton(
                                      onPressed:
                                          AdService.instance.showPrivacyOptions,
                                      child: Text(
                                        'Privacy settings',
                                        style: AppText.title(14),
                                      ),
                                    )
                                  : const SizedBox(height: 4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _column(List<Widget> tiles) => Column(
    children: [
      for (final t in tiles)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: t),
    ],
  );
}

/// Badi 3D bus (saamne se) aur us ki plate par "LEVEL X"; mushkil level par "HARD" tag
class _HeroBus extends StatelessWidget {
  const _HeroBus({required this.width, required this.level});
  final double width;
  final int level;

  @override
  Widget build(BuildContext context) {
    final img =
        SpriteBank.instance.named('home_bus_v2') ?? SpriteBank.instance.homeBus;
    final diff = LevelGenerator.specFor(level).difficulty;
    final h = width * 1408 / 1152;
    // Blender tasveer mein plate ki jagah (tasveer ke hisse ke tanasub se)
    final plate = Rect.fromLTRB(
      width * 0.28,
      h * 0.368,
      width * 0.70,
      h * 0.422,
    );
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (img != null)
            Positioned.fill(
              child: RawImage(image: img, fit: BoxFit.contain),
            ),
          Positioned.fromRect(
            rect: plate,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'LEVEL $level',
                style: AppText.title(
                  40,
                  color: const Color(0xFF25314E),
                  outlined: false,
                ),
              ),
            ),
          ),
          if (diff > 0)
            Positioned(
              left: width * 0.36,
              right: width * 0.29,
              top: h * 0.299,
              height: h * 0.045,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF292738),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FittedBox(
                    child: Text(
                      diff == 2 ? 'SUPER HARD' : 'HARD',
                      style: AppText.title(
                        width * 0.075,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Home ka manzar: aasman, pastel imaraten, footpath, sadak aur line mein log
class _HomeScenePainter extends CustomPainter {
  const _HomeScenePainter(this.t, {this.moving = false});
  final double t;

  /// false = sirf saakin manzar; true = sirf hilti cheezen (lakeerein, log)
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    if (moving) {
      _paintMoving(canvas, size);
      return;
    }
    // assets/sprites/home_bg.png (ya .webp) rakhi ho to wohi background
    final bg =
        SpriteBank.instance.named('home_bg_v2') ??
        SpriteBank.instance.named('home_bg');
    if (bg != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: bg,
        fit: BoxFit.cover,
      );
      return;
    }
    SkyPainter(t).paint(canvas, size);
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.4;

    // Door ki imaraten (pastel rang, khidkiyon ke saath)
    const colors = [
      Color(0xFFF6C6C6),
      Color(0xFFBFD9F2),
      Color(0xFFF9E0B5),
      Color(0xFFD9C8F0),
      Color(0xFFC9EBD7),
    ];
    final rnd = math.Random(7);
    var x = -w * 0.05;
    var i = 0;
    while (x < w) {
      final bw = w * (0.16 + rnd.nextDouble() * 0.12);
      final bh = h * (0.12 + rnd.nextDouble() * 0.16);
      final rect = Rect.fromLTWH(x, horizon - bh, bw, bh + 4);
      final col = colors[i % colors.length];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        ),
        Paint()..color = col,
      );
      // Chhat ki patti
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 6),
        Paint()..color = GamePalette.darker(col, 0.12),
      );
      final win = Paint()..color = Colors.white.withValues(alpha: 0.7);
      for (var wy = rect.top + 14; wy < rect.bottom - 14; wy += 18) {
        for (var wx = rect.left + 8; wx < rect.right - 12; wx += 16) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(wx, wy, 8, 10),
              const Radius.circular(2),
            ),
            win,
          );
        }
      }
      x += bw + 4;
      i++;
    }

    // Zameen (footpath)
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()..color = const Color(0xFFE9E4DA),
    );
    // Footpath ki tiles (perspective lakeerein)
    final tileLine = Paint()
      ..color = const Color(0xFFD8D1C3)
      ..strokeWidth = 1.5;
    for (var k = 1; k < 8; k++) {
      final f = k / 8;
      final y = horizon + (h - horizon) * f * f;
      canvas.drawLine(Offset(0, y), Offset(w, y), tileLine);
    }

    // Sadak: neeche chaudi, door patli (perspective)
    final road = Path()
      ..moveTo(w * 0.44, horizon)
      ..lineTo(w * 0.66, horizon)
      ..lineTo(w * 1.2, h)
      ..lineTo(w * 0.18, h)
      ..close();
    canvas.drawPath(road, Paint()..color = GamePalette.road);
    // Footpath ka kinara
    final curb = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    canvas.drawLine(Offset(w * 0.44, horizon), Offset(w * 0.18, h), curb);
  }

  void _paintMoving(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.4;
    // home_bg tasveer ho to us par lakeerein nahi, sirf log
    final hasBg =
        SpriteBank.instance.named('home_bg_v2') != null ||
        SpriteBank.instance.named('home_bg') != null;
    if (!hasBg) _dashes(canvas, w, h, horizon);
    _people(canvas, w, h);
  }

  void _dashes(Canvas canvas, double w, double h, double horizon) {
    // Darmiyani dashed lakeer (chalti hui)
    final dash = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var k = 0; k < 9; k++) {
      final f = ((k + t * 18) % 9) / 9; // 0 door, 1 qareeb
      final y = horizon + (h - horizon) * f * f;
      final cx = w * 0.55 + (w * 0.14) * f * f;
      final len = 6 + 34 * f;
      final wid = 1.5 + 5 * f;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y), width: wid, height: len),
          Radius.circular(wid),
        ),
        dash,
      );
    }
  }

  void _people(Canvas canvas, double w, double h) {
    // Footpath par bus ki taraf line mein khade log (aage wala bus ke paas,
    // peeche wale door aur chhote), halka idle hilna
    for (var k = 9; k >= 0; k--) {
      final f = 1 - k / 10; // 1 = sab se aage (qareeb)
      final y = h * (0.38 + 0.28 * f);
      final px = w * (0.43 - 0.12 * f);
      final s = w * (0.045 + 0.065 * f);
      final img =
          SpriteBank.instance.named('person_front_${k % 8}') ??
          SpriteBank.instance.person(k);
      final bob = (math.sin(t * 2 * math.pi * 6 + k)).abs() * 2.5;
      if (img != null) {
        _drawImage(
          canvas,
          img,
          Rect.fromCenter(
            center: Offset(px, y - s * 0.5 - bob),
            width: s * 1.25,
            height: s * 1.25,
          ),
        );
      } else {
        canvas.drawCircle(
          Offset(px, y - s * 0.5 - bob),
          s * 0.35,
          Paint()..color = GamePalette.bus(k),
        );
      }
    }
  }

  void _drawImage(Canvas canvas, ui.Image img, Rect dst) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      SpriteBank.paint,
    );
  }

  @override
  bool shouldRepaint(_HomeScenePainter old) =>
      old.moving != moving || (moving && old.t != t);
}
