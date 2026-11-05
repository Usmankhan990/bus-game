import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart'
    show Colors, Icons, TextPainter, TextSpan, TextStyle, TextDirection, Shadow;

import '../bus_jam_game.dart';
import '../render/board_painter.dart';

/// Level 1 ka tutorial: nikal sakne wali bus ke gird chamakta daira
/// aur "Bus par tap karein" ka paigham
class HintComponent extends Component with HasGameReference<BusJamGame> {
  HintComponent() : super(priority: 30);

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final bus = game.hintBus;
    if (bus == null) return;
    final l = game.layout;
    final c = l.busCenter(bus);
    final pulse = 0.5 + 0.5 * math.sin(_t * 5);

    canvas.drawCircle(
      c,
      l.cell * (1.15 + 0.15 * pulse),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4 + 0.5 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.cell * 0.09,
    );

    // Ungli ka nishaan neeche se tap karta hua
    final finger = c.translate(l.cell * 0.35, l.cell * (0.6 + 0.15 * pulse));
    _finger(canvas, finger, l.cell * 0.85);

    // Paigham bus ke upar (grid ke andar hi rahe)
    final bubbleW = l.cell * 3.4;
    final g = l.gridRect;
    // Neeche wali sadak par, taa ke koi gaadi na dhake
    final msgPos = Offset(g.center.dx, l.roadRect.bottom - l.road * 0.5);
    final bubble = RRect.fromRectAndRadius(
      Rect.fromCenter(center: msgPos, width: bubbleW, height: l.cell * 0.75),
      Radius.circular(l.cell * 0.4),
    );
    canvas.drawRRect(bubble, Paint()..color = const Color(0xEEFFFFFF));
    BoardPainter.text(
      canvas,
      'Tap a bus!',
      msgPos,
      l.cell * 0.36,
      const Color(0xFF3D3D63),
    );
  }

  /// Material ka "touch" icon (emoji har phone par alag dikhta hai)
  static void _finger(Canvas canvas, Offset center, double size) {
    const icon = Icons.touch_app_rounded;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: Colors.white,
          shadows: const [
            Shadow(
              color: Color(0x992B3A55),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
