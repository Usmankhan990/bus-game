import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../bus_jam_game.dart';
import '../render/palette.dart';
import '../render/passenger_painter.dart';

/// Hujoom mein khada ya gaadi ki taraf chalta hua passenger
class PassengerComponent extends Component with HasGameReference<BusJamGame> {
  PassengerComponent({required this.color, required this.pos})
    : super(priority: 20);

  /// Rang (Sort booster isay badal sakta hai)
  int color;
  Offset pos;

  /// Line mein number (0 = sab se aage)
  int queueIndex = 0;

  bool _walking = false;

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

  /// Exit se nikal kar gaadi ke darwaze tak chalo, pohanch kar [onArrive] chalao
  void walkTo(Offset door, void Function() onArrive) {
    _walking = true;
    final gate = game.layout.gate;
    _path = (pos - gate).distance > 2 ? [pos, gate, door] : [pos, door];
    _pathLen = 0;
    for (var i = 1; i < _path.length; i++) {
      _pathLen += (_path[i] - _path[i - 1]).distance;
    }
    _walked = 0;
    _t = 0;
    _onArrive = onArrive;
    priority = 25;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_popT > 0) _popT -= dt;
    final size = game.layout.passengerSize;
    _updateFacing(dt);
    if (_walking) {
      // Tez kadmon se exit, phir gaadi (jitna lamba rasta, utna waqt; had 0.45s)
      final speed = math.max(size * 16, _pathLen / 0.45);
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
      if (_t >= 1) {
        removeFromParent();
        final cb = _onArrive;
        _onArrive = null;
        cb?.call();
      }
      return;
    }
    // Line aage khiske to apni nayi jagah tak barabar raftaar se chal kar jao
    final target = game.layout.queuePosition(queueIndex);
    final gap = target - pos;
    final d = gap.distance;
    _moving = d > 0.5;
    if (_moving) {
      final step = math.max(size * 7, d * 4) * dt;
      pos = step >= d ? target : pos + gap / d * step;
    }
  }

  void _updateFacing(double dt) {
    if (dt <= 0) return;
    final step = pos - _lastPos;
    _lastPos = pos;
    final size = game.layout.passengerSize;
    // Shuru mein munh line ke aage (exit) ki taraf
    _heading ??= _angleOf(game.layout.gate - pos);
    if (step.distance > size * 0.01) {
      final target = _angleOf(step);
      final diff = math.atan2(
        math.sin(target - _heading!),
        math.cos(target - _heading!),
      );
      _heading = _heading! + diff * math.min(1.0, dt * 14);
      _stride += step.distance / size;
    }
  }

  /// Screen par rukh ka angle (0 = upar, ghadi ki sui ki taraf)
  static double _angleOf(Offset v) => math.atan2(v.dx, -v.dy);

  /// Qadam ka frame: chalte hue 1-2-3-0, khade hue 0
  int get _frame => (_walking || _moving) ? (_stride / 0.32).floor() % 4 : 0;

  @override
  void render(Canvas canvas) {
    final size = game.layout.passengerSize;
    // Chalte waqt uchhalna; khade khade bhi halka sa hilna (hujoom zinda lage)
    final bob = (_walking || _moving)
        ? (math.sin(_time * 22)).abs()
        : 0.45 * (math.sin(_time * 5.5 + _phase)).abs();
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
