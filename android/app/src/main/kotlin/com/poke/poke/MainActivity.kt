package com.poke.poke

import android.content.ContentUris
import android.content.ContentValues
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// 系统日历提醒兜底通道。
///
/// device_calendar 插件创建事件时会写入 METHOD_ALERT 提醒行，
/// 但部分国产 ROM 的日历提供程序会静默丢弃该提醒行（事件写入成功、
/// 提醒却不生效）。这里在事件创建后：
/// 1. 删除旧提醒行（避免与插件写入的重复）；
/// 2. 依次尝试 METHOD_ALERT → METHOD_DEFAULT 写入；
/// 3. 回查 Reminders 表校验是否真正落库；
/// 4. 兜底置位 Events.HAS_ALARM（部分日历应用据此显示提醒）。
class MainActivity : FlutterActivity() {
    private val channelName = "poke/calendar_reminder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "ensureReminder") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val eventId = (call.argument<Number>("eventId"))?.toLong()
                val minutes = (call.argument<Number>("minutes"))?.toInt() ?: 15
                if (eventId == null) {
                    result.error("ARGS", "缺少 eventId", null)
                    return@setMethodCallHandler
                }
                // 提供程序操作放后台线程，结果回平台线程
                Thread {
                    val payload: Map<String, Any> = try {
                        ensureReminder(eventId, minutes)
                        mapOf("ok" to true)
                    } catch (e: Exception) {
                        mapOf("ok" to false, "error" to (e.message ?: "未知错误"))
                    }
                    runOnUiThread { result.success(payload) }
                }.start()
            }
    }

    /// 确保事件带有一条真正落库的提醒；失败抛出异常（含原因）。
    private fun ensureReminder(eventId: Long, minutes: Int) {
        val resolver = contentResolver
        // 清掉插件/上次写入的旧提醒，避免重复弹提醒
        resolver.delete(
            CalendarContract.Reminders.CONTENT_URI,
            "${CalendarContract.Reminders.EVENT_ID} = ?",
            arrayOf(eventId.toString())
        )
        val methods = intArrayOf(
            CalendarContract.Reminders.METHOD_ALERT,
            CalendarContract.Reminders.METHOD_DEFAULT
        )
        for (method in methods) {
            val values = ContentValues().apply {
                put(CalendarContract.Reminders.EVENT_ID, eventId)
                put(CalendarContract.Reminders.MINUTES, minutes)
                put(CalendarContract.Reminders.METHOD, method)
            }
            try {
                resolver.insert(CalendarContract.Reminders.CONTENT_URI, values)
            } catch (_: Exception) {
                continue
            }
            if (countReminders(eventId) > 0) {
                // 部分日历应用仅在 hasAlarm=1 时展示提醒
                try {
                    val ev = ContentValues().apply {
                        put(CalendarContract.Events.HAS_ALARM, 1)
                    }
                    resolver.update(
                        ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId),
                        ev, null, null
                    )
                } catch (_: Exception) {
                    // 只读列，部分提供程序拒绝写入，忽略
                }
                return
            }
        }
        throw IllegalStateException("当前日历不接受提醒写入，可换一个日历或在日历应用里手动设置提醒")
    }

    private fun countReminders(eventId: Long): Int {
        contentResolver.query(
            CalendarContract.Reminders.CONTENT_URI,
            arrayOf(CalendarContract.Reminders._ID),
            "${CalendarContract.Reminders.EVENT_ID} = ?",
            arrayOf(eventId.toString()),
            null
        )?.use { cursor -> return cursor.count }
        return 0
    }
}
