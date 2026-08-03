package com.example.rixu

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rixu/home_widgets").setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("rixu_widgets", MODE_PRIVATE)
            when (call.method) {
                "updateSchedule" -> prefs.edit()
                    .putString("schedule_title", call.argument<String>("title"))
                    .putString("schedule_detail", call.argument<String>("detail"))
                    .putString("schedule_next_title", call.argument<String>("nextTitle"))
                    .putString("schedule_next_detail", call.argument<String>("nextDetail"))
                    .putString("schedule_items", call.argument<String>("items"))
                    .putInt("schedule_completed", call.argument<Int>("completed") ?: 0)
                    .putInt("schedule_total", call.argument<Int>("total") ?: 0)
                    .apply()
                "updateNutrition" -> prefs.edit().putString("nutrition_calorie", call.argument<String>("calorie")).putString("nutrition_macro", call.argument<String>("macro")).putInt("nutrition_calorie_progress", call.argument<Int>("calorieProgress") ?: 0).putInt("nutrition_calorie_target", call.argument<Int>("calorieTarget") ?: 0).putInt("nutrition_carbohydrate", call.argument<Int>("carbohydrate") ?: 0).putInt("nutrition_carbohydrate_target", call.argument<Int>("carbohydrateTarget") ?: 0).putInt("nutrition_protein", call.argument<Int>("protein") ?: 0).putInt("nutrition_protein_target", call.argument<Int>("proteinTarget") ?: 0).putInt("nutrition_fat", call.argument<Int>("fat") ?: 0).putInt("nutrition_fat_target", call.argument<Int>("fatTarget") ?: 0).apply()
                else -> { result.notImplemented(); return@setMethodCallHandler }
            }
            listOf(ScheduleWidgetProvider::class.java, NutritionWidgetProvider::class.java).forEach { provider ->
                sendBroadcast(Intent(this, provider).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE).putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, AppWidgetManager.getInstance(this).getAppWidgetIds(ComponentName(this, provider))))
            }
            AppWidgetManager.getInstance(this).notifyAppWidgetViewDataChanged(AppWidgetManager.getInstance(this).getAppWidgetIds(ComponentName(this, ScheduleWidgetProvider::class.java)), R.id.widget_schedule_list)
            result.success(null)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rixu/alarms").setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> result.success(AlarmRegistry.schedule(this, call.argument<String>("eventId") ?: return@setMethodCallHandler, call.argument<String>("title") ?: "日程提醒", call.argument<Long>("triggerAt") ?: return@setMethodCallHandler))
                "cancel" -> { AlarmRegistry.cancel(this, call.argument<String>("eventId") ?: return@setMethodCallHandler); result.success(null) }
                "reconcile" -> { val ids = (call.argument<List<String>>("eventIds") ?: emptyList()); AlarmRegistry.reconcile(this, ids); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
}
