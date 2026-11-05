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

/// Game screen ke neeche teen bade booster tiles (VIP, Sort, Shuffle).
/// Har tile par ginti; 0 ho to hara "+" (ad ya coins se lene ke liye).
class BoosterBar extends StatelessWidget {
  const BoosterBar({super.key, required this.onTap, this.active});

  final void Function(BoosterType type) onTap;

  /// Jo booster abhi chalu hai (VIP chunne ka intezar)
  final BoosterType? active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Chhoti screen par tiles chhote
        final size = (c.maxWidth / 4.8).clamp(52.0, 78.0);
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
                  color: active == t ? AppColors.red : const Color(0xFF55B7EB),
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
