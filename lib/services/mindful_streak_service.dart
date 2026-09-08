import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mindful_task.dart';

/// Tracks the **mindful streak**: how many consecutive days the user
/// completed a small well-being task (meditate, share a profound thought,
/// phone-free walk, …).
///
/// Unlike [StreakService] — which counts every day the app is opened — this
/// streak only grows when the user deliberately does something good for
/// themselves, ideally away from the screen. That makes it the honest
/// "disconnect" streak the app is about.
///
/// State persisted in SharedPreferences:
///  - `_keyDays`      : list of `yyyy-MM-dd` keys, one per completed day.
///  - `_keyBest`      : best streak ever.
///  - `_keyCompleted` : JSON map `yyyy-MM-dd` → task id (what was done).
///  - `_keyOverrides` : JSON map `yyyy-MM-dd` → task id (user-swapped task),
///    so a swapped task is deterministic for that day.
class MindfulStreakService {
  MindfulStreakService._();

  static const String _keyDays = 'screenbreaker.mindful_days';
  static const String _keyBest = 'screenbreaker.mindful_best';
  static const String _keyCompleted = 'screenbreaker.mindful_completed';
  static const String _keyOverrides = 'screenbreaker.mindful_overrides';

  // ---------------------------------------------------------------------------
  // Task of the day
  // ---------------------------------------------------------------------------

  /// The mindful task for [day]: the user's swap for that day if any, else the
  /// catalog entry given by the day's index (one task per day in rotation).
  static Future<MindfulTask> taskForDay(DateTime day,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final key = _dayKey(day);

    final overrides = _decodeTaskMap(p.getString(_keyOverrides));
    final swapped = overrides[key];
    if (swapped != null) return swapped;

    final index = _dayIndex(day) % MindfulTask.catalog.length;
    return MindfulTask.catalog[index];
  }

  /// The mindful task for today.
  static Future<MindfulTask> todayTask({SharedPreferences? prefs}) {
    return taskForDay(_today(), prefs: prefs);
  }

  /// Replaces today's task with the next catalog task that is not today's and
  /// was not completed recently. Returns the new task.
  static Future<MindfulTask> swapTodayTask() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await todayTask(prefs: prefs);

    // Collect the tasks completed in the last few days so we avoid repeats.
    final completed = _decodeTaskMap(prefs.getString(_keyCompleted));
    final recent = <String>{};
    for (var d = 0; d < 3; d++) {
      final dayKey = _dayKey(DateTime(_today().year, _today().month, _today().day - d));
      final task = completed[dayKey];
      if (task != null) recent.add(task.id);
    }

    final startIndex = _dayIndex(_today()) % MindfulTask.catalog.length;
    MindfulTask? next;
    for (var step = 1; step <= MindfulTask.catalog.length; step++) {
      final candidate =
          MindfulTask.catalog[(startIndex + step) % MindfulTask.catalog.length];
      if (candidate.id != current.id && !recent.contains(candidate.id)) {
        next = candidate;
        break;
      }
    }
    // All other tasks were completed recently: just take the very next one.
    next ??= MindfulTask.catalog[(startIndex + 1) % MindfulTask.catalog.length];

    final overrides = _decodeTaskMap(prefs.getString(_keyOverrides));
    overrides[_dayKey(_today())] = next;
    await prefs.setString(_keyOverrides, jsonEncode(_encodeTaskMap(overrides)));
    return next;
  }

  // ---------------------------------------------------------------------------
  // Completion
  // ---------------------------------------------------------------------------

  /// Whether the mindful task has already been completed today.
  static Future<bool> isCompletedToday({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final completed = _decodeTaskMap(p.getString(_keyCompleted));
    return completed.containsKey(_dayKey(_today()));
  }

  /// Marks today's task as done (idempotent). Records which task was
  /// completed and grows the mindful streak by one day if it was still alive.
  static Future<void> completeToday({String? taskId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dayKey(_today());

    final task = MindfulTask.byId(taskId ?? '') ?? await todayTask(prefs: prefs);

    final completed = _decodeTaskMap(prefs.getString(_keyCompleted));
    completed[key] = task;
    await prefs.setString(_keyCompleted, jsonEncode(_encodeTaskMap(completed)));

    final days = (prefs.getStringList(_keyDays) ?? const []).toSet();
    days.add(key);
    await prefs.setStringList(_keyDays, days.toList()..sort());

    final best = await bestStreak(prefs: prefs);
    final current = await currentStreak(prefs: prefs);
    if (current > best) {
      await prefs.setInt(_keyBest, current);
    }
  }

  /// The task that was completed on [day], or null if none was.
  static Future<MindfulTask?> completedTaskForDay(DateTime day,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return _decodeTaskMap(p.getString(_keyCompleted))[_dayKey(day)];
  }

  /// The last [count] days (oldest first) with the task completed on each.
  /// Useful for a "last 7 days" history strip in the UI.
  static Future<List<(DateTime, MindfulTask?)>> recentHistory(int count,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final completed = _decodeTaskMap(p.getString(_keyCompleted));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <(DateTime, MindfulTask?)>[];
    for (var i = count - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      result.add((day, completed[_dayKey(day)]));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Streaks
  // ---------------------------------------------------------------------------

  /// Consecutive completed days ending today; if today isn't completed yet but
  /// yesterday is, the streak is still "alive" and counts from yesterday.
  static Future<int> currentStreak({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final days = _sortedDates(p.getStringList(_keyDays) ?? const []);
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var cursor = today;
    if (!days.contains(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (!days.contains(cursor)) return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  /// Longest run of consecutive completed days ever.
  static Future<int> bestStreak({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final stored = p.getInt(_keyBest);
    if (stored != null && stored > 0) return stored;

    final days = _sortedDates(p.getStringList(_keyDays) ?? const []);
    if (days.isEmpty) return 0;

    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      run = (diff == 1) ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// `yyyy-MM-dd` key for a local date.
  static String _dayKey(DateTime day) {
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  /// Days since 1970-01-01 for a local date (DST-safe via UTC normalization).
  static int _dayIndex(DateTime day) {
    return DateTime.utc(day.year, day.month, day.day)
            .difference(DateTime.utc(1970))
            .inDays;
  }

  static List<DateTime> _sortedDates(List<String> keys) {
    final dates = <DateTime>[];
    for (final key in keys) {
      final date = DateTime.tryParse(key);
      if (date != null) dates.add(DateTime(date.year, date.month, date.day));
    }
    dates.sort();
    return dates;
  }

  static Map<String, MindfulTask> _decodeTaskMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return {};
      final map = <String, MindfulTask>{};
      decoded.forEach((key, value) {
        final task = MindfulTask.byId(value is String ? value : '');
        if (task != null) map[key] = task;
      });
      return map;
    } catch (_) {
      return {};
    }
  }

  static Map<String, String> _encodeTaskMap(Map<String, MindfulTask> map) {
    return map.map((key, task) => MapEntry(key, task.id));
  }
}
