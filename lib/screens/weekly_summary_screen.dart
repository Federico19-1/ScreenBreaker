import 'package:flutter/material.dart';

import '../services/preferences_repository.dart';
import '../services/usage_service.dart';
import '../services/weekly_summary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Detail screen opened by tapping the weekly summary notification.
///
/// Shows, for the most recently completed calendar week (Monday→Sunday), each
/// monitored app's total screen time plus a day-by-day breakdown. The data is
/// queried live from Android's usage statistics, so the screen always reflects
/// the same numbers the notification reported (and any corrections the system
/// applied in the meantime).
class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  static const List<String> _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool _loading = true;

  /// Monday of the completed week (range start) and the following Monday.
  late DateTime _weekStart;
  late DateTime _thisMonday;

  /// package → (name, per-day durations for Mon..Sun).
  Map<String, (String, List<Duration>)> _rows = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final enabled = await PreferencesRepository.getEnabledApps();
    _thisMonday = WeeklySummaryService.startOfWeek(DateTime.now());
    // The completed week: [last Monday, this Monday).
    _weekStart = DateTime(
      _thisMonday.year,
      _thisMonday.month,
      _thisMonday.day - 7,
    );

    // Query each day separately so we can present a per-day column.
    final perDay = <String, List<Duration>>{};
    for (var i = 0; i < 7; i++) {
      final dayStart = DateTime(
        _weekStart.year,
        _weekStart.month,
        _weekStart.day + i,
      );
      final dayEnd = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day + 1,
      );
      final usage = await UsageService.getUsageBetween(dayStart, dayEnd);
      for (final package in usage.keys) {
        perDay.putIfAbsent(package, () => List.filled(7, Duration.zero));
        perDay[package]![i] = usage[package] ?? Duration.zero;
      }
    }

    final rows = <String, (String, List<Duration>)>{};
    for (final package in enabled) {
      final durations = perDay[package] ?? List.filled(7, Duration.zero);
      final name = await PreferencesRepository.getAppName(package);
      rows[package] = (name, durations);
    }

    // Most-used apps first.
    final sorted = rows.entries.toList()
      ..sort(
        (a, b) => _total(b.value.$2).compareTo(_total(a.value.$2)),
      );

    if (!mounted) return;
    setState(() {
      _rows = {for (final e in sorted) e.key: e.value};
      _loading = false;
    });
  }

  static Duration _total(List<Duration> days) =>
      days.fold(Duration.zero, (sum, d) => sum + d);

  /// Compact per-day label: "3h", "45m", or "–" for no usage.
  static String _compact(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '–';
  }

  String _weekLabel(DateTime weekStart) {
    final lastDay = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );
    String fmt(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}';
    final sameMonth = weekStart.month == lastDay.month;
    return sameMonth
        ? '${_monthNames[weekStart.month - 1]} ${weekStart.day} – ${lastDay.day}'
        : '${fmt(weekStart)} – ${fmt(lastDay)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 26),
            SizedBox(width: 10),
            Text('Last week overview'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No monitored apps yet.\nEnable apps on the home screen to see '
            'your screen time here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.iceDim, height: 1.5),
          ),
        ),
      );
    }

    final weekTotal = _rows.values.fold<Duration>(
      Duration.zero,
      (sum, row) => sum + _total(row.$2),
    );
    final activeApps = _rows.values.where((row) => _total(row.$2) > Duration.zero).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Week header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weekLabel(_weekStart),
                style: const TextStyle(color: AppColors.iceDim, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                '${WeeklySummaryService.formatDuration(weekTotal)} across '
                '$activeApps app${activeApps == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Header row for the day columns
        Row(
          children: [
            const Expanded(
              flex: 3,
              child: Text(
                'App',
                style: TextStyle(color: AppColors.iceDim, fontSize: 12),
              ),
            ),
            for (final letter in _dayLetters)
              Expanded(
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: AppColors.iceDim,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const Expanded(
              child: Center(
                child: Text(
                  'Total',
                  style: TextStyle(color: AppColors.iceDim, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // One row per app
        for (final entry in _rows.entries) _AppWeekRow(
          name: entry.value.$1,
          days: entry.value.$2,
        ),
      ],
    );
  }
}

class _AppWeekRow extends StatelessWidget {
  const _AppWeekRow({required this.name, required this.days});
  final String name;
  final List<Duration> days;

  @override
  Widget build(BuildContext context) {
    final total = days.fold(Duration.zero, (sum, d) => sum + d);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.iceWhite, fontSize: 14),
            ),
          ),
          for (final day in days)
            Expanded(
              child: Center(
                child: Text(
                  _WeeklySummaryScreenState._compact(day),
                  style: TextStyle(
                    color: day.inMinutes > 0
                        ? AppColors.neonPurple
                        : AppColors.iceDim.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: Text(
                _WeeklySummaryScreenState._compact(total),
                style: const TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}