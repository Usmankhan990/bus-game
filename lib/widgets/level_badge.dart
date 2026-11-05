import 'package:flutter/material.dart';

import '../models/city.dart';
import '../ui/flag_icon.dart';
import '../ui/theme.dart';

/// Game ke upar beech mein "Level X" ka capsule: baayen shehar ka jhanda,
/// neeche shehar ka naam aur us shehar mein progress ki patli patti.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final city = City.of(level);
    final progress = (City.progressIn(level) + 1) / City.levelsPerCity;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 16, 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: city.accent, width: 2.5),
          boxShadow: AppShadows.hud,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Jhanda gol daire mein
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: city.accent.withValues(alpha: 0.15),
              ),
              child: FlagIcon(city, width: 22),
            ),
            const SizedBox(width: AppSpace.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level $level',
                  style: AppText.title(
                    19,
                    color: AppColors.ink,
                    outlined: false,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      city.name,
                      style: AppText.text(11.5, color: AppColors.inkMuted),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 46,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE3EAF2),
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
