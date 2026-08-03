package com.example.rixu

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

class ScheduleWidgetProvider : android.appwidget.AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id -> updateWidget(context, manager, id) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        updateWidget(context, manager, appWidgetId)
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
        val data = context.getSharedPreferences("rixu_widgets", Context.MODE_PRIVATE)
        val total = data.getInt("schedule_total", 0)
        val completed = data.getInt("schedule_completed", 0)
        val isExpanded = isExpanded(manager.getAppWidgetOptions(id))
        val launchIntent = PendingIntent.getActivity(
            context,
            id,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val serviceIntent = Intent(context, ScheduleWidgetListService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            this.data = Uri.parse("rixu://schedule-widget/$id")
        }
        val views = RemoteViews(context.packageName, R.layout.schedule_widget).apply {
            setTextViewText(
                R.id.widget_schedule_title,
                if (total == 0) "今日暂无日程" else "今日日程 · $completed/$total 已完成",
            )
            setTextViewText(
                R.id.widget_next_task_title,
                data.getString("schedule_next_title", "打开日序添加任务"),
            )
            setTextViewText(
                R.id.widget_next_task_detail,
                data.getString("schedule_next_detail", ""),
            )
            setViewVisibility(R.id.widget_next_task_container, if (isExpanded) View.GONE else View.VISIBLE)
            setViewVisibility(R.id.widget_schedule_list, if (isExpanded) View.VISIBLE else View.GONE)
            setViewVisibility(R.id.widget_schedule_empty, if (isExpanded) View.VISIBLE else View.GONE)
            setRemoteAdapter(R.id.widget_schedule_list, serviceIntent)
            setEmptyView(R.id.widget_schedule_list, R.id.widget_schedule_empty)
            setOnClickPendingIntent(R.id.schedule_widget_root, launchIntent)
        }
        manager.updateAppWidget(id, views)
        manager.notifyAppWidgetViewDataChanged(intArrayOf(id), R.id.widget_schedule_list)
    }

    private fun isExpanded(options: android.os.Bundle): Boolean {
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        return minWidth >= 250 || minHeight >= 120
    }
}
