import 'package:flutter/material.dart';

import '../models/monitored_app.dart';
import '../services/preferences_repository.dart';
import '../theme/app_theme.dart';
import 'appearance_screen.dart';

/// Configures the time limit before a warning notification is sent.
///
/// A single global limit applies to every app by default; the user can then
/// override the limit for individual monitored apps.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// The allowed threshold presets (in minutes). Kept small and round on purpose,
/// matching the spec's "10, 15, 20 minutes" style values.
const List<int> kThresholdOptions = [5, 10, 15, 20, 30, 45, 60, 90, 120];

class _SettingsScreenState extends State<SettingsScreen> {
  /// Apps currently being monitored, with their per-app override (if any).
  Map<String, (String, int?)> _apps = {}; // package -> (name, overrideMinutes)
  int _global = MonitoredApp.defaultThresholdMinutes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await PreferencesRepository.getEnabledApps();
    final global = await PreferencesRepository.getGlobalThresholdMinutes();
    final rows = <String, (String, int?)>{};
    for (final package in enabled) {
      final name = await PreferencesRepository.getAppName(package);
      // Load the stored per-app override (null → uses the global default).
      final override = await PreferencesRepository.getAppThresholdOverride(
        package,
      );
      rows[package] = (name, override);
    }
    if (!mounted) return;
    setState(() {
      _apps = rows;
      _global = global;
      _loading = false;
    });
  }

  Future<void> _setGlobal(int minutes) async {
    setState(() => _global = minutes);
    await PreferencesRepository.setGlobalThresholdMinutes(minutes);
  }

  Future<void> _setAppOverride(String package, int? minutes) async {
    setState(() {
      final existing = _apps[package];
      if (existing != null) {
        _apps[package] = (existing.$1, minutes);
      }
    });
    if (minutes == null) {
      await PreferencesRepository.clearAppThreshold(package);
    } else {
      await PreferencesRepository.setAppThresholdMinutes(package, minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen time limits'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Global time limit',
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Applied to every monitored app unless you set a custom '
                  'limit below.',
                  style: TextStyle(color: AppColors.iceDim, height: 1.4),
                ),
                const SizedBox(height: 16),
                _ThresholdDropdown(
                  value: _global,
                  onChanged: _setGlobal,
                ),
                const SizedBox(height: 32),
                if (_apps.isNotEmpty) ...[
                  Text(
                    'Per-app limits',
                    style: TextStyle(
                      color: AppColors.iceWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Override the global limit for specific apps.',
                    style: TextStyle(color: AppColors.iceDim, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: _apps.entries.map((entry) {
                      return _PerAppTile(
                        name: entry.value.$1,
                        overrideMinutes: entry.value.$2,
                        onChanged: (v) => _setAppOverride(entry.key, v),
                      );
                    }).toList(),
                  ),
                ] else
                  Text(
                    'No apps are being monitored yet. Enable some on the '
                    'home screen and they will show up here.',
                    style: TextStyle(
                      color: AppColors.iceDim,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 32),
                Text(
                  'Appearance',
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Change the app's colors and pick your logo.",
                  style: TextStyle(color: AppColors.iceDim, height: 1.4),
                ),
                const SizedBox(height: 12),
                _AppearanceCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AppearanceScreen(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: appCardDecoration(),
          child: Row(
            children: [
              Icon(Icons.palette_outlined, color: AppColors.neonPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Colors & logos',
                  style: TextStyle(
                    color: AppColors.iceWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.iceDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThresholdDropdown extends StatelessWidget {
  const _ThresholdDropdown({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      dropdownColor: AppColors.surfaceHigh,
      style: TextStyle(color: AppColors.iceWhite),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        for (final v in kThresholdOptions)
          DropdownMenuItem(
            value: v,
            child: Text(_minutesLabel(v)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _PerAppTile extends StatelessWidget {
  const _PerAppTile({
    required this.name,
    required this.overrideMinutes,
    required this.onChanged,
  });
  final String name;
  final int? overrideMinutes;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Show the dropdown including a "Use global" option when an override exists.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(color: AppColors.iceWhite, fontSize: 16),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int?>(
              initialValue: overrideMinutes,
              dropdownColor: AppColors.surfaceHigh,
              style: TextStyle(color: AppColors.iceWhite),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Use global', style: TextStyle(color: AppColors.iceDim)),
                ),
                for (final v in kThresholdOptions)
                  DropdownMenuItem<int?>(
                    value: v,
                    child: Text(_minutesLabel(v)),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

String _minutesLabel(int minutes) => '$minutes min';