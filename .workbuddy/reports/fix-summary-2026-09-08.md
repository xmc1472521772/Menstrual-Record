# 月事记 全面代码审查修复 — 交付总结

**版本**：1.33.1+104 → **1.33.2+105**
**验证**：`flutter analyze` **0 issue**（连修复前 2 条存量 info 一并清零）；`flutter test` **75/75 通过**
**提交**：8 个本地 commit（未推 remote）

---

## 一、修复清单（29/29）

### 高危（5）
| # | 问题 | 修复 |
|---|------|------|
| H1 | `startPeriodWithMerge` 布尔返回无法区分"已有进行中"与"失败" | 新增 `PeriodStartResult` 枚举（`alreadyOngoing`/`failed`），UI 分别静默/提示 |
| H2 | AI 流式请求异常路径不关 `http.Client` | `_callApiStream` 整体 try/finally，错误体读取提前到关闭前 |
| H3 | 预测算法冷启动硬编码 28 天，用户设置值不贯通 | `calculateCycleData` 增加 `userCycleLength/userPeriodLength`，`PeriodProvider` 从设置加载传入 |
| H4 | 通知调度可在 `initialize()` 完成前调用 → 静默丢调度 | Completer 就绪信号 `_ensureReady()`，调度前等待初始化完成 |
| H5 | 补录可选未来日期，破坏周期预测 | **保存前二次确认**（见下方"方案偏离"说明） |

### 中危（8）
- **M1** AI 响应 JSON 解析前剥离注释（`//` `#` `/* */`，字符串内豁免）
- **M2** 报告 `generatedAt` 非法值回退当前时间
- **M3** 编辑弹窗备注 `TextEditingController` 一次性创建、dialog 关闭时 dispose
- **M4** 跨午夜刷新的 else 分支补 `_scheduleReminderIfNeeded()`
- **M5** `setAlgorithm` 后同步桌面小组件
- **M6** `clearCachedReport` 持久化删除（await + 容错）
- **M7** AI 响应体非对象时显式抛错
- **M8** `close/refreshConnection` 先置空连接再关闭，消除竞态窗口；初始化失败 completer 加 ignore 兜底

### 低危（16）
- **L1** SettingsProvider dispose 取消防抖 Timer
- **L2** `loadRecords` 重入保护（Completer 门闩，force 请求排队重跑）
- **L3** importData overwrite 改为**跨两表单事务**（DAO `replaceAll` 支持 `txn` 参数）
- **L4** 抽取 `trend_chart_shared.dart`（枚举/截断点/日期格式化/chips），消除两个趋势图重复
- **L5** 统计页分页越界改使用处 clamp，不在 build 中改状态
- **L6** 报告缓存移出 `mounted` 块
- **L7** 注释"6轮 vs 12条"表述修正
- **L8** `PeriodRecord.fromJson` 空/脏 endDate 归一化为 ongoing
- **L9** AppStrings 重复常量清理（实为无使用点死代码，整组删除 13 个常量 + 占位符）
- **L10** DB 种子默认算法 `simple` → `adaptive`
- **L11** `DailyFlow.fromJson` flowLevel 钳制 0-3
- **L12** 日历格子 notifier 清理窗口期短路手势回调（`_selectDay` 加 mounted 守卫）
- **L13** 结束经期失败 SnackBar 反馈
- **L14** 年度热力图 `didUpdateWidget` 无条件重建索引
- **L15** `mergeWithLastPeriod` 去未使用参数、修正不实文档注释
- **L16** `@override` 补注解 + State 的 mounted 守卫规范化（顺带消灭 `_handleStartPeriod` 的 context 参数遮蔽）

---

## 二、方案偏离说明（H5）

报告原建议"补录禁选未来日期"。实现时发现 `add_record_calendar_test.dart` **明确断言**点击未来日期（6/20）追加新区间是设计行为，且默认预选（今日自动延展）本身含未来天。禁选会破坏测试契约与既有功能。

**调整方案**：保留多段补录能力，保存含未来起点区间时弹出 AlertDialog 二次确认（说明"未来日期的记录会影响周期预测"），取消则不保存。防误触目标达成，功能与测试契约完整保留。

---

## 三、过程中的重要发现

overwrite 导入测试失败（期望 1 条实际 2 条）暴露 DI 缺口：`PeriodProvider` 开事务用 `_dbProvider.database`，测试只注入了 DAO，`_dbProvider` 默认落 `DatabaseHelper()` 单例（FFI 默认路径的另一个库）→ **事务写到了另一个库**。真实 App 两边同源无此问题。已修复三个测试文件的构造（补 `dbProvider: dbHelper`）。

---

## 四、提交记录（8 个，均未推送）

| Commit | 内容 |
|--------|------|
| `4ea975f` | fix(provider): 预测贯通/枚举/事务/重入保护 + 测试 dbProvider 注入 |
| `016a240` | fix(ai): 流式资源释放与 JSON 健壮性 |
| `bcf8b7a` | fix(notification): 初始化就绪信号 |
| `36eea69` | fix(calendar): 未来区间二次确认 |
| `97e9ed3` | fix(ui): controller 生命周期与日历/统计细节 |
| `239c670` | fix(data): 连接竞态防护与导入校验 |
| `8ddb8c8` | refactor(chart): 抽取趋势图共享代码 |
| `2f7b82b` | chore: 版本号 1.33.2+105 |

## 五、注意事项

- `.workbuddy/`（memory + 审查报告）未纳入提交
- 8 个 commit 均在本地，建议按 Git 铁律**择机推 origin 备份**
- 新增字符串：`startPeriodFailed`、`endPeriodFailed`、`futureRangeConfirmTitle/Body`
- 行为变化点：① 补录含未来起点时会弹确认框；② 结束经期失败有提示；③ 全新安装默认算法为 adaptive
