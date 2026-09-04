package com.yima.yimaflutter

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        /// flutter_local_notifications 17.x 的调度存储位置（见插件源码
        /// FlutterLocalNotificationsPlugin.java: SHARED_PREFERENCES_KEY /
        /// SCHEDULED_NOTIFICATIONS）。
        private const val PLUGIN_PREFS = "notification_plugin_cache"
        private const val SCHEDULED_NOTIFICATIONS_KEY = "scheduled_notifications"

        /// 一次性自愈标记：修复完成后不再清理，避免误删有效的调度数据。
        private const val STALE_STORE_HEALED_KEY = "stale_store_healed_v1"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 一次性自愈：旧版本插件写入的调度数据格式与当前 Gson 模型不兼容，
        // loadScheduledNotifications 每次都抛 "Missing type parameter"，
        // 导致 cancelAll/zonedSchedule 全部失败、经期提醒永远无法调度。
        // 在 Flutter 插件注册前清掉过期存储即可恢复；标记防止重复清理。
        val prefs = getSharedPreferences(PLUGIN_PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(STALE_STORE_HEALED_KEY, false)) {
            prefs.edit()
                .remove(SCHEDULED_NOTIFICATIONS_KEY)
                .putBoolean(STALE_STORE_HEALED_KEY, true)
                .apply()
        }
        super.onCreate(savedInstanceState)
    }
}
