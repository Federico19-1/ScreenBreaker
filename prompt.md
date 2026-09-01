# ScreenBreaker — Flutter Android App: Full Development Prompt

## Overview

Build a complete Android application called **ScreenBreaker** using **Flutter (Dart)**.

The app's goal is to help users stay focused and reduce mindless scrolling on social media and other apps. It monitors how much time the user spends in selected apps and sends a push notification — even when ScreenBreaker itself is closed — whenever the user has been inside a monitored app for too long.

---

## Core Features

### 1. App Selection Screen (Home Screen)
- On first launch, show a list of **all installed apps** on the device (name + icon).
- The user can **toggle on/off** each app they want to monitor.
- Selected apps are saved persistently so they survive app restarts.

### 2. Time Threshold Setting
- For each monitored app (or globally), the user can set a **time limit** (e.g. 10, 15, 20 minutes).
- Default value: **15 minutes**.
- The threshold should be configurable via a simple UI (dropdown or slider).

### 3. Background Monitoring Service
- A **Foreground Service** must run continuously in the background, even when ScreenBreaker is closed.
- Every **1–2 minutes**, the service checks how long the user has been using each monitored app during the current session or day.
- If usage time for a monitored app **exceeds the set threshold**, the service triggers a **push notification**.

### 4. Notification
- Notification title: `"ScreenBreaker"`
- Notification body: `"You've been using [App Name] for too long. Time for a break! 🛑"`
- The notification must appear **on top of any app**, like a system alert.
- Avoid spamming: once a notification is sent for an app, wait at least **5 minutes** before sending another one for the same app.

---

## Tech Stack

- **Framework:** Flutter (Dart)
- **Target platform:** Android only (for now)
- **Minimum Android SDK:** 23 (Android 6.0)

---

## Required Flutter Packages

Add these to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  usage_stats: ^1.0.0                  # Read per-app usage time from Android
  flutter_foreground_task: ^8.0.0      # Run a persistent background service
  permission_handler: ^11.0.0          # Request special permissions at runtime
  shared_preferences: ^2.0.0           # Persist selected apps and settings
  device_apps: ^2.2.0                  # Retrieve list of installed apps with icons
```

---

## Android Permissions

In `AndroidManifest.xml`, add the following permissions:

```xml
<!-- Required to read app usage statistics -->
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
    tools:ignore="ProtectedPermissions" />

<!-- Required for the foreground service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- Required to post notifications on Android 13+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Required to keep the service alive -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Also register the foreground service inside the `<application>` tag as required by `flutter_foreground_task`.

---

## Permission Onboarding Flow

Since `PACKAGE_USAGE_STATS` is a **special permission** that cannot be granted programmatically, the app must:

1. On first launch, detect if the permission is missing.
2. Show an **onboarding screen** explaining why the permission is needed.
3. Display a button: **"Grant Permission"** that opens the system screen:
   `Settings → Special App Access → Usage Access → ScreenBreaker → Enable`
4. After the user returns to the app, check again if the permission was granted.
5. Only proceed to the main screen if the permission is active.

---

## App Architecture & File Structure

```
lib/
├── main.dart                        # Entry point, app initialization
├── screens/
│   ├── onboarding_screen.dart       # Permission request flow
│   ├── home_screen.dart             # App list with toggles
│   └── settings_screen.dart         # Time threshold configuration
├── services/
│   ├── foreground_service.dart      # Background monitoring logic
│   ├── usage_service.dart           # Reads usage stats from Android
│   └── notification_service.dart    # Sends local notifications
└── models/
    └── monitored_app.dart           # Data model: app name, package, threshold, enabled
```

---

## Detailed Logic: Background Service

The foreground service must:

1. Start automatically when the user enables monitoring.
2. Run a **periodic task every 60–120 seconds**.
3. On each tick:
   a. Get the list of monitored apps from `shared_preferences`.
   b. Use `usage_stats` to query how many minutes the user has spent in each monitored app **today** (or in the current session — today is preferred).
   c. Compare against the threshold for each app.
   d. If usage > threshold AND last notification for that app was > 5 minutes ago → send notification.
   e. Save the timestamp of the last notification per app in `shared_preferences`.
4. The service should show a **persistent (silent) notification** in the status bar while active, as required by Android for foreground services. Example: `"ScreenBreaker is monitoring your screen time"`.

---

## UI/UX Guidelines

- **Color palette:** dark theme preferred — deep navy or near-black background (`#0D0D0D` or `#0F172A`), with accent color in electric blue or neon green.
- **Typography:** clean, sans-serif (Flutter default `Roboto` is fine).
- **App list:** show app icon, app name, and a toggle switch per row.
- **Settings:** a clean screen with a global slider or per-app dropdowns for the time threshold.
- Keep the UI **minimal and distraction-free** — the app is about reducing screen time, so the design should reflect that.

---

## Key Implementation Notes

- Use `DeviceApps.getInstalledApplications(includeAppIcons: true, includeSystemApps: false)` to list apps.
- Use `UsageStats.queryUsageStats(...)` with a time range from **midnight today** to now, to get per-app usage for the current day.
- The `flutter_foreground_task` package requires a `@pragma('vm:entry-point')` annotated callback function defined at the **top level** (not inside a class).
- Handle the case where `usage_stats` returns `null` or empty data gracefully.
- The app must work on **Android 12 and Android 13+**, where notification and foreground service permissions became stricter.
- Do not target iOS — Android only for this version.

---

## What to Build (Step-by-Step Checklist)

- [ ] Flutter project scaffold with correct `AndroidManifest.xml` and all permissions
- [ ] `MonitoredApp` data model
- [ ] Onboarding screen with Usage Access permission flow
- [ ] Home screen: full list of installed apps with icons and toggle switches
- [ ] Persistence: save/load selected apps and thresholds using `shared_preferences`
- [ ] Settings screen: configure time thresholds (global or per-app)
- [ ] `UsageService`: query Android usage stats for a given app package
- [ ] `NotificationService`: send local notifications with correct content
- [ ] `ForegroundService`: background loop that ties everything together
- [ ] Anti-spam logic: don't notify more than once every 5 minutes per app
- [ ] Start the foreground service automatically when monitoring is toggled on

---

## Final Notes for the AI Coding Assistant

- Produce **complete, runnable code** for every file — no placeholders or `// TODO` stubs.
- Include the full `pubspec.yaml` and the full `AndroidManifest.xml`.
- If a package API has changed in recent versions, use the **latest stable API**.
- Add comments in the code where the logic is non-obvious.
- The app name displayed to the user is **ScreenBreaker**.
- Package name (application ID): `com.screenbreaker.app`
