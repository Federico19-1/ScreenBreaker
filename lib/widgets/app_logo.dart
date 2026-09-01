import 'package:flutter/material.dart';

/// The ScreenBreaker logo (assets/icons/logo.png), used across every screen.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF9B4DFF),
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Icon(
          Icons.self_improvement,
          color: const Color(0xFFF6F6FF),
          size: size * 0.7,
        ),
      ),
    );
  }
}
