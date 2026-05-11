# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

月事记 (Yima) — a menstrual cycle tracking Flutter app. All data is stored locally in SQLite (`yima_period.db`); no network calls, no analytics, no remote backend. UI is hardcoded to Chinese (`zh_CN`).

## Commands

```bash
# Run the app (standard)
flutter run

# Run with China mirrors (use run_app.bat or run_app.ps1)
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code
flutter analyze

# Regenerate app icon
python generate_icon.py
```

## Architecture

**Provider-based, flat structure.** No BLoC, no Clean Architecture layers, no code generation.

- **`main.dart`** → entry point, runs `MyApp`
- **`app.dart`** → `MaterialApp` + `MultiProvider` (registers `PeriodProvider` and `SettingsProvider`) + `MainScreen` bottom nav with 4 tabs
- **`models/`** → plain Dart classes with manual `toMap`/`fromMap`/`toJson`/`fromJson`/`copyWith`
- **`database/`** → `DatabaseHelper` (SQLite singleton), `PeriodDao` and `SettingsDao` for direct DB access
- **`providers/`** → `ChangeNotifier` subclasses that hold state and call DAOs directly
- **`screens/`** → widget trees consuming providers via `Consumer`/`Consumer2`
- **`services/`** → stateless utilities: `PredictionService` (static methods), `NotificationService` (singleton)
- **`constants/`** → design tokens (`AppColors`), UI strings (`AppStrings`), theme data (`AppTheme`)

**State management:** Two `ChangeNotifier` providers registered in `app.dart`:
- `PeriodProvider` — records, cycle data, day-type classification cache, import/export
- `SettingsProvider` — user preferences (cycle length, period length, reminders, algorithm)

**Navigation:** No routing library. `NavigationBar` (Material 3) switches between 4 screens by index. Sub-screens use `Navigator.push` with `MaterialPageRoute`.

## Key Patterns

- **Day-type classification:** `PeriodProvider` classifies each date as period, predicted period, ovulation, fertile, safe, or normal using a `Map<String, String>` cache (`_dayTypeCache`) that is cleared on data changes.
- **Prediction algorithms:** `PredictionService` offers two algorithms — simple average and weighted moving average. The active algorithm is stored in `SettingsProvider`.
- **Custom calendar:** The home screen calendar is built from scratch with `GridView.builder` and swipe gestures (not using `table_calendar`, which is listed in pubspec.yaml but unused).
- **Serialization:** All manual — no `freezed`, `json_serializable`, or `build_runner`.
- **Dark mode:** Full support via `ThemeMode.system` with complete dark color tokens in `AppColors`.

## Known Issues

- `AppDateUtils` is defined in both `lib/utils/date_utils.dart` and `lib/providers/period_provider.dart` with identical methods. The local definition shadows the import.
- `lib/widgets/` directory is empty — no reusable widgets have been extracted.
- `table_calendar` is a declared dependency but never imported.
