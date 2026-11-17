import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../game/bus_jam_game.dart';
import '../game/game_layout.dart';
import '../game/logic/level_generator.dart';
import '../game/render/palette.dart';
import '../models/booster_type.dart';
import '../models/bus_data.dart';
import '../models/city.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
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
  static final math.Random _shapeRng = math.Random();
  static QueueShape? _lastShape;

  static QueueShape _pickShape(int level) {
    final candidates = [
      for (final s in QueueShape.values)
        if (s != _lastShape) s,
    ];
    final next = _lastShape == null && level == 1
        ? QueueShape.circle
        : candidates[_shapeRng.nextInt(candidates.length)];
    _lastShape = next;
    return next;
  }

  late int _level;
  late BusJamGame _game;
  int _gameKey = 0;
  int _restartVariant = 0;
  _Overlay _overlay = _Overlay.none;
  int _boostersUsed = 0;
  int _reward = 0;
  int _earnedStars = 3;
  bool _vip = false;
  bool _bannerDone = false;
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
    AudioService.instance.stop(Sfx.win);
    AudioService.instance.stop(Sfx.coinsCollect);
    AudioService.instance.stop(Sfx.levelStart);
    AudioService.instance.stop(Sfx.carLand);
    AudioService.instance.resumeMusic();
    _toastTimer?.cancel();
    super.dispose();
  }

  static String _colorSignature(List<BusData> buses) =>
      [for (final b in buses) '${b.id}:${b.color}'].join(',');

  /// Naya level tayyar karo ([restart] par wahi arrangement, sirf rang shuffle)
  void _start(int level, {bool restart = false}) {
    AudioService.instance.stop(Sfx.win);
    AudioService.instance.stop(Sfx.coinsCollect);
    AudioService.instance.stop(Sfx.levelStart);
    AudioService.instance.stop(Sfx.carLand);
    AudioService.instance.resumeMusic();
    _level = level;
    var data = LevelGenerator.generate(
      level,
      variant: restart ? ++_restartVariant : (_restartVariant = 0),
    );
    if (restart) {
      final prev = _colorSignature(_game.level.buses);
      for (var t = 0; t < 5 && _colorSignature(data.buses) == prev; t++) {
        data = LevelGenerator.generate(level, variant: ++_restartVariant);
      }
    }
    _game = BusJamGame(
      level: data,
      queueShape: _pickShape(level),
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
    _earnedStars = 3;
    _vip = false;
    _bannerDone = false;
    _leaving = false;
  }

  void _restart() => setState(() => _start(_level, restart: true));

  void _onWin() {
    if (!mounted) return;
    _reward = AppConfig.winReward(_level);
    _earnedStars = _stars;
    // Fauran save: app band bhi ho jaye to agla level khula rahe
    _progress.completeLevel(_level, _reward);
    _progress.addStars(_earnedStars);
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
    AudioService.instance.stop(Sfx.win);
    AudioService.instance.stop(Sfx.coinsCollect);
    AudioService.instance.resumeMusic();
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

  int get _stars => AppConfig.winStars(
    boostersUsed: _boostersUsed,
    slotsUnlocked: _game.slotsUnlocked,
    revivesUsed: _game.revivesUsed,
    blockedHits: _game.blockedHits,
  );

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
        body: Stack(
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
                // Banner ad bottom bar ke bilkul upar
                const BannerAdArea(),
                // Bottom bar (VIP, Sort, Shuffle) sab se neeche
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF6FAFF), Color(0xFFD7E4F6)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x28152C52),
                          blurRadius: 12,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: BoosterBar(
                      onTap: _onBooster,
                      active: _vip ? BoosterType.vip : null,
                    ),
                  ),
                ),
              ],
            ),
            if (_toast != null) _toastView(_toast!),
            // Mushkil level shuru par laal patti (ek baar dikhne ke baad band)
            if (difficulty > 0 && !_bannerDone)
              Positioned.fill(
                key: ValueKey('banner$_gameKey'),
                child: LevelBanner(
                  text: difficulty == 2 ? 'SUPER HARD' : 'HARD',
                  color: difficulty == 2
                      ? const Color(0xFF8E1B1B)
                      : const Color(0xFFE53935),
                  onFinished: () {
                    if (mounted && !_bannerDone) {
                      setState(() => _bannerDone = true);
                    }
                  },
                ),
              ),
            if (_overlay != _Overlay.none)
              Positioned.fill(
                key: const ValueKey('overlay'),
                child: _overlayView(),
              ),
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
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LevelBadge(level: _level),
                ),
              ),
              const SizedBox(width: 8),
              CandyIconButton(
                size: 44,
                icon: Icons.pause_rounded,
                color: const Color(0xFF6674F5),
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
      key: const ValueKey('toast'),
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
        stars: _earnedStars,
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
