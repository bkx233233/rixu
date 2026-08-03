import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/schedule/data/schedule_repository.dart';

class ScheduleNotificationService {
  ScheduleNotificationService._();
  static final instance = ScheduleNotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _alarmChannel = MethodChannel('rixu/alarms');

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> initialize() async {
    if (!_isAndroid) return;
    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone));
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> schedule({required String eventId, required String title, required DateTime startAt}) async {
    if (!_isAndroid || !startAt.isAfter(DateTime.now())) return;
    final scheduled = await _alarmChannel.invokeMethod<bool>('schedule', {
      'eventId': eventId,
      'title': title,
      'triggerAt': startAt.millisecondsSinceEpoch,
    });
    if (scheduled != true) throw StateError('未允许精确闹钟提醒，请在系统设置中开启。');
  }

  Future<void> cancel(String eventId) async {
    if (_isAndroid) await _alarmChannel.invokeMethod<void>('cancel', {'eventId': eventId});
  }

  Future<void> sync(List<ScheduleReminder> reminders) async {
    if (!_isAndroid) return;
    for (final reminder in reminders) {
      await schedule(eventId: reminder.id, title: reminder.title, startAt: reminder.startAt);
    }
    await _alarmChannel.invokeMethod<void>('reconcile', {'eventIds': reminders.map((item) => item.id).toList()});
  }
}
