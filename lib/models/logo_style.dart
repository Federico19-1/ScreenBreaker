import 'package:flutter/material.dart';

/// The logo variants offered in the "Logos" section of the Appearance screen.
///
/// Every variant is drawn with Flutter primitives (icons + custom painters) so
/// its colors can be recolored live with a single tap — no asset regeneration
/// needed.
enum LogoVariant {
  shield(label: 'Shield', hint: 'The classic rounded app icon'),
  bolt(label: 'Bolt', hint: 'Fast, energetic mark'),
  hourglass(label: 'Hourglass', hint: 'Time slipping away'),
  leaf(label: 'Leaf', hint: 'Grow, unplug, breathe'),
  ring(label: 'Halo', hint: 'Minimal circular ring'),
  pause(label: 'Pause', hint: 'Take a break, press pause');

  const LogoVariant({required this.label, required this.hint});

  final String label;
  final String hint;

  /// The Material icon drawn inside the rounded tile for [shield]-like
  /// variants; null for purely painter-drawn ones.
  IconData? get icon => switch (this) {
    LogoVariant.bolt => Icons.bolt_rounded,
    LogoVariant.hourglass => Icons.hourglass_bottom_rounded,
    LogoVariant.leaf => Icons.spa_rounded,
    LogoVariant.pause => Icons.pause_rounded,
    _ => null,
  };
}

/// The user's logo choice: which variant is drawn and with which colors.
@immutable
class LogoStyle {
  const LogoStyle({
    required this.variant,
    required this.background,
    required this.foreground,
    required this.glow,
  });

  final LogoVariant variant;

  /// The rounded tile behind the glyph.
  final Color background;

  /// The glyph itself.
  final Color foreground;

  /// Subtle outer glow / border tone.
  final Color glow;

  /// Default style for a variant, derived from the active app palette so a
  /// fresh logo always matches the theme.
  factory LogoStyle.forVariant(
    LogoVariant variant, {
    required Color primary,
    required Color accent,
    required Color text,
  }) {
    return LogoStyle(
      variant: variant,
      background: primary,
      foreground: text,
      glow: accent,
    );
  }

  LogoStyle copyWith({
    LogoVariant? variant,
    Color? background,
    Color? foreground,
    Color? glow,
  }) {
    return LogoStyle(
      variant: variant ?? this.variant,
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      glow: glow ?? this.glow,
    );
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Map<String, Object?> toJson() => <String, Object?>{
    'variant': variant.name,
    'background': background.toARGB32(),
    'foreground': foreground.toARGB32(),
    'glow': glow.toARGB32(),
  };

  static LogoStyle fromJson(Map<String, Object?> json) {
    final variantName = json['variant'];
    Color color(Object? value, Color fallback) =>
        value is int ? Color(value) : fallback;
    return LogoStyle(
      variant: LogoVariant.values.firstWhere(
        (v) => v.name == variantName,
        orElse: () => LogoVariant.shield,
      ),
      background: color(json['background'], const Color(0xFF9B4DFF)),
      foreground: color(json['foreground'], const Color(0xFFF6F6FF)),
      glow: color(json['glow'], const Color(0xFFFF2ED1)),
    );
  }
}
