# ScreenBreaker — Important Notes (in simple words)

This file explains, in everyday language:

1. How to test the app yourself, right now
2. How to get the app onto your phone (and when you can)
3. Where to put your JPG so it becomes the app icon
4. What has been built so far and what the app should look like

---

## 1. How to test the app manually (right now)

**Important:** this app is **Android-only**. It reads Android's "app usage" data and runs a background service, so it **cannot** really work on Windows, Chrome, or an iPhone. You need an Android phone or an Android emulator.

You already have an Android emulator set up, named `lockin_pixel`. Here's the simplest way to test:

**Step 1 — start the emulator**

```bash
flutter emulators --launch lockin_pixel
```

**Step 2 — run the app on it**

```bash
flutter run
```

(If you have a real Android phone instead, plug it in with a USB cable, enable **Developer options → USB debugging** on the phone, and then just run `flutter run`.)

**Step 3 — what to try once the app opens**

- The **first screen** asks for **"Usage Access"**. Tap the button, find **ScreenBreaker** in the list, and turn its switch on. Go back.
- You'll see the **home screen** with a list of your installed apps, each with a toggle switch. Turn on one app, e.g. Instagram or YouTube.
- Tap the **settings** icon (top-right) and set the time limit very low, like **5 minutes**.
- Use that app for a few minutes, then come back — you should get a notification: *"You've been using [App] for too long. Time for a break!"*
- Once a week (Monday), the app sends a **weekly summary** notification. Tapping it opens a screen with a per-day breakdown. You don't have to wait a week to see it work — it's tested by the automated tests.

**Tip:** usage tracking works best on a real phone. On an emulator the system sometimes doesn't record usage data, so if nothing shows up, that's why.

---

## 2. How to download it to your phone

**Good news: you can do this right now.** You don't need the Play Store for this.

The app is built as an **APK** (the Android install file). One already exists on your computer:

```
build/app/outputs/flutter-apk/app-debug.apk
```

To get it onto your phone:

1. Build the file (run this once): `flutter build apk --debug`
2. Send the APK to your phone. Easiest ways:
   - Connect the phone with a USB cable and copy the file over, **or**
   - Upload it to Google Drive / send it to yourself via WhatsApp or email, then open it on the phone.
3. On the phone, tap the APK file and install it. Android will ask you to allow installing apps from unknown sources — that's normal, tap **Allow** / **Install**.
4. Open **ScreenBreaker** from your app list.

**When will you be able to do so?** Right now — it's just those steps above. A couple of notes:

- The **debug** APK (what you have now) is big (~160 MB) because it includes debugging tools. That's fine for testing.
- When you want a smaller, faster version for daily use, build a **release** APK instead:

  ```bash
  flutter build apk --release
  ```

  The file will be at `build/app/outputs/flutter-apk/app-release.apk` and it's much smaller.

- If you ever want it **on the Google Play Store**, that's a separate, longer process (a $25 one-time Google developer account, store listing, review…). Not needed for using the app yourself — ask me when you get there.

---

## 3. Where to put your JPG so it becomes the app icon

Right now the app still shows the **default Flutter icon** (the blue square). Your image is outside the project folder — let's bring it in.

**What to do:**

1. Copy your JPG **into the project folder** — a good spot is:

   ```
   assets/icon/app_icon.png
   ```

   - If it's a JPG, just copy it as-is for now; the tool converts it.
   - It should be **square** (width = height), and the bigger the better (ideally 1024 × 1024). If it's not square, I'll crop it for you.

2. Once the image is in the project, tell me (or just say "I put the icon in") — I'll add the `flutter_launcher_icons` tool to the project and run it. It automatically generates every size Android (and iOS, for later) needs and replaces the blue default icon.

3. Rebuild with `flutter build apk --debug` and reinstall — your icon will now appear on the phone's home screen.

**Why not just drop the JPG into the icon folder directly?** Android needs many different sizes (small, large, round versions…) of a special PNG format. Doing it by hand is error-prone — the launcher-icons tool does it perfectly in one command.

---

## 4. What has been built so far, and what the app should look like now

The app is **fully functional** — it's not a stub. All of this is implemented, checked by `flutter analyze`, covered by automated tests, and builds successfully into an APK:

| Piece | What it does |
|---|---|
| **Onboarding screen** | First launch asks you to grant **Usage Access** so the app can see how long you use each app. |
| **Home screen** | Lists all your installed apps (with their icons) and a toggle to turn monitoring on/off for each. |
| **Settings screen** | A slider for the global time limit, plus per-app overrides. |
| **Background service** | Runs every 60 seconds in the background, checks your usage, and stays alive (and restarts after a reboot). |
| **Break alerts** | When you pass the limit on an app, you get a notification on top of that app: "Time for a break!" (max once per 5 minutes per app). |
| **Weekly summary** | Every Monday, a notification with your total screen time per app for last week. |
| **Summary detail screen** | Tapping the weekly notification opens a screen with a per-day breakdown (Mon–Sun) for each app. |

**What it should look like when you open it:**

- **First launch:** a dark-themed screen explaining the app with a big "Give Usage Access" button.
- **After granting access:** the home screen — app list with switches, a top bar with the app name and a settings gear.
- **Settings:** sliders and checkboxes for time limits.
- Once the service is running, you'll see the **foreground notification** (the little persistent "monitoring" notice) in your notification bar.

**One thing to know:** usage tracking only starts once you toggle at least one app on, and the service stops when all toggles are off — that's intentional.

---

*Written as a plain-English companion to the project. Anything here you'd like me to do (copy the icon, build the release APK, or walk through testing on the emulator) — just ask.*
