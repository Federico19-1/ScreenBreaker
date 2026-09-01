import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_navigator.dart';

/// Sends the "time for a break" notifications for apps that exceed their limit.
///
/// It is used both by the UI and by the foreground-service task handler (which
/// runs on its own isolate). [initialize] is idempotent and must be called in
/// whichever isolate wants to post a notification.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'screenbreaker_break_alerts';
  static const String _channelName = 'Screen time alerts';
  static const String _channelDescription =
      'Alerts when a monitored app is used for too long';

  static const String _summaryChannelId = 'screenbreaker_weekly_summary';
  static const String _summaryChannelName = 'Weekly screen time summary';
  static const String _summaryChannelDescription =
      'A weekly recap of your screen time per monitored app';

  static const int _overLimitNotificationId = 1;
  static const int _weeklySummaryNotificationId = 2;

  /// Payload prefix for over-limit alerts; the rest of the payload carries the
  /// name of the app the user spent too long in.
  static const String _breakPayloadPrefix = 'break:';

  static bool _initialized = false;

  /// Called once from `main()` (UI isolate): detects whether the app was
  /// launched by tapping a notification (weekly summary or full-screen break
  /// alert) and remembers the pending navigation, then initializes the plugin
  /// (which also wires up tap handling for taps that arrive while the app is
  /// running).
  static Future<void> initializeLaunchHandling() async {
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final payload = launch?.notificationResponse?.payload;
        _routeFromPayload(payload);
      }
    } catch (_) {
      // Cold-start detection is best-effort; taps while running are still
      // handled by the initialize() callback below.
    }
    await initialize();
  }

  /// Sets up the plugin and creates the alert channels. Safe to call multiple
  /// times and from multiple isolates. The tap callback is only meaningful on
  /// the UI isolate (where the navigator lives).
  static Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    final ok = await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    // _initialized is per-isolate (static), which is what we want: each
    // isolate initialises its own copy once.
    if (ok != false) _initialized = true;
  }

  /// Fired when the user taps a notification while the app is running (or when
  /// it is resumed from the notification shade). Routes summary taps to the
  /// detail screen and break-alert taps to the full-screen break screen.
  static void _onNotificationResponse(NotificationResponse response) {
    _routeFromPayload(response.payload);
  }

  /// Decides what a notification payload should open in the app.
  static void _routeFromPayload(String? payload) {
    if (payload == null) return;
    if (payload == AppNavigator.weeklySummaryRoute) {
      AppNavigator.openWeeklySummary();
    } else if (payload.startsWith(_breakPayloadPrefix)) {
      final appName = payload.substring(_breakPayloadPrefix.length);
      if (appName.isNotEmpty) AppNavigator.openBreakScreen(appName);
    }
  }

  /// Posts the over-limit notification for [appName].
  ///
  /// Title: "ScreenBreaker"
  /// Body:  `You've been using <appName> for too long. Time for a break! 🛑`
  ///
  /// The alert is deliberately loud:
  /// * maximum importance/priority → heads-up banner on top of any app;
  /// * [BigTextStyleInformation] → a long, expandable message;
  /// * [fullScreenIntent] → when the phone is locked (or the user is on
  ///   Android 14+ and allowed it), the whole screen lights up with the alert;
  ///   tapping it opens the full-screen [BreakScreen].
  static Future<void> showOverLimitNotification(String appName) async {
    await initialize();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        styleInformation: BigTextStyleInformation(
          "You've been using $appName for too long.\n\n"
              'Time to step away from the screen. 🛑\n'
              'Stand up, stretch, grab some water — you will feel better '
              'for it.',
          contentTitle: 'ScreenBreaker',
          summaryText: 'Time for a break!',
        ),
      ),
    );
    await _plugin.show(
      // A stable id per package isn't available here for historical alerts, so
      // use a fixed id; the plugin replaces the previous alert, which is fine.
      _overLimitNotificationId,
      'ScreenBreaker',
      "You've been using $appName for too long. Time for a break! 🛑",
      details,
      // The payload lets the tap handler open the full-screen break screen.
      payload: '$_breakPayloadPrefix$appName',
    );
  }

  /// Posts the weekly summary: one bullet per monitored app with its total
  /// usage time, e.g. "Your screen time last week:\n• Instagram — 3h 25m".
  ///
  /// Uses its own (default-importance) channel so it is noticeable but not as
  /// intrusive as the break alerts.
  static Future<void> showWeeklySummary(List<String> lines) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _summaryChannelId,
        _summaryChannelName,
        channelDescription: _summaryChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.status,
      ),
    );
    await _plugin.show(
      _weeklySummaryNotificationId,
      'ScreenBreaker',
      'Your screen time last week:\n${lines.join('\n')}',
      details,
      // Payload lets the tap handler open the per-day breakdown screen.
      payload: AppNavigator.weeklySummaryRoute,
    );
  }
}