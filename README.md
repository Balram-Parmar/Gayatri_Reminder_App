<div align="center">

<img src="assets/ic_launcher.png" alt="Gayatri Reminder logo" width="140" />

# Gayatri Reminder

**A calm, offline-friendly reminder to chant the Gayatri Mantra at sunrise, solar noon and sunset — and a simple way to keep a daily record of your sadhna.**

[![Flutter](https://img.shields.io/badge/Flutter-3.29%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7.2%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)](#android-support)

<a href="https://play.google.com/store/apps/details?id=com.hkm.gayatri">
  <img alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="64" />
</a>

</div>

---

## Overview

Gayatri Reminder is a Flutter application built around a simple daily rhythm: chant the Gayatri Mantra three times a day — at **sunrise**, **solar noon**, and **sunset** — and record whether you completed each session.

Instead of fixed clock times, the app uses your GPS location to calculate the real sun events for the day, then schedules a notification for each one. A single tap plans reminders **30 days ahead**, so they keep working even if you do not open the app for a while. If you dismiss a reminder without completing your sadhna, it gently comes back after a delay you choose.

A calendar in the Reports tab shows your practice at a glance: green for a complete day, amber for a partial one, red for a missed one.

## Features

- **Sun-accurate reminders** — sunrise, solar noon and sunset computed for your current location.
- **30-day scheduling** — three notifications per day, created ahead of time with `awesome_notifications`.
- **Smart snooze** — dismissing a reminder reschedules it after 1–60 minutes (default **15**).
- **Practice calendar** — mark morning, afternoon and night sessions as done; days are colour-coded.
- **Offline support** — sun times are cached locally and reused when there is no connection.
- **Importable sadhna history** — load a `sadhnaMantra.json` file from another device, with an automatic timestamped backup of the existing one.
- **Manual control** — re-schedule everything, send a test notification, or cancel all reminders.
- **Light, high-contrast UI** — large type, clear status cards, and a Material 3 theme.

## Screenshots

<!-- Add your screenshots to docs/screenshots/ and uncomment the table below.

| Home | Reports | Settings |
|:---:|:---:|:---:|
| ![Home](docs/screenshots/home.png) | ![Reports](docs/screenshots/reports.png) | ![Settings](docs/screenshots/settings.png) |

-->

_Screenshots coming soon._

## How it works

```text
 GPS location ──► api.sunrisesunset.io ──► SunriseTimes.json (cache)
                                                    │
                                                    ▼
                            Awesome Notifications (3 per day × 30 days)
                                                    │
                                     dismissed ─────┴──► re-shown after N minutes
```

1. On launch, the Home tab requests the device location and asks [sunrisesunset.io](https://sunrisesunset.io) for the current month's sun times.
2. The response is cached to `SunriseTimes.json`. If the device is offline or the request fails, the cached file is used instead.
3. From **Settings → Re-Schedule Notifications For 30 Days**, the app fetches the next 30 days and creates three scheduled notifications per day: one at sunrise, one at solar noon, one at sunset.
4. When a notification is dismissed, `NotificationController` reads the configured snooze interval from `settings.json` and schedules the same reminder again.
5. In **Reports**, tapping a day lets you mark each session as done. State is written to `sadhnaMantra.json` and reflected by the calendar markers.

If location services are unavailable, the app falls back to Ahmedabad, India (`23.0225, 72.5714`).

## Tech stack

| Concern | Package |
| --- | --- |
| Framework | Flutter (Dart SDK `^3.7.2`, i.e. Flutter 3.29+) |
| Notifications | [`awesome_notifications`](https://pub.dev/packages/awesome_notifications) `^0.10.1` |
| Location | [`geolocator`](https://pub.dev/packages/geolocator) `^14.0.0` |
| Sun times | [sunrisesunset.io](https://sunrisesunset.io) REST API over [`http`](https://pub.dev/packages/http) |
| Calendar UI | [`table_calendar`](https://pub.dev/packages/table_calendar) `^3.0.9` |
| Connectivity | [`connectivity_plus`](https://pub.dev/packages/connectivity_plus) `^5.0.1` |
| Local files | [`path_provider`](https://pub.dev/packages/path_provider) + [`path`](https://pub.dev/packages/path) |
| File import | [`file_picker`](https://pub.dev/packages/file_picker) `^10.1.9` |

`shared_preferences`, `provider` and `intl` are declared in `pubspec.yaml` but not used by the current code.

No backend, no account, no analytics. All data stays on the device.

## Getting started

### Prerequisites

- Flutter **3.29** or newer (stable channel), which bundles Dart **3.7.2+**
- Android Studio with the Android SDK
- An Android device or emulator running **API 24 (Android 7.0)** or newer
- JDK **17–24** (tested with Temurin 21; Gradle 8.14 does not support JDK 25)

```bash
flutter --version
flutter doctor
```

### Run from source

```bash
git clone https://github.com/Balram-Parmar/Gayatri_Reminder_App.git
cd Gayatri_Reminder_App

flutter pub get
flutter run
```

### Build a release APK

```bash
flutter build apk --release
```

The output is written to `build/app/outputs/flutter-apk/app-release.apk`.

> **Before publishing:** the release build type in `android/app/build.gradle.kts` is currently signed with the debug keystore. Configure your own signing key first.

## Android support

| Item | Value |
| --- | --- |
| Application ID | `com.hkm.gayatri` |
| Min SDK | 24 (Android 7.0) |
| Target / compile SDK | 35 (Android 15) |
| Language | Dart + Kotlin |

This project targets **Android only**. The `ios/`, `web/`, `linux/`, `macos/` and `windows/` folders have been removed from the repository; if you ever need another platform, regenerate it with `flutter create --platforms=<platform> .` from the project root.

### Required permissions

| Permission | Purpose |
| --- | --- |
| `INTERNET` | Fetch sunrise/sunset data |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` | Compute local sun times |
| `POST_NOTIFICATIONS` | Show reminders (Android 13+) |
| `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` | Deliver reminders on time (Android 12+) |
| `RECEIVE_BOOT_COMPLETED` | Restore schedules after a reboot |
| `VIBRATE`, `WAKE_LOCK` | Deliver and alert on notifications |

On first launch the app asks for location and notification access. On Android 12+ you may also need to allow **Alarms & reminders** in system settings.

## Data & storage

Everything is stored as plain JSON in the app's downloads directory (resolved with `getDownloadsDirectory()`).

| File | Contents |
| --- | --- |
| `SunriseTimes.json` | Cached API response with sun times for the current/next 30 days |
| `sadhnaMantra.json` | Your practice history |
| `sadhnaMantra_backup_<timestamp>.json` | Automatic backup created before a sadhna file is imported |
| `settings.json` | App settings, e.g. `notification_reschedule_minutes` |

### `sadhnaMantra.json` format

Keys are `year → month → day` (month and day zero-padded), and each day holds three booleans:

```json
{
  "2025": {
    "05": {
      "01": { "morning": false, "afternoon": false, "night": false },
      "02": { "morning": true, "afternoon": true, "night": false }
    }
  }
}
```

You can back up this file, edit it, or import one from another device via **Settings → Load Sadhna File**.

## Project structure

```text
lib/
├── main.dart                   # App entry point, notification setup, bottom navigation
├── home_page.dart              # Today's sunrise / solar noon / sunset, caching, refresh
├── reports_page.dart           # Calendar, daily sadhna tracking, JSON persistence
├── settings_page.dart          # 30-day scheduling, sadhna import, snooze, test & cancel
├── notification_controller.dart# Dismiss-to-reschedule logic and settings storage
└── backup.Reports.txt          # Legacy snapshot of an earlier settings page (unused)
assets/
└── ic_launcher.png             # App logo
android/                        # Android platform configuration (Gradle, manifest, icons)
docs/screenshots/               # Screenshots referenced by this README
```

> The Dart package is still named `get_location` from the Flutter template, and the `MaterialApp` title is `Sunrise Sunset App`, while the launcher label is **Gayatri Reminder**. Imports therefore look like `package:get_location/...`; renaming the package is optional but touches every import.

## Troubleshooting

**Notifications never appear**
- Android 13+: allow notifications for the app.
- Android 12+: allow **Alarms & reminders**.
- Some vendors (Xiaomi, Oppo, Vivo, Samsung) aggressively kill background work — disable battery optimisation for the app.

**Times look wrong**
- Location permission may be denied, in which case Ahmedabad's coordinates are used. Grant precise location and tap **Full Refresh Data** on the Home tab.

**"No cached data available"**
- The cache is empty and the device is offline. Connect once so `SunriseTimes.json` can be written.

**The calendar starts at May 2025**
- The calendar's first day is hard-coded to `2025-05-01`. Adjust `firstDay` in `lib/reports_page.dart` if you need an earlier range.

## Contributing

Contributions, bug reports and suggestions are welcome.

1. Fork the repository.
2. Create a branch: `git checkout -b feature/my-change`.
3. Make your change and run `flutter analyze`.
4. Open a pull request describing what changed and why.

If you are reporting a bug, please include your device model, Android version, and steps to reproduce.

## Acknowledgements

- [sunrisesunset.io](https://sunrisesunset.io) for the free sun-time API
- The Flutter team and the maintainers of the packages listed above
- Everyone who chants the Gayatri Mantra daily — this app is for you
