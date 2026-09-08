/// The period a goal covers.
enum GoalPeriod { daily, weekly, monthly }

/// A user-defined screen-time goal: "at most [maxMinutes] minutes
/// [of packageName] per [period]".
///
/// When [packageName] is null the goal applies to the total screen time of
/// every app on the device. Well-known ids (`total.daily`, `total.weekly`,
/// `total.monthly`) are used for the three total-time goals so they can be
/// upserted reliably.
class Goal {
  const Goal({
    required this.id,
    required this.period,
    required this.maxMinutes,
    this.packageName,
  });

  /// Stable unique identifier (also used as the upsert key).
  final String id;

  /// How often the goal resets.
  final GoalPeriod period;

  /// Time limit in minutes per period.
  final int maxMinutes;

  /// Package the goal is limited to, or null for total screen time.
  final String? packageName;

  bool get isTotal => packageName == null;

  /// Human-readable period name, e.g. "Daily".
  String get periodLabel {
    switch (period) {
      case GoalPeriod.daily:
        return 'Daily';
      case GoalPeriod.weekly:
        return 'Weekly';
      case GoalPeriod.monthly:
        return 'Monthly';
    }
  }

  /// Lowercase period word for sentences, e.g. "per day".
  String get perLabel {
    switch (period) {
      case GoalPeriod.daily:
        return 'per day';
      case GoalPeriod.weekly:
        return 'per week';
      case GoalPeriod.monthly:
        return 'per month';
    }
  }

  /// `2h 30m` style formatting.
  String get limitLabel {
    final h = maxMinutes ~/ 60;
    final m = maxMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'period': period.name,
        'maxMinutes': maxMinutes,
        if (packageName != null) 'packageName': packageName,
      };

  static Goal fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      period: GoalPeriod.values.firstWhere(
        (p) => p.name == json['period'],
        orElse: () => GoalPeriod.daily,
      ),
      maxMinutes: (json['maxMinutes'] as num).toInt(),
      packageName: json['packageName'] as String?,
    );
  }
}
