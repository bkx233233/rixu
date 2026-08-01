import 'package:supabase_flutter/supabase_flutter.dart';

class MealEntry {
  const MealEntry({
    required this.id,
    required this.mealType,
    required this.foodName,
    required this.amount,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
  });

  final String id;
  final String mealType;
  final String foodName;
  final double amount;
  final String unit;
  final double calories;
  final double protein;
  final double carbohydrate;
  final double fat;
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultAmount,
    required this.defaultUnit,
    required this.calories,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
  });

  final String id;
  final String name;
  final String category;
  final double defaultAmount;
  final String defaultUnit;
  final double calories;
  final double protein;
  final double carbohydrate;
  final double fat;
}

class WeightPoint {
  const WeightPoint({required this.date, required this.weight});

  final DateTime date;
  final double weight;
}

class HealthDayData {
  const HealthDayData(
      {required this.fitnessStatus,
      required this.weight,
      required this.meals,
      required this.exercises});

  final String fitnessStatus;
  final double? weight;
  final List<MealEntry> meals;
  final List<WorkoutExercise> exercises;
}

class WorkoutExercise {
  const WorkoutExercise(
      {required this.id,
      required this.name,
      required this.sets,
      required this.repetitions,
      required this.weight,
      required this.durationSeconds});

  final String id;
  final String name;
  final int? sets;
  final int? repetitions;
  final double? weight;
  final int? durationSeconds;
}

class HealthRepository {
  HealthRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<HealthDayData> loadDay(DateTime date) async {
    final day = _dateOnly(date);
    final profile = await _client
        .from('profiles')
        .select('default_fitness_status')
        .eq('id', _userId)
        .maybeSingle();
    final dayStatus = await _client
        .from('fitness_day_statuses')
        .select('status')
        .eq('user_id', _userId)
        .eq('local_date', day)
        .maybeSingle();
    final weightRow = await _client
        .from('body_weight_entries')
        .select('weight_kg')
        .eq('user_id', _userId)
        .eq('local_date', day)
        .maybeSingle();
    final mealRows = List<Map<String, dynamic>>.from(
      await _client
          .from('meal_entries')
          .select(
              'id,meal_type,food_name,amount,unit,calorie_kcal,protein_g,carbohydrate_g,fat_g')
          .eq('user_id', _userId)
          .eq('local_date', day)
          .order('created_at'),
    );
    final sessionRows = List<Map<String, dynamic>>.from(
      await _client
          .from('workout_sessions')
          .select('id')
          .eq('user_id', _userId)
          .eq('local_date', day)
          .neq('status', 'cancelled')
          .order('created_at')
          .limit(1),
    );
    final exerciseRows = sessionRows.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('workout_exercise_logs')
                .select(
                    'id,exercise_name,sets_count,repetitions,weight_kg,duration_seconds')
                .eq('session_id', sessionRows.first['id'] as String)
                .order('position'),
          );

    return HealthDayData(
      fitnessStatus: dayStatus?['status'] as String? ??
          profile?['default_fitness_status'] as String? ??
          'rest',
      weight: (weightRow?['weight_kg'] as num?)?.toDouble(),
      meals: mealRows.map(_mealFromRow).toList(),
      exercises: exerciseRows.map(_exerciseFromRow).toList(),
    );
  }

  Future<void> addExercise({
    required DateTime date,
    required String name,
    int? sets,
    int? repetitions,
    double? weight,
    int? durationSeconds,
  }) async {
    final day = _dateOnly(date);
    final statusRow = await _client
        .from('fitness_day_statuses')
        .select('status')
        .eq('user_id', _userId)
        .eq('local_date', day)
        .maybeSingle();
    final profile = await _client
        .from('profiles')
        .select('default_fitness_status')
        .eq('id', _userId)
        .maybeSingle();
    final status = statusRow?['status'] as String? ??
        profile?['default_fitness_status'] as String? ??
        'rest';
    if (status != 'training') {
      throw StateError('休息中不能添加训练动作。');
    }
    final sessions = List<Map<String, dynamic>>.from(
      await _client
          .from('workout_sessions')
          .select('id')
          .eq('user_id', _userId)
          .eq('local_date', day)
          .neq('status', 'cancelled')
          .order('created_at')
          .limit(1),
    );
    final sessionId = sessions.isEmpty
        ? (await _client
            .from('workout_sessions')
            .insert(
                {'user_id': _userId, 'local_date': day, 'status': 'planned'})
            .select('id')
            .single())['id'] as String
        : sessions.first['id'] as String;
    final countRows = await _client
        .from('workout_exercise_logs')
        .select('id')
        .eq('session_id', sessionId);
    await _client.from('workout_exercise_logs').insert({
      'session_id': sessionId,
      'exercise_name': name,
      'position': (countRows as List).length,
      'sets_count': sets,
      'repetitions': repetitions,
      'weight_kg': weight,
      'duration_seconds': durationSeconds,
    });
  }

  Future<List<WeightPoint>> loadRecentWeights({int days = 30}) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('body_weight_entries')
          .select('local_date,weight_kg')
          .eq('user_id', _userId)
          .order('local_date'),
    );
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return rows
        .map((row) => WeightPoint(
            date: DateTime.parse(row['local_date'] as String),
            weight: (row['weight_kg'] as num).toDouble()))
        .where((point) => !point.date
            .isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day)))
        .toList();
  }

  Future<List<FoodItem>> loadFoodItems() async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('food_items')
          .select(
              'id,name,category,default_amount,default_unit,calorie_kcal,protein_g,carbohydrate_g,fat_g')
          .eq('user_id', _userId)
          .eq('is_active', true)
          .order('name'),
    );
    return rows.map(_foodItemFromRow).toList();
  }

  Future<void> saveFoodItem({
    required String name,
    required String category,
    required double defaultAmount,
    required String defaultUnit,
    required double calories,
    required double protein,
    required double carbohydrate,
    required double fat,
  }) async {
    await _client.from('food_items').upsert(
      {
        'user_id': _userId,
        'name': name,
        'category': category,
        'default_amount': defaultAmount,
        'default_unit': defaultUnit,
        'calorie_kcal': calories,
        'protein_g': protein,
        'carbohydrate_g': carbohydrate,
        'fat_g': fat,
        'is_active': true,
      },
      onConflict: 'user_id,name',
    );
  }

  Future<void> deleteFoodItem(String foodItemId) async {
    await _client
        .from('food_items')
        .delete()
        .eq('id', foodItemId)
        .eq('user_id', _userId);
  }

  Future<void> setFitnessStatus(
      {required DateTime date, required String status}) async {
    await _client.from('fitness_day_statuses').upsert(
      {'user_id': _userId, 'local_date': _dateOnly(date), 'status': status},
      onConflict: 'user_id,local_date',
    );
  }

  Future<void> saveWeight(
      {required DateTime date, required double weight}) async {
    await _client.from('body_weight_entries').upsert(
      {'user_id': _userId, 'local_date': _dateOnly(date), 'weight_kg': weight},
      onConflict: 'user_id,local_date',
    );
  }

  Future<void> addMeal({
    required DateTime date,
    required String mealType,
    required String foodName,
    required double amount,
    required String unit,
    required double calories,
    required double protein,
    required double carbohydrate,
    required double fat,
    String? foodItemId,
  }) async {
    await _client.from('meal_entries').insert({
      'user_id': _userId,
      'local_date': _dateOnly(date),
      'meal_type': mealType,
      'food_name': foodName,
      'amount': amount,
      'unit': unit,
      'calorie_kcal': calories,
      'protein_g': protein,
      'carbohydrate_g': carbohydrate,
      'fat_g': fat,
      'food_item_id': foodItemId,
    });
  }

  MealEntry _mealFromRow(Map<String, dynamic> row) {
    return MealEntry(
      id: row['id'] as String,
      mealType: row['meal_type'] as String,
      foodName: row['food_name'] as String,
      amount: (row['amount'] as num).toDouble(),
      unit: row['unit'] as String,
      calories: (row['calorie_kcal'] as num).toDouble(),
      protein: (row['protein_g'] as num).toDouble(),
      carbohydrate: (row['carbohydrate_g'] as num).toDouble(),
      fat: (row['fat_g'] as num).toDouble(),
    );
  }

  WorkoutExercise _exerciseFromRow(Map<String, dynamic> row) {
    return WorkoutExercise(
      id: row['id'] as String,
      name: row['exercise_name'] as String,
      sets: row['sets_count'] as int?,
      repetitions: row['repetitions'] as int?,
      weight: (row['weight_kg'] as num?)?.toDouble(),
      durationSeconds: row['duration_seconds'] as int?,
    );
  }

  FoodItem _foodItemFromRow(Map<String, dynamic> row) {
    return FoodItem(
      id: row['id'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      defaultAmount: (row['default_amount'] as num).toDouble(),
      defaultUnit: row['default_unit'] as String,
      calories: (row['calorie_kcal'] as num).toDouble(),
      protein: (row['protein_g'] as num).toDouble(),
      carbohydrate: (row['carbohydrate_g'] as num).toDouble(),
      fat: (row['fat_g'] as num).toDouble(),
    );
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
