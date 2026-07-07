# 月事记 (Yima)

经期记录与周期追踪 Flutter 应用。所有数据本地存储于 SQLite，无网络请求、无后端、无数据分析。

## 功能

- 经期记录：手动开始/结束经期，查看历史记录
- 周期预测：基于历史数据预测下次经期、排卵期、易孕期
- 双算法支持：简单平均 & 加权移动平均
- 自定义日历：从零构建的滑动切换日历
- 通知提醒：经期来临前可自定义提醒天数和时间
- 数据导入/导出：支持 JSON 格式导入导出
- 暗色模式：完整支持 Material 3 暗色主题
- 隐私安全：所有数据存储在本地 SQLite 数据库

## 技术栈

- **Flutter** (Material 3)
- **SQLite** (sqflite)
- **Provider** 状态管理
- **flutter_local_notifications** + **timezone** 通知调度
- 手动序列化（无 build_runner / freezed）

## 快速开始

```bash
flutter pub get
flutter run
```

## 测试

```bash
flutter test
flutter test test/providers/period_provider_test.dart  # 单个测试文件
```

## 代码分析

```bash
flutter analyze
```

## 项目结构

```
lib/
├── main.dart              # 入口，初始化 NotificationService
├── app.dart               # MaterialApp + MultiProvider + SplashScreen → MainScreen
├── models/                # 数据模型（手动 toMap/fromMap/toJson/fromJson）
│   ├── period_record.dart
│   └── cycle_data.dart
├── database/              # SQLite 数据层
│   ├── database_helper.dart  # DatabaseProvider 接口 + DatabaseHelper 单例
│   ├── period_dao.dart
│   └── settings_dao.dart
├── providers/             # ChangeNotifier 状态管理
│   ├── period_provider.dart
│   └── settings_provider.dart
├── services/              # 无状态服务
│   ├── prediction_service.dart
│   └── notification_service.dart
├── screens/               # 页面 UI
│   ├── splash_screen.dart
│   ├── home_screen.dart
│   ├── record_screen.dart
│   ├── stats_screen.dart
│   └── settings_screen.dart
├── widgets/               # 可复用组件
│   └── common_widgets.dart
├── constants/             # 设计令牌
│   ├── app_colors.dart     # AppColors + AppDimens + AppThemeColors (ThemeExtension)
│   ├── app_strings.dart
│   └── app_theme.dart
└── utils/
    └── date_utils.dart
```

## 架构要点

### 主题系统

- `AppColors` — 品牌色、功能色、日历日类型色（主题无关常量）
- `AppDimens` — 间距、圆角、阴影令牌（主题无关常量）
- `AppThemeColors` — ThemeExtension，提供主题相关的语义颜色（surface, onSurface, divider 等）
- 通过 `context.themeColors.onSurface` 访问主题颜色

### 数据库迁移

`DatabaseHelper` 支持 `onUpgrade` 回调，可通过递增版本号和添加迁移逻辑来演进 schema。

### 依赖注入

DAO 和 Provider 均支持构造函数注入 `DatabaseProvider`，便于单元测试中使用内存数据库。

### 通知调度

`NotificationService` 在 `main.dart` 初始化。`PeriodProvider` 在数据加载和算法切换时自动调度经期提醒通知。

## 版本

当前版本：1.1.0+3

格式：`major.minor.patch+build`
