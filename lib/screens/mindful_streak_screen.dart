import 'package:flutter/material.dart';

import '../models/mindful_task.dart';
import '../services/mindful_streak_service.dart';
import '../theme/app_theme.dart';

/// Full screen for the mindful streak: today's small well-being task,
/// a button to mark it done (which grows the streak), the option to swap
/// today's task for another, and the recent history.
///
/// The mindful streak only grows when the user actually completes the day's
/// task — meditating, sharing a profound thought, walking without the phone —
/// so it rewards genuine disconnection instead of just opening the app.
class MindfulStreakScreen extends StatefulWidget {
  const MindfulStreakScreen({super.key});

  @override
  State<MindfulStreakScreen> createState() => _MindfulStreakScreenState();
}

class _MindfulStreakScreenState extends State<MindfulStreakScreen> {
  MindfulTask _task = MindfulTask.catalog.first;
  bool _completed = false;
  int _streak = 0;
  int _best = 0;
  List<(DateTime, MindfulTask?)> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final task = await MindfulStreakService.todayTask();
    final completed = await MindfulStreakService.isCompletedToday();
    final streak = await MindfulStreakService.currentStreak();
    final best = await MindfulStreakService.bestStreak();
    final history = await MindfulStreakService.recentHistory(7);
    if (!mounted) return;
    setState(() {
      _task = task;
      _completed = completed;
      _streak = streak;
      _best = best;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _complete() async {
    await MindfulStreakService.completeToday();
    if (!mounted) return;
    final before = _streak;
    setState(() {
      _completed = true;
      _streak = before + 1; // today was not completed yet
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Well done! $_streak-day mindful streak 🔥',
        ),
      ),
    );
    // Reload so the header streak values and history stay accurate.
    _load();
  }

  Future<void> _swap() async {
    final next = await MindfulStreakService.swapTodayTask();
    if (!mounted) return;
    setState(() => _task = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mindful streak')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _StreakHero(streak: _streak, best: _best),
                const SizedBox(height: 16),
                _TaskCard(
                  task: _task,
                  completed: _completed,
                  onComplete: _complete,
                  onSwap: _swap,
                ),
                const SizedBox(height: 16),
                _HistoryStrip(history: _history),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak hero
// ---------------------------------------------------------------------------

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak, required this.best});
  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '$streak-day mindful streak' : 'Mindful streak',
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streak > 0
                      ? 'Every day you complete a small task, you prove that '
                          'life happens off-screen too.'
                      : 'Complete one small task a day to grow it — meditate, '
                          'share a profound thought, walk without your phone.',
                  style: TextStyle(
                    color: AppColors.iceWhite.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 14,
                      color: AppColors.iceWhite,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Best: $best days',
                      style: TextStyle(
                        color: AppColors.iceWhite,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
// Today's task card
// ---------------------------------------------------------------------------

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.completed,
    required this.onComplete,
    required this.onSwap,
  });

  final MindfulTask task;
  final bool completed;
  final VoidCallback onComplete;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: appCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                task.emoji,
                style: const TextStyle(fontSize: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Today\'s task',
                  style: TextStyle(
                    color: AppColors.iceDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!completed)
                IconButton(
                  tooltip: 'Swap for another task',
                  icon: Icon(Icons.refresh, color: AppColors.iceDim),
                  onPressed: onSwap,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: TextStyle(
              color: AppColors.iceWhite,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            task.description,
            style: TextStyle(
              color: AppColors.iceDim,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: completed
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.check_circle, color: AppColors.success),
                    label: Text(
                      'Done today',
                      style: TextStyle(color: AppColors.iceDim),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.done),
                    label: const Text('I did it!'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Last 7 days history
// ---------------------------------------------------------------------------

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.history});
  final List<(DateTime, MindfulTask?)> history;

  @override
  Widget build(BuildContext context) {
    final weekdayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 days',
            style: TextStyle(
              color: AppColors.iceWhite,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (day, task) in history)
                Column(
                  children: [
                    // Weekday letter for the header of each column.
                    Text(
                      weekdayLabels[day.weekday - 1],
                      style: TextStyle(
                        color: AppColors.iceDim,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: task != null
                            ? AppColors.success.withValues(alpha: 0.18)
                            : AppColors.surfaceHigh,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task != null
                              ? AppColors.success
                              : AppColors.purpleDim,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          task?.emoji ?? '·',
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.iceDim,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
