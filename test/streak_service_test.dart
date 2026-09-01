import 'package:flutter_test/flutter_test.dart';
import 'package:screenbreaker/services/streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 'yyyy-MM-dd' key for a date.
String key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _daysAgo(int days) =>
    DateTime(_today().year, _today().month, _today().day - days);

void main() {
  group('StreakService.currentStreak', () {
    test('returns 0 with no recorded days', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StreakService.currentStreak(), 0);
    });

    test('counts consecutive days ending today', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.streak_days': [
          key(_daysAgo(2)),
          key(_daysAgo(1)),
          key(_today()),
        ],
      });
      expect(await StreakService.currentStreak(), 3);
    });

    test('counts a streak ending yesterday while today is not yet recorded',
        () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.streak_days': [
          key(_daysAgo(3)),
          key(_daysAgo(2)),
          key(_daysAgo(1)),
        ],
      });
      expect(await StreakService.currentStreak(), 3);
    });

    test('returns 0 when neither today nor yesterday are recorded', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.streak_days': [key(_daysAgo(5))],
      });
      expect(await StreakService.currentStreak(), 0);
    });

    test('breaks the streak on a missing day', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.streak_days': [
          key(_daysAgo(1)),
          key(_today()),
          key(_daysAgo(4)),
        ],
      });
      expect(await StreakService.currentStreak(), 2);
    });
  });

  group('StreakService.bestStreak', () {
    test('finds the longest run even with gaps', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.streak_days': [
          key(_daysAgo(6)),
          key(_daysAgo(5)),
          key(_daysAgo(4)),
          key(_daysAgo(2)),
          key(_daysAgo(1)),
        ],
      });
      expect(await StreakService.bestStreak(), 3);
    });

    test('returns 0 with no recorded days', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StreakService.bestStreak(), 0);
    });
  });

  group('StreakService.recordToday', () {
    test('is idempotent for the same day', () async {
      SharedPreferences.setMockInitialValues({});
      await StreakService.recordToday();
      await StreakService.recordToday();
      expect(await StreakService.currentStreak(), 1);
    });

    test('extends an alive streak and updates the best streak', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.streak_days': [
          key(_daysAgo(2)),
          key(_daysAgo(1)),
        ],
      });
      await StreakService.recordToday();
      expect(await StreakService.currentStreak(), 3);
      expect(await StreakService.bestStreak(), 3);
    });
  });
}
