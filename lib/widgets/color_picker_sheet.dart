import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A curated palette of tappable color swatches, plus an HSV wheel-free picker
/// (hue slider + lightness slider) so any color is reachable. Shown as a modal
/// bottom sheet; returns the picked [Color] (or null when cancelled).
class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    required this.title,
    required this.initialColor,
  });

  final String title;
  final Color initialColor;

  /// Opens the sheet and resolves with the picked color, if any.
  static Future<Color?> show(
    BuildContext context, {
    required String title,
    required Color initialColor,
  }) {
    return showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ColorPickerSheet(
        title: title,
        initialColor: initialColor,
      ),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  static const List<Color> _swatches = [
    Color(0xFF9B4DFF), Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF2563EB),
    Color(0xFF38BDF8), Color(0xFF2DD4BF), Color(0xFF34D399), Color(0xFFA3E635),
    Color(0xFFF5C542), Color(0xFFFB923C), Color(0xFFFB7185), Color(0xFFFF2ED1),
    Color(0xFFEC4899), Color(0xFF0C0A14), Color(0xFF161021), Color(0xFF2A2438),
    Color(0xFF6B7280), Color(0xFFF6F6FF), Color(0xFFF2F4FC), Color(0xFFFFFFFF),
  ];

  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  void _update(HSVColor hsv) => setState(() => _hsv = hsv);

  void _pickSwatch(Color color) {
    // Keep the current hue when the swatch is (near-)black or white so the
    // sliders stay useful after picking a neutral tone.
    final saturation = HSVColor.fromColor(color).saturation;
    if (saturation < 0.08) {
      setState(() => _hsv = _hsv.withSaturation(0).withValue(
            color.computeLuminance() > 0.5 ? 1.0 : 0.06,
          ));
      Navigator.of(context).pop(color);
      return;
    }
    setState(() => _hsv = HSVColor.fromColor(color));
    Navigator.of(context).pop(color);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final edge = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: edge.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border.all(color: AppColors.purpleDim.withValues(alpha: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.iceDim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: AppColors.iceWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Live preview of the currently selected color.
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.purpleDim,
                          width: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final swatch in _swatches)
                      GestureDetector(
                        onTap: () => _pickSwatch(swatch),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.iceDim.withValues(alpha: 0.6),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Fine-tune',
                  style: TextStyle(
                    color: AppColors.iceDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Hue slider: the track sweeps the full hue circle.
                Row(
                  children: [
                    const Text('🎨'),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 14,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 9,
                          ),
                        ),
                        child: Slider(
                          value: _hsv.hue,
                          max: 360,
                          onChanged: (hue) =>
                              _update(_hsv.withHue(hue)),
                        ),
                      ),
                    ),
                  ],
                ),
                // Value (lightness) slider, tinted with the current hue.
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 14,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                    ),
                  ),
                  child: Slider(
                    value: _hsv.value,
                    onChanged: (value) => _update(_hsv.withValue(value)),
                  ),
                ),
                // Saturation slider, tinted with the current hue.
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 14,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                    ),
                  ),
                  child: Slider(
                    value: _hsv.saturation,
                    onChanged: (saturation) =>
                        _update(_hsv.withSaturation(saturation)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(color),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
