import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal.dart';
import 'usage_service.dart';

/// Persists the user's daily/weekly/monthly screen-time goals and computes
/// progress toward them for the current period.
///
/// Goals are stored as a JSON list in SharedPreferences. The three default
/// total-time goals (`total.daily`, `total.weekly`, `total.monthly`) are
/// created lazily on first read so the Goals screen always has something to
/// show; per-app goals can be added or removed freely.
class GoalService {
  GoalService._();

  static const String _keyGoals = 'screenbreaker.goals';

  static const String _dailyId = 'total.daily';
  static const String _weeklyId = 'total.weekly';
  static const String _monthlyId = 'total.monthly';

  /// Sensible defaults: 3h/day, 16h/week, 60h/month of total screen time.
  static const int _defaultDailyMinutes = 180;
  static const int _defaultWeeklyMinutes = 960;
  static const int _defaultMonthlyMinutes = 3600;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// All saved goals (creating the defaults on first use).
  static Future<List<Goal>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_keyGoals);
    if (raw == null) {
      final defaults = [
        Goal(
          id: _dailyId,
          period: GoalPeriod.daily,
          maxMinutes: _defaultDailyMinutes,
        ),
        Goal(
          id: _weeklyId,
          period: GoalPeriod.weekly,
          maxMinutes: _defaultWeeklyMinutes,
        ),
        Goal(
          id: _monthlyId,
          period: GoalPeriod.monthly,
          maxMinutes: _defaultMonthlyMinutes,
        ),
      ];
      await _saveGoals(prefs, defaults);
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves a goal, replacing any goal with the same [goal.id].
  static Future<void> upsertGoal(Goal goal) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await _loadWithoutDefaults(prefs);
    goals.removeWhere((g) => g.id == goal.id);
    goals.add(goal);
    await _saveGoals(prefs, goals);
  }

  /// Removes the goal with [goalId]; no-op if it doesn't exist.
  static Future<void> deleteGoal(String goalId) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await _loadWithoutDefaults(prefs);
    goals.removeWhere((g) => g.id == goalId);
    await _saveGoals(prefs, goals);
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  /// Progress of every goal in the current period, in the same order as
  /// [getGoals]. Spent time is computed from Android usage stats.
  static Future<List<GoalProgress>> currentProgress() async {
    final goals = await getGoals();
    final result = <GoalProgress>[];
    for (final goal in goals) {
      final spent = await _spentInCurrentPeriod(goal);
      result.add(
        GoalProgress(
          goal: goal,
          spentMinutes: spent.inMinutes,
        ),
      );
    }
    return result;
  }

  static Future<Duration> _spentInCurrentPeriod(Goal goal) async {
    final now = DateTime.now();
    switch (goal.period) {
      case GoalPeriod.daily:
        final start = DateTime(now.year, now.month, now.day);
        return _usageFor(goal, start, now);
      case GoalPeriod.weekly:
        final day = DateTime(now.year, now.month, now.day);
        final start = DateTime(day.year, day.month, day.day - (day.weekday - 1));
        return _usageFor(goal, start, now);
      case GoalPeriod.monthly:
        return _usageFor(goal, DateTime(now.year, now.month, 1), now);
    }
  }

  static Future<Duration> _usageFor(
    Goal goal,
    DateTime start,
    DateTime end,
  ) async {
    final usage = await UsageService.getUsageBetween(start, end);
    if (goal.isTotal) {
      return usage.values.fold<Duration>(
        Duration.zero,
        (sum, d) => sum + d,
      );
    }
    return usage[goal.packageName] ?? Duration.zero;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Future<List<Goal>> _loadWithoutDefaults(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_keyGoals);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveGoals(
    SharedPreferences prefs,
    List<Goal> goals,
  ) async {
    await prefs.setString(
      _keyGoals,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
  }
}

/// A goal together with the time already spent in its current period.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.spentMinutes,
  });

  final Goal goal;
  final int spentMinutes;

  /// Fraction of the limit already used, clamped to 0..1 (can exceed 1 when
  /// over budget, hence the clamp).
  double get fraction =>
      goal.maxMinutes <= 0 ? 1.0 : (spentMinutes / goal.maxMinutes).clamp(0.0, 1.0);

  /// Whether the limit has been reached or exceeded.
  bool get isOver => spentMinutes >= goal.maxMinutes;

  /// Minutes still allowed before hitting the limit (0 when over).
  int get remainingMinutes =>
      (goal.maxMinutes - spentMinutes).clamp(0, goal.maxMinutes);

  /// `1h 45m` style label of the time already spent.
  String get spentLabel => _fmt(Duration(minutes: spentMinutes));

  /// `45m left` label, or `over by 15m` when the limit is exceeded.
  String get remainingLabel {
    if (isOver) {
      return 'over by ${_fmt(Duration(minutes: spentMinutes - goal.maxMinutes))}';
    }
    return '${_fmt(Duration(minutes: remainingMinutes))} left';
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}
