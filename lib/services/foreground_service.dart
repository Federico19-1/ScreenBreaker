import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'notification_service.dart';
import 'preferences_repository.dart';
import 'streak_service.dart';
import 'strike_service.dart';
import 'usage_service.dart';
import 'weekly_summary_service.dart';

/// Smallest interval between two identical break-notifications, per app
/// (anti-spam requirement).
const Duration kAntiSpamCooldown = Duration(minutes: 5);

/// How often the background task checks app usage.
const Duration kCheckInterval = Duration(seconds: 60);

/// Facade over `flutter_foreground_task` for the app's UI (main isolate).
///
/// The actual monitoring logic lives in [ScreenBreakerTaskHandler], which runs
/// on the foreground service's own Dart isolate even when the app is closed.
class ForegroundService {
  ForegroundService._();

  static bool _initialized = false;

  /// Must be called once from `main()` before the UI starts. Configures the
  /// persistent (silent) service notification channel and the task options.
  static void initialize() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'ScreenBreaker monitoring',
        channelDescription:
            'Shows while ScreenBreaker is monitoring your screen time.',
        onlyAlertOnce: true,
        channelImportance: NotificationChannelImportance.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(kCheckInterval.inMilliseconds),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Optional (but recommended) runtime permissions so the service survives
  /// battery optimisation on some devices.
  static Future<void> requestOptionalPermissions() async {
    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {
      // Non-fatal – the user can grant battery optimisation later if needed.
    }
  }

  /// Starts (or restarts) the monitoring foreground service.
  static Future<void> startMonitoring() async {
    // Best-effort: ask to be excluded from battery optimisation so the service
    // keeps running on aggressive OEMs (non-fatal if declined).
    await requestOptionalPermissions();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'ScreenBreaker',
      notificationText: 'ScreenBreaker is monitoring your screen time',
      notificationIcon: null,
      notificationInitialRoute: '/',
      callback: screenbreakerBackgroundCallback,
    );
  }

  /// Stops the foreground service.
  static Future<void> stopMonitoring() async {
    await FlutterForegroundTask.stopService();
  }

  /// Whether the service is currently running.
  static Future<bool> get isMonitoring =>
      FlutterForegroundTask.isRunningService;
}

/// Top-level entry point invoked by the foreground service's Dart isolate.
///
/// It must be annotated with `@pragma('vm:entry-point')` and defined at the top
/// level so it is kept in the AOT snapshot and can be re-invoked by the service
/// (including after a device reboot or app update via autoRunOnBoot).
@pragma('vm:entry-point')
void screenbreakerBackgroundCallback() {
  FlutterForegroundTask.setTaskHandler(ScreenBreakerTaskHandler());
}

/// The background task that periodically checks each monitored app's usage and
/// posts a break notification once its threshold is exceeded (with a 5-minute
/// anti-spam window).
class ScreenBreakerTaskHandler extends TaskHandler {
  /// Guards against overlapping checks in case a repeat tick fires while a
  /// previous async check is still in flight.
  static bool _checkInProgress = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Make sure flutter_local_notifications is usable from this isolate.
    await NotificationService.initialize();
    debugPrint('ScreenBreaker background task started ($starter)');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(runMonitoringCheck());
  }

  /// The full monitoring pass: read settings → query usage → notify.
  static Future<void> runMonitoringCheck() async {
    if (_checkInProgress) return;
    _checkInProgress = true;
    try {
      // A day on which ScreenBreaker is monitoring counts toward the streak.
      await StreakService.recordToday();

      final enabled = await PreferencesRepository.getEnabledApps();
      if (enabled.isEmpty) return;

      final packages = enabled.toList();
      final thresholds = await PreferencesRepository.getThresholdsFor(packages);
      final usage = await UsageService.getUsageToday();
      final lastNotified = await PreferencesRepository.getLastNotifiedFor(
        packages,
      );
      final now = DateTime.now();

      for (final package in packages) {
        final usedMinutes = usage[package]?.inMinutes ?? 0;
        final threshold = thresholds[package] ?? 15;
        final last =
            lastNotified[package] ?? DateTime.fromMillisecondsSinceEpoch(0);

        final overLimit = usedMinutes > threshold;
        final cooldownElapsed = now.difference(last) > kAntiSpamCooldown;

        if (overLimit && cooldownElapsed) {
          final appName = await PreferencesRepository.getAppName(package);
          // The alert is a strike: one life lost for going over the limit.
          final strikesSoFar = await StrikeService.strikesToday();
          await StrikeService.recordStrike(package);
          await NotificationService.showOverLimitNotification(
            appName,
            strikeNumber: (strikesSoFar + 1).clamp(1, StrikeService.dailyLives),
            totalStrikes: StrikeService.dailyLives,
          );
          await PreferencesRepository.setLastNotified(package);
          debugPrint(
            'ScreenBreaker: $package used $usedMinutes m '
            '(limit $threshold m) → strike '
            '${(strikesSoFar + 1).clamp(1, StrikeService.dailyLives)} '
            'recorded.',
          );
        }
      }
    } finally {
      // Once-per-week screen-time recap (no-op on most ticks).
      try {
        await WeeklySummaryService.maybeSendWeeklySummary();
      } catch (e) {
        debugPrint('ScreenBreaker weekly summary error: $e');
      }
      _checkInProgress = false;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}