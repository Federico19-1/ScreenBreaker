import 'package:flutter/material.dart';

/// A complete, user-editable color scheme for the whole app.
///
/// The four core colors (primary, background, text, accent) are what the user
/// picks in the Appearance section; every other surface in the app is derived
/// from them so the entire interface stays consistent.
@immutable
class AppPalette {
  const AppPalette({
    required this.name,
    required this.primary,
    required this.background,
    required this.text,
    required this.accent,
  });

  final String name;

  /// Buttons, highlights, icons and the seeded Material color scheme.
  final Color primary;

  /// Screen background.
  final Color background;

  /// Primary text color (and text on primary when readable enough).
  final Color text;

  /// Secondary highlight color used in gradients and small accents.
  final Color accent;

  // ---------------------------------------------------------------------------
  // Built-in presets
  // ---------------------------------------------------------------------------

  static const AppPalette violetFuture = AppPalette(
    name: 'Purple Future',
    primary: Color(0xFF9B4DFF),
    background: Color(0xFF0C0A14),
    text: Color(0xFFF6F6FF),
    accent: Color(0xFFFF2ED1),
  );

  static const AppPalette oceanDepths = AppPalette(
    name: 'Ocean Depths',
    primary: Color(0xFF38BDF8),
    background: Color(0xFF0A1420),
    text: Color(0xFFEAF6FF),
    accent: Color(0xFF2DD4BF),
  );

  static const AppPalette emeraldNight = AppPalette(
    name: 'Emerald Night',
    primary: Color(0xFF34D399),
    background: Color(0xFF08130E),
    text: Color(0xFFECFFF5),
    accent: Color(0xFFA3E635),
  );

  static const AppPalette crimsonDusk = AppPalette(
    name: 'Crimson Dusk',
    primary: Color(0xFFFB7185),
    background: Color(0xFF1B0A12),
    text: Color(0xFFFFF1F4),
    accent: Color(0xFFFB923C),
  );

  static const AppPalette desertGold = AppPalette(
    name: 'Desert Gold',
    primary: Color(0xFFF5C542),
    background: Color(0xFF12100A),
    text: Color(0xFFFFFBEA),
    accent: Color(0xFFE0803B),
  );

  static const AppPalette arcticFrost = AppPalette(
    name: 'Arctic Frost',
    primary: Color(0xFF4F46E5),
    background: Color(0xFFF2F4FC),
    text: Color(0xFF121528),
    accent: Color(0xFFDB2777),
  );

  static const List<AppPalette> presets = [
    violetFuture,
    oceanDepths,
    emeraldNight,
    crimsonDusk,
    desertGold,
    arcticFrost,
  ];

  // ---------------------------------------------------------------------------
  // Derived surfaces (kept consistent with whichever colors are active)
  // ---------------------------------------------------------------------------

  bool get isLightBackground => background.computeLuminance() > 0.5;

  /// Card background, slightly offset from the screen background.
  Color get surface => Color.lerp(
    background,
    isLightBackground ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    isLightBackground ? 0.05 : 0.06,
  )!;

  /// Elevated card background (dialogs, dropdowns, snackbars).
  Color get surfaceHigh => Color.lerp(
    background,
    isLightBackground ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    isLightBackground ? 0.10 : 0.13,
  )!;

  /// Border / divider tone between primary and background.
  Color get border => Color.lerp(primary, background, 0.5)!;

  /// Muted (secondary) text, between text and background.
  Color get mutedText => Color.lerp(text, background, 0.38)!;

  /// Text drawn on top of [primary]; falls back to black/white when the text
  /// color would be unreadable on the primary color.
  Color get onPrimary =>
      AppPalette.contrastRatio(text, primary) >= 2.2
      ? text
      : primary.computeLuminance() > 0.4
      ? const Color(0xFF0E0C14)
      : const Color(0xFFFFFFFF);

  Color get success =>
      isLightBackground ? const Color(0xFF0B8F63) : const Color(0xFF5DFFC1);
  Color get warning =>
      isLightBackground ? const Color(0xFFB26A00) : const Color(0xFFFFB547);

  /// Signature primary → accent gradient used for hero moments.
  LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  /// Full-screen gradient for the break screen.
  LinearGradient get breakGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.lerp(background, primary, 0.6)!, primary, accent],
    stops: const [0.0, 0.55, 1.0],
  );

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool sameColorsAs(AppPalette other) =>
      primary == other.primary &&
      background == other.background &&
      text == other.text &&
      accent == other.accent;

  AppPalette copyWith({
    String? name,
    Color? primary,
    Color? background,
    Color? text,
    Color? accent,
  }) {
    return AppPalette(
      name: name ?? this.name,
      primary: primary ?? this.primary,
      background: background ?? this.background,
      text: text ?? this.text,
      accent: accent ?? this.accent,
    );
  }

  /// Guards readability: when the text barely differs from the background the
  /// text is flipped to a near-black/near-white tone instead.
  AppPalette ensureReadable() {
    if (AppPalette.contrastRatio(text, background) >= 2.8) return this;
    return copyWith(
      text: isLightBackground
          ? const Color(0xFF14121C)
          : const Color(0xFFF6F6FF),
    );
  }

  /// WCAG contrast ratio between two colors (1.0 – 21.0).
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'primary': primary.toARGB32(),
    'background': background.toARGB32(),
    'text': text.toARGB32(),
    'accent': accent.toARGB32(),
  };

  static AppPalette fromJson(Map<String, Object?> json) {
    Color color(Object? value, Color fallback) =>
        value is int ? Color(value) : fallback;
    return AppPalette(
      name: json['name'] is String ? json['name'] as String : 'Custom',
      primary: color(json['primary'], violetFuture.primary),
      background: color(json['background'], violetFuture.background),
      text: color(json['text'], violetFuture.text),
      accent: color(json['accent'], violetFuture.accent),
    );
  }
}
