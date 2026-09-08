import 'package:flutter/material.dart';

import '../services/preferences_repository.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Tracking section: how much time was spent in apps, broken down by hour of
/// the day and by app, with day-by-day navigation.
///
/// The data is queried live from Android's usage statistics for the selected
/// day (24 hourly queries, one per hour bucket).
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  /// The day being inspected (local midnight).
  late DateTime _date;

  bool _loading = true;
  bool _failed = false;

  /// 24 entries: hour index → package → time used in that hour.
  List<Map<String, Duration>> _byHour = const [];
  Map<String, Duration> _appTotals = const {};
  Map<String, String> _appNames = const {};

  static const int _maxDaysBack = 90;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final byHour = await UsageService.getUsageByHourForDay(_date);
      final totals = <String, Duration>{};
      for (final hour in byHour) {
        for (final entry in hour.entries) {
          totals[entry.key] =
              (totals[entry.key] ?? Duration.zero) + entry.value;
        }
      }

      // Resolve display names for every package that shows up.
      final names = <String, String>{};
      for (final package in totals.keys) {
        names[package] = await PreferencesRepository.getAppName(package);
      }

      if (!mounted) return;
      setState(() {
        _byHour = byHour;
        _appTotals = totals;
        _appNames = names;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  void _goTo(DateTime day) {
    setState(() => _date = day);
    _load();
  }

  void _previousDay() {
    _goTo(DateTime(_date.year, _date.month, _date.day - 1));
  }

  void _nextDay() {
    if (_isToday) return;
    _goTo(DateTime(_date.year, _date.month, _date.day + 1));
  }

  String _dayLabel() {
    final now = DateTime.now();
    if (_isToday) return 'Today';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_date.year == yesterday.year &&
        _date.month == yesterday.month &&
        _date.day == yesterday.day) {
      return 'Yesterday';
    }
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[_date.weekday - 1]}, '
        '${months[_date.month - 1]} ${_date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AppLogo(size: 26),
            SizedBox(width: 10),
            Text('Your tracking'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? _ErrorState(onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final total = _appTotals.values.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DaySelector(
          label: _dayLabel(),
          canGoNext: !_isToday,
          canGoBack: DateTime.now()
                  .difference(_date)
                  .inDays <
              _maxDaysBack,
          onPrevious: _previousDay,
          onNext: _nextDay,
        ),
        const SizedBox(height: 16),
        _SummaryCard(total: total, date: _date),
        const SizedBox(height: 16),
        _HourChartCard(
          byHour: _byHour,
          appTotals: _appTotals,
          appNames: _appNames,
        ),
        const SizedBox(height: 16),
        _AppBreakdownCard(
          appTotals: _appTotals,
          appNames: _appNames,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day selector
// ---------------------------------------------------------------------------

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.label,
    required this.canGoNext,
    required this.canGoBack,
    required this.onPrevious,
    required this.onNext,
  });
  final String label;
  final bool canGoNext;
  final bool canGoBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: appCardDecoration(),
      child: Row(
        children: [
          IconButton(
            onPressed: canGoBack ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
            color: canGoBack ? AppColors.iceWhite : AppColors.iceDim,
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            color: canGoNext ? AppColors.iceWhite : AppColors.iceDim,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.date});
  final Duration total;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDuration(total),
            style: TextStyle(
              color: AppColors.iceWhite,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'total screen time on ${_shortDate(date)}',
            style: TextStyle(
              color: AppColors.iceWhite.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// ---------------------------------------------------------------------------
// Hourly stacked chart
// ---------------------------------------------------------------------------

class _HourChartCard extends StatelessWidget {
  const _HourChartCard({
    required this.byHour,
    required this.appTotals,
    required this.appNames,
  });
  final List<Map<String, Duration>> byHour;
  final Map<String, Duration> appTotals;
  final Map<String, String> appNames;

  static final List<Color> _palette = [
    AppColors.neonPurple,
    AppColors.techMagenta,
    AppColors.success,
    Color(0xFF8B5CF6),
    Color(0xFFFF8AE2),
    Color(0xFF4CC9F0),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = appTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Top apps get their own color; everything else collapses into "Other".
    final top = sorted.take(_palette.length - 1).toList();
    final colors = <String, Color>{
      for (var i = 0; i < top.length; i++)
        top[i].key: _palette[i],
    };
    final otherTotal = sorted
        .skip(_palette.length - 1)
        .fold<Duration>(Duration.zero, (sum, e) => sum + e.value);

    final hourSegments = <List<_Segment>>[];
    var maxHour = Duration.zero;
    for (final hour in byHour) {
      final segments = <_Segment>[];
      Duration hourTotal = Duration.zero;
      for (final entry in top) {
        final used = hour[entry.key] ?? Duration.zero;
        if (used > Duration.zero) {
          segments.add(_Segment(color: colors[entry.key]!, duration: used));
          hourTotal += used;
        }
      }
      if (otherTotal > Duration.zero) {
        final other = hour.entries
            .where((e) => !colors.containsKey(e.key))
            .fold<Duration>(Duration.zero, (sum, e) => sum + e.value);
        if (other > Duration.zero) {
          segments.add(_Segment(color: AppColors.iceDim, duration: other));
          hourTotal += other;
        }
      }
      if (hourTotal > maxHour) maxHour = hourTotal;
      hourSegments.add(segments);
    }

    final totalUsage = appTotals.values.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 18, color: AppColors.neonPurple),
              SizedBox(width: 8),
              Text(
                'Usage by hour',
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (totalUsage == Duration.zero)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No usage recorded for this day',
                  style: TextStyle(color: AppColors.iceDim),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 190,
              child: CustomPaint(
                size: const Size(double.infinity, 190),
                painter: _HourlyChartPainter(
                  hourSegments: hourSegments,
                  maxHour: maxHour,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Legend(
              top: top,
              colors: colors,
              appNames: appNames,
              other: otherTotal > Duration.zero,
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment {
  const _Segment({required this.color, required this.duration});
  final Color color;
  final Duration duration;
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.top,
    required this.colors,
    required this.appNames,
    required this.other,
  });
  final List<MapEntry<String, Duration>> top;
  final Map<String, Color> colors;
  final Map<String, String> appNames;
  final bool other;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final entry in top)
          _LegendItem(
            color: colors[entry.key]!,
            label: appNames[entry.key] ?? entry.key,
          ),
        if (other) _LegendItem(color: AppColors.iceDim, label: 'Other'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: AppColors.iceDim, fontSize: 12),
        ),
      ],
    );
  }
}

class _HourlyChartPainter extends CustomPainter {
  const _HourlyChartPainter({
    required this.hourSegments,
    required this.maxHour,
  });

  final List<List<_Segment>> hourSegments;
  final Duration maxHour;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 22.0;
    final chartHeight = size.height - labelHeight;
    final slot = size.width / 24;

    // Horizontal gridlines (0 / 25 / 50 / 75 / 100%).
    final gridPaint = Paint()
      ..color = AppColors.purpleDim.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (maxHour == Duration.zero) return;

    final barWidth = slot * 0.55;
    for (var hour = 0; hour < 24; hour++) {
      final segments = hourSegments[hour];
      if (segments.isEmpty) continue;

      var yBottom = chartHeight;
      for (final segment in segments) {
        final h = chartHeight * (segment.duration.inMilliseconds /
            maxHour.inMilliseconds);
        yBottom -= h;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(hour * slot + (slot - barWidth) / 2, yBottom, barWidth, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, Paint()..color = segment.color);
      }
    }

    // Hour labels every 3 hours.
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    for (var hour = 0; hour < 24; hour += 3) {
      labelPainter.text = TextSpan(
        text: '$hour',
        style: TextStyle(color: AppColors.iceDim, fontSize: 9),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          hour * slot + (slot - labelPainter.width) / 2,
          chartHeight + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyChartPainter oldDelegate) =>
      oldDelegate.hourSegments != hourSegments ||
      oldDelegate.maxHour != maxHour;
}

// ---------------------------------------------------------------------------
// Per-app breakdown
// ---------------------------------------------------------------------------

class _AppBreakdownCard extends StatelessWidget {
  const _AppBreakdownCard({required this.appTotals, required this.appNames});
  final Map<String, Duration> appTotals;
  final Map<String, String> appNames;

  @override
  Widget build(BuildContext context) {
    final sorted = appTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: appCardDecoration(),
        child: Text(
          'No usage recorded for this day',
          style: TextStyle(color: AppColors.iceDim),
        ),
      );
    }
    final max = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apps, size: 18, color: AppColors.neonPurple),
              SizedBox(width: 8),
              Text(
                'Per app',
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final entry in sorted) ...[
            _AppUsageRow(
              name: appNames[entry.key] ?? entry.key,
              duration: entry.value,
              fraction: entry.value.inMilliseconds / max.inMilliseconds,
            ),
            if (entry != sorted.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({
    required this.name,
    required this.duration,
    required this.fraction,
  });
  final String name;
  final Duration duration;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _formatDuration(duration),
              style: TextStyle(
                color: AppColors.neonPurple,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation(AppColors.neonPurple),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

String _formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h';
  return '${minutes}m';
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.iceDim),
            const SizedBox(height: 16),
            Text(
              'Could not load usage data',
              style: TextStyle(
                color: AppColors.iceWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure Usage Access is enabled and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.iceDim, height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
