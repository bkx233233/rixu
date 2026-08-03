package com.example.rixu

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

object AlarmRegistry {
    private const val PREFS = "rixu_alarm_registry"
    fun schedule(context: Context, eventId: String, title: String, triggerAt: Long): Boolean {
        val manager = context.getSystemService(AlarmManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) return false
        val intent = Intent(context, AlarmReceiver::class.java).putExtra("eventId", eventId).putExtra("title", title)
        manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, PendingIntent.getBroadcast(context, eventId.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(eventId, JSONObject().put("title", title).put("triggerAt", triggerAt).toString()).apply()
        return true
    }
    fun cancel(context: Context, eventId: String) {
        val manager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, AlarmReceiver::class.java)
        manager.cancel(PendingIntent.getBroadcast(context, eventId.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(eventId).apply()
    }
    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.all.forEach { (id, raw) -> try { val item = JSONObject(raw as String); val at = item.getLong("triggerAt"); if (at > System.currentTimeMillis()) schedule(context, id, item.getString("title"), at) else prefs.edit().remove(id).apply() } catch (_: Exception) {} }
    }
    fun reconcile(context: Context, eventIds: List<String>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.all.keys.filter { it !in eventIds }.forEach { cancel(context, it) }
    }
}
