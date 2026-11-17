import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/logic/level_generator.dart';
import '../game/render/palette.dart';
import '../game/render/sprite_bank.dart';
import '../models/city.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../ui/candy_button.dart';
import '../ui/coin_pill.dart';
import '../ui/flag_icon.dart';
import '../ui/game_art.dart';
import '../ui/theme.dart';
import '../widgets/garage.dart';
import 'journey_screen.dart';
import '../widgets/home_features.dart';
import '../widgets/settings_panel.dart';
import 'game_screen.dart';

/// Pehli screen (continuous live animated city hub):
///  - Background mein lagatar chalti duniya: baadal, hot-air balloon, parinde,
///    samundar aur kashti, park fountain, aur roundabout par ghoomti rang-barangi gaadiyan
///  - Upar sleek HUD bar (Coins, Stars, Settings) aur City Passport Card
///  - Upar dono konon mein compact floating reward medallions (Daily, Check-in | Supplies, Spin)
///  - Neeche Level Pill + Hero Play button + frosted Garage / Shop / No Ads bar
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _timeSec = ValueNotifier<double>(0);
  final _SceneCache _sceneCache = _SceneCache();

  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _timeSec.value = elapsed.inMicroseconds / 1e6;
    })..start();
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
    _ticker.dispose();
    _timeSec.dispose();
    _sceneCache.dispose();
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const JourneyScreen()));
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
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.5);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final podSize = (w * 0.125).clamp(44.0, 54.0);

          return Stack(
            children: [
              // Lagatar chalta 2.5D animated city & roundabout traffic background
              // (super(repaint: _timeSec) ke zariye zero widget-tree rebuilds per frame)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _LiveCityScenePainter(
                      time: _timeSec,
                      cache: _sceneCache,
                      dpr: dpr,
                    ),
                  ),
                ),
              ),
              // Neeche halka dark gradient taa ke Level Pill, Play CTA aur Bottom Dock chamak kar ubhrein
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h * 0.27,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x000F1B30), Color(0x9C0D182C)],
                      ),
                    ),
                  ),
                ),
              ),
              // Responsive HUD layers (zero overlap across small & tall screens)
              SafeArea(
                child: ListenableBuilder(
                  listenable: progress,
                  builder: (context, _) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _TopHud(
                          stars: progress.stars,
                          canUnlockSkin: progress.canUnlockSkin,
                          onShop: () => _open(showShop),
                          onGarage: () => _open(showGarage),
                          onSettings: () => _open(showSettings),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _CityPassportCard(
                          level: progress.level,
                          onTap: _openJourney,
                        ),
                      ),
                      // Center open showcase: upar dono kinaron par compact event pods
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned(
                              left: 10,
                              top: 10,
                              child: Column(
                                children: [
                                  _EventPod(
                                    time: _timeSec,
                                    phase: 0,
                                    label: 'Daily Bonus',
                                    art: 'daily',
                                    color: AppColors.green,
                                    size: podSize,
                                    dot: DailyBonus.canClaim,
                                    onTap: () => _open(showDailyBonus),
                                  ),
                                  const SizedBox(height: 10),
                                  _EventPod(
                                    time: _timeSec,
                                    phase: 1.7,
                                    label: 'Check-in',
                                    art: 'checkin',
                                    color: AppColors.teal,
                                    size: podSize,
                                    dot: CheckIn.ready,
                                    onTap: () => _open(showCheckIn),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Column(
                                children: [
                                  _EventPod(
                                    time: _timeSec,
                                    phase: 0.9,
                                    label: 'Supplies',
                                    art: 'supplies',
                                    color: AppColors.orange,
                                    size: podSize,
                                    dot: FreeCoins.anythingReady,
                                    onTap: () => _open(showFreeCoins),
                                  ),
                                  const SizedBox(height: 10),
                                  _EventPod(
                                    time: _timeSec,
                                    phase: 2.5,
                                    label: 'Spin',
                                    art: 'spin',
                                    color: AppColors.purple,
                                    size: podSize,
                                    dot: LuckySpin.freeSpinReady,
                                    onTap: () => _open(showLuckySpin),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Neeche Bottom Command Dock (Level Pill + Play + Garage / Shop / No Ads)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: _BottomCommandDock(
                          width: w,
                          height: h,
                          level: progress.level,
                          canUnlockSkin: progress.canUnlockSkin,
                          onPlay: _play,
                          onGarage: () => _open(showGarage),
                          onShop: () => _open(showShop),
                          onNoAds: () => _open(showNoAds),
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
}

/// Upar wala unified bar: Coins + Stars pill + Settings
class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.stars,
    required this.canUnlockSkin,
    required this.onShop,
    required this.onGarage,
    required this.onSettings,
  });

  final int stars;
  final bool canUnlockSkin;
  final VoidCallback onShop;
  final VoidCallback onGarage;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinPill(onPlus: onShop),
                  const SizedBox(width: 8),
                  _StarPill(
                    stars: stars,
                    canUnlock: canUnlockSkin,
                    onTap: onGarage,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CandyIconButton(
          icon: Icons.settings_rounded,
          size: 44,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

/// Kul stars dikhane wali glossy pill (dabane par Garage khulti hai)
class _StarPill extends StatelessWidget {
  const _StarPill({
    required this.stars,
    required this.canUnlock,
    required this.onTap,
  });

  final int stars;
  final bool canUnlock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.play(Sfx.button, volume: 0.6);
        HapticService.instance.light();
        onTap();
      },
      child: SizedBox(
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 14, top: 6, bottom: 4),
              padding: const EdgeInsets.fromLTRB(26, 0, 14, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.creamLine, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), offset: Offset(0, 3)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$stars',
                style: AppText.title(
                  19,
                  outlined: false,
                  color: AppColors.ink,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 3,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CustomPaint(painter: _StarEmblemPainter()),
              ),
            ),
            if (canUnlock)
              Positioned(
                right: -2,
                top: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Jadeed City Destination Passport card (dabane par Journey Map khulti hai)
class _CityPassportCard extends StatelessWidget {
  const _CityPassportCard({required this.level, required this.onTap});
  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final city = City.of(level);
    final stage = City.progressIn(level);
    final frac = math.max(0.06, stage / City.levelsPerCity);
    return GestureDetector(
      onTap: () {
        AudioService.instance.play(Sfx.button, volume: 0.6);
        HapticService.instance.light();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.96),
                const Color(0xFFF0F6FF).withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: city.accent.withValues(alpha: 0.9),
              width: 2.5,
            ),
            boxShadow: AppShadows.panel,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: city.accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: city.accent.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: CityImage(city, size: 42),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FlagIcon(city, width: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            city.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title(
                              17,
                              color: AppColors.ink,
                              outlined: false,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: city.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${stage + 1}/${City.levelsPerCity}',
                            style: AppText.title(
                              12,
                              color: city.accent,
                              outlined: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 7,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFFE1E9F4)),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: frac.clamp(0.06, 1.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.green, AppColors.teal],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.lighter(city.accent, 0.2), city.accent],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x28000000), offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gol chamakdar reward medallion (Daily Bonus, Check-in, Supplies, Spin)
class _EventPod extends StatefulWidget {
  const _EventPod({
    required this.time,
    required this.phase,
    required this.label,
    required this.art,
    required this.color,
    required this.size,
    required this.onTap,
    this.dot = false,
  });

  final ValueNotifier<double> time;
  final double phase;
  final String label;
  final String art;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final bool dot;

  @override
  State<_EventPod> createState() => _EventPodState();
}

class _EventPodState extends State<_EventPod> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final top = AppColors.lighter(widget.color, 0.34);
    final rim = AppColors.darker(widget.color, 0.34);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        AudioService.instance.play(Sfx.button, volume: 0.6);
        HapticService.instance.light();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
          width: s + 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: widget.time,
                builder: (context, child) {
                  final bob =
                      math.sin(widget.time.value * 2.2 + widget.phase) * 1.9;
                  return Transform.translate(
                    offset: Offset(0, bob),
                    child: child,
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [top, widget.color],
                        ),
                        border: Border.all(
                          color: widget.dot
                              ? AppColors.gold
                              : Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: rim,
                            offset: const Offset(0, 3),
                          ),
                          if (widget.dot)
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.55),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 3,
                            child: Container(
                              width: s * 0.58,
                              height: s * 0.22,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(s),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.45),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          GameArt(widget.art, size: s * 0.68),
                        ],
                      ),
                    ),
                    if (widget.dot)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xCC162640),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: AppText.title(10.5, outlined: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Neeche wala elevated Command Dock: Level Pill + Play CTA + Frosted Garage / Shop / No Ads capsule
class _BottomCommandDock extends StatelessWidget {
  const _BottomCommandDock({
    required this.width,
    required this.height,
    required this.level,
    required this.canUnlockSkin,
    required this.onPlay,
    required this.onGarage,
    required this.onShop,
    required this.onNoAds,
  });

  final double width;
  final double height;
  final int level;
  final bool canUnlockSkin;
  final VoidCallback onPlay;
  final VoidCallback onGarage;
  final VoidCallback onShop;
  final VoidCallback onNoAds;

  @override
  Widget build(BuildContext context) {
    final playH = (height * 0.080).clamp(50.0, 60.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LevelPill(level: level),
          const SizedBox(height: 8),
          CandyButton.primary(
            label: 'Play',
            width: math.min(width * 0.68, 280),
            height: playH,
            fontSize: (playH * 0.54).clamp(26.0, 34.0),
            pulse: true,
            onPressed: onPlay,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xEB1C2E4C), Color(0xF7111E35)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.26),
                width: 1.5,
              ),
              boxShadow: AppShadows.panel,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DockTab(
                    label: 'Garage',
                    art: 'garage',
                    color: AppColors.teal,
                    dot: canUnlockSkin,
                    onTap: onGarage,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DockTab(
                    label: 'Shop',
                    art: 'shop',
                    color: AppColors.blue,
                    onTap: onShop,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DockTab(
                    label: 'No Ads',
                    art: 'noads',
                    color: AppColors.red,
                    onTap: onNoAds,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AdService.instance.privacyOptionsRequired,
            builder: (context, required, _) => required
                ? TextButton(
                    onPressed: AdService.instance.showPrivacyOptions,
                    child: Text(
                      'Privacy settings',
                      style: AppText.title(13),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DockTab extends StatefulWidget {
  const _DockTab({
    required this.label,
    required this.art,
    required this.color,
    required this.onTap,
    this.dot = false,
  });

  final String label;
  final String art;
  final Color color;
  final VoidCallback onTap;
  final bool dot;

  @override
  State<_DockTab> createState() => _DockTabState();
}

class _DockTabState extends State<_DockTab> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        AudioService.instance.play(Sfx.button, volume: 0.6);
        HapticService.instance.light();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.color.withValues(alpha: 0.40),
                    widget.color.withValues(alpha: 0.16),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.62),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GameArt(widget.art, size: 32),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: AppText.title(14.5, outlined: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.dot)
              Positioned(
                right: 4,
                top: -3,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StarEmblemPainter extends CustomPainter {
  const _StarEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c.translate(0, 2),
      r,
      Paint()..color = const Color(0xFFB86D0A),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF18A), Color(0xFFFFB914)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    final star = Path();
    final outer = r * 0.56;
    final inner = outer * 0.45;
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rad = i.isEven ? outer : inner;
      final p = Offset(c.dx + math.cos(a) * rad, c.dy + math.sin(a) * rad);
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star.shift(const Offset(0, 1)),
      Paint()..color = const Color(0x99995800),
    );
    canvas.drawPath(star, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_StarEmblemPainter old) => false;
}

/// Play button ke upar sleek Level badge (mushkil level par HARD / SUPER HARD tag)
class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final diff = LevelGenerator.specFor(level).difficulty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEE1E3356), Color(0xF7111F38)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: diff > 0
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: AppShadows.hud,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LEVEL $level',
            style: AppText.title(15, color: Colors.white, outlined: false),
          ),
          if (diff > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: diff == 2
                    ? const Color(0xFFD32F2F)
                    : AppColors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                diff == 2 ? 'SUPER HARD' : 'HARD',
                style: AppText.title(
                  11,
                  color: AppColors.gold,
                  outlined: false,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Screen size mutabiq static city backdrop aur roads ek dafa rasterize kar ke
/// yaad rakhne wala cache (zero per-frame shader lag)
class _SceneCache {
  Size? size;
  double _dpr = 1.0;
  ui.Image? _worldBackdrop;
  ui.Shader? skyShader;
  ui.Shader? raysShader;
  ui.Shader? sunShader;
  late double _sunRad;
  late Offset _sunPos;

  late double hy;
  late double seaTop;
  late double lowerY;
  late Offset rc;
  late double rx;
  late double ry;
  late double rw;
  late Offset uP0;
  late Offset uP1;
  late Offset uP2;
  late Offset lP0;
  late Offset lP1;
  late Offset lP2;
  late List<({double x, double y, double s, int kind})> trees;

  ui.Image? get worldBackdrop => _worldBackdrop;

  void dispose() {
    _worldBackdrop?.dispose();
    _worldBackdrop = null;
    skyShader = null;
    raysShader = null;
    sunShader = null;
    size = null;
  }

  void ensure(Size s, double dpr) {
    if (size == s && (_dpr - dpr).abs() < 0.01 && _worldBackdrop != null) {
      return;
    }
    size = s;
    _dpr = dpr;
    final w = s.width;
    final h = s.height;
    hy = math.max(172.0, h * 0.255);
    seaTop = hy - h * 0.022;
    lowerY = h - math.max(194.0, h * 0.27);
    rc = Offset(w * 0.50, (hy + h * 0.05 + lowerY) * 0.50);
    rx = math.min(w * 0.34, (lowerY - hy) * 0.40);
    ry = rx * 0.72;
    rw = math.min(w * 0.145, (lowerY - hy) * 0.175).clamp(38.0, 58.0);

    final skyRect = Rect.fromLTRB(0, 0, w, hy + 16);
    skyShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2D8BF0), Color(0xFF69C1FA), Color(0xFFBDE8FF)],
      stops: [0.0, 0.58, 1.0],
    ).createShader(skyRect);
    _sunPos = Offset(w * 0.78, hy * 0.58);
    _sunRad = w * 0.95;
    raysShader = ui.Gradient.radial(_sunPos, _sunRad * 0.7, [
      Colors.white.withValues(alpha: 0.20),
      Colors.white.withValues(alpha: 0.0),
    ]);
    sunShader = ui.Gradient.radial(_sunPos, w * 0.28, const [
      Color(0xBBFFF7D1),
      Color(0x00FFF7D1),
    ]);

    final midRect = Rect.fromCenter(
      center: rc,
      width: rx * 2,
      height: ry * 2,
    );
    final ringPath = Path()..addOval(midRect);

    // North spur: upper promenade se roundabout tak
    final north = Path()
      ..moveTo(w * 0.48, hy + h * 0.045)
      ..quadraticBezierTo(w * 0.50, (hy + rc.dy - ry) * 0.52, rc.dx, rc.dy - ry);
    // West & East spokes
    final west = Path()
      ..moveTo(-w * 0.10, rc.dy - h * 0.02)
      ..quadraticBezierTo(w * 0.16, rc.dy - h * 0.004, rc.dx - rx, rc.dy);
    final east = Path()
      ..moveTo(rc.dx + rx, rc.dy)
      ..quadraticBezierTo(w * 0.84, rc.dy + h * 0.004, w * 1.10, rc.dy - h * 0.018);

    // Upper waterfront viaduct avenue (extended offscreen so wrap is invisible)
    uP0 = Offset(-w * 0.22, hy + h * 0.056);
    uP1 = Offset(w * 0.50, hy + h * 0.032);
    uP2 = Offset(w * 1.22, hy + h * 0.060);
    final upper = Path()
      ..moveTo(uP0.dx, uP0.dy)
      ..quadraticBezierTo(uP1.dx, uP1.dy, uP2.dx, uP2.dy);

    // Lower sweeping foreground boulevard (extended offscreen so 4-unit bus vanishes cleanly)
    lP0 = Offset(-w * 0.22, lowerY + 18);
    lP1 = Offset(w * 0.50, lowerY - 12);
    lP2 = Offset(w * 1.22, lowerY + 16);
    final lower = Path()
      ..moveTo(lP0.dx, lP0.dy)
      ..quadraticBezierTo(lP1.dx, lP1.dy, lP2.dx, lP2.dy);

    // South connector from roundabout bottom to lower boulevard
    final south = Path()
      ..moveTo(rc.dx, rc.dy + ry)
      ..lineTo(w * 0.50, lowerY + 2);

    final roadParts = [ringPath, north, west, east, upper, lower, south];

    // Clean lane dashes
    final roadDashes = Path();
    void addDashes(ui.PathMetric m, double dashLen, double gapLen) {
      var d = 0.0;
      while (d < m.length) {
        final end = math.min(d + dashLen, m.length);
        roadDashes.addPath(m.extractPath(d, end), Offset.zero);
        d += dashLen + gapLen;
      }
    }

    final innerDashRect = Rect.fromCenter(
      center: rc,
      width: (rx + rw * 0.28) * 2,
      height: (ry + rw * 0.28) * 2,
    );
    addDashes((Path()..addOval(innerDashRect)).computeMetrics().first, 11, 11);
    addDashes(upper.computeMetrics().first, 10, 10);
    addDashes(lower.computeMetrics().first, 14, 12);

    // Park trees + bushes sides par neatly framed
    trees = [
      (x: w * 0.07, y: hy + (rc.dy - hy) * 0.48, s: w * 0.052, kind: 0),
      (x: w * 0.21, y: hy + (rc.dy - hy) * 0.36, s: w * 0.042, kind: 1),
      (x: w * 0.79, y: hy + (rc.dy - hy) * 0.36, s: w * 0.044, kind: 1),
      (x: w * 0.93, y: hy + (rc.dy - hy) * 0.48, s: w * 0.054, kind: 0),
      (x: w * 0.08, y: (rc.dy + lowerY) * 0.52, s: w * 0.056, kind: 0),
      (x: w * 0.21, y: (rc.dy + lowerY) * 0.55, s: w * 0.044, kind: 1),
      (x: w * 0.79, y: (rc.dy + lowerY) * 0.55, s: w * 0.044, kind: 1),
      (x: w * 0.92, y: (rc.dy + lowerY) * 0.52, s: w * 0.056, kind: 0),
      // Lower park trees below sweeping highway (side borders above Play)
      (x: w * 0.11, y: lowerY + 58, s: w * 0.052, kind: 1),
      (x: w * 0.89, y: lowerY + 56, s: w * 0.052, kind: 0),
    ];

    // Static skyline + harbor + park + roads + fountain base ek dafa image mein bake karo
    _worldBackdrop?.dispose();
    final pw = math.max(1, (w * dpr).ceil());
    final ph = math.max(1, (h * dpr).ceil());
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(pw / w, ph / h);
    _paintStaticWorld(c, w, h, roadParts, roadDashes);
    final pic = rec.endRecording();
    _worldBackdrop = pic.toImageSync(pw, ph);
    pic.dispose();
  }

  void _paintStaticWorld(
    Canvas canvas,
    double w,
    double h,
    List<Path> roadParts,
    Path roadDashes,
  ) {
    // 1. Door ke pastel skyscrapers windows aur spires ke sath (transparent sky background par)
    const towers = [
      (0.54, 0.065, 0.075, Color(0xFF8CB9EB)),
      (0.61, 0.055, 0.105, Color(0xFFA2C6EF)),
      (0.67, 0.075, 0.065, Color(0xFFB5D4F7)),
      (0.75, 0.060, 0.115, Color(0xFF87B3E6)),
      (0.81, 0.080, 0.085, Color(0xFFA5C8F2)),
      (0.89, 0.070, 0.095, Color(0xFF90BAE8)),
      (0.95, 0.065, 0.070, Color(0xFFB0CEEE)),
    ];
    final winPaint = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (final (tx, tw, th, col) in towers) {
      final r = Rect.fromLTWH(tx * w, seaTop - th * h + 4, tw * w, th * h);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          r,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = col,
      );
      if (th > 0.09) {
        canvas.drawRect(
          Rect.fromLTWH(r.center.dx - 1, r.top - 8, 2, 8),
          Paint()..color = col,
        );
      }
      for (var wy = r.top + 6; wy < seaTop - 4; wy += 7) {
        for (var wx = r.left + 4; wx < r.right - 5; wx += 7) {
          canvas.drawRect(Rect.fromLTWH(wx, wy, 3, 4), winPaint);
        }
      }
    }

    // 2. Harbor sea & waterfront quay cream strip
    final seaRect = Rect.fromLTRB(0, seaTop, w, hy + h * 0.032);
    canvas.drawRect(
      seaRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3ABCE8), Color(0xFF6FE3F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(seaRect),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, hy + h * 0.015, w, h * 0.016),
      Paint()..color = const Color(0xFFF3E2C3),
    );

    // 3. Lush green park + sunlit highlight patches
    final parkTop = hy + h * 0.028;
    final parkRect = Rect.fromLTRB(0, parkTop, w, h);
    canvas.drawRect(
      parkRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF83DF68), Color(0xFF56BD4A), Color(0xFF439E40)],
        ).createShader(parkRect),
    );
    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.15, h * 0.42), width: w * 0.42, height: h * 0.16),
      highlight,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.85, h * 0.60), width: w * 0.45, height: h * 0.18),
      highlight,
    );

    // 4. Multi-pass road curbs, border, asphalt, and crisp lane dashes
    void strokeAll(double width, Color color) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      for (final part in roadParts) {
        canvas.drawPath(part, paint);
      }
    }

    strokeAll(rw + 12, const Color(0xFFF6E7C8));
    strokeAll(rw + 4, const Color(0xFF3F4B63));
    strokeAll(rw, const Color(0xFF56637D));

    canvas.drawPath(
      roadDashes,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.65),
    );

    // 5. Central roundabout plaza, 8 flowers, aur pool water base
    final irx = math.max(18.0, rx - rw * 0.50 - 2);
    final iry = irx * 0.72;
    canvas.drawOval(
      Rect.fromCenter(center: rc, width: irx * 2 + 8, height: iry * 2 + 8),
      Paint()..color = const Color(0xFFF5E6C8),
    );
    canvas.drawOval(
      Rect.fromCenter(center: rc, width: irx * 2, height: iry * 2),
      Paint()..color = const Color(0xFF63CB54),
    );

    final petalR = math.max(1.8, irx * 0.038);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final fCenter = Offset(
        rc.dx + math.cos(a) * irx * 0.72,
        rc.dy + math.sin(a) * iry * 0.72,
      );
      canvas.drawCircle(
        fCenter,
        petalR * 2.2,
        Paint()..color = const Color(0xFF3E9C3C),
      );
      final col = i.isEven ? const Color(0xFFFF79B0) : const Color(0xFFFFD84D);
      final petalPaint = Paint()..color = col;
      for (var p = 0; p < 5; p++) {
        final pa = p * 2 * math.pi / 5 - math.pi / 2;
        canvas.drawCircle(
          fCenter.translate(math.cos(pa) * petalR, math.sin(pa) * petalR),
          petalR * 0.85,
          petalPaint,
        );
      }
      canvas.drawCircle(
        fCenter,
        petalR * 0.75,
        Paint()..color = i.isEven ? const Color(0xFFFFE57F) : Colors.white,
      );
    }

    final poolW = irx * 0.90;
    final poolH = iry * 0.90;
    canvas.drawOval(
      Rect.fromCenter(center: rc, width: poolW + 6, height: poolH + 6),
      Paint()..color = const Color(0xFFE7ECF4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: rc, width: poolW, height: poolH),
      Paint()
        ..shader = ui.Gradient.radial(rc, poolW * 0.5, const [
          Color(0xFF72EDFF),
          Color(0xFF2196E3),
        ]),
    );

    // 6. Static tree shadows + trunks (only leaf crowns sway gently per frame)
    final tShadow = Paint()..color = Colors.black.withValues(alpha: 0.16);
    final tTrunk = Paint()..color = const Color(0xFF8C5A3C);
    for (final tr in trees) {
      final c = Offset(tr.x, tr.y);
      final s = tr.s;
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(2, s * 0.22),
          width: s * 1.25,
          height: s * 0.55,
        ),
        tShadow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(0, -s * 0.12),
            width: s * 0.22,
            height: s * 0.55,
          ),
          Radius.circular(s * 0.08),
        ),
        tTrunk,
      );
    }
  }
}

class _TrafficUnit {
  const _TrafficUnit({
    required this.lane,
    required this.phase,
    required this.speed,
    required this.length,
    required this.color,
    this.scale = 1.0,
    this.reverse = false,
  });

  /// 0 = roundabout center loop, 1 = upper viaduct, 2 = lower highway
  final int lane;
  final double phase;
  final double speed;
  final int length;
  final int color;
  final double scale;
  final bool reverse;
}

/// Tamam rangeen khilona gaadiyan (zero overlaps, even spacing, smooth continuous movement)
const _fleet = <_TrafficUnit>[
  // 5 vehicles evenly spaced (1/5 ring apart) cruising smoothly clockwise around roundabout
  _TrafficUnit(lane: 0, phase: 0.00, speed: 0.055, length: 2, color: 7, scale: 0.96),
  _TrafficUnit(lane: 0, phase: 0.20, speed: 0.055, length: 3, color: 3, scale: 0.96),
  _TrafficUnit(lane: 0, phase: 0.40, speed: 0.055, length: 2, color: 5, scale: 0.96),
  _TrafficUnit(lane: 0, phase: 0.60, speed: 0.055, length: 4, color: 1, scale: 0.96),
  _TrafficUnit(lane: 0, phase: 0.80, speed: 0.055, length: 2, color: 6, scale: 0.96),
  // Upper distant coastal boulevard
  _TrafficUnit(lane: 1, phase: 0.12, speed: 0.062, length: 2, color: 3, scale: 0.64),
  _TrafficUnit(lane: 1, phase: 0.62, speed: 0.062, length: 3, color: 7, scale: 0.64),
  // Lower sweeping foreground highway
  _TrafficUnit(lane: 2, phase: 0.14, speed: 0.080, length: 4, color: 2, scale: 1.06, reverse: true),
  _TrafficUnit(lane: 2, phase: 0.50, speed: 0.080, length: 2, color: 5, scale: 1.06, reverse: true),
  _TrafficUnit(lane: 2, phase: 0.84, speed: 0.080, length: 3, color: 4, scale: 1.06, reverse: true),
];

/// Home ka poora continuous animated city manzar
class _LiveCityScenePainter extends CustomPainter {
  const _LiveCityScenePainter({
    required this.time,
    required this.cache,
    required this.dpr,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final _SceneCache cache;
  final double dpr;

  double get t => time.value;

  static const double _cos45 = 0.7071067811865476;
  static const double _sin45 = 0.7071067811865476;
  static final Paint _shadowOuter = Paint()..color = const Color(0x160F1F35);
  static final Paint _shadowInner = Paint()..color = const Color(0x2A0F1F35);
  static final Paint _tirePaint = Paint()..color = const Color(0xFF1F2329);
  static final Paint _archPaint = Paint()..color = const Color(0xFF15181D);
  static final Paint _rimPaint = Paint()..color = const Color(0xFFD9DEE4);
  static final Paint _chromePaint = Paint()..color = const Color(0xFFE3E8EE);
  static final Paint _sillPaint = Paint()..color = const Color(0xFFE8EEF4);
  static final Paint _glassDarkPaint = Paint()..color = const Color(0xFF213D58);
  static final Paint _headlampPaint = Paint()..color = const Color(0xFFFFF6C2);
  static final Paint _taillampPaint = Paint()..color = const Color(0xFFFF5A4E);
  static final Paint _grillePaint = Paint()..color = const Color(0xFF2A2F37);
  static final Paint _acPaint = Paint()..color = const Color(0xFFBFC6CF);
  static final Paint _acTopPaint = Paint()..color = const Color(0xFFD2D8E0);
  static final Paint _whitePaint = Paint()..color = Colors.white;
  static final Paint _arrowOutlinePaint = Paint()
    ..color = const Color(0xFF33465A)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  static final Paint _sheenPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.10);
  static final Paint _treeMain0 = Paint()..color = const Color(0xFF47B84C);
  static final Paint _treeMain1 = Paint()..color = const Color(0xFF39A96B);
  static final Paint _treeTop0 = Paint()..color = const Color(0xFF9DF069);
  static final Paint _treeTop1 = Paint()..color = const Color(0xFF82E689);

  @override
  void paint(Canvas canvas, Size size) {
    cache.ensure(size, dpr);
    final w = size.width;
    final h = size.height;
    final hy = cache.hy;

    _paintSky(canvas, w, h, hy);

    final bg = cache.worldBackdrop;
    if (bg != null) {
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        Rect.fromLTWH(0, 0, w, h),
        SpriteBank.paint,
      );
    }

    _paintHarborDynamic(canvas, w, hy);
    _paintFountainDynamic(canvas);
    _paintTrees(canvas);
    _paintTraffic(canvas);
  }

  void _paintSky(Canvas canvas, double w, double h, double hy) {
    final skyRect = Rect.fromLTRB(0, 0, w, hy + 16);
    canvas.drawRect(skyRect, Paint()..shader = cache.skyShader);

    canvas.save();
    canvas.clipRect(skyRect);

    // Ghoomti hui sunehri kirnein + chamakta sooraj
    final sun = cache._sunPos;
    final rad = cache._sunRad;
    final rays = Path();
    const rayCount = 14;
    final rot = t * 0.045;
    for (var i = 0; i < rayCount; i++) {
      final a0 = rot + i * 2 * math.pi / rayCount;
      final a1 = a0 + math.pi / rayCount * 0.5;
      rays
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(sun.dx + math.cos(a0) * rad, sun.dy + math.sin(a0) * rad)
        ..lineTo(sun.dx + math.cos(a1) * rad, sun.dy + math.sin(a1) * rad)
        ..close();
    }
    canvas.drawPath(rays, Paint()..shader = cache.raysShader);
    canvas.drawCircle(sun, w * 0.28, Paint()..shader = cache.sunShader);

    // 5 phoolte hue clouds lagatar daayen ki taraf
    const clouds = [
      (0.12, 0.28, 1.05, 0.011),
      (0.45, 0.18, 0.78, 0.008),
      (0.76, 0.42, 0.92, 0.013),
      (0.28, 0.62, 0.72, 0.009),
      (0.92, 0.70, 0.85, 0.010),
    ];
    for (final (cx0, cy0, scale, speed) in clouds) {
      final cx = ((cx0 + t * speed) % 1.4 - 0.2) * w;
      _drawCloud(canvas, Offset(cx, hy * cy0), w * 0.105 * scale);
    }

    // Dhaari-daar rangin hot-air balloon (open sky mein smoothly float kare)
    final bx = ((0.38 + t * 0.014) % 1.32 - 0.16) * w;
    final by = hy * 0.44 + math.sin(t * 1.1) * 4.5;
    _drawBalloon(canvas, Offset(bx, by), w * 0.038);

    // Udte hue parinde
    final birdPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x88213A66);
    for (var i = 0; i < 3; i++) {
      final bs = w * 0.015 * (1 - i * 0.15);
      final px = ((0.62 + i * 0.06 - t * 0.025) % 1.3 + 1.3) % 1.3 - 0.15;
      final bx2 = px * w;
      final by2 = hy * (0.44 + i * 0.06) + math.sin(t * 1.8 + i) * 3.0;
      final flap = math.sin(t * 8.5 + i * 2.0);
      birdPaint.strokeWidth = math.max(1.2, bs * 0.24);
      canvas.drawPath(
        Path()
          ..moveTo(bx2 - bs, by2 - bs * 0.55 * flap)
          ..quadraticBezierTo(bx2 - bs * 0.4, by2 - bs * 0.3, bx2, by2)
          ..quadraticBezierTo(
            bx2 + bs * 0.4,
            by2 - bs * 0.3,
            bx2 + bs,
            by2 - bs * 0.55 * flap,
          ),
        birdPaint,
      );
    }

    canvas.restore();
  }

  void _drawCloud(Canvas canvas, Offset c, double s) {
    final shade = Paint()..color = const Color(0xFFD6E9FC);
    final top = Paint()..color = Colors.white.withValues(alpha: 0.96);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, s * 0.20),
        width: s * 2.3,
        height: s * 0.66,
      ),
      shade,
    );
    for (final (dx, dy, r) in const [
      (-0.65, 0.05, 0.46),
      (-0.15, -0.24, 0.64),
      (0.45, -0.10, 0.52),
      (0.86, 0.10, 0.38),
    ]) {
      canvas.drawCircle(c.translate(dx * s, dy * s), r * s, top);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, s * 0.10),
        width: s * 2.2,
        height: s * 0.54,
      ),
      top,
    );
  }

  void _drawBalloon(Canvas canvas, Offset c, double r) {
    final rope = Paint()
      ..color = const Color(0xFF5D4638)
      ..strokeWidth = 1.2;
    canvas.drawLine(c.translate(-r * 0.32, r * 0.8), c.translate(-r * 0.22, r * 1.4), rope);
    canvas.drawLine(c.translate(r * 0.32, r * 0.8), c.translate(r * 0.22, r * 1.4), rope);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, r * 1.55), width: r * 0.52, height: r * 0.36),
        Radius.circular(r * 0.08),
      ),
      Paint()..color = const Color(0xFFB37444),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 1.75, height: r * 2.05),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6B7A), Color(0xFFFFCF4A), Color(0xFF39D0B6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromCenter(center: c, width: r * 1.75, height: r * 2.05)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 0.72, height: r * 2.02),
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );
  }

  void _paintHarborDynamic(Canvas canvas, double w, double hy) {
    final seaTop = cache.seaTop;
    final glint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final gx = w * (0.05 + i * 0.068) + math.sin(t * 1.6 + i) * 6;
      final gy = seaTop + (hy - seaTop) * (0.35 + (i % 3) * 0.28);
      final alpha = 0.35 + 0.45 * ((math.sin(t * 2.8 + i * 1.4) + 1) / 2);
      glint
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(gx - 6, gy), Offset(gx + 6, gy), glint);
    }

    // Sailboat smoothly crosses the open left harbor with gentle end fade
    final p = (0.10 + t * 0.015) % 0.60;
    final boatAlpha = (p / 0.06).clamp(0.0, 1.0) * ((0.60 - p) / 0.06).clamp(0.0, 1.0);
    if (boatAlpha > 0.01) {
      final boatX = (p - 0.04) * w;
      final boatY = seaTop + (hy - seaTop) * 0.78 + math.sin(t * 2.4) * 1.2;
      final s = w * 0.022;
      canvas.drawPath(
        Path()
          ..moveTo(boatX - s, boatY)
          ..lineTo(boatX + s, boatY)
          ..lineTo(boatX + s * 0.7, boatY + s * 0.45)
          ..lineTo(boatX - s * 0.7, boatY + s * 0.45)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: boatAlpha),
      );
      canvas.drawPath(
        Path()
          ..moveTo(boatX - s * 0.05, boatY - s * 1.4)
          ..lineTo(boatX + s * 0.85, boatY - s * 0.08)
          ..lineTo(boatX - s * 0.05, boatY - s * 0.08)
          ..close(),
        Paint()..color = const Color(0xFFFFF4D2).withValues(alpha: boatAlpha),
      );
    }
  }

  void _paintFountainDynamic(Canvas canvas) {
    final rc = cache.rc;
    final irx = math.max(18.0, cache.rx - cache.rw * 0.50 - 2);
    final iry = irx * 0.72;
    final poolW = irx * 0.90;
    final poolH = iry * 0.90;

    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var r = 0; r < 3; r++) {
      final p = (t * 0.75 + r / 3) % 1.0;
      ripple.color = Colors.white.withValues(alpha: 0.65 * (1 - p));
      canvas.drawOval(
        Rect.fromCenter(
          center: rc,
          width: poolW * (0.2 + 0.72 * p),
          height: poolH * (0.2 + 0.72 * p),
        ),
        ripple,
      );
    }

    canvas.drawCircle(
      rc.translate(0, -1),
      poolW * 0.14,
      Paint()..color = const Color(0xFFF6F8FC),
    );
    final dropPaint = Paint();
    for (var j = 0; j < 6; j++) {
      final p = (t * 1.6 + j / 6) % 1.0;
      final angle = j * math.pi / 3;
      final jetR = poolW * 0.24 * p;
      final lift = math.sin(p * math.pi) * poolH * 0.28;
      final dropPos = Offset(
        rc.dx + math.cos(angle) * jetR,
        rc.dy - 2 + math.sin(angle) * jetR * 0.65 - lift,
      );
      dropPaint.color = Colors.white.withValues(alpha: 0.85 * (1 - p));
      canvas.drawCircle(dropPos, 2.2 * (1 - p * 0.4), dropPaint);
    }
  }

  void _paintTrees(Canvas canvas) {
    for (var i = 0; i < cache.trees.length; i++) {
      final tr = cache.trees[i];
      final s = tr.s;
      final sway = math.sin(t * 1.7 + i * 1.3) * s * 0.06;
      final crown = Offset(tr.x + sway, tr.y - s * 0.55);
      canvas.drawCircle(crown, s * 0.58, tr.kind == 0 ? _treeMain0 : _treeMain1);
      canvas.drawCircle(
        crown.translate(-s * 0.14, -s * 0.14),
        s * 0.40,
        tr.kind == 0 ? _treeTop0 : _treeTop1,
      );
    }
  }

  void _paintTraffic(Canvas canvas) {
    final unit = cache.rw * 0.48;
    final drawList =
        <({Offset pos, double angle, double scale, int length, int color})>[];

    for (final v in _fleet) {
      final phase = (v.phase + t * v.speed) % 1.0;
      final u = v.reverse ? (1.0 - phase) : phase;
      late final Offset pos;
      late final Offset dir;

      if (v.lane == 0) {
        // Exact C-infinity analytic oval tangent (no PathMetric discretization)
        final theta = u * 2.0 * math.pi;
        final cosT = math.cos(theta);
        final sinT = math.sin(theta);
        pos = Offset(
          cache.rc.dx + cosT * cache.rx,
          cache.rc.dy + sinT * cache.ry,
        );
        final rawDir = Offset(-sinT * cache.rx, cosT * cache.ry);
        dir = v.reverse ? -rawDir : rawDir;
      } else {
        // Exact C-infinity quadratic Bezier derivative
        final p0 = v.lane == 1 ? cache.uP0 : cache.lP0;
        final p1 = v.lane == 1 ? cache.uP1 : cache.lP1;
        final p2 = v.lane == 1 ? cache.uP2 : cache.lP2;
        final inv = 1.0 - u;
        pos = Offset(
          inv * inv * p0.dx + 2.0 * inv * u * p1.dx + u * u * p2.dx,
          inv * inv * p0.dy + 2.0 * inv * u * p1.dy + u * u * p2.dy,
        );
        final rawTan = Offset(
          2.0 * inv * (p1.dx - p0.dx) + 2.0 * u * (p2.dx - p1.dx),
          2.0 * inv * (p1.dy - p0.dy) + 2.0 * u * (p2.dy - p1.dy),
        );
        dir = v.reverse ? -rawTan : rawTan;
      }

      // True 3D ground yaw matching 45-deg camera projection (_cos45): zero hiccups!
      drawList.add((
        pos: pos,
        angle: math.atan2(dir.dx, -dir.dy / _cos45),
        scale: v.scale,
        length: v.length,
        color: v.color,
      ));
    }

    // 2.5D depth sort: upar wali pehle, neeche wali baad mein
    drawList.sort((a, b) => a.pos.dy.compareTo(b.pos.dy));

    for (final v in drawList) {
      _paintSculpted3DVehicle(
        canvas,
        pos: v.pos,
        angle: v.angle,
        u: unit * v.scale,
        length: v.length,
        colorIndex: v.color,
      );
    }
  }

  /// Renders true continuous-angle 3D vehicle sculpted to the exact game model
  /// geometry (length 2 classic sedan with bonnet & stepped cab, length 3 van,
  /// length 4 twin-axle coach with stripe & AC) at 45-deg camera projection.
  void _paintSculpted3DVehicle(
    Canvas canvas, {
    required Offset pos,
    required double angle,
    required double u,
    required int length,
    required int colorIndex,
  }) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final w = 0.78 * u;
    final l = (length - 0.12) * u;
    final base = GamePalette.bus(colorIndex);
    final roofCol = GamePalette.lighter(base, 0.06);
    final wallLight = GamePalette.lighter(base, 0.14);
    final wallDark = GamePalette.darker(base, 0.36);

    Offset proj(double lx, double ly, double z) {
      final wx = lx * cosA + ly * sinA;
      final wy = -lx * sinA + ly * cosA;
      return Offset(wx, -wy * _cos45 - z * _sin45);
    }

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // 1. Soft two-tier ground shadow
    canvas.save();
    canvas.translate(u * 0.04, u * 0.06);
    canvas.scale(1.0, _cos45);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 1.18, height: l * 1.08),
        Radius.circular(u * 0.22),
      ),
      _shadowOuter,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.98, height: l * 0.98),
        Radius.circular(u * 0.16),
      ),
      _shadowInner,
    );
    canvas.restore();

    // 2. Wheels geometry (front axle + rear axle, plus tandem axle for coach)
    final wheelYs = <double>[
      l * 0.5 - 0.30 * u,
      -l * 0.5 + 0.30 * u,
      if (length >= 4) -l * 0.5 + 0.72 * u,
    ];
    for (final side in const [-1.0, 1.0]) {
      if (side * sinA >= -0.04) continue;
      final wx = side * (w * 0.5 - 0.02 * u);
      for (final wy in wheelYs) {
        _drawWheel3D(canvas, proj, wx, wy, 0.16 * u, 0.155 * u, cosA, sinA, side);
      }
    }

    // 3. Lower dark skirt & main rounded body tier (bonnet + trunk)
    _drawRoundedBox3D(
      canvas,
      proj: proj,
      cx: 0,
      cy: 0,
      z0: 0.09 * u,
      z1: 0.24 * u,
      width: w,
      length: l,
      radius: 0.10 * u,
      angle: angle,
      cosA: cosA,
      sinA: sinA,
      topColor: GamePalette.darker(base, 0.45),
      wallLight: GamePalette.darker(base, 0.38),
      wallDark: const Color(0xFF262B34),
    );
    _drawRoundedBox3D(
      canvas,
      proj: proj,
      cx: 0,
      cy: 0,
      z0: 0.22 * u,
      z1: 0.53 * u,
      width: w * 0.98,
      length: l * 0.99,
      radius: 0.14 * u,
      angle: angle,
      cosA: cosA,
      sinA: sinA,
      topColor: base,
      wallLight: wallLight,
      wallDark: wallDark,
      onSideFace: length >= 4
          ? (sideSign) {
              // White coach horizontal belt stripe along camera-facing long body wall
              final bx = sideSign * (w * 0.495);
              final y0 = -l * 0.44;
              final y1 = l * 0.44;
              final p0 = proj(bx, y0, 0.44 * u);
              final p1 = proj(bx, y1, 0.44 * u);
              final q0 = proj(bx, y0, 0.39 * u);
              final q1 = proj(bx, y1, 0.39 * u);
              canvas.drawPath(
                Path()
                  ..moveTo(p0.dx, p0.dy)
                  ..lineTo(p1.dx, p1.dy)
                  ..lineTo(q1.dx, q1.dy)
                  ..lineTo(q0.dx, q0.dy)
                  ..close(),
                _whitePaint,
              );
            }
          : null,
    );

    // 4. Chrome bumpers, headlights, front grille, and rear taillights
    if (cosA < 0.12) {
      // Front end visible
      _drawEndTrim(
        canvas,
        proj: proj,
        y: l * 0.502,
        w: w,
        u: u,
        isFront: true,
      );
    }
    if (cosA > -0.12) {
      // Rear end visible
      _drawEndTrim(
        canvas,
        proj: proj,
        y: -l * 0.502,
        w: w,
        u: u,
        isFront: false,
      );
    }

    // 5. Near-side wheels on top of lower body arches (4 or 6 sculpted 3D tires)
    for (final side in const [-1.0, 1.0]) {
      if (side * sinA < -0.04) continue;
      final wx = side * (w * 0.5 - 0.01 * u);
      for (final wy in wheelYs) {
        _drawWheel3D(canvas, proj, wx, wy, 0.16 * u, 0.155 * u, cosA, sinA, side);
      }
    }

    // 6. Cabin dimensions matching tool/blender/render_reference_sprites.py build_bus
    late final double cabL, cabY, bandW, roofW, roofL, roofY, topZ;
    late final int pillars;
    if (length <= 2) {
      cabL = l * 0.50;
      cabY = -l * 0.07;
      pillars = 2;
      bandW = w * 0.84;
      roofW = w * 0.74;
      roofL = cabL * 0.74;
      roofY = cabY - cabL * 0.11;
      topZ = 0.85 * u;
    } else if (length == 3) {
      cabL = l - 0.34 * u;
      cabY = -0.08 * u;
      pillars = 3;
      bandW = w * 0.92;
      roofW = w * 0.82;
      roofL = cabL - 0.01 * u;
      roofY = cabY;
      topZ = 0.80 * u;
    } else {
      cabL = l - 0.28 * u;
      cabY = -0.05 * u;
      pillars = 5;
      bandW = w * 0.92;
      roofW = w * 0.84;
      roofL = cabL - 0.01 * u;
      roofY = cabY;
      topZ = 0.80 * u;
    }
    final bandZ0 = 0.53 * u;
    final bandZ1 = 0.77 * u;

    // Far side mirror behind cabin
    final my = cabY + cabL * 0.5 - 0.06 * u;
    for (final side in const [-1.0, 1.0]) {
      if (side * sinA < 0) {
        final mp = proj(side * (bandW * 0.5 + 0.05 * u), my, 0.66 * u);
        canvas.drawCircle(mp, 0.036 * u, Paint()..color = wallDark);
        canvas.drawCircle(mp.translate(0, -0.008 * u), 0.029 * u, Paint()..color = base);
      }
    }

    // Bright chrome window sill lip under cabin glass
    _drawRoundedBox3D(
      canvas,
      proj: proj,
      cx: 0,
      cy: cabY,
      z0: 0.515 * u,
      z1: 0.545 * u,
      width: bandW * 1.06,
      length: cabL * 1.02,
      radius: 0.06 * u,
      angle: angle,
      cosA: cosA,
      sinA: sinA,
      topColor: _sillPaint.color,
      wallLight: _chromePaint.color,
      wallDark: const Color(0xFFB8C4D0),
    );

    // Tinted blue glass cabin band + painted pillars between windows
    _drawRoundedBox3D(
      canvas,
      proj: proj,
      cx: 0,
      cy: cabY,
      z0: bandZ0,
      z1: bandZ1,
      width: bandW,
      length: cabL,
      radius: 0.07 * u,
      angle: angle,
      cosA: cosA,
      sinA: sinA,
      topColor: _glassDarkPaint.color,
      wallLight: const Color(0xFF335C82),
      wallDark: const Color(0xFF1A3248),
      onSideFace: (sideSign) {
        final px = sideSign * (bandW * 0.503);
        final pw = 0.055 * u;
        final pillarPaint = Paint()..color = sideSign * sinA > 0 ? wallLight : base;
        for (var k = 1; k < pillars; k++) {
          final py = cabY - cabL * 0.5 + k * cabL / pillars;
          final a0 = proj(px, py - pw * 0.5, bandZ1);
          final b0 = proj(px, py + pw * 0.5, bandZ1);
          final a1 = proj(px, py - pw * 0.5, bandZ0);
          final b1 = proj(px, py + pw * 0.5, bandZ0);
          canvas.drawPath(
            Path()
              ..moveTo(a0.dx, a0.dy)
              ..lineTo(b0.dx, b0.dy)
              ..lineTo(b1.dx, b1.dy)
              ..lineTo(a1.dx, a1.dy)
              ..close(),
            pillarPaint,
          );
        }
      },
    );

    // Near side mirror in front of cabin
    for (final side in const [-1.0, 1.0]) {
      if (side * sinA >= 0) {
        final mp = proj(side * (bandW * 0.5 + 0.05 * u), my, 0.66 * u);
        canvas.drawCircle(mp, 0.036 * u, Paint()..color = wallDark);
        canvas.drawCircle(mp.translate(0, -0.008 * u), 0.029 * u, Paint()..color = base);
      }
    }

    // 7. Glossy colored roof cap
    _drawRoundedBox3D(
      canvas,
      proj: proj,
      cx: 0,
      cy: roofY,
      z0: bandZ1 - 0.015 * u,
      z1: topZ,
      width: roofW,
      length: roofL,
      radius: 0.06 * u,
      angle: angle,
      cosA: cosA,
      sinA: sinA,
      topColor: roofCol,
      wallLight: roofCol,
      wallDark: wallDark,
    );

    // Grey AC box on rear of coach roof
    if (length >= 4) {
      _drawRoundedBox3D(
        canvas,
        proj: proj,
        cx: 0,
        cy: -l * 0.30,
        z0: topZ,
        z1: topZ + 0.065 * u,
        width: w * 0.50,
        length: 0.48 * u,
        radius: 0.03 * u,
        angle: angle,
        cosA: cosA,
        sinA: sinA,
        topColor: _acTopPaint.color,
        wallLight: _acPaint.color,
        wallDark: const Color(0xFF9098A4),
      );
    }

    // Crisp outlined white roof arrow aligned with continuous ground angle
    final arrowY = length >= 4 ? l * 0.12 : roofY + roofL * 0.02;
    final arrowLen = math.min(0.80 * u, roofL * (length <= 2 ? 0.68 : 0.50));
    final arrowPos = proj(0, arrowY, topZ + 0.012 * u);
    canvas.save();
    canvas.translate(arrowPos.dx, arrowPos.dy);
    canvas.scale(1.0, _cos45);
    canvas.rotate(angle);
    final aw = 0.42 * u;
    final arrowPath = Path()
      ..moveTo(0, -arrowLen * 0.5)
      ..lineTo(aw * 0.5, -arrowLen * 0.02)
      ..lineTo(aw * 0.21, -arrowLen * 0.02)
      ..lineTo(aw * 0.21, arrowLen * 0.5)
      ..lineTo(-aw * 0.21, arrowLen * 0.5)
      ..lineTo(-aw * 0.21, -arrowLen * 0.02)
      ..lineTo(-aw * 0.5, -arrowLen * 0.02)
      ..close();
    canvas.drawPath(
      arrowPath,
      _arrowOutlinePaint..strokeWidth = math.max(1.2, u * 0.065),
    );
    canvas.drawPath(arrowPath, _whitePaint);
    canvas.restore();

    canvas.restore();
  }

  void _drawWheel3D(
    Canvas canvas,
    Offset Function(double lx, double ly, double z) proj,
    double wx,
    double wy,
    double wz,
    double r,
    double cosA,
    double sinA,
    double side,
  ) {
    final rimR = r * 0.60;
    final archR = r * 1.14;
    final arch = Path();
    final tread = Path();
    final tire = Path();
    final rim = Path();
    for (var k = 0; k < 10; k++) {
      final a = k * 2 * math.pi / 10;
      final ca = math.cos(a);
      final sa = math.sin(a);
      final ap = proj(wx - side * 0.04 * r, wy + ca * archR, wz + sa * archR * 0.92);
      final dp = proj(wx - side * 0.22 * r, wy + ca * r, wz + sa * r);
      final tp = proj(wx + side * 0.10 * r, wy + ca * r, wz + sa * r);
      final rp = proj(wx + side * 0.12 * r, wy + ca * rimR, wz + sa * rimR);
      if (k == 0) {
        arch.moveTo(ap.dx, ap.dy);
        tread.moveTo(dp.dx, dp.dy);
        tire.moveTo(tp.dx, tp.dy);
        rim.moveTo(rp.dx, rp.dy);
      } else {
        arch.lineTo(ap.dx, ap.dy);
        tread.lineTo(dp.dx, dp.dy);
        tire.lineTo(tp.dx, tp.dy);
        rim.lineTo(rp.dx, rp.dy);
      }
    }
    arch.close();
    tread.close();
    tire.close();
    rim.close();
    final center = proj(wx + side * 0.13 * r, wy, wz);
    canvas.drawPath(arch, _archPaint);
    canvas.drawPath(tread, _tirePaint);
    canvas.drawPath(tire, _tirePaint);
    canvas.drawPath(rim, _rimPaint);
    canvas.drawCircle(center, r * 0.17, _tirePaint);
  }

  void _drawEndTrim(
    Canvas canvas, {
    required Offset Function(double lx, double ly, double z) proj,
    required double y,
    required double w,
    required double u,
    required bool isFront,
  }) {
    // Chrome bumper bar
    final bL = proj(-w * 0.42, y, 0.25 * u);
    final bR = proj(w * 0.42, y, 0.25 * u);
    canvas.drawLine(
      bL,
      bR,
      Paint()
        ..color = _chromePaint.color
        ..strokeWidth = math.max(1.5, 0.065 * u)
        ..strokeCap = StrokeCap.round,
    );
    // Headlights or taillights
    final lp = isFront ? _headlampPaint : _taillampPaint;
    final lxL = proj(-w * 0.30, y, 0.40 * u);
    final lxR = proj(w * 0.30, y, 0.40 * u);
    final lr = math.max(1.2, 0.052 * u);
    canvas.drawCircle(lxL, lr, lp);
    canvas.drawCircle(lxR, lr, lp);
    if (isFront) {
      final gL = proj(-w * 0.15, y, 0.39 * u);
      final gR = proj(w * 0.15, y, 0.39 * u);
      canvas.drawLine(
        gL,
        gR,
        Paint()
          ..color = _grillePaint.color
          ..strokeWidth = math.max(1.2, 0.055 * u)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawRoundedBox3D(
    Canvas canvas, {
    required Offset Function(double lx, double ly, double z) proj,
    required double cx,
    required double cy,
    required double z0,
    required double z1,
    required double width,
    required double length,
    required double radius,
    required double angle,
    required double cosA,
    required double sinA,
    required Color topColor,
    required Color wallLight,
    required Color wallDark,
    void Function(double sideSign)? onSideFace,
  }) {
    final hx = width * 0.5;
    final hy = length * 0.5;
    final r = math.min(radius, math.min(hx, hy) * 0.88);
    final dz = (z1 - z0) * _sin45;

    // 16 smooth rounded perimeter vertices ordered clockwise on screen at angle = 0
    final pts = <Offset>[];
    final local = <Offset>[];
    void addCorner(double ccx, double ccy, double aStart) {
      for (var s = 0; s < 4; s++) {
        final a = aStart + s * (math.pi / 6);
        final lx = cx + ccx + math.sin(a) * r;
        final ly = cy + ccy + math.cos(a) * r;
        local.add(Offset(lx - cx, ly - cy));
        pts.add(proj(lx, ly, z1));
      }
    }

    addCorner(hx - r, hy - r, 0.0); // 0..3 front-right
    addCorner(hx - r, -hy + r, math.pi * 0.5); // 4..7 rear-right
    addCorner(-hx + r, -hy + r, math.pi); // 8..11 rear-left
    addCorner(-hx + r, hy - r, math.pi * 1.5); // 12..15 front-left

    const n = 16;
    var start = -1;
    for (var i = 0; i < n; i++) {
      final prev = (i - 1 + n) % n;
      final next = (i + 1) % n;
      if (pts[next].dx < pts[i].dx && pts[i].dx >= pts[prev].dx) {
        start = i;
        break;
      }
    }

    if (start >= 0) {
      // Backing skirt prevents hairline AA gaps between smoothly shaded facets
      final arc = <int>[start];
      var cur = start;
      for (var step = 0; step < n; step++) {
        final next = (cur + 1) % n;
        if (pts[next].dx >= pts[cur].dx) break;
        arc.add(next);
        cur = next;
      }
      if (arc.length >= 2) {
        final skirt = Path()..moveTo(pts[arc.first].dx, pts[arc.first].dy);
        for (var k = 1; k < arc.length; k++) {
          skirt.lineTo(pts[arc[k]].dx, pts[arc[k]].dy);
        }
        for (var k = arc.length - 1; k >= 0; k--) {
          skirt.lineTo(pts[arc[k]].dx, pts[arc[k]].dy + dz);
        }
        skirt.close();
        final midWall = Color.lerp(wallDark, wallLight, 0.45)!;
        canvas.drawPath(skirt, Paint()..color = midWall);

        for (var k = 0; k < arc.length - 1; k++) {
          final i0 = arc[k];
          final i1 = arc[k + 1];
          final p0 = pts[i0];
          final p1 = pts[i1];
          // Outward 2D normal dotted with studio key light (-0.65, 0.65)
          final mx = (local[i0].dx + local[i1].dx) * 0.5;
          final my = (local[i0].dy + local[i1].dy) * 0.5;
          final inv = 1.0 / math.max(0.001, math.sqrt(mx * mx + my * my));
          final nx = mx * inv;
          final ny = my * inv;
          final wx = nx * cosA + ny * sinA;
          final wy = -nx * sinA + ny * cosA;
          final shade = ((-wx * 0.60 + wy * 0.65) + 1.0) * 0.5;
          canvas.drawPath(
            Path()
              ..moveTo(p0.dx, p0.dy)
              ..lineTo(p1.dx, p1.dy)
              ..lineTo(p1.dx, p1.dy + dz)
              ..lineTo(p0.dx, p0.dy + dz)
              ..close(),
            Paint()..color = Color.lerp(wallDark, wallLight, shade.clamp(0.0, 1.0))!,
          );
        }
      }
    }

    if (onSideFace != null) {
      if (pts[4].dx < pts[3].dx) onSideFace(1.0); // right long side visible
      if (pts[12].dx < pts[11].dx) onSideFace(-1.0); // left long side visible
    }

    // Crisp horizontal top surface at z = z1
    final cTop = proj(cx, cy, z1);
    canvas.save();
    canvas.translate(cTop.dx, cTop.dy);
    canvas.scale(1.0, _cos45);
    canvas.rotate(angle);
    final topRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: length),
      Radius.circular(r),
    );
    canvas.drawRRect(topRect, Paint()..color = topColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -length * 0.04),
          width: width * 0.80,
          height: length * 0.82,
        ),
        Radius.circular(r * 0.65),
      ),
      _sheenPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiveCityScenePainter old) =>
      old.time != time || old.cache != cache || (old.dpr - dpr).abs() >= 0.01;
}
