package com.yima.yimaflutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
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

        /// 小组件数据变更通知
        const val ACTION_DATA_CHANGED = "com.yima.yimaflutter.WIDGET_DATA_CHANGED"
    }

    private var methodChannel: MethodChannel? = null

    /// 监听小组件数据变更的 BroadcastReceiver
    private val dataChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "Received data changed broadcast")
            // 通知 Flutter 端刷新数据
            methodChannel?.invokeMethod("dataChanged", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val marker = getSharedPreferences(HEAL_MARKER_FILE, Context.MODE_PRIVATE)
        if (!marker.getBoolean(STALE_STORE_HEALED_KEY, false)) {
            getSharedPreferences(PLUGIN_PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(SCHEDULED_NOTIFICATIONS_KEY)
                .apply()
            marker.edit().putBoolean(STALE_STORE_HEALED_KEY, true).apply()
        }

        // 注册数据变更广播接收器
        val filter = IntentFilter(ACTION_DATA_CHANGED)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dataChangedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(dataChangedReceiver, filter)
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    // Flutter 端请求更新小组件数据
                    val dataJson = call.argument<String>("data") ?: ""
                    WidgetDataStore.saveWidgetData(this, dataJson)
                    PeriodWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "refreshWidget" -> {
                    // Flutter 端仅刷新小组件 UI
                    PeriodWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(dataChangedReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Receiver not registered", e)
        }
        super.onDestroy()
    }
}
