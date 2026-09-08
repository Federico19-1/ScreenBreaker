import 'package:flutter/material.dart';

import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Reports section: how well you've managed your time — total and average
/// screen time over the last 7 or 30 days, best/worst days, breaks taken and
/// an overall score.
///
/// All numbers come from [ReportService], which aggregates Android usage
/// stats and the break days recorded when the user confirms a break.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportRange _range = ReportRange.week;
  ReportData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ReportService.build(_range);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  void _setRange(ReportRange range) {
    if (range == _range) return;
    setState(() => _range = range);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AppLogo(size: 26),
            const SizedBox(width: 10),
            const Text('Your reports'),
          ],
        ),
      ),
      body: _loading || _data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _RangeToggle(
                  selected: _range,
                  onChanged: _setRange,
                ),
                const SizedBox(height: 16),
                _ScoreCard(data: _data!),
                const SizedBox(height: 16),
                _StrikesCard(data: _data!),
                const SizedBox(height: 16),
                _StatsGrid(data: _data!),
                const SizedBox(height: 16),
                _TrendCard(data: _data!),
                const SizedBox(height: 16),
                _BreakCard(data: _data!),
                const SizedBox(height: 16),
                _DailyBarsCard(data: _data!),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Range toggle
// ---------------------------------------------------------------------------

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.selected, required this.onChanged});
  final ReportRange selected;
  final ValueChanged<ReportRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(),
      child: Row(
        children: [
          for (final range in ReportRange.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _ToggleOption(
                  label: switch (range) {
                    ReportRange.today => 'Today',
                    ReportRange.week => '7 days',
                    ReportRange.month => '30 days',
                  },
                  selected: range == selected,
                  onTap: () => onChanged(range),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonPurple.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.iceWhite : AppColors.iceDim,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score hero
// ---------------------------------------------------------------------------

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final message = data.score >= 80
        ? 'Excellent — your time is truly yours.'
        : data.score >= 60
            ? 'Good balance. Small tweaks can push it higher.'
            : data.score >= 40
                ? 'Room to improve — try setting a daily goal.'
                : 'Your screen time is running the show. Start with one '
                    'small goal today.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: data.score / 100,
                  strokeWidth: 8,
                  backgroundColor:
                      AppColors.iceWhite.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation(AppColors.iceWhite),
                ),
                Center(
                  child: Text(
                    '${data.score}',
                    style: TextStyle(
                      color: AppColors.iceWhite,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time management score',
                  style: TextStyle(
                    color: AppColors.iceWhite.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strikes (lives lost)
// ---------------------------------------------------------------------------

class _StrikesCard extends StatelessWidget {
  const _StrikesCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final livesLeft = (data.livesTotal - data.livesLost).clamp(0, data.livesTotal);
    final allGone = data.livesLost >= data.livesTotal && data.livesTotal > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_baseball,
                  size: 18, color: allGone ? AppColors.warning : AppColors.techMagenta),
              const SizedBox(width: 8),
              Text(
                'Strikes',
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${data.livesLost}/${data.livesTotal} lives lost',
                style: TextStyle(
                  color: allGone ? AppColors.warning : AppColors.iceDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // One heart per available life in the window.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < data.livesTotal; i++)
                Icon(
                  i < data.livesLost ? Icons.heart_broken : Icons.favorite,
                  size: 18,
                  color: i < data.livesLost
                      ? AppColors.warning
                      : AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            allGone
                ? 'Every life in this window was lost to over-limit alerts. '
                    'A strike is one over-limit notification — three a day '
                    'and the day is gone.'
                : 'Every over-limit alert is a strike: a life lost. '
                    '$livesLeft of ${data.livesTotal} still standing in this '
                    'window.',
            style: TextStyle(
              color: AppColors.iceDim,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats grid
// ---------------------------------------------------------------------------

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.schedule,
            label: 'Total',
            value: _fmt(data.totalScreenTime),
            hint: switch (data.range) {
              ReportRange.today => 'today',
              ReportRange.week => 'in 7 days',
              ReportRange.month => 'in 30 days',
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.today,
            label: 'Average day',
            value: _fmt(data.averageDay),
            hint: '${data.activeDays} active day${data.activeDays == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });
  final IconData icon;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.neonPurple),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.iceWhite,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.iceDim, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: TextStyle(color: AppColors.iceDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend
// ---------------------------------------------------------------------------

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final goingDown = data.trendMinutes <= 0;
    final diff = _fmt(Duration(minutes: data.trendMinutes.abs()));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Icon(
            goingDown ? Icons.trending_down : Icons.trending_up,
            color: goingDown ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              goingDown
                  ? 'Your screen time is going down — $diff less in the '
                      'second half of the period. Keep it up!'
                  : 'Your screen time is going up — $diff more in the second '
                      'half of the period. Worth a check-in.',
              style: TextStyle(
                color: AppColors.iceWhite,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Breaks
// ---------------------------------------------------------------------------

class _BreakCard extends StatelessWidget {
  const _BreakCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final bestDay = data.bestDay;
    final worstDay = data.worstDay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.self_improvement,
                  size: 18, color: AppColors.techMagenta),
              const SizedBox(width: 8),
              Text(
                'Breaks',
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You confirmed a break on ${data.breakDays} of the last '
            '${data.dailyUsage.length} days '
            '(${(data.breakRate * 100).round()}% of active days).',
            style: TextStyle(
              color: AppColors.iceDim,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.breakRate >= 0.5
                ? 'Great habit — regular breaks keep your attention sharp.'
                : 'Try stepping away whenever a break alert appears — breaks '
                    'count toward your score.',
            style: TextStyle(
              color: data.breakRate >= 0.5
                  ? AppColors.success
                  : AppColors.iceDim,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (bestDay != null || worstDay != null) ...[
            const SizedBox(height: 12),
            if (worstDay != null)
              Text(
                'Heaviest day: ${_shortDate(worstDay.day)} '
                    '(${_fmt(worstDay.duration)})',
                style: TextStyle(color: AppColors.iceDim, fontSize: 12),
              ),
            if (bestDay != null)
              Text(
                'Lightest day: ${_shortDate(bestDay.day)} '
                    '(${_fmt(bestDay.duration)})',
                style: TextStyle(color: AppColors.iceDim, fontSize: 12),
              ),
          ],
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
// Daily bars
// ---------------------------------------------------------------------------

class _DailyBarsCard extends StatelessWidget {
  const _DailyBarsCard({required this.data});
  final ReportData data;

  /// Maximum strike dots drawn per day (the real count is still in the
  /// Strikes card; this only keeps the chart layout bounded).
  static const int _maxStrikeDots = 6;

  @override
  Widget build(BuildContext context) {
    final maxDuration = data.dailyUsage.fold<Duration>(
      Duration.zero,
      (max, e) => e.duration > max ? e.duration : max,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 18, color: AppColors.neonPurple),
              const SizedBox(width: 8),
              Text(
                'Screen time per day',
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < data.dailyUsage.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Strike dots above the bar: one per strike that
                          // day (capped so the column can't overflow).
                          if (data.strikesPerDay[i] > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Wrap(
                                spacing: 2,
                                runSpacing: 2,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (var s = 0;
                                      s < data.strikesPerDay[i] &&
                                          s < _maxStrikeDots;
                                      s++)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          Container(
                            height: maxDuration == Duration.zero
                                ? 2
                                : 100 *
                                    (data.dailyUsage[i].duration.inMinutes /
                                        maxDuration.inMinutes),
                            decoration: BoxDecoration(
                              color: data.dailyUsage[i].duration > Duration.zero
                                  ? AppColors.neonPurple
                                  : AppColors.surfaceHigh,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _shortDate(data.dailyUsage.first.day),
                style: TextStyle(color: AppColors.iceDim, fontSize: 11),
              ),
              Text(
                _shortDate(data.dailyUsage.last.day),
                style: TextStyle(color: AppColors.iceDim, fontSize: 11),
              ),
            ],
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
// Shared helpers
// ---------------------------------------------------------------------------

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}
