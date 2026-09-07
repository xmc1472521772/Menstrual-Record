package com.yima.yimaflutter

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        /// flutter_local_notifications 17.x 的调度存储位置（见插件源码
        /// loadScheduledNotifications：getSharedPreferences(SCHEDULED_NOTIFICATIONS)
        /// 的文件名与键名同为此常量值，均为 "scheduled_notifications"；
        /// "notification_plugin_cache" 文件只存默认图标，勿混淆）。
        private const val PLUGIN_PREFS = "scheduled_notifications"
        private const val SCHEDULED_NOTIFICATIONS_KEY = "scheduled_notifications"

        /// 一次性自愈标记：修复完成后不再清理，避免误删有效的调度数据。
        /// 标记本身存到另一个 prefs 文件，避免与插件数据同文件竞争。
        private const val HEAL_MARKER_FILE = "yima_self_heal"
        private const val STALE_STORE_HEALED_KEY = "stale_store_healed_v1"

        /// Method Channel 名称
        private const val CHANNEL_NAME = "com.yima.yimaflutter/widget"
    }

    /// 待处理的 Intent action，在 Flutter 引擎就绪后转发。
    private var pendingAction: String? = null
    private var pendingFlowLevel: Int = 0

    /// Flutter 引擎引用，用于 MethodChannel 调用。
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // 一次性自愈：旧版本插件写入的调度数据格式与当前 Gson 模型不兼容，
        // loadScheduledNotifications 每次都抛 "Missing type parameter"，
        // 导致 cancelAll/zonedSchedule 全部失败、经期提醒永远无法调度。
        // 在 Flutter 插件注册前清掉过期存储即可恢复；标记防止重复清理。
        val marker = getSharedPreferences(HEAL_MARKER_FILE, Context.MODE_PRIVATE)
        if (!marker.getBoolean(STALE_STORE_HEALED_KEY, false)) {
            getSharedPreferences(PLUGIN_PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(SCHEDULED_NOTIFICATIONS_KEY)
                .apply()
            marker.edit().putBoolean(STALE_STORE_HEALED_KEY, true).apply()
        }

        // 捕获小组件发来的 Intent action，待 Flutter 引擎就绪后处理
        val action = intent?.action
        if (action != null && isWidgetAction(action)) {
            pendingAction = action
            pendingFlowLevel = intent.getIntExtra(PeriodWidgetProvider.EXTRA_FLOW_LEVEL, 0)
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    // Flutter 端请求更新小组件
                    val dataJson = call.argument<String>("data") ?: ""
                    WidgetDataStore.saveWidgetData(this, dataJson)
                    PeriodWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "refreshWidget" -> {
                    // Flutter 端仅刷新小组件 UI（不重新写入数据）
                    PeriodWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 如果有来自小组件的待处理操作，转发给 Flutter
        pendingAction?.let { action ->
            // 延迟一小段时间确保 Flutter 端 MethodChannel 已注册
            methodChannel?.let { channel ->
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    val args: MutableMap<String, Any> = mutableMapOf("action" to action)
                    if (pendingFlowLevel > 0) {
                        args["flowLevel"] = pendingFlowLevel
                    }
                    channel.invokeMethod("handleWidgetAction", args)
                }, 500)
            }
            pendingAction = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.action
        if (action != null && isWidgetAction(action)) {
            val flowLevel = intent.getIntExtra(PeriodWidgetProvider.EXTRA_FLOW_LEVEL, 0)
            val args: MutableMap<String, Any> = mutableMapOf("action" to action)
            if (flowLevel > 0) {
                args["flowLevel"] = flowLevel
            }
            methodChannel?.invokeMethod("handleWidgetAction", args)
        }
    }

    private fun isWidgetAction(action: String): Boolean {
        return action == PeriodWidgetProvider.ACTION_START_PERIOD ||
                action == PeriodWidgetProvider.ACTION_END_PERIOD ||
                action == PeriodWidgetProvider.ACTION_SET_FLOW ||
                action == PeriodWidgetProvider.ACTION_OPEN_APP
    }
}
