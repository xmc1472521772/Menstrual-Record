package com.yima.yimaflutter

import android.content.Context
import android.content.Intent
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

        /// 静态引用 MethodChannel，供 WidgetActionReceiver 等非 Activity 组件
        /// 直接通知 Flutter 端刷新数据。
        /// 生命周期：在 [configureFlutterEngine] 中赋值，在 [onDestroy] 中置空。
        @Volatile
        @JvmStatic
        var methodChannel: MethodChannel? = null
            private set
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

        super.onCreate(savedInstanceState)
    }

    /// 拦截返回键：将 app 退到后台而非销毁 Activity。
    ///
    /// 默认行为下，按返回键会调用 Activity.onDestroy() 销毁 Activity 和
    /// FlutterEngine。再次从桌面图标或小组件进入时会重新创建 Activity，
    /// 导致 app 看起来像被重启（重新显示 splash 画面）。
    ///
    /// 覆写为 moveTaskToBack(true) 后，按返回键只是将 app 退到后台，
    /// Activity 和 FlutterEngine 仍然保留在内存中。再次进入时，
    /// 配合 singleTop + FLAG_ACTIVITY_SINGLE_TOP 会走 onNewIntent 恢复，
    /// 不会重新显示 splash。
    override fun onBackPressed() {
        moveTaskToBack(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
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
                "checkWidgetDataDirty" -> {
                    // Flutter 端检查小组件是否修改了数据库
                    // 返回 true 表示需要重新加载数据，同时清除标记
                    val dirty = WidgetDataStore.isDataDirty(this)
                    if (dirty) {
                        WidgetDataStore.setDataDirty(this, false)
                    }
                    result.success(dirty)
                }
                "clearWidgetDataDirty" -> {
                    // Flutter 端主动清除 dirty 标记
                    // 当通过 MethodChannel 收到 dataChanged 通知后调用
                    WidgetDataStore.setDataDirty(this, false)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// 当 Activity 通过 SINGLE_TOP + FLAG_ACTIVITY_SINGLE_TOP 被复用时调用。
    ///
    /// 此处不做 dirty 检查，因为 onNewIntent 后一定会触发
    /// didChangeAppLifecycleState(resumed)，由 Flutter 端的 checkDataDirty
    /// 兜底。如果在 onNewIntent 中清除 dirty 标记，会导致 resumed 中的
    /// checkDataDirty 返回 false，从而不重新加载数据。
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
