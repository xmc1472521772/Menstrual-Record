package com.yima.yimaflutter

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

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
    }

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
        super.onCreate(savedInstanceState)
    }
}
