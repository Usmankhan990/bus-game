import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/progress_service.dart';
import 'theme.dart';

/// Upar baayen coins ki pill: sikka, ginti aur hara "+" (dabane par [onPlus]).
/// Coins badalne par khud update hoti hai.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, this.onPlus, this.iconKey});

  final VoidCallback? onPlus;

  /// Udte coins ki manzil (Win screen par coins yahan tak udte hain)
  final GlobalKey? iconKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProgressService.instance,
      builder: (context, _) => GestureDetector(
        onTap: onPlus == null
            ? null
            : () {
                AudioService.instance.play(Sfx.button, volume: 0.6);
                onPlus!();
              },
        child: SizedBox(
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(left: 16, top: 6, bottom: 4),
                padding: EdgeInsets.fromLTRB(
                  28,
                  0,
                  onPlus == null ? 14 : 34,
                  0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.creamLine, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), offset: Offset(0, 3)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${ProgressService.instance.coins}',
                  style: AppText.title(
                    19,
                    outlined: false,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 2,
                child: CoinIcon(key: iconKey, size: 38),
              ),
              if (onPlus != null)
                Positioned(
                  right: 4,
                  top: 11,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 18,
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

/// Code se bana chamakdar sikka
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF2A8), AppColors.coin, AppColors.coinDark],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: const Color(0xFFB87800), width: size * 0.07),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '\$',
        style: TextStyle(
          fontFamily: AppText.display,
          fontSize: size * 0.58,
          color: const Color(0xFFB87800),
          height: 1,
        ),
      ),
    );
  }
}
