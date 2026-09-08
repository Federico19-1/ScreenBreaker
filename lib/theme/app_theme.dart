import 'package:flutter/material.dart';

import '../models/app_palette.dart';
import '../services/customization_service.dart';

/// The app's live colors.
///
/// Every getter returns the value from the *active* [AppPalette] held in
/// [CustomizationService], so the entire interface — text, backgrounds,
/// buttons, gradients and the logo fallback — recolors instantly when the
/// user picks new colors in the Appearance section. All existing call sites
/// (`AppColors.iceWhite`, `AppColors.neonPurple`, …) keep working unchanged;
/// they are simply no longer compile-time constants.
abstract final class AppColors {
  static AppPalette get _p => CustomizationService.palette.value;

  // Legacy names kept for the existing call sites.
  static Color get neonPurple => _p.primary;
  static Color get bluishBlack => _p.background;
  static Color get techMagenta => _p.accent;
  static Color get iceWhite => _p.text;

  // Derived surfaces / tints.
  static Color get surface => _p.surface;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get purpleDim => _p.border;
  static Color get iceDim => _p.mutedText;
  static Color get success => _p.success;
  static Color get warning => _p.warning;

  /// Signature primary → accent gradient used for hero moments.
  static LinearGradient get brandGradient => _p.brandGradient;
}

/// Shared decoration for cards/panels across the app.
BoxDecoration appCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppColors.purpleDim.withValues(alpha: 0.45),
    ),
  );
}

/// The app-wide theme, built from the active [AppPalette]. Rebuilt whenever
/// the palette changes so every Material component follows along.
abstract final class AppTheme {
  static ThemeData dark() {
    final p = CustomizationService.palette.value;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.isLightBackground ? Brightness.light : Brightness.dark,
    ).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: p.onPrimary,
      surface: p.background,
      onSurface: p.text,
      surfaceContainerHighest: p.surface,
      error: const Color(0xFFFF5D6C),
      outline: p.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: p.isLightBackground ? Brightness.light : Brightness.dark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: p.text),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: p.text,
        displayColor: p.text,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.text : p.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.primary
              : p.surfaceHigh,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.border,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.border.withValues(alpha: 0.4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: TextStyle(color: p.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
      ),
    );
  }
}
