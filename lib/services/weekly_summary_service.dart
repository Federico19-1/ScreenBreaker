import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'preferences_repository.dart';
import 'usage_service.dart';

/// Sends a weekly summary notification with each monitored app's total screen
/// time for the completed week.
///
/// Rather than relying on a calendar scheduler (which would need extra
/// permissions and timezone data), it piggybacks on the foreground service's
/// periodic tick: it remembers which week it last handled and, the first time a
/// new week is observed, summarizes the week that just ended. This guarantees
/// exactly one summary per week as long as the service is running.
class WeeklySummaryService {
  WeeklySummaryService._();

  /// The Monday (00:00 local) of the week that [date] falls into. Weeks are
  /// anchored on Monday to match the ISO convention.
  static DateTime startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// Human-readable duration, e.g. `3h 25m` or `25m`.
  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// Called from the background monitoring loop on every tick. Sends nothing
  /// most weeks; fires once on the first tick of a new calendar week.
  static Future<void> maybeSendWeeklySummary() async {
    final enabled = await PreferencesRepository.getEnabledApps();
    if (enabled.isEmpty) return;

    final thisWeek = startOfWeek(DateTime.now());
    final lastHandled = await PreferencesRepository.getLastSummaryWeek();

    // Same week already handled (or ticked twice this week) → nothing to do.
    if (lastHandled != null && lastHandled == thisWeek) return;

    // Very first run: record the current week as the baseline so the first
    // summary covers a full week of real usage instead of firing instantly.
    if (lastHandled == null) {
      await PreferencesRepository.setLastSummaryWeek(thisWeek);
      return;
    }

    // A new week has started: summarize the completed one —
    // [lastMonday of previous week, this Monday).
    final weekStart = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);
    final usage = await UsageService.getUsageBetween(weekStart, thisWeek);

    final lines = <String>[];
    for (final package in enabled) {
      final total = usage[package] ?? Duration.zero;
      if (total.inMinutes < 1) continue; // skip apps without real usage
      final name = await PreferencesRepository.getAppName(package);
      lines.add('• $name — ${formatDuration(total)}');
    }

    // Only bother the user if there is something to report.
    if (lines.isNotEmpty) {
      await NotificationService.showWeeklySummary(lines);
      debugPrint('ScreenBreaker weekly summary sent (${lines.length} apps).');
    }

    await PreferencesRepository.setLastSummaryWeek(thisWeek);
  }
}