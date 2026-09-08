import 'package:flutter_test/flutter_test.dart';
import 'package:screenbreaker/services/preferences_repository.dart';
import 'package:screenbreaker/services/report_service.dart';
import 'package:screenbreaker/services/strike_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReportService', () {
    test('returns one entry per day in the window, oldest first', () async {
      SharedPreferences.setMockInitialValues({});
      final report = await ReportService.build(ReportRange.week);
      expect(report.dailyUsage.length, 7);
      // Without real usage data everything is zero, so no active days.
      expect(report.activeDays, 0);
      expect(report.totalScreenTime, Duration.zero);
      expect(report.score, 0);
      expect(report.bestDay, isNull);
      expect(report.worstDay, isNull);
    });

    test('today window has exactly one entry and one life set', () async {
      SharedPreferences.setMockInitialValues({});
      final report = await ReportService.build(ReportRange.today);
      expect(report.dailyUsage.length, 1);
      expect(report.livesTotal, StrikeService.dailyLives);
      expect(report.strikes, 0);
    });

    test('monthly window has 30 entries', () async {
      SharedPreferences.setMockInitialValues({});
      final report = await ReportService.build(ReportRange.month);
      expect(report.dailyUsage.length, 30);
      expect(report.livesTotal, StrikeService.dailyLives * 30);
    });

    test('counts recorded break days inside the window', () async {
      final now = DateTime.now();
      String key(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final today = DateTime(now.year, now.month, now.day);

      SharedPreferences.setMockInitialValues({
        'screenbreaker.break_days': [
          key(today),
          key(DateTime(today.year, today.month, today.day - 1)),
          key(DateTime(today.year, today.month, today.day - 10)),
        ],
      });
      final report = await ReportService.build(ReportRange.week);
      // Two break days fall within the last 7 days; the 10-days-ago one does
      // not. But without usage data there are no active days, so the rate is 0.
      expect(report.breakDays, 2);
      expect(report.breakRate, 0.0);
    });
  });

  group('PreferencesRepository break days', () {
    test('recordBreakToday is idempotent and getBreakDays reads it back',
        () async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesRepository.recordBreakToday();
      await PreferencesRepository.recordBreakToday();
      final days = await PreferencesRepository.getBreakDays();
      expect(days.length, 1);
    });
  });
}
