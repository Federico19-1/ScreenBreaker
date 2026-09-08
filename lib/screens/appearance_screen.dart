import 'package:flutter/material.dart';

import '../models/app_palette.dart';
import '../models/logo_style.dart';
import '../services/customization_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/color_picker_sheet.dart';

/// The Appearance section: change every color of the app (text, backgrounds,
/// accents — the whole interface, logo included) and pick / recolor the app
/// logo, each with a single tap.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _PalettePreviewCard(),
          SizedBox(height: 16),
          _SectionTitle(text: 'Colors'),
          SizedBox(height: 8),
          _PresetGrid(),
          SizedBox(height: 16),
          _ColorSlotsCard(),
          SizedBox(height: 24),
          _SectionTitle(text: 'Logos'),
          SizedBox(height: 8),
          _LogoSectionCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.iceWhite,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, this.selected = false, this.size = 34});
  final Color color;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.iceWhite : AppColors.purpleDim,
          width: selected ? 3 : 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.iceWhite.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: selected
          ? Icon(Icons.check, size: size * 0.55, color: _readableOn(color))
          : null,
    );
  }

  static Color _readableOn(Color background) =>
      background.computeLuminance() > 0.4
          ? const Color(0xFF12121A)
          : const Color(0xFFFFFFFF);
}

// ---------------------------------------------------------------------------
// Live preview of the current theme + logo
// ---------------------------------------------------------------------------

class _PalettePreviewCard extends StatelessWidget {
  const _PalettePreviewCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPalette>(
      valueListenable: CustomizationService.palette,
      builder: (context, palette, _) {
        return ValueListenableBuilder<LogoStyle>(
          valueListenable: CustomizationService.logo,
          builder: (context, logo, _) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppLogo(style: logo, size: 44, showGlow: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ScreenBreaker',
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live preview — every change applies instantly.',
                              style: TextStyle(
                                color: palette.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final color in [
                        palette.primary,
                        palette.accent,
                        palette.surface,
                        palette.surfaceHigh,
                        palette.text,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ColorDot(color: color, size: 26),
                        ),
                      const Spacer(),
                      Text(
                        palette.name,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Presets
// ---------------------------------------------------------------------------

class _PresetGrid extends StatelessWidget {
  const _PresetGrid();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPalette>(
      valueListenable: CustomizationService.palette,
      builder: (context, active, _) {
        return Container(
          decoration: appCardDecoration(radius: 18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final preset in AppPalette.presets)
                _PresetTile(
                  preset: preset,
                  selected: preset.sameColorsAs(active),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.selected});

  final AppPalette preset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => CustomizationService.applyPreset(preset),
      leading: _ColorDot(color: preset.primary, selected: selected),
      title: Text(
        preset.name,
        style: TextStyle(
          color: AppColors.iceWhite,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Tap to apply',
        style: TextStyle(color: AppColors.iceDim, fontSize: 12),
      ),
      // Mini preview of the preset's look.
      trailing: Container(
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          color: preset.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: preset.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: preset.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 5,
              decoration: BoxDecoration(
                color: preset.text,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 10,
              height: 5,
              decoration: BoxDecoration(
                color: preset.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual color slots
// ---------------------------------------------------------------------------

class _ColorSlotsCard extends StatelessWidget {
  const _ColorSlotsCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPalette>(
      valueListenable: CustomizationService.palette,
      builder: (context, palette, _) {
        return Container(
          decoration: appCardDecoration(radius: 18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _ColorSlotTile(
                label: 'Primary color',
                subtitle: 'Buttons, icons and highlights',
                color: palette.primary,
                slot: AppPaletteColorSlot.primary,
              ),
              _divider(),
              _ColorSlotTile(
                label: 'Background',
                subtitle: 'Screens and cards',
                color: palette.background,
                slot: AppPaletteColorSlot.background,
              ),
              _divider(),
              _ColorSlotTile(
                label: 'Text color',
                subtitle: 'Titles and body text',
                color: palette.text,
                slot: AppPaletteColorSlot.text,
              ),
              _divider(),
              _ColorSlotTile(
                label: 'Accent color',
                subtitle: 'Gradients and secondary highlights',
                color: palette.accent,
                slot: AppPaletteColorSlot.accent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() =>
      Divider(height: 1, indent: 16, color: AppColors.purpleDim.withValues(alpha: 0.4));
}

class _ColorSlotTile extends StatelessWidget {
  const _ColorSlotTile({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.slot,
  });

  final String label;
  final String subtitle;
  final Color color;
  final AppPaletteColorSlot slot;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        final picked = await ColorPickerSheet.show(
          context,
          title: label,
          initialColor: color,
        );
        if (picked != null) {
          await CustomizationService.setPaletteColor(
            slot: slot,
            color: picked,
          );
        }
      },
      leading: _ColorDot(color: color),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.iceWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.iceDim, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: AppColors.iceDim),
    );
  }
}

// ---------------------------------------------------------------------------
// Logos section
// ---------------------------------------------------------------------------

class _LogoSectionCard extends StatelessWidget {
  const _LogoSectionCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LogoStyle>(
      valueListenable: CustomizationService.logo,
      builder: (context, logo, _) {
        return Container(
          decoration: appCardDecoration(radius: 18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One-tap variant picker: every logo renders live.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final variant in LogoVariant.values)
                      _LogoChoice(
                        variant: variant,
                        selected: logo.variant == variant,
                      ),
                  ],
                ),
              ),
              Divider(
                indent: 16,
                color: AppColors.purpleDim.withValues(alpha: 0.4),
              ),
              _LogoColorTile(
                label: 'Logo background',
                slot: LogoColorSlot.background,
                color: logo.background,
              ),
              Divider(
                indent: 16,
                color: AppColors.purpleDim.withValues(alpha: 0.4),
              ),
              _LogoColorTile(
                label: 'Logo symbol',
                slot: LogoColorSlot.foreground,
                color: logo.foreground,
              ),
              Divider(
                indent: 16,
                color: AppColors.purpleDim.withValues(alpha: 0.4),
              ),
              _LogoColorTile(
                label: 'Logo glow',
                slot: LogoColorSlot.glow,
                color: logo.glow,
              ),
              ListTile(
                leading: Icon(Icons.restart_alt, color: AppColors.iceDim),
                title: Text(
                  'Reset logo to theme colors',
                  style: TextStyle(color: AppColors.iceWhite),
                ),
                onTap: () => CustomizationService.resetLogo(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One tappable logo variant: tapping it selects it (and recolors the whole
/// app's logo) in a single tap.
class _LogoChoice extends StatelessWidget {
  const _LogoChoice({required this.variant, required this.selected});

  final LogoVariant variant;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => CustomizationService.setLogoVariant(variant),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppLogo(
                style: CustomizationService.styleFor(variant),
                size: 56,
                showGlow: false,
              ),
              if (selected)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.iceWhite,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.neonPurple,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            variant.label,
            style: TextStyle(
              color: selected ? AppColors.iceWhite : AppColors.iceDim,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoColorTile extends StatelessWidget {
  const _LogoColorTile({
    required this.label,
    required this.slot,
    required this.color,
  });

  final String label;
  final LogoColorSlot slot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        final picked = await ColorPickerSheet.show(
          context,
          title: label,
          initialColor: color,
        );
        if (picked != null) {
          await CustomizationService.setLogoColor(slot: slot, color: picked);
        }
      },
      leading: _ColorDot(color: color),
      title: Text(
        label,
        style: TextStyle(color: AppColors.iceWhite, fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Tap to edit', style: TextStyle(color: AppColors.iceDim, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: AppColors.iceDim),
    );
  }
}
