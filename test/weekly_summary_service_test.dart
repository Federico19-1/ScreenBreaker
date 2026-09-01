import 'package:flutter_test/flutter_test.dart';
import 'package:screenbreaker/services/weekly_summary_service.dart';

void main() {
  group('WeeklySummaryService.startOfWeek', () {
    test('returns the Monday of the current week (ISO, Monday = 1)', () {
      // Friday 2026-08-28 belongs to the week starting Monday 2026-08-24.
      final result = WeeklySummaryService.startOfWeek(
        DateTime(2026, 8, 28, 15, 30),
      );
      expect(result, DateTime(2026, 8, 24));
    });

    test('Monday itself maps to itself (midnight)', () {
      final result = WeeklySummaryService.startOfWeek(
        DateTime(2026, 8, 24, 23, 59),
      );
      expect(result, DateTime(2026, 8, 24));
    });

    test('Sunday maps to the previous Monday', () {
      // Sunday 2026-08-30 → Monday 2026-08-24.
      final result = WeeklySummaryService.startOfWeek(DateTime(2026, 8, 30));
      expect(result, DateTime(2026, 8, 24));
    });

    test('handles month boundaries', () {
      // Thursday 2026-10-01 → Monday 2026-09-28.
      final result = WeeklySummaryService.startOfWeek(DateTime(2026, 10, 1));
      expect(result, DateTime(2026, 9, 28));
    });

    test('handles year boundaries', () {
      // Friday 2027-01-01 → Monday 2026-12-28.
      final result = WeeklySummaryService.startOfWeek(DateTime(2027, 1, 1));
      expect(result, DateTime(2026, 12, 28));
    });
  });

  group('WeeklySummaryService.formatDuration', () {
    test('formats hours and minutes', () {
      expect(
        WeeklySummaryService.formatDuration(
          const Duration(hours: 3, minutes: 25),
        ),
        '3h 25m',
      );
    });

    test('formats minutes only when under an hour', () {
      expect(
        WeeklySummaryService.formatDuration(const Duration(minutes: 25)),
        '25m',
      );
    });

    test('formats bare hours with zero minutes', () {
      expect(
        WeeklySummaryService.formatDuration(const Duration(hours: 2)),
        '2h 0m',
      );
    });
  });
}