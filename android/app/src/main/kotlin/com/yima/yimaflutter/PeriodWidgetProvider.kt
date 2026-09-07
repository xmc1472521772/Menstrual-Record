package com.yima.yimaflutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

/// 经期桌面小组件 Provider。
///
/// 功能：
/// - 显示经期状态（第几天 / 距下次经期天数 / 安全区）
/// - 快速开始经期 / 结束经期
/// - 经期中可快速记录经量（少/中/多）
/// - 点击标题区域打开 App
///
/// 数据来源：通过 [WidgetDataStore] 读取 SharedPreferences 中的 JSON。
/// 按钮操作通过 Intent action 转发给 [MainActivity]，由 Flutter 端处理。
class PeriodWidgetProvider : AppWidgetProvider() {

    companion object {
        // ── Intent Actions ──────────────────────────────────────────
        const val ACTION_START_PERIOD = "com.yima.yimaflutter.ACTION_START_PERIOD"
        const val ACTION_END_PERIOD = "com.yima.yimaflutter.ACTION_END_PERIOD"
        const val ACTION_SET_FLOW = "com.yima.yimaflutter.ACTION_SET_FLOW"
        const val ACTION_REFRESH_WIDGET = "com.yima.yimaflutter.ACTION_REFRESH_WIDGET"
        const val ACTION_OPEN_APP = "com.yima.yimaflutter.ACTION_OPEN_APP"

        // ── Intent Extras ───────────────────────────────────────────
        const val EXTRA_FLOW_LEVEL = "flow_level"

        /// 更新所有已添加的小组件。
        /// Flutter 端数据变更后通过 MethodChannel 调用此方法。
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
        // 为每个小组件实例更新 UI
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_REFRESH_WIDGET -> {
                // 收到刷新广播，更新所有小组件
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, PeriodWidgetProvider::class.java)
                val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                for (widgetId in widgetIds) {
                    updateWidget(context, appWidgetManager, widgetId)
                }
            }
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

        if (hasOngoing) {
            // ── 经期进行中 ──
            views.setTextViewText(R.id.widget_status_text, "经期第 $periodDay 天")
            views.setTextColor(R.id.widget_status_text, 0xFFB4564F.toInt())

            // 子文本
            val subText = if (periodDay > 0 && avgCycle > 0) {
                "平均经期 ${data.optInt(WidgetDataStore.Keys.AVERAGE_PERIOD, 0)} 天"
            } else {
                "点击下方结束经期"
            }
            views.setTextViewText(R.id.widget_sub_text, subText)

            // 显示经量按钮和结束按钮
            views.setViewVisibility(R.id.widget_flow_buttons, View.VISIBLE)
            views.setViewVisibility(R.id.btn_start, View.GONE)
            views.setViewVisibility(R.id.btn_end, View.VISIBLE)

            // 经量按钮
            views.setOnClickPendingIntent(
                R.id.btn_flow_light,
                buildActionIntent(context, ACTION_SET_FLOW, 1)
            )
            views.setOnClickPendingIntent(
                R.id.btn_flow_normal,
                buildActionIntent(context, ACTION_SET_FLOW, 2)
            )
            views.setOnClickPendingIntent(
                R.id.btn_flow_heavy,
                buildActionIntent(context, ACTION_SET_FLOW, 3)
            )

            // 结束经期按钮
            views.setOnClickPendingIntent(
                R.id.btn_end,
                buildActionIntent(context, ACTION_END_PERIOD, 0)
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

            // 开始经期按钮
            views.setOnClickPendingIntent(
                R.id.btn_start,
                buildActionIntent(context, ACTION_START_PERIOD, 0)
            )
        }

        // 点击标题区域打开 App
        views.setOnClickPendingIntent(
            R.id.widget_root,
            buildOpenAppIntent(context)
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /// 构建操作 Intent，发送到 MainActivity 处理。
    private fun buildActionIntent(context: Context, action: String, flowLevel: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (flowLevel > 0) {
                putExtra(EXTRA_FLOW_LEVEL, flowLevel)
            }
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, action.hashCode(), intent, flags)
    }

    /// 构建打开 App 的 Intent。
    private fun buildOpenAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, 0, intent, flags)
    }
}
