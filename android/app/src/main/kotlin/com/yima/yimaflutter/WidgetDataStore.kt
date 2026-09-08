package com.yima.yimaflutter

import android.content.Context
import org.json.JSONObject

/// 小组件数据存储工具。
///
/// 小组件运行在独立进程中，不能直接访问 Flutter 的 SQLite 数据。
/// 使用 SharedPreferences 作为桥梁，Flutter 端将经期状态序列化为 JSON
/// 写入 SharedPreferences，小组件读取后渲染 UI。
object WidgetDataStore {
    private const val PREFS_NAME = "yima_widget_prefs"
    private const val KEY_WIDGET_DATA = "widget_data_json"
    private const val KEY_DATA_DIRTY = "data_dirty_flag"

    /// 小组件数据 JSON 的字段名。
    object Keys {
        const val HAS_ONGOING = "hasOngoing"
        const val PERIOD_DAY = "periodDay"         // 经期第几天（从1开始）
        const val DAYS_UNTIL = "daysUntil"          // 距下次经期天数（无进行中经期时）
        const val PREDICTED_DATE = "predictedDate"  // 预测下次经期日期
        const val LAST_START = "lastStart"          // 最近一次经期开始日期
        const val LAST_END = "lastEnd"              // 最近一次经期结束日期
        const val AVERAGE_CYCLE = "averageCycle"    // 平均周期长度
        const val AVERAGE_PERIOD = "averagePeriod"  // 平均经期长度
        const val CYCLE_COUNT = "cycleCount"        // 总周期数
        const val TODAY_FLOW = "todayFlow"          // 今天经量等级（0=未记录, 1=少, 2=中, 3=多）
    }

    fun saveWidgetData(context: Context, json: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_WIDGET_DATA, json)
            .apply()
    }

    /// 标记数据已变更（小组件操作了数据库后调用）。
    /// App 恢复前台或收到 MethodChannel 通知时检查此标记，
    /// 若为 true 则强制重新加载数据。
    fun setDataDirty(context: Context, dirty: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_DATA_DIRTY, dirty)
            .apply()
    }

    /// 检查数据是否已变更（小组件操作了数据库）。
    /// 返回 true 表示需要重新加载 Flutter 端数据。
    fun isDataDirty(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_DATA_DIRTY, false)
    }

    fun getWidgetData(context: Context): JSONObject? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val str = prefs.getString(KEY_WIDGET_DATA, null) ?: return null
        return try {
            JSONObject(str)
        } catch (e: Exception) {
            null
        }
    }

    /// 构建默认的"无数据"JSON。
    fun defaultJson(): JSONObject {
        return JSONObject().apply {
            put(Keys.HAS_ONGOING, false)
            put(Keys.PERIOD_DAY, 0)
            put(Keys.DAYS_UNTIL, -1)
            put(Keys.PREDICTED_DATE, "")
            put(Keys.LAST_START, "")
            put(Keys.LAST_END, "")
            put(Keys.AVERAGE_CYCLE, 0)
            put(Keys.AVERAGE_PERIOD, 0)
            put(Keys.CYCLE_COUNT, 0)
            put(Keys.TODAY_FLOW, 0)
        }
    }
}
