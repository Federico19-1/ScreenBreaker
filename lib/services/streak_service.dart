import 'package:shared_preferences/shared_preferences.dart';

/// Tracks how consistently the user "uses" ScreenBreaker: every day the app is
/// opened or the monitoring service ticks, that calendar day is recorded. The
/// streak is the number of consecutive recorded days ending today (or
/// yesterday, while today is still in progress).
///
/// Both the UI isolate (app opened) and the foreground-service isolate
/// (monitoring tick) call [recordToday], so simply keeping monitoring enabled
/// keeps the streak alive — which is exactly the behavior we want to reward.
class StreakService {
  StreakService._();

  static const String _keyDays = 'screenbreaker.streak_days';
  static const String _keyBest = 'screenbreaker.best_streak';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Marks today as an active day (idempotent).
  static Future<void> recordToday() async {
    final prefs = await SharedPreferences.getInstance();
    final days = (prefs.getStringList(_keyDays) ?? const []).toSet();
    days.add(_todayKey());
    await prefs.setStringList(_keyDays, days.toList()..sort());

    final best = await bestStreak(prefs: prefs);
    final current = await currentStreak(prefs: prefs);
    if (current > best) {
      await prefs.setInt(_keyBest, current);
    }
  }

  /// Consecutive recorded days ending today; if today isn't recorded yet but
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

  /// Longest run of consecutive recorded days ever.
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

  static List<DateTime> _sortedDates(List<String> keys) {
    final dates = <DateTime>[];
    for (final key in keys) {
      final date = DateTime.tryParse(key);
      if (date != null) dates.add(DateTime(date.year, date.month, date.day));
    }
    dates.sort();
    return dates;
  }
}
