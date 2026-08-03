import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.title,
    required this.note,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  final String id;
  final String title;
  final String note;
  final DateTime startAt;
  final DateTime? endAt;
  final String status;

  bool get isCompleted => status == 'completed';
}

class PeriodGoal {
  const PeriodGoal({
    required this.id,
    required this.title,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String id;
  final String title;
  final String periodType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  bool get isCompleted => status == 'completed';
}

class ScheduleReminder {
  const ScheduleReminder({required this.id, required this.title, required this.startAt});
  final String id;
  final String title;
  final DateTime startAt;
}

class ScheduleRepository {
  ScheduleRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<List<ScheduleItem>> loadForDate(DateTime date) async {
    final localStart = DateTime(date.year, date.month, date.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final start = localStart.toUtc().toIso8601String();
    final end = localEnd.toUtc().toIso8601String();
    final localDate = _dateOnly(localStart);

    final eventRows = List<Map<String, dynamic>>.from(
      await _client
          .from('schedule_events')
          .select('id,title,note,start_at,end_at')
          .eq('user_id', _userId)
          .eq('is_active', true)
          .gte('start_at', start)
          .lt('start_at', end)
          .order('start_at', ascending: true),
    );
    final occurrenceRows = List<Map<String, dynamic>>.from(
      await _client
          .from('task_occurrences')
          .select('schedule_event_id,status')
          .eq('occurrence_date', localDate),
    );
    final statuses = <String, String>{
      for (final row in occurrenceRows)
        row['schedule_event_id'] as String: row['status'] as String,
    };

    final items = eventRows.map((row) {
      return ScheduleItem(
        id: row['id'] as String,
        title: row['title'] as String,
        note: row['note'] as String? ?? '',
        startAt: DateTime.parse(row['start_at'] as String).toLocal(),
        endAt: row['end_at'] == null
            ? null
            : DateTime.parse(row['end_at'] as String).toLocal(),
        status: statuses[row['id'] as String] ?? 'pending',
      );
    }).toList()
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
    return items;
  }

  Future<String> addTask({
    required String title,
    required String note,
    required DateTime startAt,
    DateTime? endAt,
  }) async {
    final result = await _client
        .from('schedule_events')
        .insert({
          'user_id': _userId,
          'title': title,
          'note': note,
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt?.toUtc().toIso8601String(),
          'is_task': true,
          'recurrence_type': 'none',
        })
        .select('id')
        .single();
    await _client.from('task_occurrences').insert({
      'schedule_event_id': result['id'],
      'occurrence_date': _dateOnly(startAt),
    });
    return result['id'] as String;
  }

  Future<void> setCompleted({
    required String eventId,
    required DateTime date,
    required bool completed,
  }) async {
    await _client.from('task_occurrences').upsert(
      {
        'schedule_event_id': eventId,
        'occurrence_date': _dateOnly(date),
        'status': completed ? 'completed' : 'pending',
        'completed_at':
            completed ? DateTime.now().toUtc().toIso8601String() : null,
      },
      onConflict: 'schedule_event_id,occurrence_date',
    );
  }

  Future<void> deleteTask(String eventId) async {
    await _client
        .from('schedule_events')
        .delete()
        .eq('id', eventId)
        .eq('user_id', _userId);
  }

  Future<List<ScheduleReminder>> loadFutureReminders() async {
    final rows = List<Map<String, dynamic>>.from(await _client
        .from('schedule_events')
        .select('id,title,start_at')
        .eq('user_id', _userId)
        .eq('is_active', true)
        .gte('start_at', DateTime.now().toUtc().toIso8601String())
        .order('start_at')
        .limit(100));
    return rows.map((row) => ScheduleReminder(id: row['id'] as String, title: row['title'] as String, startAt: DateTime.parse(row['start_at'] as String).toLocal())).toList();
  }

  Future<void> updateTask({
    required String eventId,
    required String title,
    required String note,
    required DateTime startAt,
    DateTime? endAt,
  }) async {
    await _client
        .from('schedule_events')
        .update({
          'title': title,
          'note': note,
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt?.toUtc().toIso8601String(),
        })
        .eq('id', eventId)
        .eq('user_id', _userId);
    await _client
        .from('task_occurrences')
        .update({'occurrence_date': _dateOnly(startAt)})
        .eq('schedule_event_id', eventId);
  }

  Future<String?> loadDailyReview(DateTime date) async {
    final row = await _client
        .from('daily_reviews')
        .select('summary')
        .eq('user_id', _userId)
        .eq('review_date', _dateOnly(date))
        .maybeSingle();
    return row?['summary'] as String?;
  }

  Future<void> saveDailyReview({
    required DateTime date,
    required String summary,
  }) async {
    await _client.from('daily_reviews').upsert(
      {
        'user_id': _userId,
        'review_date': _dateOnly(date),
        'summary': summary,
      },
      onConflict: 'user_id,review_date',
    );
  }

  Future<void> deleteDailyReview(DateTime date) async {
    await _client
        .from('daily_reviews')
        .delete()
        .eq('user_id', _userId)
        .eq('review_date', _dateOnly(date));
  }

  Future<List<PeriodGoal>> loadGoals(String periodType) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('period_goals')
          .select('id,title,period_type,start_date,end_date,status')
          .eq('user_id', _userId)
          .eq('period_type', periodType)
          .order('start_date'),
    );
    return rows
        .map(
          (row) => PeriodGoal(
            id: row['id'] as String,
            title: row['title'] as String,
            periodType: row['period_type'] as String,
            startDate: DateTime.parse(row['start_date'] as String),
            endDate: DateTime.parse(row['end_date'] as String),
            status: row['status'] as String,
          ),
        )
        .toList();
  }

  Future<void> addGoal({
    required String title,
    required String periodType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _client.from('period_goals').insert({
      'user_id': _userId,
      'title': title,
      'period_type': periodType,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
    });
  }

  Future<void> setGoalCompleted({
    required String goalId,
    required bool completed,
  }) async {
    await _client
        .from('period_goals')
        .update({
          'status': completed ? 'completed' : 'pending',
          'completed_at':
              completed ? DateTime.now().toUtc().toIso8601String() : null,
        })
        .eq('id', goalId)
        .eq('user_id', _userId);
  }

  Future<void> updateGoal({
    required String goalId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _client
        .from('period_goals')
        .update({
          'title': title,
          'start_date': _dateOnly(startDate),
          'end_date': _dateOnly(endDate),
        })
        .eq('id', goalId)
        .eq('user_id', _userId);
  }

  Future<void> deleteGoal(String goalId) async {
    await _client
        .from('period_goals')
        .delete()
        .eq('id', goalId)
        .eq('user_id', _userId);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
