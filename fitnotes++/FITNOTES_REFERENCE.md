# FitNotes — Reference for a Modern Rebuild

Reverse-engineered + researched reference for **FitNotes** (Android strength/cardio tracker,
package `com.github.jamesgay.fitnotes`, by James Gay). Built to drive a modern rebuild.

**Provenance tags** used throughout:
- `[BACKUP]` — ground truth, decoded directly from a real `FitNotes_Backup.fitnotes` (SQLite, user_version 22) in `ref/`.
- `[SHOT]` — visible in the official screenshots in `ref/`.
- `[DOCS]` — verified against official docs (fitnotesapp.com) / reverse-engineering tools, via deep-research (≥2/3 adversarial vote).
- `[OPEN]` — not yet confirmed; being researched.

---

## 1. Product philosophy (the soul to preserve)

`[DOCS]` Offline-first, **free**, **no account / no login**, no ads, full local data ownership.
Fast manual logging is the entire point — minimal taps from "open app" to "set saved". The
rebuild should keep: instant offline logging, zero forced cloud/account, complete export, and
the lightning-fast weight/reps stepper UX. These are the reasons users pick FitNotes over
Strong/Hevy.

---

## 2. Information architecture / navigation

Left **nav drawer** `[SHOT]` → top-level destinations:
- **Workout Log** (home) — the daily log. `[SHOT]`
- **Calendar** — month/list view of training days. `[SHOT]`
- **Exercises** — the exercise database (by exercise / by category). `[SHOT]`
- **Routines** — templates. `[DOCS]`
- **Body** / Measurements — bodyweight + measurements. `[BACKUP]`
- **Settings** `[SHOT]`

### Home — "Workout Log" `[SHOT]`
- Header: title, calendar icon (jump to date), `+` (add exercise to today), overflow.
- **Date bar**: `TODAY` with ◀ ▶ to move day-by-day.
- Empty state: **Start New Workout** and **Copy Previous Workout** actions.
- A logged day shows the exercises done, each with its sets.

### Exercise detail — three tabs `[SHOT]` `[DOCS]`
Opened by tapping an exercise. Header shows exercise name + **rest-timer countdown badge**,
trophy (PRs), info (notes), overflow (tools).
- **TRACK** — weight/reps (or distance/time) entry + the day's logged sets.
- **HISTORY** — every set for this exercise grouped by date (newest first).
- **GRAPH** — progress charts (see §6).

---

## 3. Exercise types — 10 total `[DOCS]`

An exercise's **Type** decides which of 4 components {Weight, Reps, Distance, Time} it records.
Each type uses **at most 2** components.

**Default (free):**
1. **Weight and Reps** — strength default (`exercise_type_id = 0` `[BACKUP]`).
2. **Distance and Time** — cardio (`exercise_type_id = 1` `[BACKUP]`; e.g. Running, Cycling).

**Supporter app (paid unlock):**
3. Weight and Distance · 4. Weight and Time · 5. Reps and Distance · 6. Reps and Time ·
7. **Weight Only** · 8. **Reps Only** (bodyweight) · 9. **Distance Only** · 10. **Time Only**

> `[BACKUP]` confirms `exercise_type_id` values 0, 1, and **3** (Time-only, e.g. Plank) in real data.
> The numeric id↔type map beyond 0/1 is partially `[OPEN]` (this backup only exercised 0/1/3).

**New Exercise fields** `[SHOT]` `[DOCS]`: Name, Notes (optional), Category, Type, Weight Unit
(defaults to global; **per-exercise unit override is Supporter-only**).

---

## 4. Logging a set (TRACK) `[SHOT]`

- Inputs are **± steppers** (also tap-to-type): WEIGHT (in the exercise's unit) and REPS
  (or DISTANCE/TIME depending on type).
- **SAVE** (green) appends the set; **CLEAR** resets inputs.
- The set list below shows `#  weight  reps`, a **comment icon** (per-set note), and — when
  *Mark Sets Complete* is on — a **completion checkbox**. `[SHOT]` `[BACKUP]`
- **Rest Timer** `[SHOT]`: configurable duration (± ), **Vibrate / Sound / Auto-start** toggles,
  **Volume** slider, Pause/Cancel; can auto-start after each saved set. Stored globally in
  `settings` and per-exercise via `default_rest_time`. `[BACKUP]`
- Weight is stored **canonically in metric** (`metric_weight`, kg) with a `unit` field; lbs are
  display-converted. `[BACKUP]`

---

## 5. History `[SHOT]`
Per-exercise: all sets grouped under date headers (`SATURDAY, MAY 30` …), newest first, each row
`weight kgs  ×  reps`. PR sets are highlighted when *Track Personal Records* is on. `[DOCS]`

---

## 6. Graphs, metrics & Personal Records

### Graph metrics — 13, all per-day aggregates `[DOCS]`
Strength: **Estimated 1RM**, **Max Weight**, **Workout Volume** (Σ weight×reps that day),
**Total Reps**, **Max Reps**, **Weight and Reps** (max weight at a chosen rep-count), **Rep Maxes**.
Cardio: **Max Distance**, **Max Time**, **Max Speed**, **Max Pace**, **Total Distance**, **Total Time**.
- Time ranges: **1m / 3m / 6m / 1y / all**. `[SHOT]`
- Graph display toggles (from `settings` `[BACKUP]`): show points, show trend line, start-axis-at-zero.
- A day's value = aggregate of that day's sets (e.g. Est.1RM = highest est.1RM of the day; Workout Volume = day's total). `[DOCS]`

### Estimated 1RM — **Brzycki** `[DOCS]` (high confidence)
FitNotes names the **Brzycki formula** explicitly in its glossary (empirically verified: docs say
225 lb × 5 → 253 lb, which matches Brzycki's 253.1 and rules out Epley 262.5 / Lombardi 264.3):

```
1RM = weight × 36 / (37 − reps)        (≡ weight / (1.0278 − 0.0278 × reps))
```

- The highest est. 1RM across all sets seeds the **2RM…15RM** rep-max grid by **inverting** the
  same equation: `weight(N) = 1RM × (37 − N) / 36` (round-trips exactly).
- `settings.estimated_1rm_max_reps_to_include` `[BACKUP]` = rep ceiling; sets above it are excluded
  from the 1RM calc (**0 = no limit**, default; docs suggest 10–12). `estimated_1rm_max_apply_to_graph`
  applies that cap to graphs too.
- Accurate for **2–10 reps**; v1.21 added a high-rep (≥10) dampening correction layered on Brzycki —
  exact form unpublished, so approximate or make configurable.

### Personal Records `[DOCS]`
- Tracks **largest weight per rep-count**. Two views: **Estimated** (derived from highest est. 1RM)
  vs **Actual** (verified max weight at each rep-count); user can switch between them.
- **Precedence**: a PR at a higher rep-count with equal/greater weight supersedes lower-rep PRs.
- `[BACKUP]`: `training_log.is_personal_record`, `is_personal_record_first` flag PR sets
  (307 flagged in this backup); trophy icon + "new PR" highlighting when enabled.

Verified in FitNotes 25.1 on the emulator, 2026-10-15: saving 120 kg × 10 removes the trophy from an earlier 100 kg × 10.
Repeating 120 kg × 10 keeps the trophy on the first matching set. Saving 120 kg × 12 removes both lower-rep trophies.
The exported database confirms that only 120 kg × 12 remains marked. Trophies indicate current records, not every past improvement.

---

## 7. Routines / templates `[DOCS]`  (schema `[BACKUP]`)

- A **Routine** contains multiple **Days/Sections**, each holding selected exercises; structure by
  weekday (Mon/Wed/Fri) or muscle group.
- Each routine exercise can have **Predefined Sets** (exact weight/reps/distance/time). **Leave a
  field blank → that value is copied from the previous workout** (e.g. fixed reps, carried-over weight).
- **Supersets**: tap exercise → **Add To Group**; grouped exercises show a **colored bar**.
  (Originally "Group", renamed "Supersets" in v1.21.) Superset storage has some ambiguity in backups.
- **Using a routine**: per-Day **Log All** adds that day's exercises (with predefined or default
  0×0 sets) to the current workout. The active routine **auto-loads** on Start New Workout; a dropdown
  switches routines. Sets can be edited/deselected before Save.
- **Copy Previous Workout** `[SHOT]` clones the last session's exercises/sets into today.
- Schema `[BACKUP]`: `Routine(name,notes)` → `RoutineSection(routine_id,name,sort_order)` →
  `RoutineSectionExercise(routine_section_id,exercise_id,sort_order,populate_sets_type)` →
  `RoutineSectionExerciseSet(routine_section_exercise_id,metric_weight,reps,distance,duration_seconds,unit,sort_order)`.
  In-log superset grouping uses `WorkoutGroup`/`WorkoutGroupExercise`
  (`auto_jump_enabled`, `rest_timer_auto_start_enabled`).

---

## 8. Calendar `[SHOT]`

- **Month View** and **List View** (drawer toggle).
- Per-day **colored dots** = muscle categories trained that day (a multi-category day shows multiple
  dots — confirmed by `[BACKUP]` per-category day counts).
- Total **workouts counter** (this backup: **338 distinct training days** = the "338 WORKOUTS"
  shown in the screenshot `[BACKUP]`↔`[SHOT]`).
- Drawer **Category Filter** (per-muscle checkboxes) + **Exercise Filter**.
- Visibility toggles in `settings`: category dots, navigation bar, detail, history dots/names/sets. `[BACKUP]`

---

## 9. Body tracking & measurements `[BACKUP]` `[DOCS]`

- **Bodyweight**: `BodyWeight(date, body_weight_metric, body_fat, comments)`; optional goal +
  "show in workout log" toggle (`settings`).
- **Measurements**: 15 seeded — Bodyweight, Body Fat, Neck, Shoulders, Chest, Waist, Hips,
  L/R Upper Arm, L/R Forearm, L/R Thigh, L/R Calf — each with a unit, optional goal, enabled flag,
  sort order; **custom measurements** supported (`Measurement.custom`).
  Records: `MeasurementRecord(measurement_id, date, time, value, comment)`.
- Units (`MeasurementUnit`): kg, lbs, cm, in, %.

---

## 10. Built-in workout tools `[DOCS]` (config `[BACKUP]`)

- **1RM Calculator** — est. 1RM from weight + reps.
- **Set Calculator** — set weights from base weight × percentage.
- **Plate Calculator** — plates needed per side. Config `[BACKUP]`: `Barbell` (e.g. 20 kg / 45 lb)
  + `Plate(weight, unit, count, enabled, colour)` (23 plate defs, kg & lb, each with a color).
- **Rep Max Grid** — `RepMaxGridFavourite(exercise_ids, rep_counts)` (saved exercise×rep-count grids).
- **Goals** — `Goal(type_id, exercise_id, metric_weight/reps/distance/duration, target_date, start_date)`.

---

## 11. Settings (full) `[BACKUP]` `[SHOT]`

`settings` is a single row, ~44 columns. Decoded:
- **Units/format**: `metric`, `first_day_of_week` (2 = Monday, Java Calendar constant),
  `weight_increment` (2.5), `body_weight_increment`.
- **Logging**: `track_personal_records`, `mark_sets_complete`, `auto_select_next_set`,
  `keep_screen_on`.
- **Estimated 1RM**: `estimated_1rm_max_reps_to_include`, `estimated_1rm_max_apply_to_graph`.
- **Graphs**: `graph_show_points`, `graph_show_trend_line`, `graph_start_at_zero`,
  `workout_graph_default_graph_type`, `workout_graph_default_time_period`.
- **Rest timer**: `rest_timer_seconds` (60), `rest_timer_vibrate`, `rest_timer_sound`,
  `rest_timer_volume`, `rest_timer_auto_start`.
- **Calendar**: `calendar_detail_visible`, `calendar_category_dots_visible`,
  `calendar_navigation_bar_visible`, `calendar_history_category_dots_visible`,
  `calendar_history_category_names_visible`, `calendar_history_sets_visible`.
- **Categories/exercise list**: `category_sort_order`, `category_show_colours`,
  `exercise_list_detail_type_id` (controls "N workouts (X ago)" detail line).
- **Workout timer**: `workout_timer_auto_start_enabled`, `workout_timer_auto_stop_enabled`
  (+ `WorkoutTime(start_date_time, end_date_time)` per day → session duration).
- **Measurements**: `measurement_tracker_initial_load`, `measurement_show_in_workout_log`.
- **Analysis**: `analysis_breakdown_breakdown_type`, `analysis_breakdown_time_period`
  (a volume/category breakdown view).
- **Home screen**: `home_screen_limit_type_id`, `home_screen_limit_value`,
  `home_screen_category_visibility_id`, `home_screen_skip_empty_dates`.
- **Theme**: `app_theme_id` (0 = Light) `[SHOT]`.

---

## 12. Data model (full schema, ground truth) `[BACKUP]`

The `.fitnotes` backup is a plain **unencrypted SQLite** DB `[DOCS]`. Tables:

| Table | Purpose |
|---|---|
| `Category` | muscle groups: `name, colour (signed ARGB int), sort_order` |
| `exercise` | `name, category_id, exercise_type_id, notes, weight_increment, default_graph_id, default_rest_time, weight_unit_id, is_favourite` |
| `training_log` | **core set log**: `exercise_id, date, metric_weight, reps, unit, distance, duration_seconds, is_personal_record, is_personal_record_first, is_complete, is_pending_update, routine_section_exercise_set_id, timer_auto_start` |
| `Comment` | polymorphic note: `date, owner_type_id, owner_id, comment` (owner_type 1 = a `training_log` set) |
| `WorkoutComment` | per-day workout note: `date, comment` |
| `Routine`,`RoutineSection`,`RoutineSectionExercise`,`RoutineSectionExerciseSet` | template hierarchy (§7) |
| `WorkoutGroup`,`WorkoutGroupExercise` | in-log supersets |
| `BodyWeight` | bodyweight + body fat (§9) |
| `Measurement`,`MeasurementRecord`,`MeasurementUnit` | body measurements (§9) |
| `Goal` | per-exercise goals |
| `Barbell`,`Plate` | plate calculator config |
| `ExerciseGraphFavourite` | pinned graphs (`graph_type_id, time_period, is_default`) |
| `RepMaxGridFavourite` | saved rep-max grids |
| `WorkoutTime` | per-day session start/end timestamps |
| `settings` | single-row app config (§11) |
| `android_metadata` | `locale` |

**Category color palette** `[BACKUP]` (the classic "Flat UI" set — good rebuild starting palette):
Abs `#2C3E50` · Back `#2980B9` · Biceps `#F39C12` · Cardio `#7F8C8D` · Chest `#C0392B` ·
Forearm `#2ECC71` · Legs `#54B2B6` · Shoulders `#8E44AD` · Triceps `#27AE60`.

**Canonical-storage rule** `[BACKUP]`: weights stored in kg (`metric_weight`); `unit=0` means "use
default unit", explicit unit otherwise. Replicate for clean kg↔lb display + import fidelity.

---

## 13. Backup, export & import

- **Backup** = the `.fitnotes` SQLite file (Local + Google Drive backup/restore — **not live sync**;
  restore overwrites current data). `[DOCS]`
- **CSV export — current Android format (10 cols)** `[DOCS]` (high confidence; verified verbatim
  across real exports dated 2023/2025/2026):

  ```
  Date,Exercise,Category,Weight,Weight Unit,Reps,Distance,Distance Unit,Time,Comment
  ```
  - One `Weight` column + separate `Weight Unit` (`kgs`|`lbs`) — **not** split kg/lbs columns; **no
    `Kind` column**; free-text field is `Comment` (always quoted; empty = `""`).
  - **Strength** row: `2022-09-14,Flat Barbell Bench Press,Chest,45.0,lbs,10,,,,""` (Distance/Unit/Time empty).
  - **Cardio** row: `2022-06-07,Cycling,Cardio,,,,0.0,m,0:00:30,""` (Weight/Unit/Reps empty).
  - Date `YYYY-MM-DD`; Time `H:MM:SS` (hours **not** zero-padded); Distance Unit observed as `m`.
- **Legacy importers** should sniff the header: older (~2020) exports used **8-col**
  `Date,Exercise,Category,Weight (lbs),Reps,Distance,Distance Unit,Time` (single combined weight col,
  no unit col) and a 9-col `+Comment` variant.
- **Do NOT** reuse the **iOS "FitNotes 2"** 11-col format (`…,Weight (kg),Weight (lbs),…,Notes,Kind`) —
  different product/developer.

---

## 14. Visual design language `[SHOT]`

- Era: **Material Design (Holo→early Material)**; flat, dense, utilitarian. Light & dark themes
  (`app_theme_id`). Accent **cyan/teal** for active tabs/links; **green Save / blue secondary / red
  destructive** buttons. Category color dots everywhere as the primary visual language.
- Rebuild opportunity: modern Material 3 / dynamic color while keeping the **information density**
  and **2-tap logging** that power users love. Don't bloat the log screen.

---

## 15. Competitor landscape `[DOCS]` (pricing point-in-time — reverify at launch)

| | **FitNotes** | **Strong** | **Hevy** | **Boostcamp** | **Liftin'** |
|---|---|---|---|---|---|
| Platforms | Android only | iOS/Android/Watch | iOS/Android/Watch/Wear OS | iOS/Android | iOS/watchOS/iPad/Mac |
| Price | **Free, no ads** | Free (3-routine cap); $4.99/mo, $29.99/yr | Free (4-routine/7-exercise/~3mo cap); $2.99/mo, $23.99/yr, $74.99 LT | Free (generous); $14.99/mo, $59.99/yr | Free (5 workouts/mo); $24.99/yr |
| Cloud sync | **No** (manual backup) | Yes (account) | Yes (account) | Yes (account) | Yes (Apple) |
| RPE/RIR | **No** | Yes | Yes (toggle) | Yes (free) | — |
| Supersets | Yes | Yes | Yes | Yes | Yes |
| Plate calc | Yes | Yes (PRO) | Yes | Yes (free) | Yes (watch) |
| Health integ. | **No** | Apple Health+Google Fit | Apple Health+Strava | — | Apple Health |
| Watch app | **No** | Apple Watch | Apple+Wear OS | — | Standalone |
| Social | No | No | **Yes (core)** | Program library | No |
| Program library | No | Template store | Template store | **11k+ free (core)** | Coach progression |
| Export | **CSV + raw SQLite** | CSV | CSV (incl. rpe, superset_id) | — | — |

## 16. Rebuild priorities `[DOCS]` — close the gap without betraying the ethos
**The soul to preserve:** free forever · no account · offline-first · full data ownership
(plain SQLite + CSV) · privacy (no telemetry) · **2-tap dense logging**.

**Highest-value additions (ranked), all keeping local-first:**
1. **Opt-in cloud sync / multi-device** — the #1 gap vs every competitor (keep sync optional).
2. **Per-set RPE/RIR field** — cheap, table-stakes in 2025 (today users abuse the comment field).
3. **Google Health Connect** (+ Apple Health if cross-platform).
4. **Wear OS / watch companion.**
5. **Richer analytics** — per-muscle volume, PR timelines, strength-score-style dashboards.
6. **Modern Material 3 UI** (the recurring "dated/early-Android-beta" complaint) — without losing density.
7. (Lower) exercise media/instructions; cross-platform (iOS).

> **Do NOT pitch as "new":** plate calculator, supersets/circuits, goals, rest timer, body
> measurements, dark theme, CSV export — FitNotes already has all of these.

## 17. Community sentiment `[DOCS]` (medium confidence — aggregated, directional)
**Loved for:** 100% free/no-ads/no-upsell (the #1 reason it's the Android pick) · simplicity/speed/
"gets out of your way" · offline & private · data ownership (CSV export) + solid progress/1RM analysis.

**Most-requested / top complaints (by apparent demand):**
1. Real cloud sync / multi-device (only Drive backup; "one uninstall = tears").
2. Dated UI ("hasn't been updated in years").
3. Android-only / no iOS.
4. Per-set RPE/RIR.
5. Exercise instructions / images / form videos (minimal exercise DB, no how-to).
6. Richer visual analytics.
7. Wearables + Health Connect.

**Migration pattern:** users "upgrade *from*" FitNotes → **Strong** (modern UX/speed) or **Hevy**
(free tier + social + charts) when they want cross-platform, sync, modern UI, richer charts, or social.
The original Android app is only sporadically updated (last meaningful update ~May 2023), fueling the
"loved but stagnant" narrative — the rebuild's core opening.

---

## 18. Remaining uncertainties `[OPEN]`
- CSV `Distance Unit` values beyond `m` (e.g. `km`, `mi`) — not seen in samples; confirm before importer.
- The exact v1.21 high-rep (>10) 1RM dampening correction — undocumented.
- Competitor pricing & free-tier caps drift — reverify at launch (notably Hevy's free routine cap).
- Exact numeric `exercise_type_id` ↔ type map beyond {0:W&R, 1:Dist&Time, 3:Time-only} — this backup
  didn't exercise the Supporter-only types.

## Emulator comparison, 2026-10-08

Tested FitNotes 25.1 (`com.github.jamesgay.fitnotes`, version code 64) alongside FitNotes++ on the existing Android 16/API 36 emulator. The emulator has no Play Store. The unmodified APK came from [APKPure](https://apkpure.net/fitnotes-gym-workout-log/com.github.jamesgay.fitnotes/download). Its SHA-256 was `3461836b0be6707f759470ff38c5059dda9776e03ce8691a209a6dfbc44abb89`, and its signing certificate SHA-1 was `e66da566f4eb77a1c341c34cc7c2cf68c23c73f2`, matching that listing. This is mirror verification, not independent Play Store verification.

Observed directly:

- Selected Flat Barbell Bench Press and saved two 60 kg × 8 sets. The form keeps the previous values for the next set.
- Opened the rest dialog from the training toolbar, changed 60 to 90 seconds, enabled Auto Start, and started the countdown. Saving the second set reset the running countdown to 90 seconds.
- The rest dialog groups duration, vibration, sound, and auto-start. Running controls change to Pause and Cancel.
- History shows both saved sets under their workout date. The exercise drawer keeps the workout list and Add Exercise within the editor.
- No workout-duration controls appeared in the tested home and training screens. This does not establish that every original-app screen lacks them.

Changes made in FitNotes++ from this comparison and user feedback:

- Rest duration, per-exercise override, auto-start, sound, and vibration are accessible through Rest timer in the set editor. Tapping the running countdown edits its remaining time.
- Workout time supports pause, resume, finish, duration editing, and reset. Paused time is excluded and state persists after reopening. Version 2 databases and backups retain their timer values.
- The training toolbar switches between exercises in the selected workout and adds another exercise without returning home. Selecting an already selected set exits editing.
- Removed introductory slogans and empty-state preambles across the app. Copied and routine sets use “Not completed” and completion controls. Their exclusion from statistics is stated where workouts are copied.

Remaining differences identified by the [official tracking guide](https://www.fitnotesapp.com/workout_tracking/): original FitNotes supports dragging logged sets and workout exercises into order, bulk history editing, and automatic movement through supersets. The 2026-10-09 update adds workout exercise reordering and removal with undo. Logged-set dragging, bulk history editing, and automatic superset switching remain unimplemented. FitNotes++ also adds snapshot weight multipliers and PR seasons described elsewhere in this repository.
