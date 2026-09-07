package com.yima.yimaflutter

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"

        /// flutter_local_notifications 17.x 的调度存储位置
        private const val PLUGIN_PREFS = "scheduled_notifications"
        private const val SCHEDULED_NOTIFICATIONS_KEY = "scheduled_notifications"
        private const val HEAL_MARKER_FILE = "yima_self_heal"
        private const val STALE_STORE_HEALED_KEY = "stale_store_healed_v1"

        /// Method Channel 名称
        private const val CHANNEL_NAME = "com.yima.yimaflutter/widget"
    }

    /// 待处理的 Intent action，在 Flutter 引擎就绪后转发。
    private var pendingAction: String? = null
    private var pendingFlowLevel: Int = 0

    /// Flutter 引擎引用
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    /// 标记 Flutter 端 MethodChannel handler 是否已注册
    private var flutterReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        val marker = getSharedPreferences(HEAL_MARKER_FILE, Context.MODE_PRIVATE)
        if (!marker.getBoolean(STALE_STORE_HEALED_KEY, false)) {
            getSharedPreferences(PLUGIN_PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(SCHEDULED_NOTIFICATIONS_KEY)
                .apply()
            marker.edit().putBoolean(STALE_STORE_HEALED_KEY, true).apply()
        }

        // 捕获小组件发来的 Intent action
        val action = intent?.action
        if (action != null && isWidgetAction(action)) {
            pendingAction = action
            pendingFlowLevel = intent.getIntExtra(PeriodWidgetProvider.EXTRA_FLOW_LEVEL, 0)
            Log.d(TAG, "onCreate: captured widget action=$action flow=$pendingFlowLevel")
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        this.flutterEngine = flutterEngine

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val dataJson = call.argument<String>("data") ?: ""
                    WidgetDataStore.saveWidgetData(this, dataJson)
                    PeriodWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "refreshWidget" -> {
                    PeriodWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "widgetReady" -> {
                    // Flutter 端通知已准备好接收操作
                    flutterReady = true
                    Log.d(TAG, "Flutter engine is ready for widget actions")
                    // 如果有待处理的操作，立即转发
                    trySendPendingAction()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 如果有来自小组件的待处理操作，尝试发送
        // 使用多次重试机制，确保 Flutter 端已注册 handler
        trySendPendingAction()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val action = intent.action
        if (action != null && isWidgetAction(action)) {
            val flowLevel = intent.getIntExtra(PeriodWidgetProvider.EXTRA_FLOW_LEVEL, 0)
            Log.d(TAG, "onNewIntent: widget action=$action flow=$flowLevel ready=$flutterReady")
            sendActionToFlutter(action, flowLevel)
        }
    }

    /// 尝试发送待处理的操作给 Flutter，带重试机制。
    private fun trySendPendingAction() {
        val action = pendingAction ?: return
        Log.d(TAG, "trySendPendingAction: action=$action ready=$flutterReady")

        val handler = Handler(Looper.getMainLooper())
        val maxRetries = 10
        var retryCount = 0

        val runnable = object : Runnable {
            override fun run() {
                if (flutterReady || retryCount >= maxRetries) {
                    if (retryCount >= maxRetries && !flutterReady) {
                        // 超过重试次数，直接尝试发送（Flutter 可能已就绪但未发 widgetReady）
                        Log.w(TAG, "Max retries reached, sending action anyway")
                    }
                    sendActionToFlutter(action, pendingFlowLevel)
                    pendingAction = null
                } else {
                    retryCount++
                    handler.postDelayed(this, 300)
                }
            }
        }
        handler.postDelayed(runnable, 300)
    }

    /// 将小组件操作通过 MethodChannel 发送给 Flutter。
    private fun sendActionToFlutter(action: String, flowLevel: Int) {
        val args: MutableMap<String, Any> = mutableMapOf("action" to action)
        if (flowLevel > 0) {
            args["flowLevel"] = flowLevel
        }
        Log.d(TAG, "Sending action to Flutter: $action flow=$flowLevel")
        methodChannel?.invokeMethod("handleWidgetAction", args, object : MethodChannel.Result {
            override fun success(result: Any?) {
                Log.d(TAG, "Action sent successfully: $action")
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.e(TAG, "Action send error: $errorCode - $errorMessage")
            }
            override fun notImplemented() {
                Log.e(TAG, "Method not implemented for action: $action")
            }
        })
    }

    private fun isWidgetAction(action: String): Boolean {
        return action == PeriodWidgetProvider.ACTION_START_PERIOD ||
                action == PeriodWidgetProvider.ACTION_END_PERIOD ||
                action == PeriodWidgetProvider.ACTION_SET_FLOW ||
                action == PeriodWidgetProvider.ACTION_OPEN_APP
    }
}
