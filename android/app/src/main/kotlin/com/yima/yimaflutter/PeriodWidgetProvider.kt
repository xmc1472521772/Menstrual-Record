package com.yima.yimaflutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/// 经期桌面小组件 Provider。
///
/// 功能：
/// - 显示经期状态（第几天 / 距下次经期天数 / 安全区）
/// - 快速开始经期 / 结束经期
/// - 经期中可快速记录经量（少/中/多）
/// - 点击标题区域打开 App
///
/// 数据来源：通过 [WidgetDataStore] 读取 SharedPreferences 中的 JSON。
/// 按钮操作通过广播 Intent 发送给 [WidgetActionReceiver]，
/// 由原生端直接操作 SQLite 数据库，不依赖 Flutter 引擎。
class PeriodWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "PeriodWidgetProvider"

        /// 更新所有已添加的小组件。
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PeriodWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (widgetIds.isNotEmpty()) {
                val intent = Intent(context, PeriodWidgetProvider::class.java)
                intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    /// 渲染单个小组件实例。
    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
        val data = WidgetDataStore.getWidgetData(context) ?: WidgetDataStore.defaultJson()

        val views = RemoteViews(context.packageName, R.layout.widget_period)

        val hasOngoing = data.optBoolean(WidgetDataStore.Keys.HAS_ONGOING, false)
        val periodDay = data.optInt(WidgetDataStore.Keys.PERIOD_DAY, 0)
        val daysUntil = data.optInt(WidgetDataStore.Keys.DAYS_UNTIL, -1)
        val predictedDate = data.optString(WidgetDataStore.Keys.PREDICTED_DATE, "")
        val cycleCount = data.optInt(WidgetDataStore.Keys.CYCLE_COUNT, 0)
        val avgCycle = data.optInt(WidgetDataStore.Keys.AVERAGE_CYCLE, 0)
        val todayFlow = data.optInt(WidgetDataStore.Keys.TODAY_FLOW, 0)

        if (hasOngoing) {
            // ── 经期进行中 ──
            views.setTextViewText(R.id.widget_status_text, "经期第 $periodDay 天")
            views.setTextColor(R.id.widget_status_text, 0xFFB4564F.toInt())

            // 子文本显示当天经量状态
            val flowText = when (todayFlow) {
                0 -> "今日经量：无"
                1 -> "今日经量：少"
                2 -> "今日经量：中"
                3 -> "今日经量：多"
                else -> "点击下方记录经量"
            }
            views.setTextViewText(R.id.widget_sub_text, flowText)

            // 显示经量按钮和结束按钮
            views.setViewVisibility(R.id.widget_flow_buttons, View.VISIBLE)
            views.setViewVisibility(R.id.btn_start, View.GONE)
            views.setViewVisibility(R.id.btn_end, View.VISIBLE)

            // 经量按钮：根据 todayFlow 高亮选中项
            // 无 (0) → 浅灰粉 #E8D5D2
            views.setInt(
                R.id.btn_flow_none,
                "setBackgroundResource",
                if (todayFlow == 0) R.drawable.widget_flow_bg_selected_none
                else R.drawable.widget_flow_bg_unselected
            )
            views.setTextColor(
                R.id.btn_flow_none,
                if (todayFlow == 0) 0xFFFFFFFF.toInt() else 0xFF6E665E.toInt()
            )
            views.setOnClickPendingIntent(
                R.id.btn_flow_none,
                buildBroadcastIntent(context, WidgetActionReceiver.ACTION_SET_FLOW, 0)
            )

            // 少 (1) → 浅暖粉 #F0B4A8
            views.setInt(
                R.id.btn_flow_light,
                "setBackgroundResource",
                if (todayFlow == 1) R.drawable.widget_flow_bg_selected_light
                else R.drawable.widget_flow_bg_unselected
            )
            views.setTextColor(
                R.id.btn_flow_light,
                if (todayFlow == 1) 0xFFFFFFFF.toInt() else 0xFF6E665E.toInt()
            )
            views.setOnClickPendingIntent(
                R.id.btn_flow_light,
                buildBroadcastIntent(context, WidgetActionReceiver.ACTION_SET_FLOW, 1)
            )

            // 中 (2) → 中暖红 #D97065
            views.setInt(
                R.id.btn_flow_normal,
                "setBackgroundResource",
                if (todayFlow == 2) R.drawable.widget_flow_bg_selected_normal
                else R.drawable.widget_flow_bg_unselected
            )
            views.setTextColor(
                R.id.btn_flow_normal,
                if (todayFlow == 2) 0xFFFFFFFF.toInt() else 0xFF6E665E.toInt()
            )
            views.setOnClickPendingIntent(
                R.id.btn_flow_normal,
                buildBroadcastIntent(context, WidgetActionReceiver.ACTION_SET_FLOW, 2)
            )

            // 多 (3) → 深酒红 #8E3F3A
            views.setInt(
                R.id.btn_flow_heavy,
                "setBackgroundResource",
                if (todayFlow == 3) R.drawable.widget_flow_bg_selected_heavy
                else R.drawable.widget_flow_bg_unselected
            )
            views.setTextColor(
                R.id.btn_flow_heavy,
                if (todayFlow == 3) 0xFFFFFFFF.toInt() else 0xFF6E665E.toInt()
            )
            views.setOnClickPendingIntent(
                R.id.btn_flow_heavy,
                buildBroadcastIntent(context, WidgetActionReceiver.ACTION_SET_FLOW, 3)
            )

            // 结束经期按钮 → 发送广播
            views.setOnClickPendingIntent(
                R.id.btn_end,
                buildBroadcastIntent(context, WidgetActionReceiver.ACTION_END_PERIOD, 0)
            )
        } else {
            // ── 非经期 ──
            views.setViewVisibility(R.id.widget_flow_buttons, View.GONE)
            views.setViewVisibility(R.id.btn_end, View.GONE)
            views.setViewVisibility(R.id.btn_start, View.VISIBLE)

            if (daysUntil > 0 && predictedDate.isNotEmpty()) {
                views.setTextViewText(R.id.widget_status_text, "距下次经期 $daysUntil 天")
                views.setTextColor(R.id.widget_status_text, 0xFF6E665E.toInt())
                views.setTextViewText(R.id.widget_sub_text, "预计 $predictedDate")
            } else if (cycleCount == 0) {
                views.setTextViewText(R.id.widget_status_text, "月事记")
                views.setTextColor(R.id.widget_status_text, 0xFFB4564F.toInt())
                views.setTextViewText(R.id.widget_sub_text, "点击开始记录经期")
            } else {
                views.setTextViewText(R.id.widget_status_text, "经期已结束")
                views.setTextColor(R.id.widget_status_text, 0xFF6E665E.toInt())
                views.setTextViewText(R.id.widget_sub_text, "等待下次经期预测")
            }

            // 开始经期按钮 → 发送广播
            views.setOnClickPendingIntent(
                R.id.btn_start,
                buildBroadcastIntent(context, WidgetActionReceiver.ACTION_START_PERIOD, 0)
            )
        }

        // 点击标题区域打开 App
        views.setOnClickPendingIntent(
            R.id.widget_root,
            buildOpenAppIntent(context)
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /// 构建广播 PendingIntent，发送给 WidgetActionReceiver。
    /// 使用广播而非 Activity 启动，这样不需要打开 App 即可执行操作。
    private fun buildBroadcastIntent(context: Context, action: String, flowLevel: Int): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).apply {
            this.action = action
            putExtra(WidgetActionReceiver.EXTRA_FLOW_LEVEL, flowLevel)
        }
        // requestCode 必须唯一，否则同 action 的 PendingIntent 会互相覆盖
        val requestCode = action.hashCode() xor flowLevel.hashCode()
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    /// 构建打开 App 的 Intent（仅标题区域使用）。
    ///
    /// 使用 FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_SINGLE_TOP：
    /// - NEW_TASK：从桌面小组件（PendingIntent）启动 Activity 必需
    /// - SINGLE_TOP：配合 manifest 中的 singleTop，如果 app 已在后台，
    ///   已存在的 Activity 会被复用（走 onNewIntent），不会创建新实例
    ///
    /// 之前设置了 taskAffinity="" 导致系统无法匹配已有任务栈，
    /// 每次都会创建新任务栈，使 app 看起来像被重新启动（重新显示 splash）。
    /// 移除 taskAffinity="" 后，系统使用包名作为默认 affinity，
    /// 能正确找到并恢复已有的 app 任务栈。
    private fun buildOpenAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, 1, intent, flags)
    }
}
