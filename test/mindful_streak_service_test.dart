import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:screenbreaker/models/mindful_task.dart';
import 'package:screenbreaker/services/mindful_streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 'yyyy-MM-dd' key for a date, matching the service's internal format.
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
  group('MindfulStreakService.currentStreak', () {
    test('returns 0 with no completed days', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await MindfulStreakService.currentStreak(), 0);
    });

    test('counts consecutive completed days ending today', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_days': [
          key(_daysAgo(2)),
          key(_daysAgo(1)),
          key(_today()),
        ],
      });
      expect(await MindfulStreakService.currentStreak(), 3);
    });

    test('counts a streak ending yesterday while today is not yet completed',
        () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_days': [
          key(_daysAgo(3)),
          key(_daysAgo(2)),
          key(_daysAgo(1)),
        ],
      });
      expect(await MindfulStreakService.currentStreak(), 3);
    });

    test('returns 0 when neither today nor yesterday are completed', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_days': [key(_daysAgo(5))],
      });
      expect(await MindfulStreakService.currentStreak(), 0);
    });

    test('breaks the streak on a missing day', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_days': [
          key(_daysAgo(1)),
          key(_today()),
          key(_daysAgo(4)),
        ],
      });
      expect(await MindfulStreakService.currentStreak(), 2);
    });
  });

  group('MindfulStreakService.bestStreak', () {
    test('finds the longest run even with gaps', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_days': [
          key(_daysAgo(6)),
          key(_daysAgo(5)),
          key(_daysAgo(4)),
          key(_daysAgo(2)),
          key(_daysAgo(1)),
        ],
      });
      expect(await MindfulStreakService.bestStreak(), 3);
    });

    test('returns 0 with no completed days', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await MindfulStreakService.bestStreak(), 0);
    });
  });

  group('MindfulStreakService.completeToday', () {
    test('is idempotent for the same day', () async {
      SharedPreferences.setMockInitialValues({});
      await MindfulStreakService.completeToday();
      await MindfulStreakService.completeToday();
      expect(await MindfulStreakService.currentStreak(), 1);
    });

    test('extends an alive streak and updates the best streak', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_days': [
          key(_daysAgo(2)),
          key(_daysAgo(1)),
        ],
      });
      await MindfulStreakService.completeToday();
      expect(await MindfulStreakService.currentStreak(), 3);
      expect(await MindfulStreakService.bestStreak(), 3);
    });

    test('marks the day as completed and records the task id', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await MindfulStreakService.isCompletedToday(), isFalse);

      await MindfulStreakService.completeToday();

      expect(await MindfulStreakService.isCompletedToday(), isTrue);
      final task = await MindfulStreakService.completedTaskForDay(_today());
      expect(task, isNotNull);
      expect(task!.id, (await MindfulStreakService.todayTask()).id);
    });

    test('records an explicit taskId when given', () async {
      SharedPreferences.setMockInitialValues({});
      const expected = MindfulTask(
        id: 'mindful.meditate',
        emoji: '🧘',
        title: 'Meditate for 5 minutes',
        description: 'Breathe.',
      );
      await MindfulStreakService.completeToday(taskId: expected.id);
      final task = await MindfulStreakService.completedTaskForDay(_today());
      expect(task!.id, expected.id);
    });
  });

  group('MindfulStreakService.taskForDay', () {
    test('rotates through the catalog one task per day', () async {
      SharedPreferences.setMockInitialValues({});
      final day = _daysAgo(0);
      final index = DateTime.utc(day.year, day.month, day.day)
              .difference(DateTime.utc(1970))
              .inDays %
          MindfulTask.catalog.length;
      expect(
        (await MindfulStreakService.taskForDay(day)).id,
        MindfulTask.catalog[index].id,
      );
      // The next day presents the following catalog task.
      final nextDay = _daysAgo(-1);
      final nextIndex =
          (DateTime.utc(nextDay.year, nextDay.month, nextDay.day)
                      .difference(DateTime.utc(1970))
                      .inDays) %
              MindfulTask.catalog.length;
      expect(
        (await MindfulStreakService.taskForDay(nextDay)).id,
        MindfulTask.catalog[nextIndex].id,
      );
    });

    test('returns the swapped task for a day with an override', () async {
      const swapped = MindfulTask(
        id: 'mindful.meditate',
        emoji: '🧘',
        title: 'Meditate for 5 minutes',
        description: 'Breathe.',
      );
      final day = _today();
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_overrides':
            jsonEncode({key(day): swapped.id}),
      });
      expect((await MindfulStreakService.taskForDay(day)).id, swapped.id);
    });
  });

  group('MindfulStreakService.swapTodayTask', () {
    test('changes today\'s task to a different one', () async {
      SharedPreferences.setMockInitialValues({});
      final before = await MindfulStreakService.todayTask();
      final after = await MindfulStreakService.swapTodayTask();
      expect(after.id, isNot(before.id));
      // And the swap is persisted for the rest of the day.
      expect((await MindfulStreakService.todayTask()).id, after.id);
    });
  });

  group('MindfulStreakService.recentHistory', () {
    test('returns the last N days oldest-first with completed tasks', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.mindful_completed':
            jsonEncode({key(_daysAgo(1)): 'mindful.meditate'}),
      });
      final history = await MindfulStreakService.recentHistory(7);
      expect(history.length, 7);
      expect(history.first.$1, _daysAgo(6));
      expect(history.last.$1, _today());
      // Yesterday has a completed task; the day before does not.
      expect(history[5].$2?.id, 'mindful.meditate');
      expect(history[4].$2, isNull);
    });
  });

  group('MindfulTask.byId', () {
    test('finds catalog tasks by id and returns null otherwise', () {
      expect(MindfulTask.byId('mindful.meditate'), isNotNull);
      expect(MindfulTask.byId('nope'), isNull);
    });
  });
}
