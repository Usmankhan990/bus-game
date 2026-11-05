import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../game/bus_jam_game.dart';
import '../game/logic/level_generator.dart';
import '../game/render/palette.dart';
import '../models/booster_type.dart';
import '../models/city.dart';
import '../services/ad_service.dart';
import '../services/progress_service.dart';
import '../ui/candy_button.dart';
import '../ui/theme.dart';
import '../widgets/banner_ad_area.dart';
import '../widgets/booster_bar.dart';
import '../widgets/booster_shop_dialog.dart';
import '../widgets/level_badge.dart';
import '../widgets/level_banner.dart';
import '../widgets/overlays.dart';
import '../widgets/settings_panel.dart';
import 'journey_screen.dart';

enum _Overlay { none, pause, win, fail }

/// Khelne wali screen (upar se neeche): top bar, game (hujoom, parking strip,
/// parking lot), boosters, aur sab se neeche banner ad ki alag jagah.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ProgressService _progress = ProgressService.instance;

  late int _level;
  late BusJamGame _game;
  int _gameKey = 0;
  _Overlay _overlay = _Overlay.none;
  int _boostersUsed = 0;
  int _reward = 0;
  bool _vip = false;
  bool _leaving = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _start(_progress.level);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Naya level tayyar karo
  void _start(int level) {
    _level = level;
    _game = BusJamGame(
      level: LevelGenerator.generate(level),
      callbacks: GameCallbacks(
        onWin: _onWin,
        onFail: _onFail,
        onToast: _showToast,
        onVipUsed: _onVipUsed,
        onLockedSlotTap: _onLockedSlotTap,
      ),
    );
    _gameKey++;
    _overlay = _Overlay.none;
    _boostersUsed = 0;
    _vip = false;
    _leaving = false;
  }

  void _restart() => setState(() => _start(_level));

  void _onWin() {
    if (!mounted) return;
    _reward = AppConfig.winReward(_level);
    // Fauran save: app band bhi ho jaye to agla level khula rahe
    _progress.completeLevel(_level, _reward);
    _progress.addStars(_stars);
    setState(() {
      _overlay = _Overlay.win;
      _vip = false;
    });
  }

  void _onFail() {
    if (!mounted) return;
    setState(() {
      _overlay = _Overlay.fail;
      _vip = false;
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ---------------- Win / Fail / Pause ----------------

  Future<bool> _doubleCoins() async {
    final earned = await AdService.instance.showRewarded();
    if (earned) _progress.addCoins(_reward);
    return earned;
  }

  Future<void> _nextLevel() async {
    if (_leaving) return;
    _leaving = true;
    // Interstitial sirf yahan, user ke "Next Level" dabane ke baad
    await AdService.instance.maybeShowInterstitial(completedLevel: _level);
    if (!mounted) return;
    // 20 level poore: naye shehar mein khush-amdeed
    if (City.startsCity(_level + 1)) {
      await showWelcomeCity(context, City.of(_level + 1));
      if (!mounted) return;
    }
    setState(() => _start(_level + 1));
  }

  Future<bool> _continueWithAd() async {
    final earned = await AdService.instance.showRewarded();
    if (earned && mounted) {
      _game.continueAfterFail();
      setState(() => _overlay = _Overlay.none);
    }
    return earned;
  }

  void _pause() {
    if (_overlay != _Overlay.none) return;
    _game.pauseEngine();
    setState(() => _overlay = _Overlay.pause);
  }

  void _resume() {
    _game.resumeEngine();
    setState(() => _overlay = _Overlay.none);
  }

  void _home() {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pop();
  }

  // ---------------- Boosters ----------------

  Future<void> _onBooster(BoosterType t) async {
    if (_overlay != _Overlay.none || _game.isEnded) return;

    // VIP dobara dabane se cancel
    if (t == BoosterType.vip && _vip) {
      _game.vipMode = false;
      setState(() => _vip = false);
      return;
    }

    if (_progress.boosterCount(t) <= 0) {
      _game.pauseEngine();
      final got = await showBoosterShop(context, t);
      if (!mounted) return;
      _game.resumeEngine();
      if (!got) return;
    }
    _applyBooster(t);
  }

  void _applyBooster(BoosterType t) {
    switch (t) {
      case BoosterType.vip:
        if (!_game.hasFreeSlot) {
          _showToast('Wait for a free slot first');
          return;
        }
        _game.vipMode = true;
        setState(() => _vip = true);
        _showToast('Tap any vehicle to send it to VIP');
      case BoosterType.shuffle:
        if (_game.shuffleBuses()) {
          _progress.useBooster(t);
          setState(() => _boostersUsed++);
        } else {
          _showToast('Nothing to shuffle right now');
        }
      case BoosterType.sort:
        if (_game.sortPassengers()) {
          _progress.useBooster(t);
          setState(() => _boostersUsed++);
        } else {
          _showToast('Park a vehicle first, then sort');
        }
    }
  }

  void _onVipUsed() {
    _progress.useBooster(BoosterType.vip);
    if (!mounted) return;
    setState(() {
      _vip = false;
      _boostersUsed++;
    });
  }

  /// Band ("+") slot par tap: ad ya coins se kholo
  Future<void> _onLockedSlotTap() async {
    if (_overlay != _Overlay.none || _game.isEnded) return;
    _game.pauseEngine();
    final ok = await showUnlockSlotDialog(context);
    if (!mounted) return;
    _game.resumeEngine();
    if (ok) _game.unlockSlot();
  }

  int get _stars => _boostersUsed == 0 ? 3 : (_boostersUsed == 1 ? 2 : 1);

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final difficulty = _game.level.difficulty;
    // Game ko batao ke upar kitni jagah bar ke neeche hai
    _game.topInset = MediaQuery.paddingOf(context).top + _barHeight;
    return PopScope(
      canPop: false,
      // Phone ka back button: settings kholo / band karo
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_overlay == _Overlay.pause) {
          _resume();
        } else {
          _pause();
        }
      },
      child: Scaffold(
        backgroundColor: GamePalette.floor,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            // Game screen ke bilkul upar se shuru; bar us ke upar tairta hai
                            Positioned.fill(
                              child: GameWidget(
                                key: ValueKey(_gameKey),
                                game: _game,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _topBar(),
                            ),
                          ],
                        ),
                      ),
                      // Boosters ki tray: upar gol kinare, halka saaya
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF7FAFE), Color(0xFFDCE7F3)],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppRadius.lg),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x261B3358),
                              blurRadius: 10,
                              offset: Offset(0, -3),
                            ),
                          ],
                        ),
                        child: BoosterBar(
                          onTap: _onBooster,
                          active: _vip ? BoosterType.vip : null,
                        ),
                      ),
                    ],
                  ),
                  if (_toast != null) _toastView(_toast!),
                  // Mushkil level shuru par laal patti
                  if (difficulty > 0)
                    Positioned.fill(
                      child: LevelBanner(
                        key: ValueKey('banner$_gameKey'),
                        text: difficulty == 2 ? 'SUPER HARD' : 'HARD',
                        color: difficulty == 2
                            ? const Color(0xFF8E1B1B)
                            : const Color(0xFFE53935),
                      ),
                    ),
                  if (_overlay != _Overlay.none)
                    Positioned.fill(child: _overlayView()),
                ],
              ),
            ),
            // Banner ki apni alag jagah, game ke neeche
            const SafeArea(top: false, child: BannerAdArea()),
          ],
        ),
      ),
    );
  }

  /// Upar ke bar ki oonchai (status bar ke ilawa)
  static const double _barHeight = 54;

  /// Chhote buttons aur level ka naam, game ke manzar ke upar (koi alag patti nahi)
  Widget _topBar() {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: _barHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Row(
            children: [
              CandyIconButton(
                size: 42,
                icon: Icons.refresh_rounded,
                onPressed: _overlay == _Overlay.none ? _restart : null,
              ),
              Expanded(
                child: Center(child: LevelBadge(level: _level)),
              ),
              // Sirf debug build: gaadiyon ke hitbox aur raste dikhao
              CandyIconButton(
                size: 42,
                icon: Icons.pause_rounded,
                onPressed: _pause,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toastView(String text) {
    return Positioned(
      left: 24,
      right: 24,
      top: MediaQuery.paddingOf(context).top + 90,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.title(17, outlined: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayView() {
    return switch (_overlay) {
      _Overlay.pause => SettingsPanel(
        inline: true,
        onClose: _resume,
        onRestart: _restart,
        onHome: _home,
      ),
      _Overlay.win => WinOverlay(
        key: ValueKey('win$_level'),
        level: _level,
        reward: _reward,
        stars: _stars,
        onDouble: _doubleCoins,
        onNext: _nextLevel,
      ),
      _Overlay.fail => FailOverlay(
        onContinue: _continueWithAd,
        onRetry: _restart,
        onHome: _home,
      ),
      _Overlay.none => const SizedBox.shrink(),
    };
  }
}
