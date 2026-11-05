import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../config/app_config.dart';
import '../ui/candy_button.dart';
import '../ui/game_popup.dart';
import '../ui/theme.dart';

/// Settings popup kholna (Home screen se)
Future<void> showSettings(BuildContext context) => showGamePopup<void>(
  context,
  (context) => SettingsPanel(onClose: () => Navigator.of(context).pop()),
);

/// Settings: Music, Sound, Vibration ke hare toggle.
/// Game ke andar ho to neeche Home (narangi) aur Restart (hara).
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.onClose,
    this.onHome,
    this.onRestart,
    this.inline = false,
  });

  final VoidCallback onClose;
  final VoidCallback? onHome;
  final VoidCallback? onRestart;

  /// Screen ke andar (dialog ke baghair): khud peeche dim aur pop animation
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => GamePopup(
        title: 'Settings',
        ribbonColor: AppColors.blue,
        dim: inline,
        animate: inline,
        onClose: onClose,
        content: [
          _ToggleRow(
            icon: Icons.music_note_rounded,
            label: 'Music',
            value: p.musicOn,
            onChanged: p.setMusic,
          ),
          const Divider(color: AppColors.creamLine, height: 8),
          _ToggleRow(
            icon: Icons.volume_up_rounded,
            label: 'Sound',
            value: p.soundOn,
            onChanged: p.setSound,
          ),
          const Divider(color: AppColors.creamLine, height: 8),
          _ToggleRow(
            icon: Icons.vibration_rounded,
            label: 'Vibration',
            value: p.vibrationOn,
            onChanged: p.setVibration,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Made by ${AppConfig.studioName} · v${AppConfig.version}',
              style: AppText.text(13, color: AppColors.inkMuted),
            ),
          ),
        ],
        footer: [
          if (onHome != null || onRestart != null)
            Row(
              children: [
                if (onHome != null)
                  Expanded(
                    child: CandyButton.secondary(
                      label: 'Home',
                      height: 54,
                      fontSize: 22,
                      onPressed: onHome,
                    ),
                  ),
                if (onHome != null && onRestart != null)
                  const SizedBox(width: 12),
                if (onRestart != null)
                  Expanded(
                    child: CandyButton.primary(
                      label: 'Restart',
                      height: 54,
                      fontSize: 22,
                      onPressed: onRestart,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          // Icon halke neele chaukor mein
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F1FD),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.blue, size: 26),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              label,
              style: AppText.title(21, color: AppColors.ink, outlined: false),
            ),
          ),
          CandySwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Hara/grey gol toggle switch (tap sound + haptic)
class CandySwitch extends StatelessWidget {
  const CandySwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.play(Sfx.button);
        HapticService.instance.select();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 66,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.green : AppColors.grey,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: value ? AppColors.greenDark : AppColors.greyDark,
            width: 2,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x44000000), offset: Offset(0, 2)),
              ],
            ),
            child: Icon(
              value ? Icons.check_rounded : Icons.close_rounded,
              size: 18,
              color: value ? AppColors.greenDark : AppColors.greyDark,
            ),
          ),
        ),
      ),
    );
  }
}
