# Upgrade Plan — Error Logs Mobile

## Current state

Score: 7.5/10 — robust log parser (no crash on odd line endings, bracketed timestamps, Java/Python traces), a11y guideline tests and fail-closed signing; no redaction, file import, icon or E2E flow yet.

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
- Tablet layout (NavigationRail).
- Localisation (Thai/English) for UI strings.

## Done in this pass (pass 3)

- Bug fix (crash): a pasted log with lone `\r` line endings (or U+2028) made `_linePattern.firstMatch(line)!` return null — `.` does not match line terminators — so the null check threw during build (red error screen). Lone CRs now split lines, the level regex uses `dotAll`, and the prefix match can never fail.
- Bug fix: bracketed timestamps (`[2026-01-01 10:00:00] ERROR boom`, `[10:00:01] WARN`) — a very common format — were parsed as unknown-level messages; they now yield the timestamp and level.
- Bug fix: signatures treated apostrophes as quotes (`can't find user 'bob'` → `can<str>bob'`), breaking grouping; a quote right after a letter is now left alone.
- Improvement: Java `Caused by:` / `... N more` and Python `File "..."` frames (with their echoed source line) are attached to the entry instead of becoming separate unknown entries.
- Edge-case unit tests for all of the above plus empty/level-only lines and Thai/emoji grouping and search. Widget tests: CR-only paste, empty states, repeat-count semantics ("2 times"), a11y guidelines, 200% text scale. Empty messages show "(no message)".
- The 200% text-scale widget test now runs at a 360 px phone width (it previously used the 800 px default test surface); no overflow found.

## Done in pass 2

- Release builds no longer sign with the debug key: `android/app/build.gradle.kts` reads the ignored `android/key.properties` and a Gradle guard fails any release assemble/bundle without it (pattern from `bookchaowalit-goal-tracker-mobile`). Root `.gitignore` also ignores `key.properties`, `*.jks`, `*.keystore`; README documents the setup. Not build-verified here (no Android SDK/Gradle in this environment).
- Decided not to persist pasted logs: log output often contains tokens, emails or other personal data, so keeping it only in memory for the session is the safer default. Recorded as an opt-in backlog item instead.

## Done in pass 1

- Replaced the Expo/npm CI (which could never fail) with fail-closed Flutter CI: `dart format` check, `flutter analyze`, `flutter test`, debug APK on `main`.
- Implemented the core feature (paste log output, filter it by level and see which errors repeat most) with pure-Dart logic in `lib/logic/`.
- Replaced placeholder Explore/Profile tabs with an About screen describing features and privacy.
- Added unit tests for the logic and widget tests for the main journey.
- Removed unused `go_router` / `flutter_riverpod` dependencies; README now matches the code.
