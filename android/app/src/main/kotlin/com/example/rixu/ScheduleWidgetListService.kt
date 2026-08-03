package com.example.rixu

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class ScheduleWidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext)

    class Factory(private val context: Context) : RemoteViewsFactory {
        private var rows = JSONArray()
        override fun onCreate() = Unit
        override fun onDataSetChanged() {
            val raw = context.getSharedPreferences("rixu_widgets", Context.MODE_PRIVATE).getString("schedule_items", "[]") ?: "[]"
            rows = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
        }
        override fun onDestroy() = Unit
        override fun getCount(): Int = rows.length()
        override fun getViewAt(position: Int): RemoteViews? {
            if (position !in 0 until rows.length()) return null
            val row = rows.getJSONObject(position)
            return RemoteViews(context.packageName, R.layout.schedule_widget_row).apply {
                setTextViewText(R.id.widget_row_time, row.optString("time"))
                setTextViewText(R.id.widget_row_title, row.optString("title"))
                setTextViewText(R.id.widget_row_status, if (row.optBoolean("completed")) "已完成" else "待完成")
            }
        }
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = position.toLong()
        override fun hasStableIds(): Boolean = false
    }
}
