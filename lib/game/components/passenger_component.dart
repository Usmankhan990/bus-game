import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../bus_jam_game.dart';
import '../game_layout.dart';
import '../render/palette.dart';
import '../render/passenger_painter.dart';

/// Hujoom mein khada ya gaadi ki taraf chalta hua passenger
class PassengerComponent extends Component with HasGameReference<BusJamGame> {
  PassengerComponent({required this.color, required this.pos})
    : super(priority: 20);

  /// Rang (Sort booster isay badal sakta hai)
  int color;
  Offset pos;

  /// Kya yeh passenger circle mein ghoom raha hai ya side chute par hai
  bool inCircle = true;
  int circleSlot = 0; // 0..59 (15 stations x 4 lanes)

  /// Side chute info (0 = left chute, 1 = right chute)
  int chuteIndex = 0;
  int chuteRank = 0; // 0 = sab se aage (circle ke paas)

  /// Line mein number (backward compatibility)
  int get queueIndex => inCircle
      ? circleSlot
      : GameLayout.maxCirclePassengers + chuteIndex * 100 + chuteRank;
  set queueIndex(int val) {
    if (val < GameLayout.maxCirclePassengers) {
      inCircle = true;
      circleSlot = val;
    } else {
      inCircle = false;
      final rest = val - GameLayout.maxCirclePassengers;
      chuteIndex = (rest ~/ 100).clamp(0, 1);
      chuteRank = rest % 100;
    }
  }

  bool _walking = false;
  bool _walkStarted = false;
  double _walkDelay = 0;
  Offset? _walkDoor;

  double _joinDelay = 0;
  int _joinChuteIdx = 0;
  int _joinLane = 0;

  // Level start intro entrance: dono side roads aur circle khali se shuru ho kar
  // side roads ke raste circle aur waiting rows mein aana
  bool _introActive = false;
  bool _introIsCircle = true;
  int _introChute = 0;
  double _introDelay = 0;
  double _introProgress = 0;
  double _introDur = 0.5;

  bool get isIntroActive => _introActive;
  bool get isIntroVisible => !_introActive || _introDelay <= 0;

  /// Circle mein jagah bharne ki shuruati stream animation
  void startCircleIntro({
    required int chuteIdx,
    required double delay,
    required double duration,
  }) {
    _introActive = true;
    _introIsCircle = true;
    _introChute = chuteIdx;
    _introDelay = delay;
    _introDur = math.max(0.15, duration);
    _introProgress = 0;
  }

  /// Side road ki waiting line bharne ki shuruati stream animation
  void startChuteIntro({required double delay}) {
    _introActive = true;
    _introIsCircle = false;
    _introChute = chuteIndex;
    _introDelay = delay;
  }

  /// Gaadi tak ka rasta: line se exit (gate), phir darwaza
  List<Offset> _path = const [];
  double _pathLen = 0;
  double _walked = 0;
  double _t = 0;
  double _time = 0;
  bool _moving = false;

  /// Har passenger ka apna hilne ka waqt, taa ke sab ek saath na hilen
  late final double _phase = (identityHashCode(this) % 628) / 100;
  double _popT = 0;
  void Function()? _onArrive;

  // Chalne ka rukh (sirf dikhawa): jidhar ja raha hai us taraf munh, mod par
  // aahista ghoomna; qadam (frame) taiy ki hui doori se
  late Offset _lastPos = pos;
  double? _heading;
  double _stride = 0;

  static const double _popDur = 0.3;

  /// Sort booster ke waqt chhota sa uchhalna
  void pop() => _popT = _popDur;

  /// Chute se circle ki taraf ek-ek karke smoothly dakhil hona
  void joinCircle(int slot, {required int chuteIdx, double delay = 0}) {
    inCircle = true;
    circleSlot = slot;
    _joinChuteIdx = chuteIdx;
    _joinLane = slot % GameLayout.circleLanes;
    _joinDelay = delay;
  }

  /// Exit gate ke raste se nikal kar gaadi ke darwaze tak chalo, pohanch kar [onArrive] chalao
  void walkTo(Offset door, void Function() onArrive, {double delay = 0}) {
    _walking = true;
    _walkDelay = delay;
    _walkDoor = door;
    _onArrive = onArrive;
    _walked = 0;
    _t = 0;
    _walkStarted = delay <= 0;
    if (_walkStarted) {
      _buildWalkPath(door);
    }
    priority = (3000 + (pos.dy * 10).clamp(0, 5000)).toInt();
  }

  void _buildWalkPath(Offset door) {
    final l = game.layout;
    final threshold = l.gateThreshold;
    final roadGate = l.gateRoad;

    final pts = <Offset>[pos];
    if ((pos - threshold).distance > 2) {
      pts.add(threshold);
    }
    if ((threshold - roadGate).distance > 2) {
      pts.add(roadGate);
    }
    pts.add(door);
    _path = pts;
    _pathLen = 0;
    for (var i = 1; i < _path.length; i++) {
      _pathLen += (_path[i] - _path[i - 1]).distance;
    }
    _walked = 0;
    _t = 0;
  }

  void _stepToward(Offset target, double maxSpeed, double dt) {
    final gap = target - pos;
    final d = gap.distance;
    _moving = d > 0.05;
    if (d > 0.1) {
      final step = maxSpeed * dt;
      pos = step >= d ? target : pos + gap / d * step;
    } else {
      pos = target;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_popT > 0) _popT -= dt;
    final size = game.layout.passengerSize;
    if (_introActive) {
      if (_introDelay > 0) {
        _introDelay -= dt;
        if (_introDelay > 0) {
          _moving = false;
          _lastPos = pos;
          priority = 100;
          return;
        }
        dt = -_introDelay;
        _introDelay = 0;
      }
      if (_introIsCircle) {
        _introProgress = math.min(1.0, _introProgress + dt / _introDur);
        final sample = game.layout.introTrackSample(
          _introChute,
          circleSlot,
          game.queueFlow,
          _introProgress,
        );
        pos = sample.pos;
        _heading = sample.heading;
        _lastPos = pos;
        _moving = true;
        _stride += dt * 3.0;
        priority = (200 + (pos.dy * 10).clamp(0, 5000)).toInt();
        if (_introProgress >= 1.0) {
          _introActive = false;
        }
        return;
      } else {
        final target = game.layout.chutePosition(chuteIndex, chuteRank);
        final d = (target - pos).distance;
        final speed = math.max(size * 18.0, d * 5.5);
        _stepToward(target, speed, dt);
        _heading = game.layout.chuteHeading(chuteIndex, chuteRank);
        _lastPos = pos;
        if (_moving) _stride += dt * 2.4;
        priority = (200 + (pos.dy * 10).clamp(0, 5000)).toInt();
        if (d <= size * 0.12) {
          pos = target;
          _introActive = false;
        }
        return;
      }
    }
    _updateFacing(dt);
    if (_walking) {
      if (!_walkStarted) {
        _walkDelay -= dt;
        // Apni baari aane tak circle ke sath ghoomta rahe taa ke stream bilkul juri rahe
        final hold = game.layout.circlePosition(circleSlot, game.queueFlow);
        _stepToward(
          hold,
          math.max(size * 14, (hold - pos).distance * 8),
          dt,
        );
        if (_walkDelay > 0) return;
        _walkStarted = true;
        _buildWalkPath(_walkDoor!);
      }
      // Tez kadmon se exit, phir gaadi (taake stream musalsal rahe)
      final speed = math.max(size * 22, _pathLen / 0.24);
      _walked = math.min(_pathLen, _walked + speed * dt);
      _t = _pathLen == 0 ? 1 : _walked / _pathLen;
      var left = _walked;
      for (var i = 1; i < _path.length; i++) {
        final seg = (_path[i] - _path[i - 1]).distance;
        if (left <= seg || i == _path.length - 1) {
          pos = Offset.lerp(
            _path[i - 1],
            _path[i],
            seg == 0 ? 1 : (left / seg).clamp(0.0, 1.0),
          )!;
          break;
        }
        left -= seg;
      }
      priority = (3000 + (pos.dy * 10).clamp(0, 5000)).toInt();
      if (_t >= 1) {
        removeFromParent();
        final cb = _onArrive;
        _onArrive = null;
        cb?.call();
      }
      return;
    }
    // Target position calculation: circle, chute se smooth entry, ya side chute
    final Offset target;
    final double speed;
    if (inCircle) {
      if (_joinDelay > 0) {
        _joinDelay -= dt;
        target = game.layout.chutePosition(_joinChuteIdx, _joinLane);
        final d = (target - pos).distance;
        speed = math.max(size * 2.55, d * 5.0);
      } else {
        target = game.layout.circlePosition(circleSlot, game.queueFlow);
        final d = (target - pos).distance;
        // Chute mouth se circle par smoothly aana, phir bina lag ke track par chalna
        speed = d > size * 0.35
            ? math.max(size * 8.5, d * 6.0)
            : math.max(size * 14, d * 8);
      }
    } else {
      target = game.layout.chutePosition(chuteIndex, chuteRank);
      final d = (target - pos).distance;
      // 0.88*s per 0.345s = 2.55*s/s par musalsal slide (4-4 jhatkon ke baghair)
      speed = math.max(size * 2.55, d * 5.0);
    }

    _stepToward(target, speed, dt);
    // Isometric depth sorting: aage khade passengers peeche walon ke upar nazar aayein
    priority = (200 + (pos.dy * 10).clamp(0, 5000)).toInt();
  }

  void _updateFacing(double dt) {
    if (dt <= 0) return;
    final step = pos - _lastPos;
    _lastPos = pos;
    final size = game.layout.passengerSize;
    if (_walking && _walkStarted) {
      if (step.distance > size * 0.01) {
        final target = _angleOf(step);
        _heading = target;
        _stride += step.distance / size;
      }
      return;
    }
    if (inCircle) {
      _heading = game.layout.circleHeading(circleSlot, game.queueFlow);
      if (_moving) _stride += dt * 2.2;
    } else {
      _heading = game.layout.chuteHeading(chuteIndex, chuteRank);
      if (_moving) _stride += dt * 1.5;
    }
  }

  /// Screen par rukh ka angle (0 = upar, ghadi ki sui ki taraf)
  static double _angleOf(Offset v) => math.atan2(v.dx, -v.dy);

  /// Qadam ka frame: chalte hue 1-2-3-0, khade hue 0
  int get _frame => (_walking || _moving) ? (_stride / 0.32).floor() % 4 : 0;

  @override
  void render(Canvas canvas) {
    if (_introActive && _introDelay > 0) return;
    final size = game.layout.passengerSize;
    // Chalte waqt uchhalna; ruke hue bilkul saakin
    final bob = _walking
        ? (math.sin(_time * 22)).abs()
        : !_moving
            ? 0.0
            : inCircle
                ? 0.65 * (math.sin(_time * 16 + _phase)).abs()
                : 0.45 * (math.sin(_time * 12 + _phase)).abs();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    var scale = 1.0;
    if (_walking && _t > 0.8) {
      // Darwaze par gaadi ke andar jaate hue chhota hota jaye
      scale = (1 - (_t - 0.8) / 0.2 * 0.7).clamp(0.3, 1.0);
    }
    if (_popT > 0) {
      scale *= 1 + 0.3 * math.sin(math.pi * (1 - _popT / _popDur));
    }
    if (scale != 1) canvas.scale(scale);
    PassengerPainter.paint(
      canvas,
      color: GamePalette.bus(color),
      colorIndex: color,
      size: size,
      bob: bob,
      heading: _heading ?? 0,
      frame: _frame,
    );
    canvas.restore();
  }
}
