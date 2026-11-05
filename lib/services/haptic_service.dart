import 'package:flutter/services.dart';

/// Halki vibration (haptic). Settings se band ho sakti hai.
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  bool enabled = true;

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void select() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
