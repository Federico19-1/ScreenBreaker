import 'dart:typed_data';

/// A single installed app the user can choose to monitor.
///
/// This is a UI-facing model; the durable state (which apps are selected, their
/// thresholds and the anti-spam timestamps) is persisted in [SharedPreferences]
/// by [PreferencesRepository].
class MonitoredApp {
  const MonitoredApp({
    required this.packageName,
    required this.appName,
    required this.enabled,
    this.thresholdMinutes = defaultThresholdMinutes,
    this.icon,
  });

  /// Default time limit in minutes applied to an app with no per-app override.
  static const int defaultThresholdMinutes = 15;

  /// Android package identifier, e.g. `com.instagram.android`.
  final String packageName;

  /// Human-readable label shown to the user.
  final String appName;

  /// Whether the app is currently being monitored.
  final bool enabled;

  /// Time limit in minutes before a warning notification is sent.
  final int thresholdMinutes;

  /// Optional icon bytes (base64-decoded PNG) loaded from the device.
  final Uint8List? icon;

  MonitoredApp copyWith({
    bool? enabled,
    int? thresholdMinutes,
    Uint8List? icon,
  }) {
    return MonitoredApp(
      packageName: packageName,
      appName: appName,
      enabled: enabled ?? this.enabled,
      thresholdMinutes: thresholdMinutes ?? this.thresholdMinutes,
      icon: icon ?? this.icon,
    );
  }
}