import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../services/goal_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Goals section: set your own daily/weekly/monthly screen-time limits and see
/// how much of each budget has already been used in the current period.
///
/// The three default goals limit *total* screen time; per-app goals can be
/// added from the picker at the bottom (or deleted by tapping the trash icon).
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<GoalProgress> _progress = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await GoalService.currentProgress();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _loading = false;
    });
  }

  Future<void> _editLimit(Goal goal, int currentMinutes) async {
    final newMinutes = await _pickMinutes(
      title: '${goal.periodLabel} limit',
      initial: currentMinutes,
    );
    if (newMinutes == null || newMinutes == currentMinutes) return;
    await GoalService.upsertGoal(
      Goal(
        id: goal.id,
        period: goal.period,
        maxMinutes: newMinutes,
        packageName: goal.packageName,
      ),
    );
    await _load();
  }

  Future<void> _addAppGoal() async {
    // Reuse the settings screen? No — keep it self-contained: pick from the
    // monitored apps the user already enabled.
    final enabled = await GoalService.getGoals();
    final usedPackages = enabled
        .map((g) => g.packageName)
        .whereType<String>()
        .toSet();

    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _AppGoalPicker(
        usedPackages: usedPackages,
      ),
    );
    if (selected == null) return;

    final minutes = await _pickMinutes(title: 'Daily limit', initial: 60);
    if (minutes == null || minutes <= 0) return;

    await GoalService.upsertGoal(
      Goal(
        id: 'app.$selected.daily',
        period: GoalPeriod.daily,
        maxMinutes: minutes,
        packageName: selected,
      ),
    );
    await _load();
  }

  Future<void> _deleteGoal(Goal goal) async {
    await GoalService.deleteGoal(goal.id);
    await _load();
  }

  Future<int?> _pickMinutes({
    required String title,
    required int initial,
  }) async {
    var minutes = initial;
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final h = minutes ~/ 60;
          final m = minutes % 60;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  h > 0 ? '$h h ${m.toString().padLeft(2, '0')} m' : '$m min',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.neonPurple,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Slider(
                  value: minutes.clamp(5, 720).toDouble(),
                  min: 5,
                  max: 720,
                  divisions: 143,
                  label: _fmt(minutes),
                  onChanged: (v) => setSheetState(() => minutes = v.round()),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(minutes),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AppLogo(size: 26),
            const SizedBox(width: 10),
            const Text('Your goals'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Set a limit for your total screen time — the progress '
                  'bars fill up as you use your phone.',
                  style: TextStyle(
                    color: AppColors.iceDim,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                for (final p in _progress) ...[
                  _GoalCard(
                    progress: p,
                    onEdit: () => _editLimit(p.goal, p.goal.maxMinutes),
                    onDelete: p.goal.isTotal
                        ? null
                        : () => _deleteGoal(p.goal),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addAppGoal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add per-app goal'),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Goal card
// ---------------------------------------------------------------------------

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalProgress progress;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final over = progress.isOver;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                goal.isTotal ? Icons.smartphone : Icons.apps,
                size: 18,
                color: over ? AppColors.warning : AppColors.neonPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal.isTotal ? 'Total screen time' : (goal.packageName!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                goal.periodLabel,
                style: TextStyle(
                  color: AppColors.iceDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Change limit',
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.iceDim),
                onPressed: onEdit,
              ),
              if (onDelete != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete goal',
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.iceDim),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 10,
                backgroundColor: AppColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(
                  over ? AppColors.warning : AppColors.neonPurple,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${progress.spentLabel} of ${goal.limitLabel}',
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  progress.remainingLabel,
                  style: TextStyle(
                    color: over ? AppColors.warning : AppColors.iceDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Per-app goal picker
// ---------------------------------------------------------------------------

class _AppGoalPicker extends StatefulWidget {
  const _AppGoalPicker({required this.usedPackages});

  final Set<String> usedPackages;

  @override
  State<_AppGoalPicker> createState() => _AppGoalPickerState();
}

class _AppGoalPickerState extends State<_AppGoalPicker> {
  List<MapEntry<String, String>> _candidates = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Same source as the home screen, so the picker offers exactly the apps
    // ScreenBreaker can measure.
    final apps = await UsageService.listInstalledApps();
    final result = <MapEntry<String, String>>[
      for (final app in apps)
        if (app.enabled && !widget.usedPackages.contains(app.packageName))
          MapEntry(app.packageName, app.appName ?? app.packageName),
    ];
    if (!mounted) return;
    setState(() {
      _candidates = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pick an app to limit',
              style: TextStyle(
                color: AppColors.iceWhite,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No available apps to limit',
                  style: TextStyle(color: AppColors.iceDim),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _candidates.length,
                  itemBuilder: (context, i) {
                    final entry = _candidates[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        entry.value,
                        style: TextStyle(color: AppColors.iceWhite),
                      ),
                      subtitle: Text(
                        entry.key,
                        style: TextStyle(
                          color: AppColors.iceDim,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(entry.key),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
