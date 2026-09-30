# Upgrade Plan — Error Logs Mobile

## Current state

Score: 7/10 — log parsing, filtering and grouping with tested pure-Dart logic, honest CI and fail-closed release signing; still no app icon or E2E flow.

## Backlog

### P0
- None open. (Release signing now fails closed without `android/key.properties`.)

### P1
- Optional, opt-in "remember last log" (off by default, with a clear-data button) if users ask for it; never persist silently.
- Redact obvious secrets (bearer tokens, emails) in the view with a toggle.
- Import a log file via the file picker.
- Replace the template launcher icon with a real app icon (the application ID `com.bookchaowalit.*` is already set).
- Add a Maestro smoke flow for the main journey.
- Add a CI job that builds a signed release bundle from repository secrets (keystore decoded at runtime, never committed).

### P2
- Tablet layout (NavigationRail) and 130% text-scale widget test.
- Localisation (Thai/English) for UI strings.

## Done in this pass (pass 2)

- Release builds no longer sign with the debug key: `android/app/build.gradle.kts` reads the ignored `android/key.properties` and a Gradle guard fails any release assemble/bundle without it (pattern from `bookchaowalit-goal-tracker-mobile`). Root `.gitignore` also ignores `key.properties`, `*.jks`, `*.keystore`; README documents the setup. Not build-verified here (no Android SDK/Gradle in this environment).
- Decided not to persist pasted logs: log output often contains tokens, emails or other personal data, so keeping it only in memory for the session is the safer default. Recorded as an opt-in backlog item instead.

## Done in pass 1

- Replaced the Expo/npm CI (which could never fail) with fail-closed Flutter CI: `dart format` check, `flutter analyze`, `flutter test`, debug APK on `main`.
- Implemented the core feature (paste log output, filter it by level and see which errors repeat most) with pure-Dart logic in `lib/logic/`.
- Replaced placeholder Explore/Profile tabs with an About screen describing features and privacy.
- Added unit tests for the logic and widget tests for the main journey.
- Removed unused `go_router` / `flutter_riverpod` dependencies; README now matches the code.
