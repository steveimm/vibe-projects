# FitNotes++

An offline workout logger for Android, rebuilt with Flutter. No account, ads, or cloud service is required.

## Features

- **Workout log:** ten recording types, exercise reordering, multiple-exercise deletion with confirmation, editable sets, per-set and daily notes, completion status, selective copying, and an editable session timer with pause/resume.
- **Exercise picker:** search across all exercises or select a body part, create exercises from either view, favorites, archive/restore, body-part management, and exercise-specific rest and weight increments.
- **Routines:** named training days, ordered preset sets, optional previous-session values, multiple-routine deletion, and saving an existing workout as a routine.
- **Progress:** workout analysis with date filters and trends, exercise-specific charts, Brzycki 1RM estimates, actual and estimated rep records, goals, training balance, and measurement history.
- **Weight multipliers:** named factors per exercise, with the combined factor stored on each new set. Existing sets retain their original factor.
- **PR seasons:** reset the record-comparison window without deleting history. All-time records use gold trophies, and current-season records use silver.
- **Rest timer:** per-exercise duration and auto-start controls, pause/resume, added time, selectable sound and vibration, background countdown notifications, and recovery of running or paused timers after reopening the app.
- **Preferences:** light/dark/system appearance, metric/imperial units, weight increments, record highlights, completion controls, keep-screen-on, and rep limits for max-weight estimates. Weeks start on Monday.
- **Data:** full SQLite backup/restore with recovery of the previous state, CSV export/import, and original FitNotes workout import.

The exercise and set counts stay visible while scrolling, with a circular + button at the bottom right. Holding an exercise enters edit mode. Tap more cards to select them, then use Delete to remove them after confirmation. Adding exercises, date navigation, and opening set editors are disabled until edit mode ends. Selecting a logged set offers Delete and Update, and Back exits editing. Workout timer controls are available only for today. Other dates keep duration editing and reset in the timer menu. Back from a newly selected exercise returns to the picker until a set is saved, then returns to Home. Browsing without saving preserves the picker's search and scroll position.

## Data behavior

Weights are stored in kilograms and distances in meters. Display-unit changes preserve the stored values. A multiplier is captured when a set is added, including a copied or routine-generated set.

Copied and routine sets appear as "Not completed" in the log and calendar. They do not count toward volume, records, graphs, or performed-workout counts until marked complete. Logging a new set records it as performed.

Full `.fitnotesplus` backups contain the app's exercises, sets, notes, routines, measurements, goals, multipliers, seasons, and preferences. Restore validates the database and replaces data in a transaction. **Undo last restore** recovers the automatic copy made immediately before restoration.

Original `.fitnotes` imports merge categories, exercises, workout sets, set comments, and daily notes. Source IDs prevent duplicate sets when importing the same backup again. Unsupported original exercise-type IDs reject the import rather than silently reinterpret data. Original FitNotes routines, measurements, and application preferences are not part of this importer.

CSV exports contain performed sets in the standard ten-column FitNotes format, using canonical kg/meters and effective weights. CSV import also supports the legacy combined `Weight (lbs)` column. Reimporting an export does not duplicate matching sets. Use a full backup to retain raw weights, multipliers, RPE, routines, and preferences.

Schema version 5 migrates existing databases without discarding their workout history. Version 2 through 5 backups can be restored. The reference backup and reconstruction notes are in [`ref/`](ref/) and [`FITNOTES_REFERENCE.md`](FITNOTES_REFERENCE.md).

## Development

The project requires Flutter 3.47 or newer (Dart 3.13+) and uses Drift/SQLite, Riverpod, go_router, and fl_chart. Native Android code handles document export, keep-screen-on, and the foreground rest-timer service.

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build apk --debug --split-per-abi
flutter build apk --release --split-per-abi
```

Build separate APKs per ABI. Outputs are in `build/app/outputs/flutter-apk/`. Use `app-arm64-v8a-release.apk` for the ARM64 emulator. The existing Android release configuration uses the development signing key.

- `lib/core/database/`: schema, migration, and starter data.
- `lib/core/repositories/`: workout, exercise, routine, progress, and preference operations.
- `lib/core/import/` and `lib/core/services/`: data transfers and timer state.
- `lib/features/`: screens grouped by workflow.
- `lib/app/` and `lib/shared/`: routing, theme, shared controls, and charts.
- `test/`: migration, import, backup, analytics, workflow, calendar, and timer regression checks.

Android background rest timing uses a bounded wake lock and a user-visible foreground service. Its declaration follows the [Android foreground-service documentation](https://developer.android.com/develop/background-work/services/fgs/service-types#special-use). Notification access can be managed from Settings → Timer notifications.

## Verification

The 1.1.0 update was exercised through ADB on an ARM64 Android 16/API 36 emulator. The walkthrough covered logging and validation, edits and notes, selective copying, delete/undo, routine creation and reordering, favorites and archive/restore, categories, multipliers and RPE, seasons and goals, measurements, calculators, units, calendar preferences, full backup/restore/recovery, CSV and repeated FitNotes imports, background timer completion, and paused-timer recovery.

Light/dark appearance and 200% text scaling were visually checked. The test suite includes regression checks for migration, canonical data preservation, planned-versus-performed sets, all ten recording types, PR windows, backup/CSV round trips, and calendar/timer/layout behavior.
