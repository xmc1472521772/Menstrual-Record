# Menstrual-Record（月事记）全面代码审查报告

> 审查日期：2026-09-08 ｜ 版本基线：1.33.1+104
> 范围：lib/ 全部 30 个 Dart 源文件（约 17,000 行）+ 静态分析 + 测试套件
> 性质：只读审查，未修改任何代码

## 机器验证结果

| 检查项 | 结果 |
|---|---|
| `flutter analyze` | 0 error / 0 warning / 2 info（均为已知存量：`database_helper.dart:153` 缺 @override、`home_screen.dart:637` use_build_context_synchronously） |
| `flutter test` | **75/75 全部通过**（日志中的 MissingPluginException 为测试环境未 mock 平台通道的预期输出，已被捕获） |

---

## 一、高严重（P0）— 功能正确性 / 资源泄漏

### H1. startPeriod 失败路径仍返回"创建成功"
- **位置**：`lib/providers/period_provider.dart:586-587、626-627`
- **问题**：`ok ? PeriodStartResult.created : PeriodStartResult.created` — 三元表达式两分支相同，DB 写入失败时 UI 仍按"新建成功"处理。另 `566-568`：`_hasOngoing` 为真时也直接返回 `created`，UI 无法区分"已有进行中的经期"。
- **修复**：失败返回失败枚举；已有进行中返回对应枚举（如 `alreadyOngoing`），调用方按结果分支提示。

### H2. AI SSE 流的 http.Client 泄漏
- **位置**：`lib/services/ai_health_service.dart` `_callApiStream`
- **问题**：流式请求无 try/finally。流中途抛异常或消费方取消订阅（用户退出问答页）时 `http.Client` 永不 close，socket 泄漏。多次进出问答页可累积。
- **修复**：`final client = http.Client(); try { ... } finally { client.close(); }`，或订阅 `onDone`/`onError` 时显式 close。

### H3. 预测基线不使用用户设置值（与设置页承诺矛盾）
- **位置**：`lib/services/prediction_service.dart`（`defaultCycleLength = 28`、`defaultPeriodLength = 5` 硬编码）
- **问题**：记录不足时 cold-start 一律按 28/5 预测，完全不读取用户在设置页填写的周期/经期天数；而设置页提示文字（`AppStrings.predictionHint`）明确承诺"记录不足时会使用以下默认值进行预测"。用户把默认周期改成 35 后冷启动预测仍是 28，功能性不一致。
- **修复**：`PredictionService` 各入口接收设置值参数（或在 Provider 层把 `SettingsProvider` 的当前值传入），替换硬编码常量。

### H4. 通知时区初始化竞态
- **位置**：`lib/services/notification_service.dart`（`initialize()` 在 main 中未 await）
- **问题**：`schedulePeriodReminder` 可能先于 `tz.setLocalLocation(...)` 完成，导致提醒被排到错误的绝对时刻（相差时区偏移量）。首启 + 快速进入记录页时最容易触发。
- **修复**：`main` 中 `await NotificationService.instance.initialize()`；或在调度入口用 Completer 保证初始化完成后再排程。

### H5. 未来日期可录入并破坏全部预测
- **位置**：`lib/screens/add_record_calendar_page.dart`（`saveMultipleRecords` 无日期校验）
- **问题**：补录日历允许选中并保存未来日期。未来记录会成为 `sortedRecords.last`，"最近一次经期起点"被指向未来 → 周期长度算出负数/异常值，下次经期预测、排卵日、安全期全线错乱。
- **修复**：日历禁选今天之后的日期（cell 置灰禁用）+ 保存前二次校验。

---

## 二、中严重（P1）— 局部功能异常 / 可靠性

### M1. JSON 修复正则误伤字符串内容
- **位置**：`ai_health_service.dart` `_repairJsonString`
- **问题**：`//[^\n\r]*` 与 `#[^\n\r]*` 两条正则会把 JSON 字符串值中的 `https://...`、含 `#` 的合法内容当作注释截断，反而把原本合法的 JSON 改坏。
- **修复**：改为逐字符扫描（记录是否在字符串字面量内、是否转义）后再剥离注释；或只在冒号/花括号结构位置处理。

### M2. 健康报告 generatedAt 失真
- **位置**：`ai_health_service.dart:245`（`HealthReport.fromJson`）
- **问题**：`generatedAt: DateTime.now()` 丢弃了 JSON 中实际存储的生成时间。重启后从缓存加载的报告显示"刚刚生成"，误导用户。
- **修复**：优先解析 `generatedAt` 字段，解析失败再回退 `DateTime.now()`。

### M3. 编辑备注 TextEditingController 每次重建新建
- **位置**：`lib/screens/record_screen.dart:1248-1249`
- **问题**：`StatefulBuilder` 的 builder 内 `TextEditingController(text: editNotes)` 每次重建都创建新控制器 → 用户每输入一个字符光标跳回末尾，旧控制器泄漏。
- **修复**：进入编辑时创建一次（如 showDialog 前或 initState 级别的局部变量），关闭时 dispose。

### M4. _refreshForNewDay 分支漏调提醒调度
- **位置**：`period_provider.dart:1023-1055`
- **问题**：else 分支（无需完整刷新时）未调用 `_scheduleReminderIfNeeded()`，跨午夜轻量刷新后提醒排程可能与最新数据不一致。
- **修复**：两个分支统一调用；或确认轻量路径不影响提醒数据后补充注释说明。

### M5. setAlgorithm 不同步小组件
- **位置**：`period_provider.dart:502-507`
- **问题**：切换预测算法后未调用 `_updateWidget()`，桌面小组件继续显示旧算法的预测结果，直到下一次数据变更才纠正。
- **修复**：`setAlgorithm` 尾部追加 `_updateWidget()`（与其他变更路径保持一致）。

### M6. clearCachedReport 未 await 且无异常保护
- **位置**：`period_provider.dart:176-184`
- **问题**：`_settingsDao.setValue(...)` 为 fire-and-forget，DB 异常会变成未捕获的异步错误。
- **修复**：`unawaited(...)` + try/catch，或完整 await。

### M7. jsonDecode 的 TypeError 绕过 AI 重试逻辑
- **位置**：`ai_health_service.dart:1162`
- **问题**：`jsonDecode(...) as Map<String, dynamic>` 解析结构不符时抛 TypeError（Error 非 Exception），`generateReport` 的 `on Exception` catch 接不住，整个生成流程直接失败而不走重试。
- **修复**：改为 `as Object?` 后显式判断类型抛 Exception，或 catch 范围放宽。

### M8. refreshConnection 与在飞 DAO 操作的竞态
- **位置**：`lib/database/database_helper.dart`
- **问题**：小组件同步触发 `refreshConnection`（关旧连接→开新连接）窗口期间，正在执行的 DAO 查询可能抛 `database_closed`；`completeError` 在无监听者时可能产生未处理异步异常。
- **修复**：重连前在调用侧串行化（互斥锁/队列）；`completeError` 前检查是否已有监听者。

---

## 三、低严重 / 优化建议（P2）

| # | 位置 | 问题 / 建议 |
|---|---|---|
| L1 | `settings_provider.dart` | 两个防抖 Timer（`_cycleLengthDebounce`/`_periodLengthDebounce`）未在 `dispose` 中 cancel，dispose 后回调仍可能触发 |
| L2 | `period_provider.dart` `loadRecords` | 无重入保护：小组件 dirty + 生命周期恢复可能并发触发两次加载，建议加 `_loading` 标志 |
| L3 | `period_provider.dart` `importData` | overwrite 模式跨两张表的 replaceAll 非原子，中途失败导致数据不一致；建议 `batch`/`transaction` 包裹 |
| L4 | `cycle_chart.dart`(848行) + `period_length_chart.dart`(794行) | 大量重复的坐标计算/绘制代码，可抽公共基类或工具函数（约 400 行可复用） |
| L5 | `stats_screen.dart` | `_displayCount` 在 build 中赋值（build 副作用）；仅 1 条记录时（totalCycles==0）统计页显示空态但首页已有数据，体验可商榷 |
| L6 | `ai_assistant_screen.dart` `_generateReport` | `if (mounted)` 包住了 `cacheReport`：用户生成中途退出页面时，已成功生成的报告被丢弃、API 调用白费。cacheReport 是 service 层操作，不应依赖 mounted |
| L7 | `ai_health_service.dart:429` | 注释说"最多最近6轮"实际取 12 条，注释与代码不符 |
| L8 | `lib/models/period_record.dart` | `fromJson`：endDate 为空字符串（非 null）时 `DateTime.parse('')` 抛异常；未校验 endDate >= startDate。导入外部数据时风险更高 |
| L9 | `AppStrings` | 多组重复常量：`predictionHint`/`predictionHintText`、`autoSelectHint`/`autoSelectHintText`、`selectedNDays`/`selectedNDaysText`、`nRecords`/`nRecordsCount`、`editPeriodTooShort`/`periodTooShort` 等，建议合并清理 |
| L10 | `settings_provider.dart` | 默认 `_algorithm = 'adaptive'` 与 DB 种子值 `'simple'` 不一致：全新首启（无 DB 种子路径）与有 DB 时默认算法不同 |
| L11 | `daily_flow.dart` | `fromJson` 无 flowLevel 范围校验（0-3 之外的原样入库） |
| L12 | `home_screen.dart` 日历 | PageView 翻页动画中途页面被销毁时，页面级 ValueNotifier 已 dispose 但手势回调仍可能触发 → 选中态偶发失效 |
| L13 | `home_screen.dart` | `endPeriod(DateTime.now())` 失败时无任何用户反馈（静默失败） |
| L14 | `year_heatmap.dart` | `didUpdateWidget` 用 List 身份（`!=`）比较决定是否重建索引；当前调用方每次传入新实例故无实害，但若上游复用同一实例会显示陈旧数据 |
| L15 | `period_provider.dart` | `checkAndRefreshForNewDay` 文档注释声称"在 setAlgorithm 中隐式调用"与实际不符；`_mergeWithLastPeriod(newStartDate)` 参数未使用 — 注释/签名清理 |
| L16 | `home_screen.dart:637`、`database_helper.dart:153` | analyze 已报的 2 条 info：补 `@override`；用 State 的 mounted 检查替代 context 判断 |

---

## 四、修复优先级建议

1. **P0 五项**建议在下一个 patch 版本集中处理：H1（误报成功）与 H3（预测默认值）直接影响核心功能的正确性；H2/H4 是概率性但后果明显（泄漏、通知时间错误）；H5 一旦触发会污染整个数据集的预测。
2. **P1 八项**可按模块拆分：AI 相关（M1/M2/M6/M7）一个 commit，Provider 相关（M4/M5/M6）一个 commit，UI 相关（M3）+ DB（M8）各一个。
3. **P2** 属于健康度清理，可在功能冻结期批量处理；L4（图表重复代码）改动面大，建议单独排期。

## 五、整体评价

代码架构清晰（Provider 平铺 + DAO 注入 + 手动序列化），主题 token 体系执行到位，测试覆盖核心 Provider 逻辑且全部通过。主要风险集中在三处：**startPeriod 结果枚举**（真 bug）、**AI 服务层**（资源泄漏 + JSON 处理健壮性）、**预测算法与设置值脱节**（承诺与实现不一致）。均为局部修复，不涉及架构调整。
