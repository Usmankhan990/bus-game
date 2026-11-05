import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:flame/components.dart';

import '../../models/bus_data.dart';
import '../bus_jam_game.dart';
import '../game_layout.dart';
import '../render/bus_painter.dart';
import '../render/sprite_bank.dart';
import 'smoke_component.dart';
import '../render/palette.dart';

/// Gaadi is waqt kya kar rahi hai
enum BusMode { grid, driving, flying, parked, departing }

/// Screen par ek bus. Rules GameModel mein hain, yeh sirf dikhati aur animate karti hai.
class BusComponent extends Component with HasGameReference<BusJamGame> {
  BusComponent(this.data) : super(priority: 1);

  final BusData data;
  BusMode mode = BusMode.grid;

  /// Kis slot ki taraf ja rahi hai / kis slot mein khadi hai (-1 = grid par)
  int slot = -1;

  Offset pos = Offset.zero;
  double angle = 0;
  double unit = 0;
  double _lift = 1;
  double _rotor = 0;

  // Hilne (shake) aur uchalne (pop) ke timers
  double _shakeT = 0;
  double _popT = 0;
  static const double _shakeDur = 0.32;
  static const double _popDur = 0.35;

  // Tap par dabna-uchhalna (squash), slot mein pohanch kar bounce, laal chamak
  double _squashT = 0;
  double _landT = 0;
  double _flashT = 0;
  static const double _squashDur = 0.16;
  static const double _landDur = 0.32;
  static const double _flashDur = 0.6;

  // Raste par chalne ka hisaab
  List<Offset> _path = const [];
  double _dist = 0;
  double _total = 0;
  double _elapsed = 0;
  double _speed = 0;
  double _startUnit = 0;
  double _departT = 0;
  void Function()? _onDone;

  bool get isAnimating =>
      mode == BusMode.driving ||
      mode == BusMode.flying ||
      mode == BusMode.departing;

  @override
  void onMount() {
    super.onMount();
    final l = game.layout;
    pos = l.busCenter(data);
    angle = data.angle;
    unit = l.cell;
  }

  // Driver jaisi feel (sirf dikhawa; asal angle/pos par koi asar nahi):
  // mod par body ka jhukna, brake par aage dabna, raftaar par peeche
  double _lean = 0;
  double _pitch = 0;
  double _prevAngle = 0;
  double _prevDist = 0;
  double _prevSpeed = 0;

  // Pahiyon ka ghoomna: jitna chale utna ghoomein (radian)
  double _wheelPhase = 0;
  Offset _wheelPrev = Offset.zero;

  // Darwaza (0 = band, 1 = poora khula) aur sawari baithne par halka dabna
  double _door = 0;
  double _doorHold = 0;
  double _boardT = 0;
  static const double _boardDur = 0.18;

  /// Passenger is gaadi ki taraf chal pada: darwaza kholo
  void openDoor() => _doorHold = 0.5;

  /// Passenger andar baith gaya: halka sa dabna, darwaza thodi der aur khula
  void boardPulse() {
    _boardT = _boardDur;
    _doorHold = 0.35;
  }

  /// Rasta band: thoda sa hilo
  void shake() => _shakeT = _shakeDur;

  /// Raste mein rukawat bani gaadi: hilo aur laal chamko
  void flashRed() {
    _shakeT = _shakeDur;
    _flashT = _flashDur;
  }

  // Takrane (bump) ka hisaab: aage khaali cells tak jao, takrao, wapis aao
  double _bumpT = 0;
  double _bumpDur = 0;
  double _bumpDist = 0;
  void Function()? _onBumpHit;
  bool _bumpHitDone = false;

  /// Rasta band: [freeUnits] tak aage jao, rukawat se takrao aur wapis aao.
  /// Takrane ke lamhe [onHit] chalta hai (maslan rukawat wali gaadi ko hilana).
  void bump(double freeUnits, {void Function()? onHit}) {
    if (_bumpT > 0) return;
    // Bilkul saath khadi rukawat par bhi bump saaf nazar aaye
    _bumpDist = (math.max(freeUnits, 0.22) + 0.12) * game.layout.cell;
    _bumpDur = 0.22 + freeUnits * 0.07;
    _bumpT = _bumpDur;
    _onBumpHit = onHit;
    _bumpHitDone = false;
  }

  /// Takrane ki animation mein aage kitna gaye (0..1..0)
  double get _bumpOffset {
    if (_bumpT <= 0) return 0;
    final t = 1 - _bumpT / _bumpDur; // 0 se 1
    // 55% waqt aage jana (tez hota hua), baqi wapis aana
    if (t < 0.55) {
      final u = t / 0.55;
      return _bumpDist * u * u;
    }
    final u = (t - 0.55) / 0.45;
    return _bumpDist * (1 - u) * (1 - u * 0.2);
  }

  /// Shuffle ke waqt chhota sa uchhalna
  void pop() => _popT = _popDur;

  /// Sadak se ghoom kar slot tak jao
  void driveTo(int slotIndex, List<Offset> path, void Function() onDone) {
    // Kone gol: asli gaadi ki tarah narm mod le
    final path2 = _smoothPath(path, game.layout.cell * 1.1);
    _startMove(slotIndex, path2, game.layout.cell * 17, onDone);
    mode = BusMode.driving;
    _squashT = _squashDur;
  }

  /// Helicopter: seedha urr kar slot tak
  void flyTo(int slotIndex, void Function() onDone) {
    _startMove(
      slotIndex,
      [pos, game.layout.slotCenters[slotIndex]],
      game.layout.cell * 8,
      onDone,
    );
    mode = BusMode.flying;
  }

  void _startMove(
    int slotIndex,
    List<Offset> path,
    double speed,
    void Function() onDone,
  ) {
    slot = slotIndex;
    _path = path;
    _total = 0;
    for (var i = 1; i < path.length; i++) {
      _total += (path[i] - path[i - 1]).distance;
    }
    _dist = 0;
    _elapsed = 0;
    _speed = speed;
    _startUnit = unit;
    _onDone = onDone;
    priority = 10;
  }

  /// Bhari hui gaadi: pehle bay se reverse ho kar mudti hai (yahan slot khaali
  /// ho jaata hai), phir raftaar pakar kar sadak par screen se bahar nikal jaati hai
  void depart(void Function() onDone) {
    mode = BusMode.departing;
    _departT = 0;
    _driveT = 0;
    _onDone = onDone;
    priority = 12;
    final l = game.layout;
    _exitSign = pos.dx >= l.width / 2 ? 1 : -1;
    _revFrom = pos;
    _revTo = pos.translate(
      -math.sin(angle) * l.bayH * 0.85,
      math.cos(angle) * l.bayH * 0.85,
    );
    _revAngle = angle;
    // Rawangi par peeche se dhuein ke gole
    final back = BusPainter.bodyLength(unit, data.length) / 2;
    for (var k = 0; k < 4; k++) {
      final tail = pos.translate(
        -math.sin(angle) * back + (k - 1.5) * unit * 0.18,
        math.cos(angle) * back + k * unit * 0.05,
      );
      game.add(SmokePuff(tail, unit * (0.35 + k * 0.06)));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final l = game.layout;
    if (_shakeT > 0) _shakeT -= dt;
    if (_popT > 0) _popT -= dt;
    if (_landT > 0) _landT -= dt;
    if (_flashT > 0) _flashT -= dt;
    if (_boardT > 0) _boardT -= dt;
    if (_doorHold > 0) _doorHold -= dt;
    final doorTarget = _doorHold > 0 && mode == BusMode.parked ? 1.0 : 0.0;
    _door += (doorTarget - _door) * math.min(1.0, dt * 14);
    if (_bumpT > 0) {
      _bumpT -= dt;
      if (!_bumpHitDone && 1 - _bumpT / _bumpDur >= 0.55) {
        _bumpHitDone = true;
        _onBumpHit?.call();
      }
    }

    switch (mode) {
      case BusMode.grid:
        // Screen ka size badle to bhi sahi jagah par rahe
        pos = l.busCenter(data);
        angle = data.angle;
        unit = l.cell;
      case BusMode.parked:
        // Extra slot khulne par slots khisakte hain, bus aaram se nayi jagah jaye
        final k = math.min(1.0, dt * 12);
        pos = Offset.lerp(pos, l.slotCenters[slot], k)!;
        unit += (l.slotUnitFor(data.length) - unit) * k;
        angle = _lerpAngle(angle, GameLayout.bayAngle, k);
      case BusMode.driving:
      case BusMode.flying:
        _advance(dt, l.slotUnitFor(data.length));
      case BusMode.departing:
        _updateDepart(dt, l);
    }
    _updateFeel(dt);
  }

  /// Mod ki tezi se jhukao, raftaar ke badlao se aage/peeche dabna
  void _updateFeel(double dt) {
    if (dt <= 0) return;
    // Taiy ki hui doori / pahiye ka radius (0.16 unit) = ghoomne ka angle
    if (unit > 0) {
      _wheelPhase += (pos - _wheelPrev).distance / unit / 0.16;
    }
    _wheelPrev = pos;
    final driving = mode == BusMode.driving || mode == BusMode.departing;
    var leanTarget = 0.0;
    var pitchTarget = 0.0;
    if (driving) {
      final turn = math.atan2(
        math.sin(angle - _prevAngle),
        math.cos(angle - _prevAngle),
      );
      leanTarget = (turn / dt * 0.035).clamp(-0.09, 0.09);
      final speed = mode == BusMode.driving
          ? (_dist - _prevDist) / dt / math.max(unit, 1)
          : 0.0;
      final accel = (speed - _prevSpeed) / dt;
      _prevSpeed = speed;
      // Raftaar badhe to peeche (lamba), brake par aage (chhota)
      pitchTarget = (accel * 0.0009).clamp(-0.035, 0.035);
    } else {
      _prevSpeed = 0;
    }
    final k = math.min(1.0, dt * 10);
    _lean += (leanTarget - _lean) * k;
    _pitch += (pitchTarget - _pitch) * k;
    _prevAngle = angle;
    _prevDist = _dist;
  }

  double _smokeT = 0;

  // Rawangi: reverse (bay se bahar) aur phir aage sadak par
  double _driveT = 0;
  double _exitSign = 1;
  Offset _revFrom = Offset.zero;
  Offset _revTo = Offset.zero;
  double _revAngle = 0;
  static const double _reverseDur = 0.38;

  void _updateDepart(double dt, GameLayout l) {
    if (_departT < 1) {
      // 1) Reverse: aahista peeche, aur peechla hissa nikalne ki taraf ghoomta hai
      _departT = math.min(1.0, _departT + dt / _reverseDur);
      final e = _departT * _departT * (3 - 2 * _departT);
      pos = Offset.lerp(_revFrom, _revTo, e)!;
      angle = _revAngle + _exitSign * 0.55 * e;
      if (_departT >= 1) _finish(); // slot ab khaali
      return;
    }
    // 2) Aage: sadak ke rukh mein mud kar raftaar pakdo
    _driveT += dt;
    angle = _lerpAngle(angle, _exitSign * math.pi / 2, math.min(1.0, dt * 7));
    final v = unit * (1.5 + 26 * _driveT);
    pos = Offset(
      pos.dx + math.sin(angle) * v * dt,
      pos.dy -
          math.cos(angle) * v * dt +
          (l.laneY - pos.dy) * math.min(1.0, dt * 5),
    );
    _smokeT -= dt;
    if (_smokeT <= 0) {
      _smokeT = 0.06;
      final back = BusPainter.bodyLength(unit, data.length) / 2;
      game.add(
        SmokePuff(
          pos.translate(-math.sin(angle) * back, math.cos(angle) * back),
          unit * 0.3,
        ),
      );
    }
    final margin = BusPainter.bodyLength(unit, data.length);
    if (pos.dx < -margin || pos.dx > l.width + margin) removeFromParent();
  }

  /// Toote hue raste (seedhi lakeeren) ke kone gol karo: har kone par
  /// [radius] pehle se baad tak ek narm mod (quadratic curve)
  static List<Offset> _smoothPath(List<Offset> pts, double radius) {
    if (pts.length < 3) return pts;
    final out = <Offset>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      final a = pts[i - 1], c = pts[i], b = pts[i + 1];
      final inLen = (c - a).distance, outLen = (b - c).distance;
      if (inLen == 0 || outLen == 0) continue;
      final r = math.min(radius, math.min(inLen, outLen) * 0.45);
      final p0 = c - (c - a) / inLen * r;
      final p2 = c + (b - c) / outLen * r;
      out.add(p0);
      for (var k = 1; k <= 8; k++) {
        final t = k / 8;
        final u = 1 - t;
        out.add(p0 * (u * u) + c * (2 * u * t) + p2 * (t * t));
      }
    }
    out.add(pts.last);
    return out;
  }

  void _advance(double dt, double endUnit) {
    // Pehle halka sa dab kar uchhlo, phir chalo
    if (_squashT > 0) {
      _squashT -= dt;
      return;
    }
    _elapsed += dt;
    // Peeche se dhuaan (sirf sadak par chalte waqt, helicopter mein nahi)
    _smokeT -= dt;
    if (mode == BusMode.driving && _smokeT <= 0) {
      _smokeT = 0.05;
      final back = BusPainter.bodyLength(unit, data.length) / 2;
      final tail = pos.translate(
        -math.sin(angle) * back,
        math.cos(angle) * back,
      );
      game.add(SmokePuff(tail, unit * 0.32));
    }
    // Asli driver jaisi raftaar: shuru mein aahista, parking se pehle brake,
    // aur tez mod par thoda dheema
    final start = math.min(1.0, 0.25 + _elapsed * 2.6);
    final brakeDist = unit * 3.2;
    final brake = mode == BusMode.driving
        ? ((_total - _dist) / brakeDist).clamp(0.28, 1.0)
        : 1.0;
    final turn = mode == BusMode.driving
        ? 1 - 0.45 * (_turnAhead().abs() / 1.2).clamp(0.0, 1.0)
        : 1.0;
    _dist = math.min(_total, _dist + _speed * start * brake * turn * dt);
    final progress = _total == 0 ? 1.0 : _dist / _total;

    // Raste par mojooda nuqta aur us hisse ka rukh
    var remaining = _dist;
    var segAngle = angle;
    for (var i = 1; i < _path.length; i++) {
      final a = _path[i - 1];
      final b = _path[i];
      final len = (b - a).distance;
      if (len == 0) continue;
      final d = b - a;
      segAngle = math.atan2(d.dx, -d.dy);
      if (remaining <= len || i == _path.length - 1) {
        pos = Offset.lerp(a, b, (remaining / len).clamp(0.0, 1.0))!;
        break;
      }
      remaining -= len;
    }

    if (mode == BusMode.flying) {
      unit = _startUnit + (endUnit - _startUnit) * progress;
      angle = _lerpAngle(angle, GameLayout.bayAngle, math.min(1.0, dt * 4));
      _lift = 1 + 0.35 * math.sin(math.pi * progress);
      _rotor += dt * 25;
    } else {
      // Slot ke qareeb aakar chhoti ho jaye
      final shrink = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);
      unit = _startUnit + (endUnit - _startUnit) * shrink;
      angle = _lerpAngle(angle, segAngle, math.min(1.0, dt * 14));
    }

    if (_dist >= _total) {
      pos = _path.last;
      angle = GameLayout.bayAngle;
      unit = endUnit;
      _lift = 1;
      mode = BusMode.parked;
      priority = 5;
      _landT = _landDur;
      _finish();
    }
  }

  /// Aage (thodi door) raste ka mod kitna tez hai: abhi ke rukh aur aage ke
  /// rukh ka farq (radians)
  double _turnAhead() {
    final ahead = _dist + unit * 1.6;
    var remaining = ahead;
    for (var i = 1; i < _path.length; i++) {
      final a = _path[i - 1];
      final b = _path[i];
      final len = (b - a).distance;
      if (len == 0) continue;
      if (remaining <= len || i == _path.length - 1) {
        final d = b - a;
        final h = math.atan2(d.dx, -d.dy);
        return math.atan2(math.sin(h - angle), math.cos(h - angle));
      }
      remaining -= len;
    }
    return 0;
  }

  void _finish() {
    final cb = _onDone;
    _onDone = null;
    cb?.call();
  }

  /// Sab se chhota rasta le kar angle badalna
  static double _lerpAngle(double from, double to, double t) {
    final diff = math.atan2(math.sin(to - from), math.cos(to - from));
    return from + diff * t;
  }

  int get _filledSeats {
    if (slot < 0) return 0;
    if (mode == BusMode.departing) return data.capacity;
    final slots = game.model.slots;
    if (slot >= slots.length) return 0;
    final s = slots[slot];
    return s != null && s.bus.id == data.id ? s.filled : 0;
  }

  @override
  void render(Canvas canvas) {
    var offset = pos;
    if (mode == BusMode.grid && _bumpT > 0) {
      final b = _bumpOffset;
      offset = offset.translate(data.fx * b, data.fy * b);
    }
    if (_shakeT > 0) {
      // Aage peeche hilna (jidhar munh hai)
      final amp = unit * 0.09 * (_shakeT / _shakeDur);
      final s = math.sin(_shakeT * 60) * amp;
      offset = offset.translate(data.fx * s, data.fy * s);
    }
    var scale = _lift;
    if (_popT > 0) {
      scale *= 1 + 0.18 * math.sin(math.pi * (1 - _popT / _popDur));
    }
    if (_squashT > 0) {
      // Pehle dabna, phir thoda phoolna
      final u = 1 - _squashT / _squashDur;
      scale *= u < 0.5 ? 1 - 0.14 * (u / 0.5) : 0.86 + 0.24 * ((u - 0.5) / 0.5);
    }
    if (_landT > 0) {
      scale *= 1 + 0.14 * math.sin(math.pi * (1 - _landT / _landDur));
    }
    if (_boardT > 0) {
      // Sawari baithi: suspension halka sa dabta hai
      scale *= 1 - 0.035 * math.sin(math.pi * (1 - _boardT / _boardDur));
    }

    final sprite = SpriteBank.instance.vehicle(data.length, data.color, angle);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (sprite != null) {
      if (SpriteBank.instance.usesNativeVehicles) {
        canvas.save();
        canvas.scale(scale);
        canvas.translate(unit * .04, unit * .10);
        canvas.scale(1, math.cos(SpriteBank.tilt));
        canvas.rotate(angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: unit * .80,
              height: BusPainter.bodyLength(unit, data.length),
            ),
            Radius.circular(unit * .15),
          ),
          Paint()
            ..color = const Color(0x350F1F35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .10),
        );
        canvas.restore();
      }
      // 3D tasveer: sahi rukh wali tasveer, bacha hua chhota angle ghuma kar
      final img = sprite.image;
      final size = SpriteBank.vehicleFrameUnits(data.length) * unit;
      // Ek-rukh wali tasveer: gaadi ki lambai ke barabar, shakal ke tanasub se
      final Rect dst;
      if (sprite.directional) {
        dst = Rect.fromCenter(center: Offset.zero, width: size, height: size);
      } else {
        final h = BusPainter.bodyLength(unit, data.length) * 1.06;
        dst = Rect.fromCenter(
          center: Offset.zero,
          width: h * img.width / img.height,
          height: h,
        );
      }
      canvas.save();
      canvas.scale(scale);
      if (_pitch.abs() > 0.001) {
        // Gaadi ki lambai ke rukh mein halka khinchao/dabao
        canvas.rotate(angle);
        canvas.scale(1, 1 + _pitch);
        canvas.rotate(-angle);
      }
      canvas.rotate(sprite.rotation + _lean);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        SpriteBank.paint,
      );
      if (_flashT > 0) {
        // Laal chamak (sirf gaadi ki shakal par)
        // Do dafa laal chamak
        final a = (math.sin(_flashT / _flashDur * math.pi * 2)).abs() * 0.8;
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          dst,
          Paint()
            ..colorFilter = ColorFilter.mode(
              Color.fromRGBO(255, 40, 40, a),
              BlendMode.srcATop,
            ),
        );
      }
      canvas.restore();
      if (mode == BusMode.driving || mode == BusMode.departing) {
        canvas.save();
        canvas.scale(scale);
        canvas.rotate(_lean);
        _paintWheelSpin(canvas);
        canvas.restore();
      }
      if (mode == BusMode.flying) {
        canvas.save();
        canvas.translate(0, -unit * 0.6);
        canvas.rotate(angle);
        BusPainter.rotor(
          canvas,
          unit * BusPainter.widthFactor,
          BusPainter.bodyLength(unit, data.length),
          _rotor % (2 * math.pi),
        );
        canvas.restore();
      }
      if (_door > 0.02 && slot >= 0) _paintDoor(canvas, scale);
      // Bay mein: kitni seats baaki hain
      if (slot >= 0 && mode == BusMode.parked) {
        _seatBadge(canvas, size);
      }
    } else {
      canvas.rotate(angle);
      canvas.scale(scale);
      BusPainter.paint(
        canvas,
        color: GamePalette.bus(data.color),
        colorIndex: data.color,
        unit: unit,
        length: data.length,
        capacity: data.capacity,
        filled: _filledSeats,
        showSeats: slot >= 0,
        rotorAngle: mode == BusMode.flying ? _rotor % (2 * math.pi) : -1,
      );
    }
    canvas.restore();
  }

  /// Camera ki taraf wale pahiyon par ghoomte spoke (rim ki chamak). Jagah
  /// Blender model jaisi: x = +-0.45, z = 0.16, aur aage/peeche ke dhure.
  void _paintWheelSpin(Canvas canvas) {
    final f = Offset(math.sin(angle), -math.cos(angle));
    final r = Offset(math.cos(angle), math.sin(angle));
    final cosT = math.cos(SpriteBank.tilt);
    final sinT = math.sin(SpriteBank.tilt);
    // Gaadi ke apne nuqte (x side, y aage, z oonchai) se screen par
    Offset project(double x, double y, double z) {
      final p = r * x + f * y;
      return Offset(p.dx, p.dy * cosT - z * sinT) * unit;
    }

    final l = data.length - 0.12;
    final axles = [
      l / 2 - 0.30,
      -l / 2 + 0.30,
      if (data.length >= 4) -l / 2 + 0.72,
    ];
    final paint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = math.max(1.0, unit * 0.03)
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      // Sirf woh taraf jo camera (screen ke neeche) ki taraf ho
      if ((r * side).dy < 0.15) continue;
      final x = side * 0.45;
      for (final y in axles) {
        final hub = project(x, y, 0.16);
        for (var k = 0; k < 3; k++) {
          final a = -_wheelPhase + k * 2 * math.pi / 3;
          final tip = project(
            x,
            y + math.cos(a) * 0.085,
            0.16 + math.sin(a) * 0.085,
          );
          canvas.drawLine(hub, tip, paint);
        }
      }
    }
  }

  /// Aage ki taraf darwaza: khulte waqt andar ki peeli roshni chaudi hoti hai
  void _paintDoor(Canvas canvas, double scale) {
    final l = game.layout;
    if (slot >= l.slotCenters.length) return;
    // Darwaze ki jagah (layout.doorOf) gaadi ke apne nuqte ke hisaab se
    final local = (l.doorOf(slot) - pos) * scale;
    canvas.save();
    canvas.translate(local.dx, local.dy);
    canvas.rotate(angle);
    final w = unit * 0.5 * _door;
    final h = unit * 0.2;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w + 2, height: h),
      Radius.circular(h * 0.35),
    );
    canvas.drawRRect(
      r.inflate(unit * 0.08),
      Paint()
        ..color = Color.fromRGBO(255, 214, 102, 0.35 * _door)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.1),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFFFFE08A));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xCC2B3A55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  /// Bay ke neeche gaadi ke rang wala label: kitni seats abhi baaki hain
  void _seatBadge(Canvas canvas, double size) {
    final left = data.capacity - _filledSeats;
    final tp = TextPainter(
      text: TextSpan(
        text: '$left',
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: unit * 0.42,
          fontWeight: FontWeight.w900,
          fontFamily: 'Lilita',
          shadows: const [
            Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final c = Offset(0, game.layout.bayH * 0.68);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c,
        width: math.max(tp.width + unit * 0.4, unit * 0.9),
        height: tp.height + unit * 0.06,
      ),
      Radius.circular(unit * 0.15),
    );
    canvas.drawRRect(r, Paint()..color = GamePalette.bus(data.color));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }
}
