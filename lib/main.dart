import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'screens/break_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/weekly_summary_screen.dart';
import 'services/app_navigator.dart';
import 'services/customization_service.dart';
import 'services/foreground_service.dart';
import 'services/notification_service.dart';
import 'services/usage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Communication port lets the foreground task send data back to the UI.
  FlutterForegroundTask.initCommunicationPort();
  // Configure the persistent service notification channel + task options.
  ForegroundService.initialize();
  // Detect taps that launched the app (e.g. the weekly summary notification)
  // and wire up notification-tap navigation.
  await NotificationService.initializeLaunchHandling();
  // Load the user's saved colors + logo before the first frame renders.
  await CustomizationService.load();
  runApp(const ScreenBreakerApp());
}

class ScreenBreakerApp extends StatefulWidget {
  const ScreenBreakerApp({super.key});

  @override
  State<ScreenBreakerApp> createState() => _ScreenBreakerAppState();
}

class _ScreenBreakerAppState extends State<ScreenBreakerApp> {
  @override
  void initState() {
    super.initState();
    // Rebuild the whole MaterialApp (and thus every screen) whenever the
    // user changes the color palette in the Appearance section.
    CustomizationService.palette.addListener(_onPaletteChanged);
  }

  @override
  void dispose() {
    CustomizationService.palette.removeListener(_onPaletteChanged);
    super.dispose();
  }

  void _onPaletteChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenBreaker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      navigatorKey: AppNavigator.navigatorKey,
      home: const _RootGate(),
      routes: {
        // Opened when the weekly summary notification is tapped.
        AppNavigator.weeklySummaryRoute: (_) => const WeeklySummaryScreen(),
        // Opened when an over-limit alert is tapped (or auto-launched by the
        // full-screen intent); arguments = the app name as a String.
        AppNavigator.breakRoute: (context) => BreakScreen(
          appName: ModalRoute.of(context)?.settings.arguments as String? ?? '',
        ),
      },
    );
  }
}

/// Decides between the onboarding (Usage Access) flow and the main screen.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    // If the app was launched by tapping the weekly summary notification, the
    // navigator exists by the time the first frame renders, so open it now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigator.tryOpenPending();
    });
    _check();
  }

  Future<void> _check() async {
    final granted = await UsageService.hasUsageAccess();
    if (!mounted) return;
    setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _granted == null
          ? const _SplashPlaceholder()
          : _granted!
              ? const HomeScreen(key: ValueKey('home'))
              : OnboardingScreen(
                  key: const ValueKey('onboarding'),
                  onGranted: () {
                    setState(() => _granted = true);
                  },
                ),
    );
  }
}

class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bluishBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 96),
            const SizedBox(height: 20),
            Text(
              'ScreenBreaker',
              style: TextStyle(
                color: AppColors.iceWhite,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.neonPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}