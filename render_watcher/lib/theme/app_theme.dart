import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

abstract final class AppText {
  static TextStyle mono({
    double size = 12,
    Color color = AppColors.textMuted,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size, color: color, fontWeight: weight, height: height);

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: AppColors.textMuted,
  );
}

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentStrong,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        surface: AppColors.surface1,
        onSurface: AppColors.text,
        error: AppColors.critical,
        outline: AppColors.outline,
      ),
    );
    final text = base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.2),
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineSmall: text.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
        titleLarge: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: text.bodyMedium
            ?.copyWith(color: AppColors.textMuted, height: 1.45),
      ),
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.white.withValues(alpha: 0.06),
      splashColor: Colors.white.withValues(alpha: 0.10),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.divider, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.accentStrong
                : AppColors.outline),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surface3,
        thumbColor: AppColors.accent,
        overlayColor: Color(0x338B5CF6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface1,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.handle,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.textGhost),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x558B5CF6),
        selectionHandleColor: AppColors.accent,
      ),
    );
  }
}
