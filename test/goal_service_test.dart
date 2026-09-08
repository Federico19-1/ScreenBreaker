import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:screenbreaker/models/goal.dart';
import 'package:screenbreaker/services/goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GoalService.getGoals', () {
    test('creates the three default total goals on first read', () async {
      SharedPreferences.setMockInitialValues({});
      final goals = await GoalService.getGoals();
      expect(goals.length, 3);
      expect(goals.map((g) => g.period),
          containsAll([GoalPeriod.daily, GoalPeriod.weekly, GoalPeriod.monthly]));
      expect(goals.every((g) => g.isTotal), isTrue);
    });

    test('reads back persisted goals', () async {
      SharedPreferences.setMockInitialValues({
        'screenbreaker.goals': jsonEncode([
          {
            'id': 'app.com.instagram.android.daily',
            'period': 'daily',
            'maxMinutes': 45,
            'packageName': 'com.instagram.android',
          },
        ]),
      });
      final goals = await GoalService.getGoals();
      expect(goals.length, 1);
      expect(goals.first.packageName, 'com.instagram.android');
      expect(goals.first.maxMinutes, 45);
    });
  });

  group('GoalService.upsertGoal', () {
    test('updates an existing goal with the same id', () async {
      SharedPreferences.setMockInitialValues({});
      await GoalService.upsertGoal(
        const Goal(
          id: 'total.daily',
          period: GoalPeriod.daily,
          maxMinutes: 120,
        ),
      );
      final goals = await GoalService.getGoals();
      expect(goals.where((g) => g.id == 'total.daily').length, 1);
      expect(
        goals.firstWhere((g) => g.id == 'total.daily').maxMinutes,
        120,
      );
    });

    test('adds a new per-app goal alongside the defaults', () async {
      SharedPreferences.setMockInitialValues({});
      // Trigger default creation.
      await GoalService.getGoals();
      await GoalService.upsertGoal(
        const Goal(
          id: 'app.com.youtube.android.daily',
          period: GoalPeriod.daily,
          maxMinutes: 30,
          packageName: 'com.youtube.android',
        ),
      );
      final goals = await GoalService.getGoals();
      expect(goals.length, 4);
      expect(
        goals.where((g) => g.packageName == 'com.youtube.android').length,
        1,
      );
    });
  });

  group('GoalService.deleteGoal', () {
    test('removes only the requested goal', () async {
      SharedPreferences.setMockInitialValues({});
      await GoalService.getGoals(); // create defaults
      await GoalService.upsertGoal(
        const Goal(
          id: 'app.com.reddit.frontpage.daily',
          period: GoalPeriod.daily,
          maxMinutes: 20,
          packageName: 'com.reddit.frontpage',
        ),
      );
      await GoalService.deleteGoal('app.com.reddit.frontpage.daily');
      final goals = await GoalService.getGoals();
      expect(goals.length, 3);
      expect(
        goals.where((g) => g.id == 'app.com.reddit.frontpage.daily'),
        isEmpty,
      );
    });
  });

  group('GoalProgress', () {
    test('computes fraction, remaining and over status', () {
      const goal = Goal(
        id: 'total.daily',
        period: GoalPeriod.daily,
        maxMinutes: 120,
      );
      final under = GoalProgress(goal: goal, spentMinutes: 60);
      expect(under.fraction, closeTo(0.5, 0.001));
      expect(under.isOver, isFalse);
      expect(under.remainingMinutes, 60);
      expect(under.remainingLabel, '1h left');

      final over = GoalProgress(goal: goal, spentMinutes: 150);
      expect(over.fraction, 1.0);
      expect(over.isOver, isTrue);
      expect(over.remainingLabel, 'over by 30m');
    });

    test('handles a zero limit without dividing by zero', () {
      const goal = Goal(
        id: 'total.daily',
        period: GoalPeriod.daily,
        maxMinutes: 0,
      );
      final p = GoalProgress(goal: goal, spentMinutes: 10);
      expect(p.fraction, 1.0);
      expect(p.isOver, isTrue);
    });
  });

  group('Goal labels', () {
    test('formats limits and period labels', () {
      const g1 = Goal(
        id: 'a',
        period: GoalPeriod.daily,
        maxMinutes: 150,
      );
      expect(g1.limitLabel, '2h 30m');
      expect(g1.periodLabel, 'Daily');
      expect(g1.perLabel, 'per day');

      const g2 = Goal(
        id: 'b',
        period: GoalPeriod.monthly,
        maxMinutes: 60,
      );
      expect(g2.limitLabel, '1h');
      expect(g2.periodLabel, 'Monthly');
    });
  });
}
