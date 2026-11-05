import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/city.dart';
import '../bus_jam_game.dart';
import '../game_layout.dart';
import '../render/board_painter.dart';

/// Upar kul baqi passengers ki ginti: hujoom ke UPAR draw hoti hai (warna
/// log pill ko dhak dete hain)
class CountPillComponent extends Component with HasGameReference<BusJamGame> {
  CountPillComponent() : super(priority: 28);

  @override
  void render(Canvas canvas) {
    final remaining = game.waitingPassengers;
    if (remaining > 0) BoardPainter.countPill(canvas, game.layout, remaining);
  }
}

/// Peeche ka board. Na badalne wala hissa ek dafa "Picture" mein record hota hai
/// (har frame dobara banana mehnga hai); bays aur ginti har frame.
class BoardComponent extends Component with HasGameReference<BusJamGame> {
  BoardComponent() : super(priority: 0);

  Picture? _static;
  GameLayout? _forLayout;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final l = game.layout;
    if (_static == null || !identical(_forLayout, l)) {
      _static?.dispose();
      final rec = PictureRecorder();
      BoardPainter.paintStatic(
        Canvas(rec),
        l,
        city: City.of(game.level.level),
        buses: game.level.buses,
      );
      _static = rec.endRecording();
      _forLayout = l;
    }
    canvas.drawPicture(_static!);
    BoardPainter.paintClouds(canvas, l, _time);
    BoardPainter.paintDynamic(
      canvas,
      l,
      slotUsed: [for (final s in game.model.slots) s != null],
      hasVip: game.model.hasVip,
      stripFlash: game.stripFlash,
    );
  }

  @override
  void onRemove() {
    _static?.dispose();
    _static = null;
    super.onRemove();
  }
}
