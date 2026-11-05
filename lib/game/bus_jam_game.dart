import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueNotifier, kDebugMode;

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../models/bus_data.dart';
import '../models/level_data.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import 'components/board_component.dart';
import 'components/bus_component.dart';
import 'components/hint_component.dart';
import 'components/passenger_component.dart';
import 'game_layout.dart';
import 'logic/game_model.dart';
import 'logic/geometry.dart';
import 'logic/seeded_random.dart';
import 'render/sprite_bank.dart';
import 'components/debug_component.dart';
import 'render/palette.dart';

/// Game se Flutter screens ko khabar dene ke liye
class GameCallbacks {
  const GameCallbacks({
    required this.onWin,
    required this.onFail,
    required this.onToast,
    required this.onVipUsed,
    required this.onLockedSlotTap,
  });

  final void Function() onWin;
  final void Function() onFail;
  final void Function(String message) onToast;

  /// VIP booster se gaadi uth gayi (booster ki ginti kam karo)
  final void Function() onVipUsed;

  /// Player ne band ("+") slot par tap kiya
  final void Function() onLockedSlotTap;
}

/// Flame game: board dikhata hai, taps leta hai aur animations chalata hai.
/// Asal qawaid (rules) GameModel mein hain.
class BusJamGame extends FlameGame with TapCallbacks {
  BusJamGame({required this.level, required this.callbacks})
    : model = GameModel(level);

  final LevelData level;
  final GameCallbacks callbacks;
  final GameModel model;

  GameLayout? _layout;

  /// Screen ka layout. Size ya slots badlein to dobara banta hai.
  GameLayout get layout => _layout ??= GameLayout(
    width: size.x,
    height: size.y,
    cols: level.cols,
    rows: level.rows,
    slotPlaces: model.totalSlotPlaces,
    topInset: topInset,
    passengers: level.passengers.length,
    content: _content,
  );

  /// Camera ka frame: shuru mein gaadiyan jahan khadi hain (level bhar wahi;
  /// Shuffle sirf rang badalta hai, jagah nahi)
  late final Rect _content = GameLayout.contentOf(
    level.buses,
    level.cols,
    level.rows,
  );

  /// Upar ke tairte bar ki oonchai (GameScreen batati hai)
  double topInset = 0;

  final Map<int, BusComponent> _busViews = {};
  final Map<int, BusComponent> _slotViews = {};
  final List<PassengerComponent> _queueViews = [];

  /// Line ka agla passenger jo abhi screen par nahi aaya (model.queue mein index)
  int _nextToShow = 0;
  int _walking = 0;
  double _boardCooldown = 0;
  bool _ended = false;
  bool _anyMove = false;
  HintComponent? _hint;

  /// VIP booster: agla tap kisi bhi gaadi ko utha kar VIP slot mein le jaata hai
  bool vipMode = false;

  /// Kitne passengers line mein hain magar screen par nazar nahi aate
  int get hiddenPassengers => model.queue.length - _nextToShow;

  /// Line mein baqi passengers (upar ginti ki pill mein)
  int get waitingPassengers => model.remainingPassengers;

  /// Slots bhare hon to parking strip ki laal chamak (1 se 0 tak)
  double stripFlash = 0;

  /// Debug: har gaadi ka hitbox aur rasta dikhao (sirf debug build mein)
  bool showHitboxes = false;

  // Gaadi ki 3D tasveer tirchhe camera se bani hai (SpriteBank.tilt):
  // screen par gaadi upar-neeche cos(tilt) guna chapti dikhti hai aur chhat
  // (~0.84 unit oonchi) sin(tilt) ke hisaab se upar uthi nazar aati hai. Tap ka
  // hisaab isi nazar aane wali shakal se hona chahiye, warna chhat par tap chook jaata hai.
  static final double squash = math.cos(SpriteBank.tilt);
  static final double roofLift = 0.84 * math.sin(SpriteBank.tilt);

  /// Screen ke nuqte par kaun si gaadi hai (nazar aane wali shakal ke mutabiq).
  /// Kai gaadiyan hon to jis ka nazar aane wala darmiyan sab se qareeb ho.
  BusData? pickBus(Offset screen) {
    final l = layout;
    if (!l.boardPanel.inflate(l.cell).contains(screen)) return null;
    final bx = (screen.dx - l.gridRect.left) / l.cell + l.contentOrigin.dx;
    final by = (screen.dy - l.gridRect.top) / l.cell + l.contentOrigin.dy;
    final sprites = SpriteBank.instance.hasVehicles;
    BusData? best;
    var bestD = double.infinity;
    for (final b in model.grid) {
      if (!isPickable(b)) continue;
      // Chhoti gaadi ka hitbox thoda zyada bada
      final slack = b.length <= 2 ? 0.22 : 0.14;
      final box = Geo.busBox(b, inflate: slack);
      final dy = by - b.cy;
      final bool hit;
      if (sprites) {
        hit =
            box.contains(bx, b.cy + dy / squash) ||
            box.contains(bx, b.cy + (dy + roofLift) / squash) ||
            box.contains(bx, b.cy + (dy + roofLift * 0.5) / squash);
      } else {
        hit = box.contains(bx, by);
      }
      if (!hit) continue;
      final vy = sprites ? b.cy - roofLift * 0.5 : b.cy;
      final d = (bx - b.cx) * (bx - b.cx) + (by - vy) * (by - vy);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best;
  }

  /// Jo gaadi abhi grid par khadi hai aur hil nahi rahi
  bool isPickable(BusData b) => _busViews[b.id]?.mode == BusMode.grid;

  /// Tutorial ke liye: woh gaadi jo abhi nikal sakti hai
  BusData? get hintBus {
    if (_anyMove) return null;
    final movable = model.movableBuses();
    if (movable.isEmpty) return null;
    // Pehle passenger ke rang wali gaadi dikhao, taa ke pehla tap sahi ho
    final front = model.frontColor;
    return movable.firstWhere(
      (b) => b.color == front,
      orElse: () => movable.first,
    );
  }

  @override
  Color backgroundColor() => GamePalette.skyBottom;

  @override
  Future<void> onLoad() async {
    add(BoardComponent());
    add(CountPillComponent());
    for (final b in model.grid) {
      final v = BusComponent(b);
      _busViews[b.id] = v;
      add(v);
    }
    _fillQueue(initial: true);
    if (level.isTutorial) add(_hint = HintComponent());
    // Debug build: hitbox dikhane wali tah (showHitboxes se chalu)
    if (kDebugMode) add(DebugHitboxComponent());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout = null;
  }

  /// Line mein jitni jagah ho utne passengers screen par lao
  void _fillQueue({bool initial = false}) {
    final l = layout;
    while (_queueViews.length < l.maxVisiblePassengers &&
        _nextToShow < model.queue.length) {
      final index = _queueViews.length;
      // Naye passengers hujoom ke peeche (upar daayen) se aate hain
      final start = initial ? l.queuePosition(index) : l.hiddenBubblePos;
      final p = PassengerComponent(color: model.queue[_nextToShow], pos: start)
        ..queueIndex = index;
      _queueViews.add(p);
      add(p);
      _nextToShow++;
    }
  }

  bool get _busy => _walking > 0 || _busViews.values.any((b) => b.isAnimating);

  /// Aam slots kitne bhare hain (0..1). Upar wala mood emoji isay sunta hai.
  final ValueNotifier<double> slotFill = ValueNotifier(0);

  @override
  void update(double dt) {
    super.update(dt);
    if (stripFlash > 0) stripFlash = (stripFlash - dt / 0.6).clamp(0.0, 1.0);
    final normal = model.normalSlotCount;
    if (normal > 0) {
      var used = 0;
      for (var i = model.hasVip ? 1 : 0; i < model.slots.length; i++) {
        if (model.slots[i] != null) used++;
      }
      final f = used / normal;
      if (f != slotFill.value) slotFill.value = f;
    }
    if (_ended) return;

    // Line ka pehla passenger apne rang ki khadi gaadi mein jaye
    _boardCooldown -= dt;
    if (_boardCooldown <= 0 && _queueViews.isNotEmpty) {
      final slot = model.startBoarding();
      if (slot != null) {
        final p = _queueViews.removeAt(0);
        for (var i = 0; i < _queueViews.length; i++) {
          _queueViews[i].queueIndex = i;
        }
        _fillQueue();
        _walking++;
        // Sirf dikhawa: gaadi ka darwaza khule, baithne par halka dabe
        _slotViews[slot]?.openDoor();
        p.walkTo(layout.doorOf(slot), () {
          _walking--;
          _slotViews[slot]?.boardPulse();
          _onPassengerSeated(slot);
        });
        _boardCooldown = 0.09;
      }
    }

    _checkEnd();
  }

  void _onPassengerSeated(int slot) {
    AudioService.instance.play(Sfx.board, volume: 0.4);
    final full = model.finishBoarding(slot);
    if (!full) return;

    // Gaadi bhar gayi: rawana
    final view = _slotViews[slot];
    AudioService.instance.play(Sfx.busDepart, volume: 0.6);
    HapticService.instance.light();
    if (view == null) {
      model.depart(slot);
      return;
    }
    view.depart(() {
      model.depart(slot);
      _slotViews.remove(slot);
      _busViews.remove(view.data.id);
    });
  }

  void _checkEnd() {
    if (_busy) return;
    if (model.isWon) {
      _ended = true;
      AudioService.instance.play(Sfx.win);
      HapticService.instance.medium();
      callbacks.onWin();
    } else if (model.isStuck) {
      _ended = true;
      AudioService.instance.play(Sfx.fail);
      HapticService.instance.medium();
      callbacks.onFail();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (_ended || paused) return;
    final p = Offset(event.canvasPosition.x, event.canvasPosition.y);

    // Band ("+") slot par tap
    final slotIndex = layout.slotIndexAt(p);
    if (slotIndex != null && slotIndex >= model.slotCount) {
      AudioService.instance.play(Sfx.button);
      callbacks.onLockedSlotTap();
      return;
    }

    final bus = pickBus(p);
    if (bus == null) return;
    final view = _busViews[bus.id];
    if (view == null) return;

    if (vipMode) {
      _vipPick(bus, view);
      return;
    }

    final r = model.launch(bus.id);
    switch (r.status) {
      case LaunchStatus.blocked:
        // Aage ja kar rukawat se takrao aur wapis aao
        final blocker = model.blockerOf(bus);
        AudioService.instance.play(Sfx.tap, volume: 0.4);
        HapticService.instance.light();
        view.bump(
          model.freeDistanceAhead(bus),
          onHit: () {
            AudioService.instance.play(Sfx.blocked, volume: 0.6);
            HapticService.instance.medium();
            view.shake();
            if (blocker != null) _busViews[blocker.id]?.flashRed();
          },
        );
      case LaunchStatus.noSlot:
        view.shake();
        stripFlash = 1;
        AudioService.instance.play(Sfx.blocked, volume: 0.5);
        HapticService.instance.medium();
        callbacks.onToast(
          model.lockedSlots > 0
              ? 'All slots are full! Tap + to unlock one.'
              : 'All slots are full!',
        );
      case LaunchStatus.notFound:
        break;
      case LaunchStatus.ok:
        AudioService.instance.play(Sfx.tap, volume: 0.5);
        AudioService.instance.play(Sfx.busMove, volume: 0.45);
        HapticService.instance.light();
        _slotViews[r.slot] = view;
        view.driveTo(
          r.slot,
          layout.routeToSlot(bus, r.slot),
          () => model.arrive(r.slot),
        );
        _onFirstMove();
    }
  }

  void _vipPick(BusData bus, BusComponent view) {
    final r = model.launch(bus.id, ignoreBlock: true, useVip: true);
    if (r.status == LaunchStatus.noSlot) {
      callbacks.onToast('No free slot!');
      return;
    }
    if (r.status != LaunchStatus.ok) return;
    vipMode = false;
    AudioService.instance.play(Sfx.busMove, volume: 0.5);
    HapticService.instance.medium();
    _slotViews[r.slot] = view;
    view.flyTo(r.slot, () => model.arrive(r.slot));
    callbacks.onVipUsed();
    _onFirstMove();
  }

  void _onFirstMove() {
    _anyMove = true;
    _hint?.removeFromParent();
    _hint = null;
  }

  // ---------------- Boosters ----------------

  /// Kya abhi koi slot khaali hai? (Lift ke liye)
  bool get hasFreeSlot => model.freeVipSlot != null || model.freeSlot != null;

  bool get isEnded => _ended;

  /// Band slot kholo (ad ya coins ke baad). Koi band na ho to naya slot.
  void unlockSlot() {
    model.unlockSlot();
    _layout = null;
    HapticService.instance.medium();
  }

  /// Fail ke baad ad dekh kar ek slot ke saath dobara shuru
  void continueAfterFail() {
    unlockSlot();
    _ended = false;
  }

  /// Shuffle booster. Kamyab ho to true.
  bool shuffleBuses() {
    final ok = model.shuffleGridColors(
      SeededRandom(DateTime.now().microsecondsSinceEpoch),
    );
    if (!ok) return false;
    for (final b in model.grid) {
      _busViews[b.id]?.pop();
    }
    AudioService.instance.play(Sfx.tap);
    HapticService.instance.medium();
    return true;
  }

  /// Sort booster: baith sakne wale passengers line mein aage. Kamyab ho to true.
  bool sortPassengers() {
    if (!model.sortQueue()) return false;
    // Screen par nazar aane wale passengers ke rang naye order ke mutabiq
    for (var i = 0; i < _queueViews.length; i++) {
      _queueViews[i]
        ..color = model.queue[model.head + i]
        ..pop();
    }
    AudioService.instance.play(Sfx.tap);
    HapticService.instance.medium();
    return true;
  }
}
