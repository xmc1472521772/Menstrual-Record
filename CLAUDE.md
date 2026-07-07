# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

月事记 (Yima) — a menstrual cycle tracking Flutter app. All data is stored locally in SQLite (`yima_period.db`); no network calls, no analytics, no remote backend. UI is hardcoded to Chinese (`zh_CN`).

## Commands

```bash
# Run the app
flutter run

# Run tests (uses sqflite_common_ffi with in-memory database)
flutter test
flutter test test/providers/period_provider_test.dart  # single file

# Analyze code
flutter analyze
```

## Architecture

**Provider-based, flat structure.** No BLoC, no Clean Architecture layers, no code generation.

- **`main.dart`** → entry point, runs `MyApp`, initializes `NotificationService`
- **`app.dart`** → `MaterialApp` + `MultiProvider` (registers `PeriodProvider` and `SettingsProvider`) + `SplashScreen` → `MainScreen` bottom nav with 4 tabs
- **`models/`** → plain Dart classes with manual `toMap`/`fromMap`/`toJson`/`fromJson`/`copyWith` (with `clear*` flags for nullable fields)
- **`database/`** → `DatabaseProvider` (abstract interface), `DatabaseHelper` (SQLite singleton with `onUpgrade` migration), `PeriodDao` and `SettingsDao` (accept `DatabaseProvider?` for DI)
- **`providers/`** → `ChangeNotifier` subclasses with constructor injection support
- **`screens/`** → widget trees consuming providers via `Consumer`/`Consumer2`
- **`widgets/`** → reusable components (`SectionCard`, `StatCircle`, `EmptyState`, `LegendItem`)
- **`services/`** → `PredictionService` (static), `NotificationService` (singleton, timezone-aware)
- **`constants/`** → `AppColors` (brand/functional/calendar), `AppDimens` (spacing/radius/elevation), `AppThemeColors` (ThemeExtension), `AppStrings`, `AppTheme`

**State management:** Two `ChangeNotifier` providers registered in `app.dart`:
- `PeriodProvider` — records, cycle data, day-type classification cache, import/export, notification scheduling
- `SettingsProvider` — user preferences (cycle length, period length, reminders, algorithm)

**Navigation:** No routing library. `SplashScreen` (1.2s) → `MainScreen` with `NavigationBar` (Material 3). Sub-screens use `Navigator.push` with `MaterialPageRoute`.

## Key Patterns

- **Theme system:** `AppThemeColors` is a `ThemeExtension` registered in both light and dark themes. Access theme-aware colors via `context.themeColors.onSurface` (extension on `BuildContext`). Theme-independent colors (brand, functional, calendar) remain in `AppColors` as constants. Spacing/radius/elevation tokens are in `AppDimens`.
- **Day-type classification:** `PeriodProvider` classifies each date as period, predicted period, ovulation, fertile, safe, or normal using a `Map<String, String>` cache (`_dayTypeCache`) that is cleared on data changes.
- **Prediction algorithms:** `PredictionService` offers two algorithms — simple average and weighted moving average. The active algorithm is stored in `SettingsProvider`.
- **Notification scheduling:** `NotificationService` uses `timezone` package for `zonedSchedule`. `PeriodProvider` auto-schedules reminders on data load and algorithm change.
- **Dependency injection:** `DatabaseProvider` interface allows injecting in-memory databases for testing. DAOs and Providers accept optional constructor parameters.
- **Database migration:** `DatabaseHelper` supports `onUpgrade` callback. Increment `_dbVersion` and add migration logic as needed.
- **Serialization:** All manual — no `freezed`, `json_serializable`, or `build_runner`. `toJson` preserves `null` values; `fromJson` converts empty strings to `null` for nullable fields.
- **Dark mode:** Full support via `ThemeMode.system` with complete dark color tokens in `AppThemeColors.dark`.

## Known Issues

- `AppDateUtils` is defined in both `lib/utils/date_utils.dart` and `lib/providers/period_provider.dart` with identical methods. The local definition shadows the import.
- Static text styles in `record_screen.dart` are now instance methods that take `BuildContext` (e.g., `_pastStyle(context)`) to support theme-aware colors.
