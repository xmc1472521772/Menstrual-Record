# AGENTS.md

月事记 (Yima) — a menstrual cycle tracking Flutter app. All data is local SQLite (`yima_period.db`); no network, no backend. UI is hardcoded to Chinese (`zh_CN`). **Android-only** — no iOS/macOS/Linux/Windows/Web platform code.

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
- `app.dart` → root assembly only (`MaterialApp` + `MultiProvider` (`PeriodProvider`, `SettingsProvider`, `AiAssistantProvider`) + lifecycle + global text-scaling clamp); the bottom-nav shell lives in `screens/main_screen.dart` (`MainScreen`, entered from `SplashScreen`)
- `models/` → plain Dart classes with **manual** `toMap`/`fromMap`/`toJson`/`fromJson`/`copyWith`
- `database/` → `DatabaseProvider` (abstract interface), `DatabaseHelper` (SQLite singleton, `onUpgrade` migration), `PeriodDao`, `SettingsDao`
- `providers/` → `ChangeNotifier` subclasses with **constructor injection** support for testing. `PeriodProvider` = data state only; notification scheduling is delegated to `services/notification_sync_coordinator.dart` (`NotificationSyncCoordinator`), widget pushes to `WidgetService.pushCycleSnapshot`. `AiAssistantProvider` owns the chat streaming replay pacing (80ms throttled flush, `beginChatStream` / `onStreamChunk` / `finishChatStream` / `abortChatStream`).
- `screens/` → widget trees consuming providers via `Consumer`/`Selector`. HomeScreen takes an injected `onOpenSettings` callback (no global keys for cross-tab navigation).
- `widgets/` → reusable components (`SectionCard`, `StatCircle`, `EmptyState`, `LegendItem` in `common_widgets.dart`), 4 CustomPainter charts, plus `calendar/calendar_core.dart` (shared month math + weekday header used by both the home single-select calendar and the multi-select calendar) and `ai/` (chat bubble, report view, model selector, session sheet).
- `services/` → `PredictionService` (static methods), `NotificationService` (singleton, timezone-aware scheduling), `NotificationSyncCoordinator` (3-way reminder sync with dedup + serialized chain), `WidgetService`, `BackupService`, `AiHealthService`.
- `constants/` → `app_colors.dart` contains **`AppColors` + `AppShadows` + `AppDimens` + `AppThemeColors`** (ThemeExtension); `app_strings.dart` (all user-facing strings — do not inline Chinese literals); `app_theme.dart` (text styles + light/dark ThemeData); `app_breakpoints.dart` (`AppBreakpoints.wide=600 / desktop=840`, reserved for future wide-screen layouts).

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

- **Dark-mode contrast rule**: `AppColors.ink / inkSecondary / inkTertiary / canvas / tile / hairline` are **light-theme fixed values**. Never use them on theme-dependent surfaces (AppBar, `themeColors.surfaceCard/surfaceTile`, Card theme). Use `context.themeColors.onSurface*` / `divider` instead. Fixed light surfaces (`AppColors.brandSurface`, `brandSoft`) may keep them.
- **`table_calendar`** has been removed from dependencies. The custom calendar is the only calendar implementation (two UIs share `widgets/calendar/calendar_core.dart`).
- **Static text styles in `record_screen.dart`** are now instance methods that take `BuildContext` (e.g., `_pastStyle(context)`) to support theme-aware colors. They cannot be `const`.
- **Provider 生命周期回调**：`app.dart` 的 `_MyAppState` 在 `initState` 创建 Provider 并以 `.value` 注入；回调里禁止 `context.read`（context 在 MultiProvider 之上）。
- **通知同步**：改提醒开关/提前天数/提醒时间后必须调用 `periodProvider.syncNotifications()`；禁止 `cancelAll`，一律按 ID 精确取消（见 `NotificationSyncCoordinator`）。
