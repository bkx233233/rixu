package com.example.rixu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.content.Intent
import android.app.PendingIntent

class NutritionWidgetProvider : android.appwidget.AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val data = context.getSharedPreferences("rixu_widgets", Context.MODE_PRIVATE)
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.nutrition_widget).apply {
                setTextViewText(R.id.widget_nutrition_calorie, data.getString("nutrition_calorie", "请先完善资料"))
                setTextViewText(R.id.widget_nutrition_macro, data.getString("nutrition_macro", "碳水 0g · 蛋白 0g · 脂肪 0g"))
                setProgressBar(R.id.widget_nutrition_calorie_progress, data.getInt("nutrition_calorie_target", 1).coerceAtLeast(1), data.getInt("nutrition_calorie_progress", 0).coerceAtLeast(0), false)
                setTextViewText(R.id.widget_nutrition_carbohydrate, "碳水 ${data.getInt("nutrition_carbohydrate", 0)}/${data.getInt("nutrition_carbohydrate_target", 0)}g")
                setTextViewText(R.id.widget_nutrition_protein, "蛋白 ${data.getInt("nutrition_protein", 0)}/${data.getInt("nutrition_protein_target", 0)}g")
                setTextViewText(R.id.widget_nutrition_fat, "脂肪 ${data.getInt("nutrition_fat", 0)}/${data.getInt("nutrition_fat_target", 0)}g")
                setOnClickPendingIntent(R.id.nutrition_widget_root, PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            manager.updateAppWidget(id, views)
        }
    }
}
