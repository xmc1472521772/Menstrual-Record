package com.yima.yimaflutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/// 小组件操作接收器。
///
/// 接收来自桌面小组件的广播操作（开始经期/结束经期/记录经量），
/// 直接操作 SQLite 数据库，不依赖 Flutter 引擎。
///
/// 操作完成后：
/// 1. 更新 SharedPreferences 中的小组件数据
/// 2. 刷新所有小组件 UI
/// 3. 发送广播通知 App 刷新数据（App 在前台时会自动 reload）
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetActionReceiver"

        const val ACTION_START_PERIOD = "com.yima.yimaflutter.WIDGET_START_PERIOD"
        const val ACTION_END_PERIOD = "com.yima.yimaflutter.WIDGET_END_PERIOD"
        const val ACTION_SET_FLOW = "com.yima.yimaflutter.WIDGET_SET_FLOW"
        const val EXTRA_FLOW_LEVEL = "flow_level"

        /// 操作完成后通知 App 刷新的广播 action
        const val ACTION_DATA_CHANGED = "com.yima.yimaflutter.WIDGET_DATA_CHANGED"

        /// App 包名，用于发送数据变更广播
        private const val APP_PACKAGE = "com.yima.yimaflutter"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "Received action: $action")

        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            .format(Calendar.getInstance().time)

        when (action) {
            ACTION_START_PERIOD -> handleStartPeriod(context, today)
            ACTION_END_PERIOD -> handleEndPeriod(context, today)
            ACTION_SET_FLOW -> {
                val flowLevel = intent.getIntExtra(EXTRA_FLOW_LEVEL, 0)
                if (flowLevel > 0) {
                    handleSetFlow(context, today, flowLevel)
                }
            }
        }

        // 操作完成后：
        // 1. 更新小组件 UI
        PeriodWidgetProvider.updateAllWidgets(context)
        // 2. 通知 App 数据已变更（App 在前台时自动 reload）
        val notifyIntent = Intent(ACTION_DATA_CHANGED).apply {
            setPackage(APP_PACKAGE)
        }
        context.sendBroadcast(notifyIntent)
    }

    /// 开始经期：插入一条新的经期记录（end_date = NULL 表示进行中）
    private fun handleStartPeriod(context: Context, today: String) {
        val db = openDatabase(context) ?: return
        try {
            // 检查是否已有进行中的经期
            val cursor = db.rawQuery(
                "SELECT id FROM period_records WHERE end_date IS NULL",
                null
            )
            if (cursor.moveToFirst()) {
                // 已有进行中的经期，不重复插入
                cursor.close()
                Log.d(TAG, "Already has ongoing period, skipping")
                return
            }
            cursor.close()

            // 插入新记录
            val now = System.currentTimeMillis()
            db.execSQL(
                "INSERT INTO period_records (start_date, end_date, created_at) VALUES (?, NULL, ?)",
                arrayOf(today, now)
            )
            Log.d(TAG, "Started new period: $today")

            // 更新小组件数据
            updateWidgetDataFromDb(context, db)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting period", e)
        } finally {
            db.close()
        }
    }

    /// 结束经期：将进行中的经期记录设置 end_date
    private fun handleEndPeriod(context: Context, today: String) {
        val db = openDatabase(context) ?: return
        try {
            // 查找进行中的经期
            val cursor = db.rawQuery(
                "SELECT id, start_date FROM period_records WHERE end_date IS NULL ORDER BY start_date DESC LIMIT 1",
                null
            )
            if (!cursor.moveToFirst()) {
                cursor.close()
                Log.d(TAG, "No ongoing period to end")
                return
            }

            val id = cursor.getLong(0)
            val startDate = cursor.getString(1)
            cursor.close()

            // 计算经期天数
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val start = sdf.parse(startDate)
            val end = sdf.parse(today)
            val periodLength = ((end.time - start.time) / (1000 * 60 * 60 * 24) + 1).toInt()

            // 更新记录
            db.execSQL(
                "UPDATE period_records SET end_date = ?, period_length = ? WHERE id = ?",
                arrayOf(today, periodLength, id)
            )
            Log.d(TAG, "Ended period: id=$id, end=$today, length=$periodLength")

            // 更新小组件数据
            updateWidgetDataFromDb(context, db)
        } catch (e: Exception) {
            Log.e(TAG, "Error ending period", e)
        } finally {
            db.close()
        }
    }

    /// 记录经量：在 daily_flows 表中插入/更新当天经量
    private fun handleSetFlow(context: Context, today: String, flowLevel: Int) {
        val db = openDatabase(context) ?: return
        try {
            // 检查是否有进行中的经期（只有经期中才能记录经量）
            val cursor = db.rawQuery(
                "SELECT id FROM period_records WHERE end_date IS NULL",
                null
            )
            if (!cursor.moveToFirst()) {
                cursor.close()
                Log.d(TAG, "No ongoing period, cannot set flow")
                return
            }
            cursor.close()

            // upsert daily_flows
            db.execSQL(
                """INSERT OR REPLACE INTO daily_flows (date, flow_level)
                   VALUES (?, ?)""",
                arrayOf(today, flowLevel)
            )
            Log.d(TAG, "Set flow: $today = $flowLevel")

            // 更新小组件数据
            updateWidgetDataFromDb(context, db)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting flow", e)
        } finally {
            db.close()
        }
    }

    /// 从数据库读取当前状态，更新小组件数据到 SharedPreferences
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
                // 计算第几天
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val start = sdf.parse(lastStart)
                val now = Calendar.getInstance()
                val diff = ((now.timeInMillis - start.time) / (1000 * 60 * 60 * 24) + 1).toInt()
                periodDay = diff.coerceAtLeast(1)
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
            var avgCycle = 28
            var avgPeriod = 5
            val settingsCursor = db.rawQuery(
                "SELECT key, value FROM settings WHERE key IN ('avg_cycle_length', 'avg_period_length')",
                null
            )
            while (settingsCursor.moveToNext()) {
                val key = settingsCursor.getString(0)
                val value = settingsCursor.getInt(1)
                when (key) {
                    "avg_cycle_length" -> avgCycle = value
                    "avg_period_length" -> avgPeriod = value
                }
            }
            settingsCursor.close()

            // 计算总周期数
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
                // 简单预测：上次开始日期 + 平均周期
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val lastStartDate = sdf.parse(lastStart)
                val cal = Calendar.getInstance()
                cal.time = lastStartDate
                cal.add(Calendar.DAY_OF_MONTH, avgCycle)
                val predicted = cal.time
                val today = Calendar.getInstance()
                val todayCal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val predCal = Calendar.getInstance().apply {
                    time = predicted
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                daysUntil = ((predCal.timeInMillis - todayCal.timeInMillis) / (1000 * 60 * 60 * 24)).toInt()
                if (daysUntil < 0) daysUntil = 0
                val monthFmt = SimpleDateFormat("M月d日", Locale.getDefault())
                predictedDate = monthFmt.format(predicted)
            }

            // 构建 JSON 并保存到 SharedPreferences
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
            }
            WidgetDataStore.saveWidgetData(context, json.toString())
            Log.d(TAG, "Widget data updated: $json")
        } catch (e: Exception) {
            Log.e(TAG, "Error updating widget data", e)
        }
    }

    /// 打开 Flutter 的 SQLite 数据库
    private fun openDatabase(context: Context): SQLiteDatabase? {
        return try {
            // Flutter sqflite 数据库路径：/data/data/<package>/databases/yima_period.db
            val dbPath = context.getDatabasePath("yima_period.db").absolutePath
            val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READWRITE)
            Log.d(TAG, "Opened database: $dbPath")
            db
        } catch (e: Exception) {
            Log.e(TAG, "Error opening database", e)
            null
        }
    }
}
