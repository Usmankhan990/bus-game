import 'package:flutter/material.dart';

import '../models/booster_type.dart';
import '../services/ad_service.dart';
import '../services/progress_service.dart';
import '../ui/candy_button.dart';
import '../ui/coin_pill.dart';
import '../ui/game_popup.dart';
import '../ui/theme.dart';
import 'booster_bar.dart';

String boosterDescription(BoosterType t) => switch (t) {
  BoosterType.vip => 'Pick any vehicle and send it straight to the golden VIP spot, even if its road is blocked.',
  BoosterType.sort =>
    'Passengers who match a parked vehicle move to the front of the line.',
  BoosterType.shuffle =>
    'Mix up the colors of the vehicles in the parking lot.',
};

/// Band slot kholne ki qeemat (coins)
const int unlockSlotPrice = 150;

/// Booster khatam ho jaye to yeh popup: coins se khareedein ya ad dekh kar free.
/// Booster mil gaya (ginti mein jud gaya) to true.
Future<bool> showBoosterShop(BuildContext context, BoosterType type) async {
  final got = await _showOffer(
    context,
    title: type.title,
    icon: boosterIcon(type),
    color: boosterColor(type),
    description: boosterDescription(type),
    price: type.price,
  );
  if (got) ProgressService.instance.addBooster(type);
  return got;
}

/// Band ("+") slot kholne ka popup. Khul gaya to true.
Future<bool> showUnlockSlotDialog(BuildContext context) => _showOffer(
  context,
  title: 'Extra Slot',
  icon: Icons.local_parking_rounded,
  color: AppColors.green,
  description: 'Unlock one more parking spot for this level.',
  price: unlockSlotPrice,
);

Future<bool> _showOffer(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Color color,
  required String description,
  required int price,
}) async {
  final result = await showGamePopup<bool>(
    context,
    (context) => _OfferPopup(
      title: title,
      icon: icon,
      color: color,
      description: description,
      price: price,
    ),
  );
  return result ?? false;
}

class _OfferPopup extends StatefulWidget {
  const _OfferPopup({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.price,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final int price;

  @override
  State<_OfferPopup> createState() => _OfferPopupState();
}

class _OfferPopupState extends State<_OfferPopup> {
  bool _busy = false;

  void _buy() {
    if (ProgressService.instance.spendCoins(widget.price)) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _watchAd() async {
    setState(() => _busy = true);
    final earned = await AdService.instance.showRewarded();
    if (!mounted) return;
    if (earned) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = ProgressService.instance.coins >= widget.price;
    return GamePopup(
      title: widget.title,
      ribbonColor: widget.color,
      onClose: _busy ? null : () => Navigator.of(context).pop(false),
      content: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darker(widget.color, 0.4),
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        PopupText(widget.description),
      ],
      footer: [
        CandyButton.secondary(
          label: canAfford ? '${widget.price}' : 'Not enough coins',
          leading: const CoinIcon(size: 28),
          fontSize: 22,
          height: 54,
          onPressed: canAfford && !_busy ? _buy : null,
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<bool>(
          valueListenable: AdService.instance.rewardedReady,
          builder: (context, ready, _) => CandyButton.primary(
            label: _busy
                ? 'Loading ad...'
                : ready
                ? 'Free'
                : 'Ad not available',
            icon: Icons.play_circle_fill_rounded,
            fontSize: 22,
            height: 54,
            onPressed: ready && !_busy ? _watchAd : null,
          ),
        ),
      ],
    );
  }
}
