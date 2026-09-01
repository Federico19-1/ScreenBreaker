import 'package:flutter/material.dart';

/// Central navigation hub used by notification tap handlers, which fire
/// outside the widget tree and therefore cannot push routes themselves.
///
/// The app exposes its navigator via [navigatorKey]; handlers ask this class to
/// open a route, and if the navigator isn't built yet (e.g. the app was cold
/// started by tapping the notification) the open is deferred until the first
/// frame renders ([tryOpenPending]).
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Route name of the weekly summary detail screen.
  static const String weeklySummaryRoute = '/weekly-summary';

  /// Route name of the full-screen break screen.
  static const String breakRoute = '/break';

  /// When true, a route was requested before the navigator was ready.
  static bool _deferredOpenPending = false;

  /// App name of a pending break-screen open (before the navigator exists).
  static String? _pendingBreakApp;

  /// Called from `main()` when the app was launched by tapping the weekly
  /// summary notification: remembers the request until the UI is up.
  static void markPendingWeeklySummary() {
    _deferredOpenPending = true;
  }

  /// Called from `main()` when the app was launched by a full-screen break
  /// alert: remembers which app triggered it until the UI is up.
  static void markPendingBreak(String appName) {
    _pendingBreakApp = appName;
  }

  /// Attempts to open the deferred route once the navigator exists. Safe to
  /// call any time after the first frame; does nothing if nothing is pending.
  static void tryOpenPending() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return; // not built yet – retried after a later frame
    if (_deferredOpenPending) {
      _deferredOpenPending = false;
      navigator.pushNamed(weeklySummaryRoute);
    }
    final breakApp = _pendingBreakApp;
    if (breakApp != null) {
      _pendingBreakApp = null;
      navigator.pushNamed(breakRoute, arguments: breakApp);
    }
  }

  /// Opens the weekly summary screen if the navigator is ready, otherwise
  /// defers it (used when the tap arrives before the first frame).
  static void openWeeklySummary() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _deferredOpenPending = true;
      return;
    }
    navigator.pushNamed(weeklySummaryRoute);
  }

  /// Opens the full-screen break screen for [appName] if the navigator is
  /// ready, otherwise defers it.
  static void openBreakScreen(String appName) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingBreakApp = appName;
      return;
    }
    navigator.pushNamed(breakRoute, arguments: appName);
  }
}