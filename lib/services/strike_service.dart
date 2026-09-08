import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One over-limit alert = one strike (like in baseball): a life lost.
///
/// Every time the background monitoring loop fires a break notification,
/// [StrikeService.recordStrike] appends a record. The daily / weekly / monthly
/// reports count these to show how many "lives" were lost to mindless
/// scrolling.
class StrikeRecord {
  const StrikeRecord({
    required this.day,
    required this.packageName,
    required this.time,
  });

  /// Local day (midnight) the strike happened on.
  final DateTime day;

  /// Package that was over its limit.
  final String packageName;

  /// Exact moment the strike was recorded.
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'd': StrikeService.dayKey(day),
        'a': packageName,
        't': time.millisecondsSinceEpoch,
      };

  static StrikeRecord fromJson(Map<String, dynamic> json) {
    final day = DateTime.tryParse(json['d'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch((json['t'] as num? ?? 0).toInt());
    return StrikeRecord(
      day: DateTime(day.year, day.month, day.day),
      packageName: json['a'] as String? ?? '',
      time: DateTime.fromMillisecondsSinceEpoch((json['t'] as num? ?? 0).toInt()),
    );
  }
}

/// Persists and counts strikes.
///
/// Strikes are stored as a JSON list in SharedPreferences and pruned to the
/// last 90 days on every write, which comfortably covers the monthly report.
class StrikeService {
  StrikeService._();

  static const String _keyStrikes = 'screenbreaker.strikes';

  /// Lives available each day. Three strikes in one day = a day fully lost.
  static const int dailyLives = 3;

  /// How far back strike records are kept.
  static const int _retentionDays = 90;

  /// `yyyy-MM-dd` key for a local date.
  static String dayKey(DateTime day) {
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Records one strike for [packageName] right now (called from the
  /// monitoring loop right after a break notification is posted).
  static Future<void> recordStrike(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final record = StrikeRecord(
      day: DateTime(now.year, now.month, now.day),
      packageName: packageName,
      time: now,
    );

    final all = _decode(prefs.getString(_keyStrikes))..add(record);
    await prefs.setString(_keyStrikes, jsonEncode(_encode(_prune(all))));
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// All stored strikes, oldest first.
  static Future<List<StrikeRecord>> all() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = _decode(prefs.getString(_keyStrikes));
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  /// Strikes recorded on [day] (local midnight-based).
  static Future<int> strikesOnDay(DateTime day,
      {List<StrikeRecord>? strikes}) async {
    final list = strikes ?? await all();
    final target = DateTime(day.year, day.month, day.day);
    return list.where((s) => s.day == target).length;
  }

  /// Strikes in the inclusive window [start, end] (local days).
  static Future<int> strikesBetween(DateTime start, DateTime end,
      {List<StrikeRecord>? strikes}) async {
    final list = strikes ?? await all();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return list
        .where((s) => !s.day.isBefore(startDay) && !s.day.isAfter(endDay))
        .length;
  }

  /// Strikes recorded today.
  static Future<int> strikesToday({List<StrikeRecord>? strikes}) {
    final now = DateTime.now();
    return strikesOnDay(DateTime(now.year, now.month, now.day),
        strikes: strikes);
  }

  /// Lives (of [dailyLives]) still left today after the strikes taken so far.
  static Future<int> livesLeftToday({List<StrikeRecord>? strikes}) async {
    final used = await strikesToday(strikes: strikes);
    return (dailyLives - used).clamp(0, dailyLives);
  }

  /// Strikes per day for the last [days] days, oldest first — aligned with
  /// the daily usage series in the Reports screen. Passing [strikes] avoids
  /// re-reading storage for every call.
  static Future<List<int>> strikesPerDay(int days,
      {List<StrikeRecord>? strikes}) async {
    final list = strikes ?? await all();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(days, (i) {
      final day = DateTime(today.year, today.month, today.day - (days - 1 - i));
      return list.where((s) => s.day == day).length;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Drops records older than the retention window.
  static List<StrikeRecord> _prune(List<StrikeRecord> records) {
    final now = DateTime.now();
    final cutoff =
        DateTime(now.year, now.month, now.day - _retentionDays + 1);
    return records.where((s) => !s.day.isBefore(cutoff)).toList();
  }

  static List<StrikeRecord> _decode(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List<dynamic>) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(StrikeRecord.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _encode(List<StrikeRecord> records) {
    return records.map((r) => r.toJson()).toList();
  }
}
