import 'package:flutter/material.dart';

/// Color tokens. Hierarchy comes from value steps, not shadows (Uber Base dark).
/// Violet is reserved for the agent: confidence, live state, the one primary CTA.
abstract final class AppColors {
  static const bg = Color(0xFF07080C);
  static const surface1 = Color(0xFF0F1117);
  static const surface2 = Color(0xFF171A23);
  static const surface3 = Color(0xFF21252F);
  static const logBg = Color(0xFF0B0C11);
  static const divider = Color(0xFF1B1E28);
  static const outline = Color(0xFF2A2E3A);
  static const handle = Color(0xFF3A3F4E);

  static const text = Color(0xFFECEEF4);
  static const textSecondary = Color(0xFFC4C8D4);
  static const textMuted = Color(0xFF9AA0B2);
  static const textFaint = Color(0xFF8F95A8);
  static const textGhost = Color(0xFF6F768A);

  static const accent = Color(0xFF8B5CF6);
  static const accentStrong = Color(0xFF7445E6);
  static const accentText = Color(0xFFB9A2FF);
  static const onInverse = Color(0xFF5B2FD0);

  static const critical = Color(0xFFDE5B5D);
  static const criticalText = Color(0xFFF07B7D);
  static const warning = Color(0xFFC79A3A);
  static const warningText = Color(0xFFD6AD55);
  static const ok = Color(0xFF5C9D70);
  static const okText = Color(0xFF74B888);
  static const info = Color(0xFF5E8BDB);
  static const infoText = Color(0xFF8FB0EA);
}

abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

abstract final class Radii {
  static const control = 12.0;
  static const card = 16.0;
  static const panel = 20.0;
  static const sheet = 28.0;
  static const pill = 99.0;
}

/// Motion tokens: Material 3 durations/easing (exact) and M3 spring pairs.
abstract final class Motion {
  static const press = Durations.short4; // 200ms
  static const enter = Durations.medium4; // 400ms
  static const exit = Durations.short4; // 200ms
  static const tab = Durations.medium2; // 300ms
  static const transform = Durations.long1; // 450ms
  static const fadeIn = Durations.short3; // 150ms
  static const fadeOut = Duration(milliseconds: 75);

  static const standard = Easing.standard;
  static const decelerate = Easing.emphasizedDecelerate;
  static const accelerate = Easing.emphasizedAccelerate;

  /// Small overshoot for indicators and toggles.
  static const playful = Cubic(0.25, 1.1, 0.4, 1.0);

  /// M3 DefaultSpatial: bottom sheets and the mini-player release.
  static final sheetSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.9);

  /// M3 FastSpatial: buttons and switches.
  static final fastSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1400, ratio: 0.9);
}
