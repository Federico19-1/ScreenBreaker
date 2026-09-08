import 'package:flutter_test/flutter_test.dart';
import 'package:screenbreaker/services/strike_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StrikeService.recordStrike', () {
    test('stores a strike with today and the package', () async {
      SharedPreferences.setMockInitialValues({});
      await StrikeService.recordStrike('com.instagram.android');

      final all = await StrikeService.all();
      expect(all.length, 1);
      expect(all.first.packageName, 'com.instagram.android');

      final now = DateTime.now();
      expect(
        all.first.day,
        DateTime(now.year, now.month, now.day),
      );
    });

    test('counts multiple strikes per day', () async {
      SharedPreferences.setMockInitialValues({});
      await StrikeService.recordStrike('com.instagram.android');
      await StrikeService.recordStrike('com.youtube.android');
      await StrikeService.recordStrike('com.reddit.frontpage');

      expect(await StrikeService.strikesToday(), 3);
      expect(await StrikeService.livesLeftToday(), 0);
    });

    test('strikes survive a storage round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      await StrikeService.recordStrike('com.instagram.android');
      // A second "read" simulates the next isolate/session.
      expect(await StrikeService.strikesToday(), 1);
    });
  });

  group('StrikeService.livesLeftToday', () {
    test('is full with no strikes', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StrikeService.livesLeftToday(), StrikeService.dailyLives);
    });

    test('never goes negative when over 3 strikes', () async {
      SharedPreferences.setMockInitialValues({});
      for (var i = 0; i < 5; i++) {
        await StrikeService.recordStrike('com.instagram.android');
      }
      expect(await StrikeService.livesLeftToday(), 0);
      expect(await StrikeService.strikesToday(), 5);
    });
  });

  group('StrikeService.strikesBetween', () {
    test('only counts strikes inside the window', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final old20 = StrikeRecord(
        day: DateTime(today.year, today.month, today.day - 20),
        packageName: 'com.youtube.android',
        time: DateTime(today.year, today.month, today.day - 20, 10),
      );
      final old40 = StrikeRecord(
        day: DateTime(today.year, today.month, today.day - 40),
        packageName: 'com.reddit.frontpage',
        time: DateTime(today.year, today.month, today.day - 40, 10),
      );
      final todayStrike = StrikeRecord(
        day: today,
        packageName: 'com.instagram.android',
        time: now,
      );

      SharedPreferences.setMockInitialValues({
        'screenbreaker.strikes':
            '[${strikeJson(old20)},${strikeJson(old40)},${strikeJson(todayStrike)}]',
      });

      final week = DateTime(today.year, today.month, today.day - 6);
      expect(await StrikeService.strikesBetween(week, today), 1);

      final month = DateTime(today.year, today.month, today.day - 29);
      expect(await StrikeService.strikesBetween(month, today), 2);
    });
  });

  group('StrikeService.strikesPerDay', () {
    test('returns one bucket per day, oldest first', () async {
      SharedPreferences.setMockInitialValues({});
      await StrikeService.recordStrike('com.instagram.android');

      final perDay = await StrikeService.strikesPerDay(7);
      expect(perDay.length, 7);
      expect(perDay.last, 1); // today
      expect(perDay.take(6).every((c) => c == 0), isTrue);
    });
  });
}

/// Minimal JSON for a [StrikeRecord] matching the service's encoding.
String strikeJson(StrikeRecord r) {
  final json = r.toJson();
  return '{"d":"${json['d']}","a":"${json['a']}","t":${json['t']}}';
}
