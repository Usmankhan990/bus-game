import 'package:flutter/material.dart';

import '../models/booster_type.dart';
import '../services/progress_service.dart';
import '../ui/icon_tile.dart';
import '../ui/theme.dart';

IconData boosterIcon(BoosterType t) => switch (t) {
  BoosterType.vip => Icons.flight_rounded,
  BoosterType.sort => Icons.groups_rounded,
  BoosterType.shuffle => Icons.shuffle_rounded,
};

Color boosterColor(BoosterType t) => switch (t) {
  BoosterType.vip => AppColors.orange,
  BoosterType.sort => AppColors.blue,
  BoosterType.shuffle => AppColors.purple,
};

/// Game screen ke neeche teen booster tiles (VIP, Sort, Shuffle).
/// Compact size taa ke neeche space kam le aur board/arena ko zyada jagah mile.
class BoosterBar extends StatelessWidget {
  const BoosterBar({super.key, required this.onTap, this.active});

  final void Function(BoosterType type) onTap;

  /// Jo booster abhi chalu hai (VIP chunne ka intezar)
  final BoosterType? active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Chhoti screen par tiles chhote aur compact (Image 2 jaisa)
        final size = (c.maxWidth / 6.8).clamp(44.0, 54.0);
        return ListenableBuilder(
          listenable: ProgressService.instance,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final t in BoosterType.values)
                IconTile(
                  icon: active == t ? Icons.close_rounded : boosterIcon(t),
                  art: active == t ? null : t.key,
                  compact: true,
                  label: t.title,
                  color: active == t ? AppColors.red : boosterColor(t),
                  count: ProgressService.instance.boosterCount(t),
                  active: active == t,
                  size: size,
                  labelColor: Colors.white,
                  onTap: () => onTap(t),
                ),
            ],
          ),
        );
      },
    );
  }
}
