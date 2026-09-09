class AppStrings {
  static const String appName = '月事记';

  static const String home = '首页';
  static const String record = '记录';
  static const String stats = '统计';
  static const String settings = '设置';

  static const String startPeriod = '开始经期';
  static const String endPeriod = '结束经期';
  static const String periodOngoing = '经期进行中';
  static const String daysUntilPeriod = '距离下次经期还有';
  static const String currentDay = '当前周期第';
  static const String days = '天';
  static const String averageCycle = '平均周期';
  static const String averagePeriod = '平均经期天数';
  static const String predictedNextPeriod = '预测下次经期';
  static const String historyRecords = '历史记录';
  static const String noRecords = '暂无记录';

  static const String cycleLength = '周期天数';
  static const String periodDuration = '经期天数';
  static const String reminderDays = '提前提醒天数';
  static const String predictionAlgorithm = '预测算法';
  static const String simpleAverage = '简单平均法';
  static const String weightedAverage = '自适应混合算法';
  static const String exportData = '导出数据';
  static const String importData = '导入数据';
  static const String dataManagement = '数据管理';

  static const String save = '保存';
  static const String cancel = '取消';
  static const String delete = '删除';
  static const String confirm = '确认';
  static const String startDate = '开始日期';
  static const String endDate = '结束日期';
  static const String selectDate = '选择日期';

  static const String exportSuccess = '数据导出成功';
  static const String importSuccess = '数据导入成功';
  static const String importError = '数据导入失败';
  static const String deleteConfirm = '确定要删除这条记录吗？';
  static const String importMode = '导入模式';
  static const String appendImport = '追加导入';
  static const String overwriteImport = '覆盖导入';

  static const String notificationTitle = '经期提醒';
  static const String notificationTooltip = '打开提醒设置';
  static const String notificationBody = '预计即将到来，请做好准备';

  // ─── Home screen ─────────────────────────────────────────────────
  static const String recordToStartPredict = '记录经期以开始预测';
  static const String noData = '暂无数据';
  static const String predictedToday = '预计今天';
  static const String overdue = '已逾期';
  static const String startRecordingPrompt = '开始记录您的经期';
  static const String recordToViewStats = '记录后可查看周期预测与统计';
  static const String legendPeriod = '经期中';
  static const String legendPredicted = '预测';
  static const String legendOvulation = '排卵期';
  static const String legendFertile = '易孕期';
  static const String legendSafe = '安全期';
  static const String todayButton = '今';

  // ─── Record screen ───────────────────────────────────────────────
  static const String noOngoingPeriod = '暂无进行中的经期';
  static const String addPeriodRecord = '添加经期记录';
  static const String saveRecord = '保存记录';
  static const String recordSaved = '记录已保存';
  static const String saveFailed = '保存失败，请检查日期是否冲突';
  static const String selectEndDate = '请选择结束日期';
  static const String savedNRecords = '已保存 {} 条记录';
  static const String saveFailed2 = '保存失败';
  static const String multiSelectCalendar = '多选日历';
  static const String ongoingTag = '进行中';
  static const String deleteRecord = '删除记录';
  static const String editRecord = '编辑记录';
  static const String editRecordTitle = '编辑经期记录';
  static const String editRecordHint = '修改经期的起止日期';
  static const String recordUpdated = '记录已更新';
  static const String updateFailed = '更新失败，请检查日期是否冲突';
  static const String endDateCannotBeBeforeStart = '结束日期不能早于开始日期';
  static const String clearEndDate = '清除结束日期';
  static const String clearEndDateHint = '设为进行中的经期';
  static const String editConflictPrevOverlap = '修改后的开始日期与上一条记录重叠，请调整';
  static const String editConflictNextOverlap = '修改后的结束日期与下一条记录重叠，请调整';
  static const String editConflictStartAfterEnd = '开始日期不能晚于结束日期';
  static const String editRangeConstraintPrev = '开始日期不能早于上一条记录的结束日期';
  static const String editRangeConstraintNext = '结束日期不能晚于下一条记录的开始日期';
  static const String dateCannotBeFuture = '不能选择今天之后的日期';
  static const String dateRangeOverlap = '所选日期与已有记录重叠，请调整';
  static const String duration = '持续';

  // ─── Stats screen ────────────────────────────────────────────────
  static const String noStatsData = '暂无统计数据';
  static const String recordToViewStatsData = '记录经期后即可查看统计';
  static const String cycleOverview = '周期概览';
  static const String avgCycleLabel = '平均周期';
  static const String avgPeriodLabel = '平均经期';
  static const String recordCycles = '记录周期';
  static const String cycleTrend = '周期趋势';
  static const String noCycleDataInRange = '当前时间范围内暂无周期数据';
  static const String shortest = '最短';
  static const String longest = '最长';
  static const String averageLabel = '平均';
  static const String basedOnAllHistory = '基于所有历史数据的平均值';
  static const String weightedMoreAccurate = '根据数据特征自动切换算法，更精准';
  static const String weightedDescription = '自适应混合算法：自动检测周期规律性，规律用户用 WMA-6 加权移动平均，不规律或突变用户用 WMA-3 + 剪切均值，冷启动用医学基线 28 天。';
  static const String needMoreDataToPredict = '需要更多数据来预测';
  static const String viewMore = '查看更多';
  static const String collapse = '收起';
  static const String recordsCount = '共 {} 条记录';
  static const String daysLeft = '还有 {} 天';
  static const String today_ = '今天';
  static const String daysPassed = '已过 {} 天';

  // ─── Stats Tab Labels ───────────────────────────────────────────
  static const String statsTabOverview = '概览';
  static const String statsTabTrend = '趋势';
  static const String statsTabHistory = '历史';

  // ─── Home Flow Quick Pick ───────────────────────────────────────
  static const String todayFlow = '今日经量';
  static const String flowLabelNone = '无';
  static const String flowLabelLight = '少';
  static const String flowLabelNormal = '中';
  static const String flowLabelHeavy = '多';

  // ─── Settings screen ─────────────────────────────────────────────
  static const String cycleParams = '周期参数';
  static const String reminderSettings = '提醒设置';
  static const String reminderTime = '提醒时间';
  static const String reminderPeriodDaily = '经期记录提醒';
  static const String reminderPeriodDailyDesc = '经期中每天定时提醒记录当日状态';
  static const String reminderOvulation = '排卵期提示';
  static const String reminderOvulationDesc = '排卵日当天提醒，关注身体变化';
  static const String exportSuccessHint = '数据导出成功（明文 JSON，请妥善保管）';
  static const String exportFailed = '导出失败: {}';
  static const String importFailed = '导入失败: {}';
  static const String selectImportMode = '选择导入模式：';
  static const String saveFailedRetry = '保存失败，请重试';

  // ─── Splash screen ───────────────────────────────────────────────
  static const String splashSubtitle = '记录周期，关爱自己';

  // ─── AddRecordCalendarPage ───────────────────────────────────────
  static const String addPeriodRecordTitle = '添加经期记录';
  static const String dateConflict = '所选日期与已有记录冲突';
  static const String futureRangeConfirmTitle = '包含未来日期';
  static const String futureRangeConfirmBody = '所选区间包含今天之后的日期，确定要保存吗？未来日期的记录会影响周期预测。';

  // ─── Misc ────────────────────────────────────────────────────────
  static const String nDaysUnit = '个';

  // ─── Period Merge ─────────────────────────────────────────────────
  static const String mergePromptTitle = '是否续接上一段经期？';
  static const String mergePromptBody = '您上一次经期刚结束{}天，本次是续接上一段经期，还是开启新的经期？';
  static const String mergeAction = '续接上一段';
  static const String newPeriodAction = '开启新经期';
  static const String mergeSilentDone = '已续接上一段经期';
  static const String startPeriodFailed = '开始经期失败，请重试';
  static const String endPeriodFailed = '结束经期失败，请重试';

  // ─── Misc UI strings ──────────────────────────────────────────────
  static const String ongoing = '进行中';
  static const String confirmWarning = '确认异常';
  static const String deleteRecordLabel = '删除记录';
  static const String retry = '重试';
  static const String loadFailed = '加载数据失败';

  // ─── AI Assistant ──────────────────────────────────────────────
  static const String aiAssistant = 'AI助手';
  static const String aiHealthReport = '健康报告';
  static const String aiGenerateReport = '生成报告';
  static const String aiRegenerateReport = '重新分析';
  static const String aiNoDataTitle = '暂无数据可分析';
  static const String aiNoDataSubtitle = '请先记录至少一次经期数据，AI助手将为您生成个性化健康分析报告';
  static const String aiAnalyzing1 = '正在整理经期数据…';
  static const String aiAnalyzing2 = '正在分析周期规律…';
  static const String aiAnalyzing3 = '正在生成健康建议…';
  // 报告 7 部分标题
  static const String aiSectionCurrentOverview = '本周期概览';
  static const String aiSectionCycleTrend = '周期趋势';
  static const String aiSectionSymptomTrend = '症状趋势';
  static const String aiSectionComparison = '与过去相比';
  static const String aiSectionAttentions = '值得关注的地方';
  static const String aiSectionNextCycleSuggestions = '下一周期建议';
  static const String aiSectionMedicalReminders = '就医提醒';
  static const String aiSectionConclusion = '总结';
  static const String aiHealthScore = '健康评分';
  static const String aiReportTime = '报告生成时间';
  static const String aiEvidence = '依据';
  static const String aiDisclaimer = '本报告由智谱GLM-4大模型基于您记录的本地数据生成，仅供参考，不构成医疗诊断。AI分析结果可能存在不准确之处，如有健康疑虑，请及时就医咨询专业医生。';
  static const String aiDataUpdatedHint = '经期数据已更新，建议重新生成报告';
  static const String aiApiKeyNotConfigured = 'API Key 未配置，请联系开发者';
  static const String aiYouMatched = '您当前已符合此情况';
  static const String aiModelChangedHint = '已切换模型，建议重新生成报告';
  static const String aiScoreTrend = '健康评分趋势';

  // ─── AI Chat ───────────────────────────────────────────────────
  static const String aiChatTitle = '经期问答';
  static const String aiChatHint = '输入您的经期相关问题…';
  static const String aiChatSend = '发送';
  static const String aiChatThinking = '正在思考…';
  static const String aiChatError = '回答失败，请重试';
  /// 流式回答异常时的消息前缀（后接具体错误信息）。
  static const String aiChatFailedPrefix = '回答失败：';
  static const String aiChatDisclaimer = 'AI回答仅供参考，不构成医疗诊断。如有健康疑虑请就医。';
  static const String aiChatQuickQ1 = '我的周期规律吗？';
  static const String aiChatQuickQ2 = '经量正常吗？';
  static const String aiChatQuickQ3 = '如何调理经期？';
  static const String aiChatTabReport = '健康报告';
  static const String aiChatTabQA = '经期问答';
  // 聊天会话管理（1.36.0）
  static const String aiChatNewChat = '新建聊天';
  static const String aiChatHistory = '历史聊天';
  static const String aiChatClearMessages = '清空消息';
  static const String aiChatHistoryTitle = '历史聊天记录';
  static const String aiChatHistoryEmpty = '暂无历史聊天记录';
  static const String aiChatCurrentTag = '当前';
  static const String aiChatClearConfirmTitle = '清空当前对话？';
  static const String aiChatClearConfirmContent =
      '将清除当前对话的全部消息，此操作无法恢复。其他历史聊天不会受影响。';
  static const String aiChatClearConfirmAction = '清空';
  static const String aiChatCancel = '取消';
  static String aiChatMessageCount(int count) => '$count 条消息';

  // ─── AI Model Switch ─────────────────────────────────────────────
  static const String aiModelSwitch = 'AI模型';
  static const String aiReportModel = '报告模型';
  static const String aiChatModel = '问答模型';

  // ─── P2-2 收敛：散落硬编码文案 ───────────────────────────────────
  // 记录编辑弹窗字段标签
  static const String mood = '心情';
  static const String symptoms = '症状';
  static const String notes = '备注';
  static const String notesHint = '记录其他感受...';
  // 日详情弹窗
  static const String flowAmount = '经量';
  static const String daysToNextPeriod = '距下次经期还有 {} 天';
  static const String predictedStartsToday = '今天预测经期开始';
  static const String periodRecordLabel = '经期记录：';
  // AI 报告
  static const String analysisFailed = '分析失败';
  static const String scoreHealthy = '健康';
  static const String scoreGood = '良好';
  static const String scoreNeedsAttention = '需关注';
  static const String scoreNeedsDoctor = '需就医';
  static const String aiChatEmptySubtitle = '基于您的经期数据进行智能问答';
  // 预测模式标签（统计页预测卡片）
  static const String predictionModeBaseline = '医学基线';
  static const String predictionModeWmaRegular = 'WMA-6 加权移动平均';
  static const String predictionModeWmaVolatile = 'WMA-3 + 剪切均值';
  static const String predictionModeSimple = '简单平均';

  // ─── 二次确认与数据管理补充文案（E2 收敛）────────────────────────
  /// 异常经期长度提示的二次确认后缀（与 [periodLengthWarning] 组合使用）。
  static const String lengthWarningConfirm = '确认无误请再次点击保存';
  static const String restoreBackup = '恢复自动备份';
  static const String noBackupYet = '暂无自动备份';
  static const String selectBackup = '选择备份';
  static const String latestBadge = '最新';
  static const String backupRestored = '备份已恢复';
  static const String restoreFailed = '恢复失败';

  // ─── 统计页 AI 入口卡（E2 收敛）─────────────────────────────────
  static const String aiAssistantCardTitle = 'AI健康助手';
  static const String aiAssistantCardSubtitle = '基于您的周期数据生成健康分析报告';
  static const String aiAssistantCardNeedsData = '记录数据后即可使用';

  // ─── 统计页预测卡补充（E2 收敛）─────────────────────────────────
  static const String predictionWindowPrefix = '预测窗口：';
  static const String to = '至';
  static const String cycleLengthN = '周期 {} 天';

  // ─── C2 口径统一：统计页历史计的是「周期」而非「记录」────────────
  static const String cyclesCount = '共 {} 个周期';

  // ─── 首页状态卡（C1 紧凑开关）────────────────────────────────────
  static const String heroStatsToggle = '切换均值显示';
  static const String heroStatsExpand = '展开均值显示';
  // P2-4：日历隐藏手势（长按记录经量）可发现性提示。
  static const String calendarLongPressHint = '长按日期可记录当日经量';
}
