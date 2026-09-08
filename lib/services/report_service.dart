import '../services/preferences_repository.dart';
import 'usage_service.dart';

/// How far back a report looks.
enum ReportRange { week, month }

/// One day's total screen time.
class DailyUsage {
  const DailyUsage({required this.day, required this.duration});
  final DateTime day;
  final Duration duration;
}

/// Aggregated "how well did I manage my time" data for the Reports page.
///
/// Everything is computed from two sources: Android usage stats (screen time
/// per day) and the break days recorded by [PreferencesRepository] whenever
/// the user confirms a break on the full-screen Break page.
class ReportData {
  const ReportData({
    required this.range,
    required this.dailyUsage,
    required this.totalScreenTime,
    required this.averageDay,
    required this.activeDays,
    required this.bestDay,
    required this.worstDay,
    required this.breakDays,
    required this.breakRate,
    required this.trendMinutes,
    required this.score,
  });

  final ReportRange range;

  /// One entry per day of the window (oldest first), including zero-usage days.
  final List<DailyUsage> dailyUsage;

  /// Total screen time across the whole window.
  final Duration totalScreenTime;

  /// Average screen time across days that had any usage.
  final Duration averageDay;

  /// How many days in the window had at least some usage.
  final int activeDays;

  /// The day with the least usage (among days with usage), or null.
  final DailyUsage? bestDay;

  /// The day with the most usage, or null.
  final DailyUsage? worstDay;

  /// Number of days in the window on which the user confirmed a break.
  final int breakDays;

  /// Break days / active days (0..1).
  final double breakRate;

  /// Second half of the window minus first half, in minutes. Negative means
  /// screen time went down — a good thing.
  final int trendMinutes;

  /// Overall time-management score, 0–100.
  final int score;
}

class ReportService {
  ReportService._();

  /// Builds the report covering [range]: daily usage series, totals, average,
  /// best/worst days, break stats and an overall score.
  static Future<ReportData> build(ReportRange range) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = range == ReportRange.week ? 7 : 30;
    final start = DateTime(today.year, today.month, today.day - (days - 1));

    // One aggregated usage query per day, run in parallel.
    final daily = await Future.wait(
      List.generate(days, (i) async {
        final day =
            DateTime(today.year, today.month, today.day - (days - 1 - i));
        final dayEnd = DateTime(day.year, day.month, day.day + 1);
        final usage = await UsageService.getUsageBetween(day, dayEnd);
        return DailyUsage(
          day: day,
          duration: usage.values.fold<Duration>(
            Duration.zero,
            (sum, d) => sum + d,
          ),
        );
      }),
    );

    final total = daily.fold<Duration>(
      Duration.zero,
      (sum, e) => sum + e.duration,
    );
    final activeDays = daily
        .where((e) => e.duration > Duration.zero)
        .length;
    final average = activeDays == 0
        ? Duration.zero
        : Duration(minutes: total.inMinutes ~/ activeDays);

    // Best = least usage, worst = most usage among days with any usage.
    DailyUsage? best;
    DailyUsage? worst;
    for (final e in daily) {
      if (e.duration == Duration.zero) continue;
      if (best == null || e.duration < best.duration) best = e;
      if (worst == null || e.duration > worst.duration) worst = e;
    }

    // Breaks: count recorded break days inside the window.
    final breakKeys = await PreferencesRepository.getBreakDays();
    var breakDays = 0;
    for (final key in breakKeys) {
      final date = DateTime.tryParse(key);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (!day.isBefore(start) && !day.isAfter(today)) breakDays++;
    }
    final breakRate = activeDays == 0 ? 0.0 : breakDays / activeDays;

    // Trend: compare the second half of the window against the first half.
    final half = days ~/ 2;
    final firstHalf = daily
        .take(half)
        .fold<Duration>(Duration.zero, (s, e) => s + e.duration);
    final secondHalf = daily
        .skip(days - half)
        .fold<Duration>(Duration.zero, (s, e) => s + e.duration);
    final trendMinutes = secondHalf.inMinutes - firstHalf.inMinutes;

    final score = _score(
      total: total,
      activeDays: activeDays,
      breakRate: breakRate,
    );

    return ReportData(
      range: range,
      dailyUsage: daily,
      totalScreenTime: total,
      averageDay: average,
      activeDays: activeDays,
      bestDay: best,
      worstDay: worst,
      breakDays: breakDays,
      breakRate: breakRate,
      trendMinutes: trendMinutes,
      score: score,
    );
  }

  /// Overall time-management score from 0 to 100.
  ///
  /// 60 points come from staying under a 4h/day average budget, 40 from
  /// taking breaks on at least half of the active days.
  static int _score({
    required Duration total,
    required int activeDays,
    required double breakRate,
  }) {
    if (activeDays == 0) return 0;
    final avgMinutes = total.inMinutes / activeDays;
    // 0 min → 60 pts, 4h → 30 pts, 8h+ → 0 pts.
    final timePoints = 60 * (1 - (avgMinutes / 480).clamp(0.0, 1.0));
    final breakPoints = 40 * breakRate.clamp(0.0, 1.0);
    return (timePoints + breakPoints).round().clamp(0, 100);
  }
}
