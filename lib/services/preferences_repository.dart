import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/monitored_app.dart';

/// Thin, single source of truth for everything this app persists with
/// shared_preferences.
///
/// Both the UI (main isolate) and the foreground-service task handler run in
/// separate isolates, and both read from the same SharedPreferences file. The
/// task handler calls [reload] before every read so it always sees the latest
/// values written by the UI.
class PreferencesRepository {
  PreferencesRepository._();

  static const String _keyEnabledApps = 'screenbreaker.selected_apps';
  static const String _keyAppNames = 'screenbreaker.app_names';
  static const String _keyThresholds = 'screenbreaker.thresholds';
  static const String _keyGlobalThreshold = 'screenbreaker.global_threshold';
  static const String _keyLastNotified = 'screenbreaker.last_notified';
  static const String _keyLastSummaryWeek = 'screenbreaker.last_summary_week';

  // ---------------------------------------------------------------------------
  // Selected (monitored) apps
  // ---------------------------------------------------------------------------

  /// Returns the set of package names currently enabled for monitoring.
  static Future<Set<String>> getEnabledApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return (prefs.getStringList(_keyEnabledApps) ?? const []).toSet();
  }

  static Future<void> setAppEnabled(String packageName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_keyEnabledApps) ?? const []).toSet();
    if (enabled) {
      current.add(packageName);
    } else {
      current.remove(packageName);
    }
    await prefs.setStringList(_keyEnabledApps, current.toList()..sort());
  }

  // ---------------------------------------------------------------------------
  // App names (used by the background service to build notification text)
  // ---------------------------------------------------------------------------

  static Future<void> saveAppName(String packageName, String appName) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeStringMap(prefs.getString(_keyAppNames));
    map[packageName] = appName;
    await prefs.setString(_keyAppNames, jsonEncode(map));
  }

  /// Looks up the cached name for [packageName]; falls back to the package
  /// name so that notifications still read naturally.
  static Future<String> getAppName(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final map = _decodeStringMap(prefs.getString(_keyAppNames));
    return map[packageName] ?? packageName;
  }

  // ---------------------------------------------------------------------------
  // Thresholds (global default + optional per-app override)
  // ---------------------------------------------------------------------------

  static Future<int> getGlobalThresholdMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt(_keyGlobalThreshold) ??
        MonitoredApp.defaultThresholdMinutes;
  }

  static Future<void> setGlobalThresholdMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGlobalThreshold, minutes);
  }

  static Future<void> setAppThresholdMinutes(
    String packageName,
    int minutes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeIntMap(prefs.getString(_keyThresholds));
    map[packageName] = minutes;
    await prefs.setString(_keyThresholds, jsonEncode(map));
  }

  static Future<void> clearAppThreshold(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeIntMap(prefs.getString(_keyThresholds));
    map.remove(packageName);
    await prefs.setString(_keyThresholds, jsonEncode(map));
  }

  /// Returns only the stored per-app override for [packageName], or null when
  /// the app has no custom limit (and therefore uses the global default).
  static Future<int?> getAppThresholdOverride(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _decodeIntMap(prefs.getString(_keyThresholds))[packageName];
  }

  /// The effective threshold for [packageName]: its per-app override if one
  /// exists, otherwise the global default.
  static Future<int> getThresholdFor(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final overrides = _decodeIntMap(prefs.getString(_keyThresholds));
    final override = overrides[packageName];
    if (override != null) return override;
    return prefs.getInt(_keyGlobalThreshold) ??
        MonitoredApp.defaultThresholdMinutes;
  }

  /// Map of package name -> effective threshold for a list of apps (one query,
  /// used by the background monitoring loop).
  static Future<Map<String, int>> getThresholdsFor(
    List<String> packages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final overrides = _decodeIntMap(prefs.getString(_keyThresholds));
    final global = prefs.getInt(_keyGlobalThreshold) ??
        MonitoredApp.defaultThresholdMinutes;
    return {
      for (final p in packages) p: overrides[p] ?? global,
    };
  }

  // ---------------------------------------------------------------------------
  // Anti-spam timestamps (last break-notification time per app)
  // ---------------------------------------------------------------------------

  static Future<Map<String, DateTime>> getLastNotifiedFor(
    List<String> packages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final map = _decodeIntMap(prefs.getString(_keyLastNotified));
    return {
      for (final p in packages)
        p: DateTime.fromMillisecondsSinceEpoch(map[p] ?? 0),
    };
  }

  static Future<void> setLastNotified(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeIntMap(prefs.getString(_keyLastNotified));
    map[packageName] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_keyLastNotified, jsonEncode(map));
  }

  // ---------------------------------------------------------------------------
  // Weekly summary bookkeeping
  // ---------------------------------------------------------------------------

  /// The Monday (start of week) that the last weekly summary covered, or null
  /// if no summary has ever been sent. Used to send the summary exactly once
  /// per week without any calendar/clock schedulers.
  static Future<DateTime?> getLastSummaryWeek() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final millis = prefs.getInt(_keyLastSummaryWeek);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> setLastSummaryWeek(DateTime monday) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSummaryWeek, monday.millisecondsSinceEpoch);
  }

  // ---------------------------------------------------------------------------
  // Map helpers (SharedPreferences has no native map type, so we JSON-encode)
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _decodeStringMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static Map<String, int> _decodeIntMap(String? json) {
    final map = _decodeStringMap(json);
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
}