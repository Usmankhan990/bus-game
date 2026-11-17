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
import 'components/hit_effect_component.dart';
import 'components/passenger_component.dart';
import 'components/slot_full_tip_component.dart';
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
  BusJamGame({
    required this.level,
    required this.callbacks,
    QueueShape? queueShape,
  })  : model = GameModel(level),
        queueShape =
            queueShape ??
            QueueShape.values[(level.level - 1) % QueueShape.values.length];

  final LevelData level;
  final GameCallbacks callbacks;
  final GameModel model;
  final QueueShape queueShape;

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
    queueShape: queueShape,
    content: _content,
  );

  /// Camera ka frame: shuru mein gaadiyan jahan khadi hain; agar shuffle
  /// kisi gaadi ko bahar rakhe to zaroorat mutabiq barh sakta hai
  late Rect _content = GameLayout.contentOf(
    level.buses,
    level.cols,
    level.rows,
  );
  int _shuffleNonce = 0;

  /// Upar ke tairte bar ki oonchai (GameScreen batati hai)
  double topInset = 0;

  final Map<int, BusComponent> _busViews = {};
  final Map<int, BusComponent> _slotViews = {};
  final List<PassengerComponent> _circleViews = [];
  final List<PassengerComponent> _leftChuteViews = [];
  final List<PassengerComponent> _rightChuteViews = [];

  /// Roundabout par passengers ki raftaar se ghoomne ka flow
  double queueFlow = 0;

  /// Screen par nazar aane wale saare passengers (circle + side chutes)
  List<PassengerComponent> get queueViews =>
      [..._circleViews, ..._leftChuteViews, ..._rightChuteViews];

  /// Screen par ghoomne wale passengers ke rang
  Set<int> get visiblePassengerColors => queueViews.map((p) => p.color).toSet();

  int _walking = 0;
  double _boardCooldown = 0;
  double _introElapsed = 0;
  bool _introSfxPlayed = false;
  double _lastCarLandSfxAt = -1.0;
  int _carLandSfxCount = 0;
  int _blockedHits = 0;
  int _slotsUnlocked = 0;
  int _revivesUsed = 0;
  bool _ended = false;
  bool _anyMove = false;
  HintComponent? _hint;

  /// VIP booster: agla tap kisi bhi gaadi ko utha kar VIP slot mein le jaata hai
  bool vipMode = false;

  /// Kitne passengers line mein hain magar screen par nazar nahi aate
  int get hiddenPassengers =>
      math.max<int>(0, model.remainingPassengers - queueViews.length);

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
  static final double roofLift = 0.84 * BusData.sizeScale * math.sin(SpriteBank.tilt);

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

  /// Jo gaadi abhi grid par khadi hai aur apni jagah utar kar ruk chuki hai
  bool isPickable(BusData b) {
    final view = _busViews[b.id];
    return view != null &&
        view.mode == BusMode.grid &&
        !view.isDropping &&
        !view.isShuffling;
  }

  /// Screen par is waqt kitne log (side roads / circle mein) dikhai de rahe hain
  int get visibleQueueCount => queueViews.where((p) => p.isIntroVisible).length;

  /// Kya level start ki drop aur stream intro animation mukammal ho chuki hai
  bool get isIntroFinished =>
      !_busViews.values.any((b) => b.isDropping) &&
      !queueViews.any((p) => p.isIntroActive);

  bool get introSoundPlayed => _introSfxPlayed;
  int get carLandSoundCount => _carLandSfxCount;

  /// Jab upar se girne wali gari zameen par baithay to narm throttled thump bajaye
  void playCarLandSound() {
    if (_ended || _carLandSfxCount >= 6) return;
    if (_lastCarLandSfxAt >= 0 && _introElapsed - _lastCarLandSfxAt < 0.075) {
      return;
    }
    _lastCarLandSfxAt = _introElapsed;
    _carLandSfxCount++;
    AudioService.instance.play(Sfx.carLand, volume: 0.48);
  }

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
    final sortedBuses = List.of(model.grid)
      ..sort(
        (a, b) => a.cy != b.cy ? a.cy.compareTo(b.cy) : a.cx.compareTo(b.cx),
      );
    final minY = sortedBuses.isEmpty ? 0.0 : sortedBuses.first.cy;
    final maxY = sortedBuses.isEmpty ? 1.0 : sortedBuses.last.cy;
    final spanY = math.max(1.0, maxY - minY);
    for (final b in sortedBuses) {
      final normY = (b.cy - minY) / spanY;
      final normX = b.cx / math.max(1.0, level.cols.toDouble());
      final delay = 0.04 + normY * 0.28 + normX * 0.08;
      final v = BusComponent(b, dropDelay: delay);
      _busViews[b.id] = v;
      add(v);
    }
    _fillQueue(initial: true);
    _introSfxPlayed = true;
    AudioService.instance.play(Sfx.levelStart, volume: 0.72);
    if (level.isTutorial) add(_hint = HintComponent());
    // Debug build: hitbox dikhane wali tah (showHitboxes se chalu)
    if (kDebugMode) add(DebugHitboxComponent());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout = null;
  }

  int get leftChuteCount => _leftChuteViews.length;
  int get rightChuteCount => _rightChuteViews.length;

  bool _isStationEmpty(int station) => !_circleViews.any(
    (p) => p.circleSlot ~/ GameLayout.circleLanes == station,
  );

  /// Line mein jitni jagah ho utne passengers screen par lao:
  /// Shuru mein side roads aur circle khali hote hain; level start hote hi dono
  /// side roads se log stream banakar circle aur waiting queues bhar dete hain.
  void _fillQueue({bool initial = false}) {
    final l = layout;
    const maxChuteCapacity = 44;

    if (initial) {
      // 1) Shuru mein circle ke stations tayyar karein (104 max)
      final stationGroups = <int, List<PassengerComponent>>{};
      for (var st = 0; st < GameLayout.circleStations; st++) {
        if (!_isStationEmpty(st)) continue;
        final remainingInQueue =
            model.queue.length - (model.head + _circleViews.length);
        if (remainingInQueue <= 0) break;
        final take = math.min(GameLayout.circleLanes, remainingInQueue);
        final list = <PassengerComponent>[];
        for (var lane = 0; lane < take; lane++) {
          final nextIdx = model.head + _circleViews.length;
          if (nextIdx >= model.queue.length) break;
          final circleSlot = st * GameLayout.circleLanes + lane;
          final p = PassengerComponent(
            color: model.queue[nextIdx],
            pos: l.chuteSpawnPos(0),
          )
            ..inCircle = true
            ..circleSlot = circleSlot;
          _circleViews.add(p);
          list.add(p);
          add(p);
        }
        stationGroups[st] = list;
      }

      // Circle ke stations ko left aur right half mein baant kar dono side roads se bhejein
      const predictedFlow = 0.70 * 0.85;
      final fullCircle = stationGroups.length == GameLayout.circleStations;
      final leftStations = <int>[];
      final rightStations = <int>[];
      for (final st in stationGroups.keys) {
        final u = l.stationU(st, predictedFlow);
        final side = fullCircle
            ? ((u > 0.0 && u < 0.50) ? 0 : 1)
            : (st.isOdd ? 0 : 1);
        if (side == 0) {
          leftStations.add(st);
        } else {
          rightStations.add(st);
        }
      }
      leftStations.sort(
        (a, b) => l
            .introPathLength(0, b * GameLayout.circleLanes, predictedFlow)
            .compareTo(
              l.introPathLength(0, a * GameLayout.circleLanes, predictedFlow),
            ),
      );
      rightStations.sort(
        (a, b) => l
            .introPathLength(1, b * GameLayout.circleLanes, predictedFlow)
            .compareTo(
              l.introPathLength(1, a * GameLayout.circleLanes, predictedFlow),
            ),
      );

      var maxPath = l.leftFeederMetric.length;
      for (final st in leftStations) {
        maxPath = math.max(
          maxPath,
          l.introPathLength(0, st * GameLayout.circleLanes, predictedFlow),
        );
      }
      for (final st in rightStations) {
        maxPath = math.max(
          maxPath,
          l.introPathLength(1, st * GameLayout.circleLanes, predictedFlow),
        );
      }
      const stepDelay = 0.036;
      final marchSpeed = math.max(l.passengerSize * 22.0, maxPath / 0.48);

      void launchSide(int side, List<int> stations) {
        for (var i = 0; i < stations.length; i++) {
          final st = stations[i];
          final delay = 0.03 + i * stepDelay;
          for (final p in stationGroups[st]!) {
            final len = l.introPathLength(side, p.circleSlot, predictedFlow);
            p.pos = l.introTrackSample(side, p.circleSlot, queueFlow, 0.0).pos;
            p.startCircleIntro(
              chuteIdx: side,
              delay: delay,
              duration: len / marchSpeed,
            );
          }
        }
      }

      launchSide(0, leftStations);
      launchSide(1, rightStations);

      // 2) Baqi line dono side roads (chutes) par circle streams ke bilkul peeche aayen:
      final overflow = model.queue.length - (model.head + _circleViews.length);
      if (overflow <= 0) return;
      final rightTarget = overflow >= maxChuteCapacity * 2
          ? maxChuteCapacity
          : ((overflow ~/ 8) * 4).clamp(0, overflow);
      final leftTarget = math.min(maxChuteCapacity, overflow - rightTarget);

      final leftChuteBase = 0.03 + leftStations.length * stepDelay + 0.01;
      final leftStart = model.head + _circleViews.length;
      for (var r = 0; r < leftTarget; r++) {
        final p = PassengerComponent(
          color: model.queue[leftStart + r],
          pos: l.chuteSpawnPos(0),
        )
          ..inCircle = false
          ..chuteIndex = 0
          ..chuteRank = r;
        p.startChuteIntro(delay: leftChuteBase + (r ~/ 4) * stepDelay);
        _leftChuteViews.add(p);
        add(p);
      }

      final rightChuteBase = 0.03 + rightStations.length * stepDelay + 0.01;
      final rightStart = model.queue.length - rightTarget;
      for (var r = 0; r < rightTarget; r++) {
        final p = PassengerComponent(
          color: model.queue[rightStart + r],
          pos: l.chuteSpawnPos(1),
        )
          ..inCircle = false
          ..chuteIndex = 1
          ..chuteRank = r;
        p.startChuteIntro(delay: rightChuteBase + (r ~/ 4) * stepDelay);
        _rightChuteViews.add(p);
        add(p);
      }
      return;
    }

    // 3) Khel ke dauran left chute jab aage bheje to beech ke baqi log peeche se left chute mein aayen
    final unspawnedEnd = model.queue.length - _rightChuteViews.length;
    while (_leftChuteViews.length < maxChuteCapacity) {
      final nextIdx =
          model.head + _circleViews.length + _leftChuteViews.length;
      if (nextIdx >= unspawnedEnd) break;
      final rank = _leftChuteViews.length;
      final p = PassengerComponent(
        color: model.queue[nextIdx],
        pos: l.chuteSpawnPos(0),
      )
        ..inCircle = false
        ..chuteIndex = 0
        ..chuteRank = rank;
      _leftChuteViews.add(p);
      add(p);
    }
  }

  /// Jab khali [station] left ya right road ke paas aaye to wahan se 4-row circle mein bhejen
  void _feedStationFromChute(int station, {required int chuteIdx}) {
    if (!_isStationEmpty(station)) return;
    final source = chuteIdx == 0 ? _leftChuteViews : _rightChuteViews;
    if (source.isEmpty) return;

    final take = math.min(GameLayout.circleLanes, source.length);
    for (var lane = 0; lane < take; lane++) {
      final entrant = source.removeAt(0);
      entrant.joinCircle(
        station * GameLayout.circleLanes + lane,
        chuteIdx: chuteIdx,
        delay: lane * 0.080,
      );
      _circleViews.add(entrant);
    }
    for (var i = 0; i < source.length; i++) {
      source[i].chuteRank = i;
    }

    // Chutes par nayi 4-row spawn karein agar model.queue mein baqi ho
    _fillQueue();
  }

  /// Ghoomti hui khali jagah jab left road ke paas jaye to left se fill ho;
  /// jab left khatam ho jaye aur khali jagah right road ke paas jaye to right se fill ho.
  void _refillEmptyStationsAtDocks() {
    if (_leftChuteViews.isEmpty && _rightChuteViews.isEmpty) return;
    final l = layout;
    for (var st = 0; st < GameLayout.circleStations; st++) {
      if (!_isStationEmpty(st)) continue;
      if (_leftChuteViews.isNotEmpty) {
        if (l.isStationAtLeftDock(st, queueFlow)) {
          _feedStationFromChute(st, chuteIdx: 0);
        }
      } else if (_rightChuteViews.isNotEmpty) {
        if (l.isStationAtRightDock(st, queueFlow)) {
          _feedStationFromChute(st, chuteIdx: 1);
        }
      }
    }
  }

  bool get _busy =>
      _walking > 0 ||
      _busViews.values.any((b) => b.isAnimating || b.isShuffling);

  /// Aam slots kitne bhare hain (0..1). Upar wala mood emoji isay sunta hai.
  final ValueNotifier<double> slotFill = ValueNotifier(0);

  @override
  void update(double dt) {
    super.update(dt);
    _introElapsed += dt;
    // Circle hamesha mustaqil speed 0.70 se ghoomta rahe (boarding ke waqt bhi na ruke)
    const flowSpeed = 0.70;
    queueFlow += dt * flowSpeed;

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

    // Khuli jagah (open gate) se guzarne wali ek poori 4-logon ki station ek sath gaadi mein jaye
    _boardCooldown -= dt;
    if (_boardCooldown <= 0 && _circleViews.isNotEmpty) {
      int? bestStation;
      var bestDelta = double.infinity;

      for (var st = 0; st < GameLayout.circleStations; st++) {
        if (!layout.isStationInGateZone(st, queueFlow)) continue;
        final delta = layout.stationGateDelta(st, queueFlow);
        if (delta >= bestDelta) continue;

        final row = _circleViews
            .where((p) => p.circleSlot ~/ GameLayout.circleLanes == st)
            .toList();
        if (row.isEmpty) continue;
        final allReady = row.every(
          (p) =>
              !p.isIntroActive &&
              (p.pos - layout.circlePosition(p.circleSlot, queueFlow)).distance <=
                  layout.passengerSize * 1.5,
        );
        if (!allReady) continue;
        final hasParked = row.any(
          (p) => model.findParkedSlotForColor(p.color) != null,
        );
        if (!hasParked) continue;

        bestDelta = delta;
        bestStation = st;
      }

      if (bestStation != null) {
        final row = _circleViews
            .where((p) => p.circleSlot ~/ GameLayout.circleLanes == bestStation)
            .toList()
          ..sort((a, b) => b.circleSlot.compareTo(a.circleSlot)); // outer -> inner

        var boardedAny = false;
        var stepIdx = 0;
        for (final p in row) {
          final slot = model.reserveSeatForColor(p.color);
          if (slot == null) continue;
          boardedAny = true;
          _circleViews.remove(p);
          _walking++;
          _slotViews[slot]?.openDoor();
          p.walkTo(
            layout.doorOf(slot),
            () {
              _walking--;
              _slotViews[slot]?.boardPulse();
              _onPassengerSeated(slot);
            },
            delay: stepIdx * 0.085,
          );
          stepIdx++;
        }

        if (boardedAny) {
          _boardCooldown = 0.08;
        }
      }
    }

    _refillEmptyStationsAtDocks();
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

  BusComponent? busView(int id) => _busViews[id];

  bool get _isStuck {
    if (!isIntroFinished) return false;
    // 1) Agar koi normal slot khaali hai to bilkul stuck nahi
    if (model.freeSlot != null) return false;

    // 2) Agar koi gaadi abhi rawana ho rahi hai ya chal rahi hai to stuck nahi
    for (final s in model.slots) {
      if (s == null) continue;
      if (s.phase != SlotPhase.parked) return false;
    }
    if (_busy) return false;

    // 3) Khadi gaadiyon ke rang jin mein jagah baqi hai
    final parkedColors = <int>{};
    for (final s in model.slots) {
      if (s != null && s.phase == SlotPhase.parked && s.hasRoom) {
        parkedColors.add(s.color);
      }
    }
    if (parkedColors.isEmpty) return true;

    // 4) Circle mein ghoomne wale passengers mein se kisi ka rang khadi gaadi se milta hai?
    // User requirement: agar matching banda circle mein hai to us ke gate tak aane ka wait karna chahiye.
    if (_circleViews.any((p) => parkedColors.contains(p.color))) {
      return false;
    }

    // 5) Kya circle mein koi khaali station hai jo feeder chute se matching banda la sake?
    final hasEmptyStation = List.generate(
      GameLayout.circleStations,
      (st) => _isStationEmpty(st),
    ).any((empty) => empty);

    if (hasEmptyStation) {
      if (_leftChuteViews.any((p) => parkedColors.contains(p.color))) {
        return false;
      }
      if (_leftChuteViews.isEmpty &&
          _rightChuteViews.any((p) => parkedColors.contains(p.color))) {
        return false;
      }
    }

    // 6) Kisi bhi tarah se koi passenger kisi parked bus mein nahi aa sakta
    return true;
  }

  void _checkEnd() {
    if (_busy || _ended) return;
    if (model.isWon) {
      _ended = true;
      AudioService.instance.play(Sfx.win);
      HapticService.instance.medium();
      callbacks.onWin();
    } else if (_isStuck) {
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
        _blockedHits++;
        // Aage ja kar rukawat se takrao, hit sound & impact effect chale, aur wapis aao
        final blocker = model.blockerOf(bus);
        AudioService.instance.play(Sfx.tap, volume: 0.35);
        HapticService.instance.light();
        view.bump(
          model.freeDistanceAhead(bus),
          onHit: () {
            AudioService.instance.play(Sfx.hitEffect, volume: 0.85);
            HapticService.instance.medium();
            add(
              HitEffectComponent(
                pos: view.bumpImpactPoint,
                unit: layout.cell,
                dir: Offset(bus.fx, bus.fy),
              ),
            );
            view.shake();
            if (blocker != null) _busViews[blocker.id]?.hitBy(bus.fx, bus.fy);
          },
        );
      case LaunchStatus.noSlot:
        view.shake();
        stripFlash = 1;
        AudioService.instance.play(Sfx.blocked, volume: 0.5);
        HapticService.instance.medium();
        _showSlotFullNear(view);
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
      view.shake();
      stripFlash = 1;
      AudioService.instance.play(Sfx.blocked, volume: 0.5);
      HapticService.instance.medium();
      _showSlotFullNear(view);
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

  void _showSlotFullNear(BusComponent view) {
    for (final old in children.whereType<SlotFullTipComponent>().toList()) {
      old.removeFromParent();
    }
    final l = layout;
    final bounds = Rect.fromLTRB(
      8,
      l.boardPanel.top + 4,
      l.width - 8,
      l.boardPanel.bottom - 4,
    );
    add(
      SlotFullTipComponent(
        targetPos: view.pos,
        unit: l.cell,
        bounds: bounds,
        text: model.lockedSlots > 0 ? 'Slots full! Tap +' : 'Slots full!',
      ),
    );
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

  /// Star rating ke liye level ke dauran li gayi madad aur ghalat takkarein
  int get blockedHits => _blockedHits;
  int get slotsUnlocked => _slotsUnlocked;
  int get revivesUsed => _revivesUsed;

  void _openBonusSlot() {
    model.unlockSlot();
    _layout = null;
    HapticService.instance.medium();
  }

  /// Band slot kholo (ad ya coins ke baad). Koi band na ho to naya slot.
  void unlockSlot() {
    _openBonusSlot();
    _slotsUnlocked++;
  }

  /// Fail ke baad ad dekh kar ek slot ke saath dobara shuru
  void continueAfterFail() {
    _openBonusSlot();
    _revivesUsed++;
    _ended = false;
  }

  /// Shuffle booster: gaadiyon ki poori arrangement (positions, angles, order
  /// aur rang) naye pattern ke sath badalta hai. Kamyab ho to true.
  bool shuffleBuses() {
    final beforeViews = <int, (Offset, double)>{};
    for (final b in model.grid) {
      final v = _busViews[b.id];
      if (v != null) beforeViews[b.id] = (v.pos, v.angle);
    }

    final ok = model.shuffleArrangement(
      SeededRandom(
        DateTime.now().microsecondsSinceEpoch ^ (++_shuffleNonce * 7919),
      ),
      bounds: (
        left: _content.left,
        top: _content.top,
        right: _content.right,
        bottom: _content.bottom,
      ),
    );
    if (!ok) return false;

    final needed = GameLayout.contentOf(model.grid, level.cols, level.rows);
    if (needed.left < _content.left - 1e-4 ||
        needed.top < _content.top - 1e-4 ||
        needed.right > _content.right + 1e-4 ||
        needed.bottom > _content.bottom + 1e-4) {
      _content = _content.expandToInclude(needed);
      _layout = null;
    }

    for (final b in model.grid) {
      final view = _busViews[b.id];
      final prev = beforeViews[b.id];
      if (view != null && prev != null) {
        view.shuffleArrangeFrom(prev.$1, prev.$2);
      } else {
        view?.pop();
      }
    }
    AudioService.instance.play(Sfx.tap);
    HapticService.instance.medium();
    return true;
  }

  /// Sort booster: baith sakne wale passengers line mein aage. Kamyab ho to true.
  bool sortPassengers() {
    if (!model.sortQueue()) return false;
    final sortedCircle = List<PassengerComponent>.from(_circleViews)
      ..sort((a, b) {
        final stA = a.circleSlot ~/ GameLayout.circleLanes;
        final stB = b.circleSlot ~/ GameLayout.circleLanes;
        if (stA != stB) {
          return layout
              .stationAheadAngle(stA, queueFlow)
              .compareTo(layout.stationAheadAngle(stB, queueFlow));
        }
        return (a.circleSlot % GameLayout.circleLanes).compareTo(
          b.circleSlot % GameLayout.circleLanes,
        );
      });
    final front = [...sortedCircle, ..._leftChuteViews];
    for (var i = 0;
        i < front.length && model.head + i < model.queue.length;
        i++) {
      front[i]
        ..color = model.queue[model.head + i]
        ..pop();
    }
    final rightStart = model.queue.length - _rightChuteViews.length;
    for (var i = 0; i < _rightChuteViews.length && rightStart + i >= model.head; i++) {
      _rightChuteViews[i]
        ..color = model.queue[rightStart + i]
        ..pop();
    }
    AudioService.instance.play(Sfx.tap);
    HapticService.instance.medium();
    return true;
  }
}
