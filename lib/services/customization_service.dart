import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_palette.dart';
import '../models/logo_style.dart';

/// Single source of truth for the app's live customization state.
///
/// Holds the active [AppPalette] (all colors) and the current [LogoStyle]
/// (which logo is drawn and with which colors), persists both through
/// shared_preferences and notifies every listener — the MaterialApp theme,
/// all screens and every logo — the moment anything changes.
class CustomizationService {
  CustomizationService._();

  static const String _keyPalette = 'screenbreaker.palette.v1';
  static const String _keyLogo = 'screenbreaker.logo.v1';

  /// Notifies the whole app (via ValueListenableBuilder in main.dart).
  static final ValueNotifier<AppPalette> palette = ValueNotifier<AppPalette>(
    AppPalette.violetFuture,
  );

  static final ValueNotifier<LogoStyle> logo = ValueNotifier<LogoStyle>(
    const LogoStyle(
      variant: LogoVariant.shield,
      background: Color(0xFF9B4DFF),
      foreground: Color(0xFFF6F6FF),
      glow: Color(0xFFFF2ED1),
    ),
  );

  static bool _loaded = false;

  /// Loads the saved customization once, before the first frame.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawPalette = prefs.getString(_keyPalette);
      if (rawPalette != null) {
        final decoded = (jsonDecode(rawPalette) as Map).cast<String, Object?>();
        palette.value = AppPalette.fromJson(decoded).ensureReadable();
      }
      final rawLogo = prefs.getString(_keyLogo);
      if (rawLogo != null) {
        final decoded = (jsonDecode(rawLogo) as Map).cast<String, Object?>();
        logo.value = LogoStyle.fromJson(decoded);
      }
    } catch (_) {
      // Corrupted or missing values: keep the defaults.
    }
  }

  /// Replaces the whole palette (used by presets and the color editor).
  static Future<void> setPalette(AppPalette newPalette) async {
    final readable = newPalette.ensureReadable();
    palette.value = readable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPalette, jsonEncode(readable.toJson()));
  }

  /// Updates a single core color of the active palette.
  static Future<void> setPaletteColor({
    required AppPaletteColorSlot slot,
    required Color color,
  }) async {
    final current = palette.value;
    await setPalette(
      current.copyWith(
        primary: slot == AppPaletteColorSlot.primary ? color : null,
        background: slot == AppPaletteColorSlot.background ? color : null,
        text: slot == AppPaletteColorSlot.text ? color : null,
        accent: slot == AppPaletteColorSlot.accent ? color : null,
        name: 'Custom',
      ),
    );
  }

  /// Applies a built-in preset.
  static Future<void> applyPreset(AppPalette preset) => setPalette(preset);

  /// Stores a style for a logo variant so switching variants keeps the user's
  /// per-variant colors. Only the active variant is persisted globally.
  static final Map<LogoVariant, LogoStyle> _variantStyles = {};

  static LogoStyle styleFor(LogoVariant variant) {
    final active = logo.value;
    if (active.variant == variant) return active;
    return _variantStyles[variant] ?? LogoStyle.forVariant(
      variant,
      primary: palette.value.primary,
      accent: palette.value.accent,
      text: palette.value.text,
    );
  }

  /// Switches the active logo variant (keeping its last-used colors).
  static Future<void> setLogoVariant(LogoVariant variant) async {
    logo.value = styleFor(variant);
    await _persistLogo();
  }

  /// Updates one color of the active logo.
  static Future<void> setLogoColor({
    required LogoColorSlot slot,
    required Color color,
  }) async {
    final current = logo.value;
    logo.value = current.copyWith(
      background: slot == LogoColorSlot.background ? color : null,
      foreground: slot == LogoColorSlot.foreground ? color : null,
      glow: slot == LogoColorSlot.glow ? color : null,
    );
    _variantStyles[current.variant] = logo.value;
    await _persistLogo();
  }

  /// Resets the active logo to palette-derived defaults.
  static Future<void> resetLogo() async {
    _variantStyles.remove(logo.value.variant);
    logo.value = LogoStyle.forVariant(
      logo.value.variant,
      primary: palette.value.primary,
      accent: palette.value.accent,
      text: palette.value.text,
    );
    await _persistLogo();
  }

  static Future<void> _persistLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogo, jsonEncode(logo.value.toJson()));
  }
}

/// Which editable color slot inside the active palette.
enum AppPaletteColorSlot { primary, background, text, accent }

/// Which editable color slot inside the active logo.
enum LogoColorSlot { background, foreground, glow }
