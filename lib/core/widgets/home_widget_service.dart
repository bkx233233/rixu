import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/health/data/health_repository.dart';
import '../../features/schedule/data/schedule_repository.dart';

class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();
  static const _channel = MethodChannel('rixu/home_widgets');

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> updateSchedule(List<ScheduleItem> items) async {
    if (!_isAndroid) return;
    final completed = items.where((item) => item.isCompleted).length;
    ScheduleItem? next;
    for (final item in items) {
      if (!item.isCompleted) {
        next = item;
        break;
      }
    }
    await _channel.invokeMethod('updateSchedule', {
      'title': items.isEmpty ? '今日暂无日程' : '今日日程 · $completed/${items.length} 已完成',
      'detail': next == null ? '今日任务已全部完成' : '下一项：${next.title}',
      'nextTitle': next?.title ?? (items.isEmpty ? '打开日序添加任务' : '今日任务已全部完成'),
      'nextDetail': next == null
          ? (items.isEmpty ? '打开日序添加任务' : '做得不错，明天继续。')
          : '${next.startAt.hour.toString().padLeft(2, '0')}:${next.startAt.minute.toString().padLeft(2, '0')} 开始',
      'completed': completed,
      'total': items.length,
      'items': jsonEncode([
        for (final item in items)
          {
            'id': item.id,
            'time': '${item.startAt.hour.toString().padLeft(2, '0')}:${item.startAt.minute.toString().padLeft(2, '0')}',
            'title': item.title,
            'completed': item.isCompleted,
          },
      ]),
    });
  }

  Future<void> updateNutrition(HealthDayData data, NutritionTarget? target) async {
    if (!_isAndroid) return;
    final intake = data.intake;
    final calorie = target == null ? '请在“我的”完善资料' : '已摄入 ${intake.calories.round()} / ${target.calories.round()} 千卡';
    await _channel.invokeMethod('updateNutrition', {
      'calorie': calorie,
      'macro': '碳水 ${intake.carbohydrate.round()}g · 蛋白 ${intake.protein.round()}g · 脂肪 ${intake.fat.round()}g',
      'calorieProgress': intake.calories.round(),
      'calorieTarget': target?.calories.round() ?? 0,
      'carbohydrate': intake.carbohydrate.round(),
      'carbohydrateTarget': target?.carbohydrate.round() ?? 0,
      'protein': intake.protein.round(),
      'proteinTarget': target?.protein.round() ?? 0,
      'fat': intake.fat.round(),
      'fatTarget': target?.fat.round() ?? 0,
    });
  }
}
