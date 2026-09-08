import 'package:flutter/material.dart';

import '../models/logo_style.dart';
import '../services/customization_service.dart';

/// The ScreenBreaker logo, used across every screen.
///
/// The logo is drawn with Flutter primitives so it follows the user's
/// customization: the active [LogoStyle] (variant + colors) is read from
/// [CustomizationService] and every color is applied live — a single tap in
/// the Appearance > Logos section recolors the whole app's logo.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 32,
    this.style,
    this.showGlow = true,
  });

  final double size;

  /// Overrides the active style (used by the logo editor previews).
  final LogoStyle? style;

  /// Whether to draw the soft outer glow (disabled for tiny sizes).
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LogoStyle>(
      valueListenable: CustomizationService.logo,
      builder: (context, active, _) {
        final style = this.style ?? active;
        final radius = size * 0.24;
        Widget glyph;
        if (style.variant == LogoVariant.shield) {
          glyph = CustomPaint(
            size: Size.square(size * 0.62),
            painter: _ShieldPainter(style.foreground),
          );
        } else {
          glyph = Icon(
            style.variant.icon!,
            color: style.foreground,
            size: size * 0.58,
          );
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: style.glow.withValues(alpha: 0.55),
              width: size * 0.035,
            ),
            boxShadow: showGlow
                ? [
                    BoxShadow(
                      color: style.glow.withValues(alpha: 0.35),
                      blurRadius: size * 0.35,
                      spreadRadius: size * 0.02,
                    ),
                  ]
                : null,
          ),
          child: Center(child: glyph),
        );
      },
    );
  }
}

/// Draws the classic shield silhouette with Flutter primitives.
class _ShieldPainter extends CustomPainter {
  _ShieldPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.94, h * 0.14)
      // Right side down, then curve to the bottom point.
      ..lineTo(w * 0.94, h * 0.55)
      ..quadraticBezierTo(w * 0.94, h * 0.82, w * 0.5, h)
      ..quadraticBezierTo(w * 0.06, h * 0.82, w * 0.06, h * 0.55)
      ..lineTo(w * 0.06, h * 0.14)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ShieldPainter oldDelegate) => oldDelegate.color != color;
}
