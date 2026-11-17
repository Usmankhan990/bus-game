import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/render/sprite_bank.dart';
import '../models/vehicle_skin.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../ui/candy_button.dart';
import '../ui/game_popup.dart';
import '../ui/theme.dart';

/// Garage: stars se khaas gaadiyan kholo aur chuno
Future<void> showGarage(BuildContext context) => showGamePopup<void>(
  context,
  (context) => GamePopup(
    title: 'Garage',
    ribbonColor: AppColors.blue,
    onClose: () => Navigator.of(context).pop(),
    maxWidth: 420,
    content: const [_GarageBody()],
  ),
);

class _GarageBody extends StatelessWidget {
  const _GarageBody();

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final h = MediaQuery.sizeOf(context).height;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kitne stars hain
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 26),
                const SizedBox(width: 6),
                Text('${progress.stars}', style: AppText.title(22)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const PopupText('Win levels to earn stars and unlock new rides!'),
          const SizedBox(height: 8),
          SizedBox(
            height: (h * 0.5).clamp(260.0, 560.0),
            child: GridView.count(
              // Dialog ke andar screen ki (status bar) padding na lagao
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
              children: [
                for (final s in VehicleSkin.values) _SkinCard(skin: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatefulWidget {
  const _SkinCard({required this.skin});
  final VehicleSkin skin;

  @override
  State<_SkinCard> createState() => _SkinCardState();
}

class _SkinCardState extends State<_SkinCard> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    SpriteBank.instance.skinPreview(widget.skin).then((img) {
      if (mounted) setState(() => _img = img);
    });
  }

  Future<void> _tap() async {
    final p = ProgressService.instance;
    final s = widget.skin;
    if (!p.unlockedSkins.contains(s)) {
      if (!p.unlockSkin(s)) return;
      AudioService.instance.play(Sfx.gift);
    } else {
      p.selectSkin(s);
    }
    // Chuni hui gaadi ki saari tasveerein abhi load kar lo
    if (p.selectedSkins[s.length] == s) {
      await SpriteBank.instance.loadSkin(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final s = widget.skin;
    final unlocked = p.unlockedSkins.contains(s);
    final inUse = p.selectedSkins[s.length] == s;
    final affordable = p.stars >= s.cost;
    final kind = switch (s.length) {
      2 => 'Car',
      3 => 'Van',
      _ => 'Bus',
    };

    final Widget button;
    if (!unlocked) {
      button = CandyButton(
        height: 38,
        fontSize: 18,
        color: affordable ? AppColors.green : AppColors.grey,
        leading: const Icon(Icons.star_rounded, color: AppColors.gold),
        label: '${s.cost}',
        onPressed: affordable ? _tap : null,
      );
    } else {
      button = CandyButton(
        height: 38,
        fontSize: 18,
        color: inUse ? AppColors.orange : AppColors.blue,
        label: inUse ? 'Equipped' : 'Use',
        onPressed: _tap,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: inUse
              ? const [Color(0xFFFFF6DD), Color(0xFFFFE7A8)]
              : unlocked
              ? const [Colors.white, Color(0xFFEAF3FC)]
              : const [Color(0xFFF1F4F8), Color(0xFFDDE4EC)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: inUse ? AppColors.orange : AppColors.creamLine,
          width: inUse ? 3 : 2,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_img != null)
                  // Tasveer mein gaadi ke gird khaali jagah hai, is liye bara karke kaato
                  ClipRect(
                    child: Transform.scale(
                      scale: 1.55,
                      child: Opacity(
                        opacity: unlocked ? 1 : 0.55,
                        child: RawImage(image: _img, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                if (!unlocked)
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xCC2B3A55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                // Chuni hui gaadi par hara "tick" badge
                if (inUse)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              s.title,
              style: AppText.title(18, color: AppColors.ink, outlined: false),
            ),
          ),
          Text(
            '$kind · ${s.seats} seats',
            style: AppText.text(13, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 6),
          button,
        ],
      ),
    );
  }
}
