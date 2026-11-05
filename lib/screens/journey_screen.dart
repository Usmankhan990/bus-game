import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/city.dart';
import '../services/progress_service.dart';
import '../ui/candy_button.dart';
import '../ui/flag_icon.dart';
import '../ui/game_popup.dart';
import '../ui/theme.dart';

/// Shehar ki 3D nishani (`assets/sprites/city_<id>.png`)
class CityImage extends StatelessWidget {
  const CityImage(this.city, {super.key, this.size = 120, this.locked = false});
  final City city;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      'assets/sprites/city_${city.id}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
    if (locked) {
      // Band shehar: halka aur rang ke baghair
      img = Opacity(
        opacity: 0.8,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: img,
        ),
      );
    }
    return img;
  }
}

/// Safar ka map: saare shehar ek raaste par, neeche se upar. Mukammal shehar
/// par tick, mojooda shehar par bus aur progress, aage wale band.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  static const double _rowH = 240;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mojooda shehar screen ke beech mein
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final current = City.of(ProgressService.instance.level);
      final fromTop = (City.values.length - 1 - current.index) * _rowH;
      final target = fromTop - _scroll.position.viewportDimension / 2 + _rowH;
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = ProgressService.instance.level;
    final current = City.of(level);
    final tour = City.tourOf(level);
    final cities = City.values.reversed.toList(); // upar aakhri shehar
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6EC6F5), Color(0xFFB9E8FF), Color(0xFFDDF3C8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: [
                    CandyIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 46,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('My Journey', style: AppText.title(30)),
                          if (tour > 1)
                            Text('World Tour $tour', style: AppText.title(16)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 46),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CustomPaint(
                    painter: _PathPainter(count: cities.length, rowH: _rowH),
                    child: Column(
                      children: [
                        for (var i = 0; i < cities.length; i++)
                          SizedBox(
                            height: _rowH,
                            child: _CityNode(
                              city: cities[i],
                              current: current,
                              level: level,
                              tour: tour,
                              left: i.isEven,
                            ),
                          ),
                      ],
                    ),
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

/// Shehron ko jodne wala nuqton wala raasta (zig-zag)
class _PathPainter extends CustomPainter {
  _PathPainter({required this.count, required this.rowH});
  final int count;
  final double rowH;

  Offset _node(int i, Size s) =>
      Offset(i.isEven ? s.width * 0.3 : s.width * 0.7, rowH * (i + 0.42));

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(_node(0, size).dx, _node(0, size).dy);
    for (var i = 1; i < count; i++) {
      final a = _node(i - 1, size);
      final b = _node(i, size);
      path.cubicTo(
        a.dx,
        (a.dy + b.dy) / 2,
        b.dx,
        (a.dy + b.dy) / 2,
        b.dx,
        b.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 22) {
        final p = m.getTangentForOffset(d)!.position;
        canvas.drawCircle(p, 3.5, Paint()..color = const Color(0xFFF2A93B));
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.count != count;
}

class _CityNode extends StatelessWidget {
  const _CityNode({
    required this.city,
    required this.current,
    required this.level,
    required this.tour,
    required this.left,
  });
  final City city;
  final City current;
  final int level;
  final int tour;
  final bool left;

  @override
  Widget build(BuildContext context) {
    final done = city.index < current.index;
    final here = city == current;
    final locked = city.index > current.index;
    final first = city.firstLevel(tour);
    final progress = City.progressIn(level);

    final status = here
        ? Column(
            children: [
              Text(
                'You are here',
                style: AppText.title(15, color: AppColors.gold),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress / City.levelsPerCity,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$progress / ${City.levelsPerCity}',
                style: AppText.title(14),
              ),
            ],
          )
        : Text(
            done
                ? 'Completed'
                : 'Levels $first–${first + City.levelsPerCity - 1}',
            style: AppText.title(
              15,
              color: done ? AppColors.green : Colors.white,
            ),
          );

    final card = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Gol chabootra
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: locked ? 0.35 : 0.85),
                border: Border.all(
                  color: here ? AppColors.gold : Colors.white,
                  width: here ? 5 : 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
            CityImage(city, size: 136, locked: locked),
            if (locked)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF5B4A7A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            if (here)
              const Positioned(
                top: -18,
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: AppColors.orange,
                  size: 40,
                ),
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlagIcon(city, width: 30),
            const SizedBox(width: 6),
            Text(city.name, style: AppText.title(22)),
          ],
        ),
        status,
      ],
    );

    return Align(alignment: Alignment(left ? -0.42 : 0.42, -0.4), child: card);
  }
}

/// Naye shehar mein pohanchne par (pehla level shuru hone se pehle)
Future<void> showWelcomeCity(BuildContext context, City city) =>
    showGamePopup<void>(
      context,
      (context) => GamePopup(
        title: 'New City!',
        ribbonColor: AppColors.blue,
        content: [
          Center(child: CityImage(city, size: 190)),
          Center(
            child: Text(
              'Welcome to ${city.name}!',
              textAlign: TextAlign.center,
              style: AppText.title(26, color: AppColors.ink, outlined: false),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlagIcon(city, width: 30),
              const SizedBox(width: 8),
              Text(
                city.country,
                style: AppText.text(18, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const PopupText('New streets, new crowds. Let\'s clear the jam!'),
        ],
        footer: [
          CandyButton.primary(
            label: "Let's Go!",
            height: 60,
            fontSize: 26,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

/// Home par shehar ka chhota button (shehar, bandi aur progress)
class CityChip extends StatelessWidget {
  const CityChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = ProgressService.instance.level;
    final city = City.of(level);
    final progress = City.progressIn(level);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: city.accent, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CityImage(city, size: 40),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlagIcon(city, width: 22),
                    const SizedBox(width: 5),
                    Text(
                      city.name,
                      style: AppText.title(
                        16,
                        color: AppColors.ink,
                        outlined: false,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 86,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: math.max(0.04, progress / City.levelsPerCity),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE3E7EF),
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.map_rounded, color: Color(0xFF3B2A6B), size: 22),
          ],
        ),
      ),
    );
  }
}
