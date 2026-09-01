# ScreenBreaker — Explanations

This file explains the design decisions behind the redesign, with a deep dive
into the question you asked: **how (and if it's possible) to make notifications
larger and more eye-catching** — your goal being a huge on-screen message that
really pushes you to stop using the app.

---

## 1. Can a notification display a HUGE message on screen? — Short answer

**Yes, with Android limitations.** The notification itself (the small banner)
is always drawn by Android and has a fixed maximum size — you can't make the
banner itself gigantic. But you CAN make the app take over the whole screen
when the alert fires, and that's where a truly huge, unmissable message can
live.

I implemented the strongest options Android allows (see section 2). Here's the
full picture of what's possible and what isn't:

| Option | What it does | Possible? |
|---|---|---|
| Regular notification | Small card in the notification shade | ✅ Always |
| Heads-up banner | Alert pops on top of ANY app, even full-screen games | ✅ Needs max importance |
| Big expanded message | Long multi-line text, expandable by the user | ✅ Implemented |
| Full-screen takeover | The WHOLE screen lights up with your message | ✅ Implemented (with conditions) |
| Arbitrary giant overlay on other apps | Your own UI drawn on top of whatever app is open | ❌ Blocked for background use on modern Android |

The last row is the one big "no": apps can no longer draw their own windows on
top of other apps from the background on modern Android (the
`SYSTEM_ALERT_WINDOW` "Display over other apps" permission was restricted, and
Google Play forbids it for this use case). The realistic way to get a "huge
message on the screen" is the full-screen takeover — which is exactly what this
app now does.

---

## 2. What I changed in the app (implemented)

The over-limit alert ("You've been using X for too long") is now as loud as
Android allows:

1. **Heads-up banner on top of any app** — the channel uses
   `Importance.max` + `Priority.high`, so the alert pops over whatever you're
   doing, including other full-screen apps.

2. **Big, expandable message** — the alert now uses Android's
   `BigTextStyle`: when you pull it down you see a long, multi-line
   motivational message, not just one line.

3. **Full-screen intent** — when the phone is **locked**, Android lights up
   the entire screen with the alert (the system's own full-screen
   notification UI). When the phone is **unlocked and you're in another app**,
   the alert still appears as the heads-up banner on top.

4. **A full-screen "STOP" screen in the app** — tapping the alert (or
   accepting the full-screen prompt) opens a dedicated **BreakScreen**: a huge,
   purple→magenta full-screen page with the logo, "STOP! 🛑" in giant type,
   the app name, a motivational message, and a button you have to consciously
   tap ("OK, I'm taking a break") before you can get back to what you were
   doing.

5. **Permission handled for Android 14+** — on Android 14 and newer, the
   `USE_FULL_SCREEN_INTENT` permission is denied by default for newly
   installed apps. The app asks for it during onboarding; if the user declines
   (or is on an older Android), the alert still works as a heads-up banner —
   just without the automatic full-screen takeover.

---

## 3. How the full-screen flow works (and its conditions)

```
Over-limit detected (background service)
        │
        ▼
Notification posted with fullScreenIntent + BigTextStyle
        │
        ├── Phone locked      → Android shows its full-screen alert UI
        │                        (tap/accept → ScreenBreaker opens)
        ├── Phone unlocked,
        │   other app open    → heads-up banner on top (tap → BreakScreen)
        └── Phone unlocked,
            app foreground    → heads-up banner (tap → BreakScreen)
```

Conditions & caveats:

- **Android 14+ opt-in:** the user must allow "Full screen" for ScreenBreaker
  (requested automatically at onboarding; can also be enabled in
  *Settings → Apps → ScreenBreaker → Full screen*). Until then, no automatic
  full-screen takeover — only the heads-up banner.
- **Some manufacturers** (Xiaomi, Samsung, etc.) override these settings with
  their own battery/notification rules; a few disable full-screen intents
  entirely. Nothing the app can do about that — it's a device policy.
- **The banner itself can't be resized** — Android draws it. The "huge"
  message lives in our full-screen BreakScreen, which is the point of the
  design.

---

## 4. Ideas to make the alert even more eye-catching (future work)

These are all easy to add on top of what exists:

- **Loud sound + vibration** for the break alert (a dedicated alarm-like
  sound, vibration pattern).
- **Repeated reminders** — re-alert every 5 minutes while you stay over the
  limit (the anti-spam cooldown already exists; it just needs a "keep
  nagging" option).
- **Animated BreakScreen** — e.g. a pulsing/breathing animation, or a Lottie
  animation, instead of the static screen.
- **Countdown button** — "I'll take a break for 2 minutes" with a timer that
  locks the screen.
- **Personalized messages** — rotate through motivational lines, or reference
  your streak ("You'd have lost a 12-day streak!").
- **In-app blocking** — while ScreenBreaker is in the foreground, show the
  BreakScreen automatically (not only via the notification tap).

---

## 5. The redesign — what changed visually

- **New "Purple Future" palette** applied app-wide:
  - Neon purple `#9B4DFF` — main color (buttons, accents, chart)
  - Bluish black `#0C0A14` — background
  - Tech magenta `#FF2ED1` — accents (news, gradient hero)
  - Ice white `#F6F6FF` — text and details
- **Logo everywhere**: your `web/icons/Logo.png` is now the app logo in the
  app bar, onboarding, splash screen, launcher icon (Android + adaptive), web
  favicon and web manifest. A square 1024×1024 padded version was generated
  for the launcher icon (Android requires square icons).
- **Streak mini-section** on the home screen, above the monitored-apps list:
  🔥 your current streak, your best streak, and today's total screen time.
  The streak counts consecutive days you use ScreenBreaker (opening the app or
  keeping monitoring active).
- **Tracking section** (new screen): pick any day (arrows), see your total
  screen time, a stacked bar chart of usage **by hour** with one color **per
  app**, and a per-app breakdown with progress bars.
- **News section** (new screen): recent articles about screen time, attention,
  phone/TV effects on health. See section 6 for how it works and its limits.

---

## 6. News section — notes, limits and issues

- **Source:** Google News' public RSS search (no API key, no account needed),
  queried for terms like *screen time health*, *phone addiction attention
  span*, *digital wellbeing children screens*, *too much screen time sleep*,
  *television screen time attention*. Results are merged, de-duplicated,
  sorted newest-first, and cached for 15 minutes.
- **Tapping an article** opens it in your browser.
- **If there's no internet**, the section shows a friendly error with a
  "Try again" button instead of crashing.
- **Limitations to be aware of:**
  - **Language:** the queries are in English, so you'll get mostly English
    articles. To get Italian (or other) news, the query list in
    `lib/services/news_service.dart` can be changed (e.g. add
    `"tempo schermo salute"`).
  - **Source quality:** Google News aggregates from many outlets — a few
    results can be clickbait or low-quality; there's no medical review.
  - **No offline cache** — articles only load with a connection.
  - If you'd rather use a specific trusted source (WHO, Harvard Health, your
    favourite outlet's own RSS), that's a small change — say the word.

---

## 7. Tracking section — notes and limits

- Data comes straight from Android's own usage statistics (the same data used
  for the limits), so it's accurate for monitored apps.
- **Per-hour granularity** is achieved with 24 queries (one per hour of the
  selected day) — accurate, but slightly slow on first load; a spinner is
  shown.
- **Limitations:**
  - Android only keeps usage history for a limited time (often ~7–30 days),
    so very old days may show "No usage recorded".
  - Emulators frequently don't record usage data at all — on a real phone it
    works reliably.
  - The chart shows the top apps plus an "Other" bucket so the legend stays
    readable.
- The existing **weekly summary screen** (Mon–Sun per app, opened from the
  weekly notification) complements the day-by-day view here.

---

## 8. Streak section — definition

- A "streak day" is any day you **use ScreenBreaker**: open the app, or have
  monitoring running (the background service records it automatically).
- The current streak counts consecutive streak days ending **today**; if today
  hasn't been recorded yet (e.g. you haven't opened the app since midnight)
  but yesterday was, the streak is still "alive" and counts from yesterday.
- The best-ever streak is also tracked and shown.
- This means the simplest way to grow your streak is simply keeping
  monitoring on every day.

---

*Everything above is implemented, compiles cleanly (`flutter analyze`), and
is covered by automated tests (`flutter test`).*
