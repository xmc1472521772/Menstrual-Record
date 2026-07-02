# AGENTS.md

月事记 (Yima) — a menstrual cycle tracking Flutter app. All data is local SQLite (`yima_period.db`); no network, no backend. UI is hardcoded to Chinese (`zh_CN`).

## Commands

```bash
flutter run
flutter test
flutter test test/<file>.dart   # single test
flutter analyze
flutter pub run flutter_launcher_icons  # regenerate launcher icon
```

> **Do not use `run_app.bat` or `run_app.ps1` as-is.** They hardcode absolute paths (`E:\yimaflutter`, `D:\Android\Sdk`) from the original dev machine. If you need China mirrors, set `FLUTTER_STORAGE_BASE_URL` and `PUB_HOSTED_URL` yourself and then run `flutter run`.

## Versioning

**每次更新都必须修改版本号！** 版本号格式：`major.minor.patch+build`

- `major`：大版本更新（不兼容的 API 修改）
- `minor`：新功能添加
- `patch`：Bug 修复
- `build`：构建号，每次发布递增

修改位置：`pubspec.yaml` 中的 `version` 字段，例如 `1.1.0+2`。

## Architecture

Flat Provider-based structure. No BLoC, no Clean Architecture layers, **no code generation** (`build_runner`, `freezed`, `json_serializable` are not used).

- `main.dart` → `MyApp`
- `app.dart` → `MaterialApp` + `MultiProvider` (`PeriodProvider`, `SettingsProvider`) + `SplashScreen` → `MainScreen` bottom nav (4 tabs)
- `models/` → plain Dart classes with **manual** `toMap`/`fromMap`/`toJson`/`fromJson`/`copyWith`
- `database/` → `DatabaseHelper` (SQLite singleton), `PeriodDao`, `SettingsDao`
- `providers/` → `ChangeNotifier` subclasses that call DAOs directly
- `screens/` → widget trees consuming providers via `Consumer`/`Consumer2`
- `services/` → `PredictionService` (static methods), `NotificationService` (singleton)
- `constants/` → `AppColors`, `AppStrings`, `AppTheme`

### Navigation

App starts with `SplashScreen` (2s animation), then navigates to `MainScreen`. `NavigationBar` switches 4 screens by index. Sub-screens use `Navigator.push` with `MaterialPageRoute`.

### Prediction & Caching

- `PredictionService` offers two algorithms: `simple` and `weighted`. Active algorithm lives in `SettingsProvider`.
- `PeriodProvider` classifies each date (period / predicted / ovulation / fertile / safe / normal) using a `Map<String, String>` `_dayTypeCache` that is **cleared on every data mutation**.
- `PeriodProvider` auto-ends ongoing periods that exceed the user's configured period length.

### Calendar

Built from scratch with `GridView.builder` and swipe gestures. `table_calendar` is declared in `pubspec.yaml` but **never imported or used**. Both home screen and add-record calendar support swipe-to-change-month with animated transitions.

## Lint & Style

Standard `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`. No custom rules. Prefer following the existing manual serialization style.

- `flutter analyze` — No issues found.
- `flutter test` — All tests passed. Test uses `sqflite_common_ffi` for database initialization.

## Known Traps

- **`AppDateUtils` is duplicated.** It exists in both `lib/utils/date_utils.dart` and `lib/providers/period_provider.dart` (local class at the bottom of the file). The local definition shadows the import. If you change date logic, you may need to change both or deduplicate them.
- **`lib/widgets/` is empty.** All widgets are inline in `screens/`.
- **`table_calendar`** is a dead dependency; do not introduce it unless you intend to replace the custom calendar.
- **`generate_icon.py` hardcodes `E:\yimaflutter\assets\icon\app_icon.png`.** Won't work outside the original dev machine. Edit the path before running.
