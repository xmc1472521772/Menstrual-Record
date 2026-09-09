# Menstrual-Record 项目长期记忆

## 基本信息
- 当前版本：**1.37.0+116**（2026-09-09，报告全量问题修复：深色对比度 P0 + 布局分析报告 17 项落地，analyze 0 issue + 175/175 测试通过）
- 架构、命令、主题系统等见 AGENTS.md；版本规范：每次更新必须递增版本号
- **1.37.0 结构变化**：①导航壳迁至 `screens/main_screen.dart`（app.dart 只剩根装配），MainScreen.globalKey 已删，HomeScreen 走注入回调 onOpenSettings；②通知三路同步迁至 `services/notification_sync_coordinator.dart`（去重状态+串行链随迁，PeriodProvider.syncNotifications 变委托，注入 settingsDao 透传）；③小组件推送细节下沉 `WidgetService.pushCycleSnapshot`；④AI 流式回放节奏（80ms 节流 flush/begin/onChunk/finish/abort）下沉 `AiAssistantProvider`，AI 屏 UI 拆至 `widgets/ai/`（chat_bubble/report_view/model_selector/session_sheet）；⑤双日历共享核心 `widgets/calendar/calendar_core.dart`（leadingBlankDays/daysInMonth/monthRowCount/buildMonthCells/CalendarWeekdayHeader）——首页固定 42 格用 buildMonthCells，多选页行数用 monthRowCount；⑥深色模式铁律入 AGENTS.md：AppColors.ink*/canvas/tile/hairline 是浅色固定值，禁用于主题表面（AppBar/themeColors 面板），一律 themeColors.onSurface*；固定浅色面（brandSurface/brandSoft）可保留
- **1.37.0 新增 token/设置**：AppDimens.navBarHeight=64/navBarClearance=100/appBarHeight=68/fabLift=80；AppColors.aiCardStart/End（紫渐变收编）；AppBreakpoints(600/840) 仅预留未启用；SettingsProvider 新 key `home_hero_compact`（首页状态卡紧凑开关，heroCompact/setHeroCompact，点均值区折叠双均值条）；AppStrings 新增 cyclesCount/lengthWarningConfirm/restoreBackup 系列/aiAssistantCard 系列/aiChatFailedPrefix/heroStats* 等
- **1.34.0 通知架构**：三通知 ID 固定（0=经期预告单次、1=period_daily_log 经期每日重复 matchDateTimeComponents=time、2=ovulation_reminder 排卵日单次=预测经期前14天）；**禁止 cancelAll 误删其他通道**，一律按 ID 精确取消；PeriodProvider 公开 `syncNotifications()`（三个子同步独立去重 + _syncChain 串行化防并发），设置页改开关/提前天数/提醒时间后必须调用
- **1.34.0 设置新 key**：reminder_period_daily / reminder_ovulation（'1'/'0'，默认开）；AI 报告历史 key：ai_report_history_json（ReportHistoryEntry 列表，上限 30 条丢最旧，cacheReport 内追加，clearCachedReport 不清历史）
- **单测调通知插件三件套**（period_provider_test notification sync group 已固化）：①tz.initializeTimeZones()+setLocalLocation(tz.UTC)（否则 tz.local 抛 LateInitializationError）；②FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin()（测试环境不跑 GeneratedPluginRegistrant）；③mock 'initialize' 必须返回 true（声明 Future<bool>）

## 关键约定（新增/更新）
- **流式平滑回放（1.36.1）**：`_callApiStream` 的 content delta 统一走 `revealContentChunk()`——≤120 字透传，>120 字打字机回放（12 字/60ms ≈ 200 字/秒，超长块提速单块 ≤5.4s）。成因：OpenRouter 免费通道按请求路由上游，部分上游把整段攒进单个超大 delta；实测正常上游 ~2 字/秒滴流也属正常。公式勿改回 6000（测试 6s 上限会撞）
- **1.36.0 聊天会话架构**：聊天存储 = `ai_chat_sessions_json`（ChatSession 列表，上限 20 会话 × 50 消息）；旧 `ai_chat_json` 扁平数据 ensureLoaded 时自动迁移成单会话并清空旧 key。API：startNewChat（保留旧会话回空态）/ clearActiveSession（只删当前，先清 messages 防流式回写）/ openSession（可续聊）/ appendMessage（无会话自动建，标题=首条用户消息截 20 字）/ updateMessage（流式 flush，越界静默）。**流式输出绑定发起时的 ChatSession 对象引用 + _streamingSessionId**，中途切会话不串写。排序：updatedAt 降序 + createdAt 兜底，且 updatedAt 取 msg.timestamp（取 DateTime.now() 会在同毫秒连发时排序不确定）
- **跨机型字体铁律**（1.35.0+111）：全局字体为内置 MiSans GB2312 子集（assets/fonts/，4 字重共 6.6MB，子集外生僻字回退系统字体属预期）；`AppTheme.fontFamily = 'MiSans'`，**新增 CustomPainter/TextPainter 绘制文字必须显式加 `fontFamily: AppTheme.fontFamily`**（TextPainter 不继承 ThemeData）；系统字体缩放已由 app.dart builder 全局钳制 1.0~1.3，页面内不要再做局部钳制
- **AI Key 注入铁律**：AI 助手的 API Key 走编译期注入（`ai_health_service.dart` 的 `String.fromEnvironment`），**release 构建必须带** `--dart-define=GLM_API_KEY=<key> --dart-define=OPENROUTER_API_KEY=<key>`，否则 app 内提示"API Key 未配置"。Key 值不落代码/git/memory，仅进构建命令行。模型映射：GLM→智谱 glm-4-flash；OpenRouter→ling-3.0-flash-sante:free
- **AI 模型输出预算约定**：max_tokens 按模型配置（`AiModelConfig.maxOutputTokens`：Ling 16384 / GLM-4-Flash 4096 上限内）；Ling-3.0 是混合推理模型，请求带 `reasoning:{enabled:false,exclude:true}`，解析前剥离 `<think>` 标签，content 空时回退 `message.reasoning`。AI 错误用 `AiServiceException(retryable)` 分类，generateReport 自动重试瞬态错误（限流/5xx/网络/空内容/格式异常）
- **Dart replaceAll 陷阱**：`String.replaceAll(RegExp, r'$1')` 的 `$1` 是**字面文本**不是捕获组引用（会吞掉匹配并插入 "$1"）——必须用 `replaceAllMapped((m) => m.group(1)!)`。曾导致 JSON 尾逗号修复从未生效且改坏 JSON
- **dbProvider 注入铁律**：PeriodProvider 持有 `_dbProvider` 开事务（importData overwrite 跨表原子替换）；测试注入 DAO 时**必须同步注入 `dbProvider: dbHelper`**，否则事务默认落 DatabaseHelper() 单例（FFI 默认路径），与内存库脱钩——已固化到三个测试文件
- **Provider 获取规则**：`app.dart` 的 `_MyAppState` 在 `initState` 中直接创建 `PeriodProvider`/`SettingsProvider` 实例（late final 字段），以 `ChangeNotifierProvider<T>.value` 注入 `MultiProvider`；生命周期回调直接引用字段。**禁止**在该 State 的回调里用 `context.read`（context 在 MultiProvider 上方，必然抛 ProviderNotFoundException）
- **State 方法禁用 context 参数遮蔽**：State 的辅助方法（如 `_handleStartPeriod`）不接收 `BuildContext context` 参数——参数名遮蔽 State.context 后 `mounted` 守卫失效，触发 use_build_context_synchronously
- **小组件同步机制**（三代演进后的现状）：原生 `WidgetActionReceiver` 直接写 SQLite → `WidgetDataStore.setDataDirty(true)` → MethodChannel `dataChanged` 通知（前台即时）；App 恢复前台时 `checkDataDirty()` 兜底（后台时 MethodChannel 可能丢失）；`loadRecords(forceRefresh: true)` 会刷新数据库连接
- **Git 铁律**：① 绝不使用 `git stash`（2026-09-08 曾因 stash 被中断导致对象库损坏）；② **定期推 origin 备份**（本次靠用户昨晚的推送才救回 104 个提交，当天未推送的 11 个提交对象丢失）；③ 多组独立改动拆分本地 commit
- **Git 现状**：main = `8051eb4`（1.34.0+109，2026-09-08 晚，已推 origin 同步，ls-remote 确认）
- **1.33.5 架构变化**：AI 报告缓存/聊天历史已迁出 PeriodProvider → `AiAssistantProvider`（settings key：ai_report_json / ai_chat_json 上限 50 条）；自动备份 → `BackupService` 单例（30s trailing 去抖，commitMutation 只 schedule）；编辑弹窗在 `widgets/period_edit_dialog.dart`、AI 报告卡片在 `widgets/report_cards.dart`
- **1.33.5 依赖与构建链**：flutter_markdown_plus 1.0.12 / file_picker 12.2.0（pickFile，取消返回 null）/ share_plus 13.3.0（SharePlus.instance.share）/ flutter_local_notifications 22.3.0（全命名参数，uiLocalNotificationDateInterpretation 已删）/ timezone 0.11.1 / flutter_lints 6；**settings.gradle Kotlin 2.2.20 + AGP 8.9.1**（share_plus 13 metadata + androidx.core 1.18 硬性要求，回退旧版无法出包）
- **诊断教训**：判断远程状态必须用 `git ls-remote` 直查，不能依赖本地 refs/remotes（refs 损坏/陈旧时会误判）；事发时 origin/main 曾短暂显示为陈旧的 21b3aaf，导致误报"历史全丢"
- **测试沙箱绕过**：`env 'PROGRAMFILES(X86)=C:/Program Files (x86)'`（export 不接受括号名）+ 清代理 + PATH 前置 `C:/Users/xmc/.workbuddy/binaries/python/versions/3.13.12/DLLs`
- 测试 mock 类 `implements DatabaseProvider` 时必须实现全部成员（含 `refreshConnection`），新增接口成员要同步改 mock

## 存量问题（未修，非阻塞）
- ~~2 条 analyze info~~ 已随本次修复清零（L16 落地），当前 analyze 0 issue
