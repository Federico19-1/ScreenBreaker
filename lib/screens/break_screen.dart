import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Full-screen "time for a break" screen.
///
/// Opened when the user taps (or the system auto-launches) the over-limit
/// notification. Designed to be impossible to ignore: a huge message fills the
/// whole screen so the user is forced to consciously dismiss it before
/// returning to whatever they were doing.
class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key, required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2A0E4E),
              AppColors.neonPurple,
              AppColors.techMagenta,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const AppLogo(size: 120),
                const Spacer(),
                const Text(
                  'STOP! 🛑',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 24,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'You\'ve been using "$appName" for too long.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.iceWhite.withValues(alpha: 0.95),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This is your sign to step away from the screen. '
                  'Stand up, stretch, drink some water — your eyes and '
                  'your attention will thank you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.iceWhite,
                      foregroundColor: AppColors.neonPurple,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK, I\'m taking a break'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.iceWhite,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('I\'m done scrolling'),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
