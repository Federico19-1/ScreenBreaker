import 'dart:typed_data';

import 'package:usage_stats/usage_stats.dart';

/// Wraps the `usage_stats` plugin and exposes the small subset of queries the
/// monitoring loop needs.
///
/// "Today" means from local midnight until now, matching how a user thinks
/// about their screen time ("I've been on Instagram 42 minutes today").
class UsageService {
  UsageService._();

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Aggregated per-app foreground time in the range [start, end), keyed by
  /// package name. Returns an empty map on any error or when the
  /// usage-access permission is not granted.
  static Future<Map<String, Duration>> getUsageBetween(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final aggregated = await UsageStats.queryAndAggregateUsageStats(
        start,
        end,
      );
      return aggregated.map(
        (package, info) => MapEntry(
          package,
          Duration(milliseconds: info.totalTimeInForegroundMs ?? 0),
        ),
      );
    } catch (_) {
      // The plugin can throw if PACKAGE_USAGE_STATS is missing or on odd device
      // states. Treat it as "no data" and let the caller decide what to do.
      return <String, Duration>{};
    }
  }

  /// Aggregated per-app foreground time from local midnight until now,
  /// keyed by package name.
  static Future<Map<String, Duration>> getUsageToday() {
    return getUsageBetween(_startOfToday(), DateTime.now());
  }

  /// Aggregated per-app foreground time for one whole calendar day (midnight
  /// to midnight), keyed by package name. Days in the future yield {}.
  static Future<Map<String, Duration>> getUsageForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(start.year, start.month, start.day + 1);
    return getUsageBetween(start, end);
  }

  /// Per-app foreground time bucketed by hour of day for [day].
  ///
  /// Returns a list of 24 maps (index 0 = midnight–1am … 23 = 11pm–midnight);
  /// each map is package → time spent in that hour. Uses the same aggregation
  /// query as everything else, run once per hour in parallel.
  static Future<List<Map<String, Duration>>> getUsageByHourForDay(
    DateTime day,
  ) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final queries = List.generate(24, (hour) {
      final start = DateTime(dayStart.year, dayStart.month, dayStart.day + hour);
      final end = DateTime(start.year, start.month, start.day + 1);
      return getUsageBetween(start, end);
    });
    return Future.wait(queries);
  }

  /// How many whole minutes [packageName] was in the foreground today.
  static Future<Duration> getUsageForPackage(String packageName) async {
    final today = await getUsageToday();
    return today[packageName] ?? Duration.zero;
  }

  /// Returns every installed, user-visible (non-system) app the caller is
  /// allowed to see (a launcher `<queries>` entry grants broad visibility on
  /// Android 11+). Returns an empty list on any error.
  static Future<List<AppInfo>> listInstalledApps() async {
    try {
      return await UsageStats.queryInstalledApps(includeSystem: false);
    } catch (_) {
      return <AppInfo>[];
    }
  }

  /// Fetches the PNG launcher icon for [packageName], or null if unavailable.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      return await UsageStats.getAppIcon(packageName);
    } catch (_) {
      return null;
    }
  }

  /// Whether the PACKAGE_USAGE_STATS permission has been granted.
  static Future<bool> hasUsageAccess() async {
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the PACKAGE_USAGE_STATS permission by opening the system
  /// Usage Access settings screen (it can only be granted by the user there).
  static Future<void> requestUsageAccess() async {
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {
      // Ignore – the user is responsible for enabling it from the system UI.
    }
  }
}