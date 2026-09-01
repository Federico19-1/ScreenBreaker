import 'package:flutter/services.dart';

/// Requests Android permissions that no Flutter plugin exposes.
///
/// On Android 14+ the `USE_FULL_SCREEN_INTENT` permission (needed for the
/// full-screen break alert) is denied by default for newly installed apps that
/// target SDK 34+, so the app must ask the OS for it. The Kotlin side of this
/// channel lives in `MainActivity.kt`.
class SystemPermissions {
  SystemPermissions._();

  static const MethodChannel _channel =
      MethodChannel('screenbreaker/permissions');

  /// Asks the user to allow full-screen notifications (Android 14+).
  ///
  /// On older Android versions, or when the user declines, the break alert
  /// still works as a heads-up banner — so failures are intentionally ignored.
  static Future<void> requestFullScreenIntent() async {
    try {
      await _channel.invokeMethod<bool>('requestFullScreenIntent');
    } catch (_) {
      // Non-Android platforms or plugin-less environments: nothing to do.
    }
  }
}
