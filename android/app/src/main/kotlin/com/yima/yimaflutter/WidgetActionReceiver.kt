package com.yima.yimaflutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

/// 小组件操作接收器。
///
/// 接收来自桌面小组件的广播操作（开始经期/结束经期/记录经量），
/// 直接操作 SQLite 数据库，逻辑与 PeriodProvider 完全对齐。
///
/// 操作完成后：
/// 1. 更新 SharedPreferences 中的小组件数据
/// 2. 刷新所有小组件 UI
/// 3. 发送广播通知 App 刷新数据
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetActionReceiver"

        const val ACTION_START_PERIOD = "com.yima.yimaflutter.WIDGET_START_PERIOD"
        const val ACTION_END_PERIOD = "com.yima.yimaflutter.WIDGET_END_PERIOD"
        const val ACTION_SET_FLOW = "com.yima.yimaflutter.WIDGET_SET_FLOW"
        const val EXTRA_FLOW_LEVEL = "flow_level"

        const val ACTION_DATA_CHANGED = "com.yima.yimaflutter.WIDGET_DATA_CHANGED"
        private const val APP_PACKAGE = "com.yima.yimaflutter"

        private val DATE_FMT = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "Received action: $action")

        val today = DATE_FMT.format(Calendar.getInstance().time)
        val db = openDatabase(context)

        if (db == null) {
            Log.e(TAG, "Cannot open database")
            return
        }

        try {
            when (action) {
                ACTION_START_PERIOD -> handleStartPeriod(context, db, today)
                ACTION_END_PERIOD -> handleEndPeriod(context, db, today)
                ACTION_SET_FLOW -> {
                    val flowLevel = intent.getIntExtra(EXTRA_FLOW_LEVEL, 0)
                    if (flowLevel > 0) {
                        handleSetFlow(context, db, today, flowLevel)
                    }
                }
            }

            // 操作完成后更新小组件数据
            updateWidgetDataFromDb(context, db)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling action: $action", e)
        } finally {
            db.close()
        }

        // 刷新小组件 UI
        PeriodWidgetProvider.updateAllWidgets(context)

        // 通知 App 数据已变更
        val notifyIntent = Intent(ACTION_DATA_CHANGED).apply {
            setPackage(APP_PACKAGE)
        }
        context.sendBroadcast(notifyIntent)
    }

    // ─── 开始经期（与 PeriodProvider.startPeriodWithMerge 对齐）──────────

    /// 开始经期逻辑：
    /// 1. 已有进行中 → 不操作
    /// 2. 无历史记录 → 直接新建
    /// 3. 距上次结束 0 天（同天）→ 合并（撤销结束状态）
    /// 4. 距上次结束 ≤ 阈值天 → 合并（小组件无法弹窗，按续接处理）
    /// 5. 距上次结束 > 阈值天 → 直接新建
    private fun handleStartPeriod(context: Context, db: SQLiteDatabase, today: String) {
        // 1. 检查是否已有进行中的经期
        val ongoingCursor = db.rawQuery(
            "SELECT id FROM period_records WHERE end_date IS NULL",
            null
        )
        if (ongoingCursor.moveToFirst()) {
            Log.d(TAG, "Already has ongoing period, skipping start")
            ongoingCursor.close()
            return
        }
        ongoingCursor.close()

        // 2. 查找最近一条已结束的经期
        val lastEndedCursor = db.rawQuery(
            "SELECT id, start_date, end_date FROM period_records WHERE end_date IS NOT NULL ORDER BY start_date DESC LIMIT 1",
            null
        )

        if (!lastEndedCursor.moveToFirst()) {
            // 无历史记录 → 直接新建
            lastEndedCursor.close()
            insertNewPeriod(db, today)
            Log.d(TAG, "No history, created new period: $today")
            return
        }

        val lastId = lastEndedCursor.getLong(0)
        val lastStartDate = lastEndedCursor.getString(1)
        val lastEndDate = lastEndedCursor.getString(2)
        lastEndedCursor.close()

        // 3. 计算间隔天数
        val gapDays = daysBetween(lastEndDate, today)
        Log.d(TAG, "Gap days from last end: $gapDays")

        // 4. 读取合并阈值
        val mergeThreshold = getSettingInt(db, "merge_threshold", 2)

        // 5. 决定操作
        if (gapDays <= mergeThreshold) {
            // 间隔 ≤ 阈值 → 合并（撤销结束状态）
            // 清空 end_date 和 period_length，恢复 ongoing
            db.execSQL(
                "UPDATE period_records SET end_date = NULL, period_length = NULL WHERE id = ?",
                arrayOf(lastId)
            )
            Log.d(TAG, "Merged with last period (id=$lastId), gap=$gapDays days")
        } else {
            // 间隔 > 阈值 → 直接新建
            insertNewPeriod(db, today)
            Log.d(TAG, "Created new period: $today (gap=$gapDays > threshold=$mergeThreshold)")
        }
    }

    // ─── 结束经期（与 PeriodProvider.endPeriod 对齐）──────────

    /// 结束经期逻辑：
    /// 1. 查找进行中的经期
    /// 2. 设置 end_date = today, period_length = (today - start).days + 1
    private fun handleEndPeriod(context: Context, db: SQLiteDatabase, today: String) {
        val ongoingCursor = db.rawQuery(
            "SELECT id, start_date FROM period_records WHERE end_date IS NULL ORDER BY start_date DESC LIMIT 1",
            null
        )

        if (!ongoingCursor.moveToFirst()) {
            ongoingCursor.close()
            Log.d(TAG, "No ongoing period to end")
            return
        }

        val id = ongoingCursor.getLong(0)
        val startDate = ongoingCursor.getString(1)
        ongoingCursor.close()

        // 计算经期天数：(today - start).days + 1, clamp(1, 999)
        val periodLength = daysBetween(startDate, today) + 1
        val clampedLength = periodLength.coerceIn(1, 999)

        db.execSQL(
            "UPDATE period_records SET end_date = ?, period_length = ? WHERE id = ?",
            arrayOf(today, clampedLength, id)
        )
        Log.d(TAG, "Ended period: id=$id, end=$today, length=$clampedLength")
    }

    // ─── 记录经量（与 PeriodProvider.setDailyFlow 对齐）──────────

    /// 记录经量逻辑：
    /// 1. 检查是否有进行中的经期（只有经期中才能记录经量）
    /// 2. upsert daily_flows 表
    private fun handleSetFlow(context: Context, db: SQLiteDatabase, today: String, flowLevel: Int) {
        // 检查是否有进行中的经期
        val ongoingCursor = db.rawQuery(
            "SELECT id FROM period_records WHERE end_date IS NULL",
            null
        )
        if (!ongoingCursor.moveToFirst()) {
            ongoingCursor.close()
            Log.d(TAG, "No ongoing period, cannot set flow")
            return
        }
        ongoingCursor.close()

        // upsert daily_flows
        db.execSQL(
            """INSERT OR REPLACE INTO daily_flows (date, flow_level) VALUES (?, ?)""",
            arrayOf(today, flowLevel)
        )
        Log.d(TAG, "Set flow: $today = $flowLevel")
    }

    // ─── 工具方法 ──────────────────────────────────────────────

    /// 插入新的经期记录
    private fun insertNewPeriod(db: SQLiteDatabase, today: String) {
        val now = System.currentTimeMillis()
        db.execSQL(
            "INSERT INTO period_records (start_date, end_date, created_at) VALUES (?, NULL, ?)",
            arrayOf(today, now)
        )
    }

    /// 计算两个日期字符串之间的天数差 (end - start)
    private fun daysBetween(startDateStr: String, endDateStr: String): Long {
        return try {
            val start = DATE_FMT.parse(startDateStr)
            val end = DATE_FMT.parse(endDateStr)
            TimeUnit.MILLISECONDS.toDays(end.time - start.time)
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating days between $startDateStr and $endDateStr", e)
            0L
        }
    }

    /// 读取设置表中的整数值
    private fun getSettingInt(db: SQLiteDatabase, key: String, defaultVal: Int): Int {
        val cursor = db.rawQuery(
            "SELECT value FROM settings WHERE key = ?",
            arrayOf(key)
        )
        return if (cursor.moveToFirst()) {
            val value = cursor.getInt(0)
            cursor.close()
            value
        } else {
            cursor.close()
            defaultVal
        }
    }

    /// 从数据库读取当前状态，更新小组件数据到 SharedPreferences
    /// （与 WidgetService._buildWidgetJson 逻辑对齐）
    private fun updateWidgetDataFromDb(context: Context, db: SQLiteDatabase) {
        try {
            // 查找进行中的经期
            val ongoingCursor = db.rawQuery(
                "SELECT start_date FROM period_records WHERE end_date IS NULL ORDER BY start_date DESC LIMIT 1",
                null
            )

            var hasOngoing = false
            var periodDay = 0
            var lastStart = ""

            if (ongoingCursor.moveToFirst()) {
                hasOngoing = true
                lastStart = ongoingCursor.getString(0)
                periodDay = (daysBetween(lastStart,
                    DATE_FMT.format(Calendar.getInstance().time)) + 1).toInt().coerceAtLeast(1)
            }
            ongoingCursor.close()

            // 查找最近已结束的经期
            var lastEnd = ""
            if (!hasOngoing) {
                val endedCursor = db.rawQuery(
                    "SELECT start_date, end_date FROM period_records WHERE end_date IS NOT NULL ORDER BY start_date DESC LIMIT 1",
                    null
                )
                if (endedCursor.moveToFirst()) {
                    lastStart = endedCursor.getString(0)
                    lastEnd = endedCursor.getString(1)
                }
                endedCursor.close()
            }

            // 读取设置
            var avgCycle = getSettingInt(db, "avg_cycle_length", 28)
            var avgPeriod = getSettingInt(db, "avg_period_length", 5)

            // 计算总周期数（有 end_date 的记录数）
            val countCursor = db.rawQuery(
                "SELECT COUNT(*) FROM period_records WHERE end_date IS NOT NULL",
                null
            )
            var cycleCount = 0
            if (countCursor.moveToFirst()) {
                cycleCount = countCursor.getInt(0)
            }
            countCursor.close()

            // 计算距下次经期天数
            var daysUntil = -1
            var predictedDate = ""
            if (!hasOngoing && lastStart.isNotEmpty()) {
                val predicted = predictNextPeriod(db, lastStart, avgCycle)
                if (predicted != null) {
                    val todayStr = DATE_FMT.format(Calendar.getInstance().time)
                    val predictedStr = DATE_FMT.format(predicted)
                    daysUntil = daysBetween(todayStr, predictedStr).toInt()
                    if (daysUntil < 0) daysUntil = 0
                    val monthFmt = SimpleDateFormat("M月d日", Locale.getDefault())
                    predictedDate = monthFmt.format(predicted)
                }
            }

            // 读取当天经量等级
            var todayFlow = 0
            if (hasOngoing) {
                val todayStr = DATE_FMT.format(Calendar.getInstance().time)
                val flowCursor = db.rawQuery(
                    "SELECT flow_level FROM daily_flows WHERE date = ?",
                    arrayOf(todayStr)
                )
                if (flowCursor.moveToFirst()) {
                    todayFlow = flowCursor.getInt(0)
                }
                flowCursor.close()
            }

            // 构建 JSON 并保存
            val json = org.json.JSONObject().apply {
                put("hasOngoing", hasOngoing)
                put("periodDay", periodDay)
                put("daysUntil", daysUntil)
                put("predictedDate", predictedDate)
                put("lastStart", lastStart)
                put("lastEnd", lastEnd)
                put("averageCycle", avgCycle)
                put("averagePeriod", avgPeriod)
                put("cycleCount", cycleCount)
                put("todayFlow", todayFlow)
            }
            WidgetDataStore.saveWidgetData(context, json.toString())
            Log.d(TAG, "Widget data updated: $json")
        } catch (e: Exception) {
            Log.e(TAG, "Error updating widget data", e)
        }
    }

    /// 简单预测下次经期：使用所有历史记录的平均周期长度
    /// （与 PredictionService.simple 算法对齐）
    private fun predictNextPeriod(db: SQLiteDatabase, lastStart: String, fallbackCycle: Int): java.util.Date? {
        return try {
            // 计算所有已完成周期的平均长度
            // 周期长度 = 当前记录的 start_date - 上一条记录的 start_date
            val cursor = db.rawQuery(
                "SELECT start_date FROM period_records ORDER BY start_date ASC",
                null
            )
            val dates = mutableListOf<String>()
            while (cursor.moveToNext()) {
                dates.add(cursor.getString(0))
            }
            cursor.close()

            if (dates.size < 2) {
                // 不足 2 条记录，使用设置的默认值
                val last = DATE_FMT.parse(lastStart)
                val cal = Calendar.getInstance()
                cal.time = last
                cal.add(Calendar.DAY_OF_MONTH, fallbackCycle)
                return cal.time
            }

            // 计算相邻记录间的周期长度平均值
            var totalCycle = 0L
            var count = 0
            for (i in 1 until dates.size) {
                val prev = DATE_FMT.parse(dates[i - 1])
                val curr = DATE_FMT.parse(dates[i])
                val cycle = curr.time - prev.time
                if (cycle > 0) {
                    totalCycle += cycle
                    count++
                }
            }

            val avgCycleMs = if (count > 0) totalCycle / count else fallbackCycle * 24L * 60 * 60 * 1000L
            val last = DATE_FMT.parse(lastStart)
            java.util.Date(last.time + avgCycleMs)
        } catch (e: Exception) {
            Log.e(TAG, "Error predicting next period", e)
            null
        }
    }

    /// 打开 Flutter 的 SQLite 数据库
    private fun openDatabase(context: Context): SQLiteDatabase? {
        return try {
            val dbPath = context.getDatabasePath("yima_period.db").absolutePath
            SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READWRITE)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening database", e)
            null
        }
    }
}
