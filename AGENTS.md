# AGENTS.md

月事记 (Yima) — a menstrual cycle tracking Flutter app. All data is local SQLite (`yima_period.db`); no network, no backend. UI is hardcoded to Chinese (`zh_CN`).

## Commands

```bash
flutter run
flutter test
flutter test test/providers/period_provider_test.dart   # single test
flutter analyze
```

> If you need China mirrors, set `FLUTTER_STORAGE_BASE_URL` and `PUB_HOSTED_URL` environment variables yourself and then run `flutter run`.

## Versioning

**每次更新都必须修改版本号！** 版本号格式：`major.minor.patch+build`

- `major`：大版本更新（不兼容的 API 修改）
- `minor`：新功能添加
- `patch`：Bug 修复
- `build`：构建号，每次发布递增

修改位置：`pubspec.yaml` 中的 `version` 字段，例如 `1.1.0+3`。

## Architecture

Flat Provider-based structure. No BLoC, no Clean Architecture layers, **no code generation** (`build_runner`, `freezed`, `json_serializable` are not used).

- `main.dart` → `MyApp` (initializes `NotificationService`)
- `app.dart` → `MaterialApp` + `MultiProvider` (`PeriodProvider`, `SettingsProvider`) + `SplashScreen` → `MainScreen` bottom nav (4 tabs)
- `models/` → plain Dart classes with **manual** `toMap`/`fromMap`/`toJson`/`fromJson`/`copyWith`
- `database/` → `DatabaseProvider` (abstract interface), `DatabaseHelper` (SQLite singleton, `onUpgrade` migration), `PeriodDao`, `SettingsDao`
- `providers/` → `ChangeNotifier` subclasses with **constructor injection** support for testing
- `screens/` → widget trees consuming providers via `Consumer`/`Consumer2`
- `widgets/` → reusable components (`SectionCard`, `StatCircle`, `EmptyState`, `LegendItem`)
- `services/` → `PredictionService` (static methods), `NotificationService` (singleton, timezone-aware scheduling)
- `constants/` → `AppColors` (brand/functional/calendar colors), `AppDimens` (spacing/radius/elevation tokens), `AppThemeColors` (ThemeExtension for theme-aware semantic colors), `AppStrings`, `AppTheme`

### Navigation

App starts with `SplashScreen` (1.2s animation), then navigates to `MainScreen`. `NavigationBar` switches 4 screens by index. Sub-screens use `Navigator.push` with `MaterialPageRoute`.

### Theme System

- `AppColors` — brand, functional, and calendar day-type colors (theme-independent constants)
- `AppDimens` — spacing, radius, and elevation tokens (theme-independent constants)
- `AppThemeColors` — `ThemeExtension<AppThemeColors>` registered in `AppTheme.lightTheme` / `AppTheme.darkTheme`; provides `surface`, `surfaceCard`, `onSurface`, `onSurfaceSecondary`, `onSurfaceTertiary`, `divider`, `background`
- Access via `context.themeColors.onSurface` (convenience extension on `BuildContext`)

### Prediction & Caching

- `PredictionService` offers two algorithms: `simple` and `weighted`. Active algorithm lives in `SettingsProvider`.
- `PeriodProvider` classifies each date (period / predicted / ovulation / fertile / safe / normal) using a `Map<String, String>` `_dayTypeCache` that is **cleared on every data mutation**.
- `PeriodProvider` auto-ends ongoing periods that exceed the user's configured period length.

### Notification Scheduling

- `NotificationService` is initialized in `main.dart`.
- `PeriodProvider._scheduleReminderIfNeeded()` automatically schedules a reminder when records are loaded or the algorithm changes.
- Uses `timezone` package for cross-timezone `zonedSchedule` support.

### Dependency Injection

- `DatabaseProvider` is an abstract interface; `DatabaseHelper` implements it.
- `PeriodDao` and `SettingsDao` accept `DatabaseProvider?` for testing.
- `PeriodProvider` and `SettingsProvider` accept `PeriodDao?` and `SettingsDao?` for testing.
- Tests use `sqflite_common_ffi` with `inMemoryDatabasePath`.

### Calendar

Built from scratch with `GridView.builder` and swipe gestures. Both home screen and add-record calendar support swipe-to-change-month with animated transitions.

### Database Migration

`DatabaseHelper` supports `onUpgrade` callback. To add a new schema version:
1. Increment `_dbVersion`
2. Add migration logic in `_onUpgrade` (e.g., `if (oldVersion < 2) { ... }`)

## Lint & Style

Standard `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`. No custom rules. Prefer following the existing manual serialization style.

## Known Traps

- **`AppDateUtils` is duplicated.** It exists in both `lib/utils/date_utils.dart` and `lib/providers/period_provider.dart` (local class at the bottom of the file). The local definition shadows the import. If you change date logic, you may need to change both or deduplicate them.
- **`table_calendar`** has been removed from dependencies. The custom calendar is the only calendar implementation.
- **Static text styles in `record_screen.dart`** are now instance methods that take `BuildContext` (e.g., `_pastStyle(context)`) to support theme-aware colors. They cannot be `const`.
