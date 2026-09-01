import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/system_permissions.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// First-run screen explaining why ScreenBreaker needs Usage Access and guiding
/// the user to the system settings page to enable it.
///
/// `PACKAGE_USAGE_STATS` is a special permission that cannot be granted from an
/// app dialog, so we must detect its absence, send the user to
/// "Settings → Special app access → Usage access", and re-check when they come
/// back. Only then do we let them into the main screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onGranted});

  /// Invoked once the user has enabled Usage Access (and after we request the
  /// notification permission).
  final VoidCallback onGranted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _granted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Be gentle: if the permission is already granted, skip straight through.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user is sent to the Android Usage Access settings screen; re-check
    // every time we come back to the foreground.
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await UsageService.hasUsageAccess();
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _checking = false;
    });
    if (granted) {
      // Stop polling before opening the notification permission dialog so the
      // timer cannot re-trigger this flow while the dialog is up.
      _pollTimer?.cancel();
      await _finish();
    } else {
      // Poll as a fallback in case lifecycle events are missed.
      _pollTimer?.cancel();
      if (mounted) {
        _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _checkPermission();
        });
      }
    }
  }

  Future<void> _finish() async {
    // Android 13+ requires the runtime notification permission before we can
    // show the foreground-service or break-alert notifications.
    await Permission.notification.request();
    // Android 14+ requires the user to allow full-screen notifications for
    // the full-screen break alert. Best-effort: some devices/versions don't
    // have this permission, which is fine (the alert still works as a
    // heads-up banner).
    await SystemPermissions.requestFullScreenIntent();
    if (mounted) {
      widget.onGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Center(child: AppLogo(size: 110)),
              const SizedBox(height: 28),
              const Text(
                'Welcome to ScreenBreaker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ScreenBreaker helps you spend less time on '
                'mindless scrolling by warning you when you\'ve been '
                'in an app too long.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.iceDim, fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bullet(icon: Icons.apps, text: 'Choose which apps to monitor'),
                    SizedBox(height: 12),
                    _Bullet(icon: Icons.timer, text: 'Set a daily time limit'),
                    SizedBox(height: 12),
                    _Bullet(icon: Icons.notifications_active, text: 'Get a nudge when you go over'),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (_checking)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_granted)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '✅ Usage access granted!',
                      style: TextStyle(color: AppColors.success, fontSize: 16),
                    ),
                  ),
                )
              else ...[
                const Text(
                  'One last step',
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'To measure your screen time we need Usage Access. '
                  'Tap below, then enable ScreenBreaker under '
                  'Special app access → Usage access.',
                  style: TextStyle(color: AppColors.iceDim, height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => UsageService.requestUsageAccess(),
                  child: const Text('Grant Permission'),
                ),
                TextButton(
                  onPressed: (mounted) ? _checkPermission : null,
                  child: const Text(
                    "I've already enabled it — Continue",
                    style: TextStyle(color: AppColors.iceDim),
                  ),
                ),
              ],
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonPurple, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.iceWhite, fontSize: 15),
          ),
        ),
      ],
    );
  }
}