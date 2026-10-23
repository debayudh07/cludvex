import 'package:flutter/services.dart';

import '../data/models.dart';

/// Semantic haptics. Alert haptics are debounced so a storm doesn't buzz
/// the phone continuously.
abstract final class Haptics {
  static DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);

  static void alert(Severity severity) {
    final now = DateTime.now();
    if (now.difference(_lastAlert) < const Duration(seconds: 2)) return;
    _lastAlert = now;
    switch (severity) {
      case Severity.critical:
        HapticFeedback.errorNotification();
      case Severity.warning:
        HapticFeedback.warningNotification();
      case Severity.info:
      case Severity.resolved:
        HapticFeedback.lightImpact();
    }
  }

  static void success() => HapticFeedback.successNotification();
  static void error() => HapticFeedback.errorNotification();
  static void selection() => HapticFeedback.selectionClick();
  static void heavy() => HapticFeedback.heavyImpact();
  static void light() => HapticFeedback.lightImpact();
}
