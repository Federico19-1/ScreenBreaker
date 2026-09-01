import 'package:flutter/material.dart';

/// ScreenBreaker's visual identity — the "Purple Future" palette.
///
/// * Neon purple  (#9B4DFF) — main color
/// * Bluish black (#0C0A14) — background
/// * Tech magenta (#FF2ED1) — futuristic accents
/// * Ice white    (#F6F6FF) — text and details
abstract final class AppColors {
  // Core palette
  static const Color neonPurple = Color(0xFF9B4DFF);
  static const Color bluishBlack = Color(0xFF0C0A14);
  static const Color techMagenta = Color(0xFFFF2ED1);
  static const Color iceWhite = Color(0xFFF6F6FF);

  // Derived surfaces / tints (kept in the same purple family)
  static const Color surface = Color(0xFF161021); // card background
  static const Color surfaceHigh = Color(0xFF1F1733); // elevated cards
  static const Color purpleDim = Color(0xFF4A2A7A); // borders / muted purple
  static const Color magentaDim = Color(0xFF8A2070); // muted magenta
  static const Color iceDim = Color(0xFF9C94B8); // muted text
  static const Color success = Color(0xFF5DFFC1); // streak / good state
  static const Color warning = Color(0xFFFFB547); // warnings

  /// Signature purple → magenta gradient used for hero moments.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonPurple, techMagenta],
  );
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

/// The app-wide dark theme, built around the "Purple Future" palette.
abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.neonPurple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.neonPurple,
      onPrimary: AppColors.iceWhite,
      secondary: AppColors.techMagenta,
      onSecondary: AppColors.iceWhite,
      surface: AppColors.bluishBlack,
      onSurface: AppColors.iceWhite,
      surfaceContainerHighest: AppColors.surface,
      error: const Color(0xFFFF5D6C),
      outline: AppColors.purpleDim,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bluishBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bluishBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.iceWhite,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.iceWhite),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.iceWhite,
        displayColor: AppColors.iceWhite,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.neonPurple,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.iceWhite
              : AppColors.iceDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.neonPurple
              : AppColors.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonPurple,
          foregroundColor: AppColors.iceWhite,
          disabledBackgroundColor: AppColors.purpleDim,
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
          foregroundColor: AppColors.neonPurple,
          side: const BorderSide(color: AppColors.purpleDim),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.neonPurple,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.purpleDim.withValues(alpha: 0.4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: AppColors.iceWhite),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
