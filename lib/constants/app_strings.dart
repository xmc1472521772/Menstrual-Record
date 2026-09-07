class AppStrings {
  static const String appName = '月事记';

  /// 占位符，用于含参数的字符串模板。
  static const String nPlaceholder = '{}';
  static const String nPlaceholder2 = '{}';

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
  static const String editPeriodTooShort = '经期仅{}天，时长偏短，确认是否正确？';
  static const String editPeriodTooLong = '经期{}天，时长偏长，确认是否正确？';
  static const String editRangeConstraintPrev = '开始日期不能早于上一条记录的结束日期';
  static const String editRangeConstraintNext = '结束日期不能晚于下一条记录的开始日期';
  static const String duration = '持续';
  static const String nRecords = '共 {} 条';

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
  static const String predictionHint = '当有足够的历史记录时，系统会根据实际记录计算平均值；当记录不足时，会使用以下默认值进行预测。';
  static const String exportSuccessHint = '数据导出成功（明文 JSON，请妥善保管）';
  static const String exportFailed = '导出失败: {}';
  static const String importFailed = '导入失败: {}';
  static const String selectImportMode = '选择导入模式：';
  static const String saveFailedRetry = '保存失败，请重试';

  // ─── Splash screen ───────────────────────────────────────────────
  static const String splashSubtitle = '记录周期，关爱自己';

  // ─── AddRecordCalendarPage ───────────────────────────────────────
  static const String addPeriodRecordTitle = '添加经期记录';
  static const String autoSelectHint = '点击日期自动从该天起选中 {} 天，点相邻日期可逐天增减';
  static const String selectedNDays = '已选 {} 天：{}';
  static const String dateConflict = '所选日期与已有记录冲突';

  // ─── Misc ────────────────────────────────────────────────────────
  static const String nDaysUnit = '个';

  // ─── Period Merge ─────────────────────────────────────────────────
  static const String mergePromptTitle = '是否续接上一段经期？';
  static const String mergePromptBody = '您上一次经期刚结束{}天，本次是续接上一段经期，还是开启新的经期？';
  static const String mergeAction = '续接上一段';
  static const String newPeriodAction = '开启新经期';
  static const String mergeSilentDone = '已续接上一段经期';

  // ─── Misc UI strings ──────────────────────────────────────────────
  static const String ongoing = '进行中';
  static const String nRecordsCount = '共 $nPlaceholder 条';
  static const String periodTooShort = '经期仅$nPlaceholder天，时长偏短，确认是否正确？';
  static const String periodTooLong = '经期$nPlaceholder天，时长偏长，确认是否正确？';
  static const String confirmWarning = '确认异常';
  static const String deleteRecordLabel = '删除记录';
  static const String retry = '重试';
  static const String avgN = '平均 $nPlaceholder 天';
  static const String predictionHintText = '当有足够的历史记录时，系统会根据实际记录计算平均值；当记录不足时，会使用以下默认值进行预测。';
  static const String loadFailed = '加载数据失败';
  static const String autoSelectHintText = '点击日期自动从该天起选中 $nPlaceholder 天，点相邻日期可逐天增减';
  static const String selectedNDaysText = '已选 $nPlaceholder 天：$nPlaceholder2';
}
