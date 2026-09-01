import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/monitored_app.dart';
import '../services/foreground_service.dart';
import '../services/preferences_repository.dart';
import '../services/streak_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'news_screen.dart';
import 'settings_screen.dart';
import 'tracking_screen.dart';

/// Main screen: your streak, monitoring status, shortcuts to the tracking and
/// news sections, and every installed (non-system) app with a toggle to add it
/// to (or remove it from) the monitored list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MonitoredApp> _apps = [];
  bool _loading = true;
  String? _error;
  bool _monitoring = false;

  Duration _todayTotal = Duration.zero;
  int _streak = 0;
  int _bestStreak = 0;

  @override
  void initState() {
    super.initState();
    _refreshServiceState();
    _loadApps();
    _loadTodayUsage();
    _loadStreak();
    // Opening the app counts as "using ScreenBreaker" today.
    StreakService.recordToday();
  }

  Future<void> _refreshServiceState() async {
    final running = await ForegroundService.isMonitoring;
    if (mounted) {
      setState(() => _monitoring = running);
    }
  }

  Future<void> _loadTodayUsage() async {
    final usage = await UsageService.getUsageToday();
    final total = usage.values.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );
    if (mounted) setState(() => _todayTotal = total);
  }

  Future<void> _loadStreak() async {
    final current = await StreakService.currentStreak();
    final best = await StreakService.bestStreak();
    if (mounted) {
      setState(() {
        _streak = current;
        _bestStreak = best;
      });
    }
  }

  Future<void> _loadApps() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // usage_stats returns the apps the launcher can see (system apps are
      // excluded), fetching icons lazily below to keep the UI snappy.
      final apps = await UsageService.listInstalledApps();

      final enabled = await PreferencesRepository.getEnabledApps();
      final stickers = <MonitoredApp>[];

      for (final app in apps.where((a) => a.enabled)) {
        final threshold = await PreferencesRepository.getThresholdFor(
          app.packageName,
        );
        stickers.add(
          MonitoredApp(
            packageName: app.packageName,
            appName: app.appName ?? app.packageName,
            enabled: enabled.contains(app.packageName),
            thresholdMinutes: threshold,
          ),
        );
        // Cache the display name so the background service can build
        // meaningful notification text without querying PackageManager.
        await PreferencesRepository.saveAppName(
          app.packageName,
          app.appName ?? app.packageName,
        );
      }

      stickers.sort(
        (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _apps = stickers;
        _loading = false;
      });

      // Load icons after the list renders so rows appear immediately.
      _loadIcons();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadIcons() async {
    for (int i = 0; i < _apps.length; i++) {
      final app = _apps[i];
      if (app.icon != null) continue;
      final bytes = await UsageService.getAppIcon(app.packageName);
      if (!mounted || bytes == null) continue;
      setState(() {
        _apps[i] = _apps[i].copyWith(icon: bytes);
      });
    }
  }

  Future<void> _toggleApp(MonitoredApp app, bool enabled) async {
    // Persist the selection straight away so the background service picks it up.
    await PreferencesRepository.setAppEnabled(app.packageName, enabled);
    await PreferencesRepository.saveAppName(app.packageName, app.appName);

    setState(() {
      final index = _apps.indexWhere((a) => a.packageName == app.packageName);
      if (index != -1) {
        _apps[index] = _apps[index].copyWith(enabled: enabled);
      }
    });

    // Start monitoring as soon as at least one app is selected; stop it when
    // the last one is removed.
    final enabledCount = _apps.where((a) => a.enabled).length;
    if (enabledCount > 0) {
      await ForegroundService.startMonitoring();
    } else {
      await ForegroundService.stopMonitoring();
    }
    await _refreshServiceState();
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _apps.where((a) => a.enabled).length;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 30),
            SizedBox(width: 10),
            Text('ScreenBreaker'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              // Thresholds may have changed while on the settings screen.
              _loadApps();
              _loadTodayUsage();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Mini-section: your ScreenBreaker streak.
          _StreakCard(
            streak: _streak,
            bestStreak: _bestStreak,
            todayTotal: _todayTotal,
          ),
          const SizedBox(height: 12),
          _StatusBanner(enabledCount: enabledCount, monitoring: _monitoring),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NavCard(
                  icon: Icons.insights,
                  iconColor: AppColors.neonPurple,
                  title: 'Tracking',
                  subtitle: 'Screen time by hour & app',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TrackingScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NavCard(
                  icon: Icons.newspaper,
                  iconColor: AppColors.techMagenta,
                  title: 'News',
                  subtitle: 'Health & screen time',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NewsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Monitored apps',
                style: TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (enabledCount > 0)
                Text(
                  '$enabledCount on',
                  style: const TextStyle(color: AppColors.iceDim, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._buildAppList(),
        ],
      ),
    );
  }

  List<Widget> _buildAppList() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        _ErrorView(message: _error!, onRetry: _loadApps),
      ];
    }
    if (_apps.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No apps found on this device',
              style: TextStyle(color: AppColors.iceDim),
            ),
          ),
        ),
      ];
    }
    return [
      Container(
        decoration: appCardDecoration(radius: 18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < _apps.length; i++) ...[
              _AppRow(
                app: _apps[i],
                onChanged: (v) => _toggleApp(_apps[i], v),
              ),
              if (i != _apps.length - 1)
                const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Streak mini-section
// ---------------------------------------------------------------------------

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.streak,
    required this.bestStreak,
    required this.todayTotal,
  });
  final int streak;
  final int bestStreak;
  final Duration todayTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '$streak-day streak' : 'Start your streak',
                  style: const TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streak > 0
                      ? _motivation(streak)
                      : 'Open ScreenBreaker today to begin — every day '
                          'you stay mindful counts.',
                  style: TextStyle(
                    color: AppColors.iceWhite.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _StreakStat(
                      icon: Icons.local_fire_department,
                      label: 'Best: $bestStreak days',
                    ),
                    _StreakStat(
                      icon: Icons.schedule,
                      label: 'Today: ${_fmtDuration(todayTotal)}',
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

  static String _motivation(int days) {
    if (days >= 30) return 'A whole month of mindful screens. Incredible!';
    if (days >= 14) return 'Two weeks strong — your future self is proud.';
    if (days >= 7) return 'A full week! Keep the momentum going.';
    return 'Keep it going — streaks grow one mindful day at a time.';
  }

  static String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.iceWhite),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.iceWhite, fontSize: 12),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status banner
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.enabledCount, required this.monitoring});
  final int enabledCount;
  final bool monitoring;

  @override
  Widget build(BuildContext context) {
    final active = enabledCount > 0 && monitoring;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Icon(
            active ? Icons.visibility : Icons.visibility_off,
            color: active ? AppColors.success : AppColors.iceDim,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              active
                  ? 'Monitoring $enabledCount app${enabledCount == 1 ? '' : 's'}'
                  : 'Select apps below to start monitoring',
              style: TextStyle(
                color: active ? AppColors.iceWhite : AppColors.iceDim,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation cards (Tracking / News)
// ---------------------------------------------------------------------------

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.iceDim,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App row
// ---------------------------------------------------------------------------

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.onChanged});
  final MonitoredApp app;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget leading;
    if (app.icon != null) {
      leading = _AppIcon(bytes: app.icon!);
    } else {
      leading = const _AppIcon(bytes: null);
    }

    return SwitchListTile(
      value: app.enabled,
      activeThumbColor: AppColors.iceWhite,
      secondary: leading,
      title: Text(
        app.appName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.iceWhite),
      ),
      subtitle: Text(
        'Limit: ${app.thresholdMinutes} min',
        style: const TextStyle(color: AppColors.iceDim),
      ),
      onChanged: onChanged,
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({this.bytes});
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.surfaceHigh,
        child: Icon(Icons.android, color: AppColors.iceDim),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes!,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surfaceHigh,
          child: Icon(Icons.android, color: AppColors.iceDim),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.iceDim, size: 48),
          const SizedBox(height: 12),
          Text(
            'Could not load apps:\n$message',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.iceDim),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
