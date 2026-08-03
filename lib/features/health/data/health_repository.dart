import 'package:supabase_flutter/supabase_flutter.dart';

class MealEntry {
  const MealEntry({required this.id, required this.mealType, required this.foodName, required this.amount, required this.unit, required this.calories, required this.protein, required this.carbohydrate, required this.fat});
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
  const FoodItem({required this.id, required this.name, required this.category, required this.caloriesPer100g, required this.proteinPer100g, required this.carbohydratePer100g, required this.fatPer100g, required this.isSystem, required this.sourceName, this.needsNutritionCompletion = false});
  final String id;
  final String name;
  final String category;
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbohydratePer100g;
  final double? fatPer100g;
  final bool isSystem;
  final String sourceName;
  final bool needsNutritionCompletion;
  double get defaultAmount => 100;
  String get defaultUnit => 'g';
  double get calories => caloriesPer100g ?? 0;
  double get protein => proteinPer100g ?? 0;
  double get carbohydrate => carbohydratePer100g ?? 0;
  double get fat => fatPer100g ?? 0;
  bool get isUsable => caloriesPer100g != null && proteinPer100g != null && carbohydratePer100g != null && fatPer100g != null;
  NutritionValues calculate(double grams) {
    if (!isUsable) throw StateError('这个食物缺少每 100 克营养数据，请先补充。');
    final factor = grams / 100;
    return NutritionValues(calories: caloriesPer100g! * factor, protein: proteinPer100g! * factor, carbohydrate: carbohydratePer100g! * factor, fat: fatPer100g! * factor);
  }
}

class NutritionValues {
  const NutritionValues({required this.calories, required this.protein, required this.carbohydrate, required this.fat});
  final double calories;
  final double protein;
  final double carbohydrate;
  final double fat;
  static const zero = NutritionValues(calories: 0, protein: 0, carbohydrate: 0, fat: 0);
  NutritionValues operator +(NutritionValues other) => NutritionValues(calories: calories + other.calories, protein: protein + other.protein, carbohydrate: carbohydrate + other.carbohydrate, fat: fat + other.fat);
}

class NutritionTarget extends NutritionValues {
  const NutritionTarget({required super.calories, required super.protein, required super.carbohydrate, required super.fat, required this.deficit, required this.mode});
  final int deficit;
  final String mode;
}

class ProfileData {
  const ProfileData({required this.heightCm, required this.sex, required this.birthDate, required this.activityLevel, required this.onboardingCompleted});
  final double? heightCm;
  final String? sex;
  final DateTime? birthDate;
  final String? activityLevel;
  final bool onboardingCompleted;
}

class WeightPoint { const WeightPoint({required this.date, required this.weight}); final DateTime date; final double weight; }

class WorkoutExercise {
  const WorkoutExercise({required this.id, required this.name, required this.sets, required this.repetitions, required this.weight, required this.durationSeconds});
  final String id; final String name; final int? sets; final int? repetitions; final double? weight; final int? durationSeconds;
}

class HealthDayData {
  const HealthDayData({required this.fitnessStatus, required this.weight, required this.meals, required this.exercises});
  final String fitnessStatus; final double? weight; final List<MealEntry> meals; final List<WorkoutExercise> exercises;
  NutritionValues get intake => meals.fold(NutritionValues.zero, (sum, item) => sum + NutritionValues(calories: item.calories, protein: item.protein, carbohydrate: item.carbohydrate, fat: item.fat));
}

class HealthRepository {
  HealthRepository(this._client);
  final SupabaseClient _client;
  String get _userId => _client.auth.currentUser!.id;

  Future<HealthDayData> loadDay(DateTime date) async {
    final day = _dateOnly(date);
    final profileRequest = _client.from('profiles').select('default_fitness_status').eq('id', _userId).maybeSingle();
    final statusRequest = _client.from('fitness_day_statuses').select('status').eq('user_id', _userId).eq('local_date', day).maybeSingle();
    final weightRequest = _client.from('body_weight_entries').select('weight_kg').eq('user_id', _userId).eq('local_date', day).maybeSingle();
    final mealRequest = _client.from('meal_entries').select('id,meal_type,food_name,amount,unit,calorie_kcal,protein_g,carbohydrate_g,fat_g').eq('user_id', _userId).eq('local_date', day).order('created_at');
    final sessionRequest = _client.from('workout_sessions').select('id').eq('user_id', _userId).eq('local_date', day).neq('status', 'cancelled').order('created_at').limit(1);
    final results = await Future.wait([profileRequest, statusRequest, weightRequest, mealRequest, sessionRequest]);
    final sessions = List<Map<String, dynamic>>.from(results[4] as List);
    final exercises = sessions.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await _client.from('workout_exercise_logs').select('id,exercise_name,sets_count,repetitions,weight_kg,duration_seconds').eq('session_id', sessions.first['id'] as String).order('position'));
    final meals = List<Map<String, dynamic>>.from(results[3] as List);
    final status = results[1] as Map<String, dynamic>?;
    final profile = results[0] as Map<String, dynamic>?;
    final weight = results[2] as Map<String, dynamic>?;
    return HealthDayData(fitnessStatus: status?['status'] as String? ?? profile?['default_fitness_status'] as String? ?? 'rest', weight: (weight?['weight_kg'] as num?)?.toDouble(), meals: meals.map(_mealFromRow).toList(), exercises: exercises.map(_exerciseFromRow).toList());
  }

  Future<ProfileData> loadProfile() async {
    final row = await _client.from('profiles').select('height_cm,sex,birth_date,activity_level,onboarding_completed').eq('id', _userId).single();
    return ProfileData(heightCm: (row['height_cm'] as num?)?.toDouble(), sex: row['sex'] as String?, birthDate: row['birth_date'] == null ? null : DateTime.parse(row['birth_date'] as String), activityLevel: row['activity_level'] as String?, onboardingCompleted: row['onboarding_completed'] as bool? ?? false);
  }

  Future<NutritionTarget?> loadNutritionTarget() async {
    final row = await _client.from('nutrition_targets').select('calorie_kcal,protein_g,carbohydrate_g,fat_g,daily_calorie_deficit_kcal,calculation_mode').eq('user_id', _userId).maybeSingle();
    if (row == null || row['calorie_kcal'] == null) return null;
    return NutritionTarget(calories: (row['calorie_kcal'] as num).toDouble(), protein: (row['protein_g'] as num?)?.toDouble() ?? 0, carbohydrate: (row['carbohydrate_g'] as num?)?.toDouble() ?? 0, fat: (row['fat_g'] as num?)?.toDouble() ?? 0, deficit: (row['daily_calorie_deficit_kcal'] as num?)?.toInt() ?? 0, mode: row['calculation_mode'] as String? ?? 'calculated');
  }

  Future<void> saveProfileAndTarget({required double heightCm, required String sex, required DateTime birthDate, required String activityLevel, required double currentWeightKg, required NutritionTarget target}) async {
    await Future.wait([
      _client.from('profiles').update({'height_cm': heightCm, 'sex': sex, 'birth_date': _dateOnly(birthDate), 'activity_level': activityLevel, 'onboarding_completed': true}).eq('id', _userId),
      saveWeight(date: DateTime.now(), weight: currentWeightKg),
      saveNutritionTarget(target),
    ]);
  }

  Future<void> saveNutritionTarget(NutritionTarget target) => _client.from('nutrition_targets').upsert({'user_id': _userId, 'calorie_kcal': target.calories.round(), 'protein_g': target.protein, 'carbohydrate_g': target.carbohydrate, 'fat_g': target.fat, 'daily_calorie_deficit_kcal': target.deficit, 'calculation_mode': target.mode});

  Future<List<WeightPoint>> loadRecentWeights({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days - 1));
    final rows = List<Map<String, dynamic>>.from(await _client.from('body_weight_entries').select('local_date,weight_kg').eq('user_id', _userId).gte('local_date', _dateOnly(cutoff)).order('local_date'));
    return rows.map((row) => WeightPoint(date: DateTime.parse(row['local_date'] as String), weight: (row['weight_kg'] as num).toDouble())).toList();
  }

  Future<List<FoodItem>> loadFoodItems() async {
    final results = await Future.wait([
      _client.from('food_items').select('id,name,category,calories_per_100g,protein_per_100g,carbohydrate_per_100g,fat_per_100g,source_name').eq('user_id', _userId).eq('is_active', true).order('name'),
      _client.from('system_food_items').select('id,name,category,calories_per_100g,protein_per_100g,carbohydrate_per_100g,fat_per_100g,source_name').eq('is_active', true).order('name'),
    ]);
    return [...List<Map<String, dynamic>>.from(results[0] as List).map((row) => _foodFromRow(row, false)), ...List<Map<String, dynamic>>.from(results[1] as List).map((row) => _foodFromRow(row, true))]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> saveFoodItem({String? id, required String name, required String category, double? caloriesPer100g, double? proteinPer100g, double? carbohydratePer100g, double? fatPer100g, double? defaultAmount, String? defaultUnit, double? calories, double? protein, double? carbohydrate, double? fat}) async {
    final basis = defaultAmount ?? 100;
    final factor = 100 / basis;
    final per100Calories = caloriesPer100g ?? (calories ?? 0) * factor;
    final per100Protein = proteinPer100g ?? (protein ?? 0) * factor;
    final per100Carbohydrate = carbohydratePer100g ?? (carbohydrate ?? 0) * factor;
    final per100Fat = fatPer100g ?? (fat ?? 0) * factor;
    final values = {'user_id': _userId, 'name': name, 'category': category, 'default_amount': 100, 'default_unit': 'g', 'calorie_kcal': per100Calories, 'protein_g': per100Protein, 'carbohydrate_g': per100Carbohydrate, 'fat_g': per100Fat, 'calories_per_100g': per100Calories, 'protein_per_100g': per100Protein, 'carbohydrate_per_100g': per100Carbohydrate, 'fat_per_100g': per100Fat, 'source_name': '个人录入', 'is_active': true};
    if (id == null) { await _client.from('food_items').insert(values); } else { await _client.from('food_items').update(values).eq('id', id).eq('user_id', _userId); }
  }

  Future<void> deleteFoodItem(String id) => _client.from('food_items').delete().eq('id', id).eq('user_id', _userId);
  Future<void> setFitnessStatus({required DateTime date, required String status}) => _client.from('fitness_day_statuses').upsert({'user_id': _userId, 'local_date': _dateOnly(date), 'status': status}, onConflict: 'user_id,local_date');
  Future<void> saveWeight({required DateTime date, required double weight}) => _client.from('body_weight_entries').upsert({'user_id': _userId, 'local_date': _dateOnly(date), 'weight_kg': weight}, onConflict: 'user_id,local_date');
  Future<void> deleteWeight(DateTime date) => _client.from('body_weight_entries').delete().eq('user_id', _userId).eq('local_date', _dateOnly(date));

  Future<void> addMeal({required DateTime date, required String mealType, required String foodName, required double amount, required String unit, required double calories, required double protein, required double carbohydrate, required double fat, String? foodItemId}) => _client.from('meal_entries').insert({'user_id': _userId, ..._mealValues(date: date, mealType: mealType, foodName: foodName, amount: amount, unit: unit, calories: calories, protein: protein, carbohydrate: carbohydrate, fat: fat, foodItemId: foodItemId)});
  Future<void> updateMeal({required String id, required DateTime date, required String mealType, required String foodName, required double amount, required String unit, required double calories, required double protein, required double carbohydrate, required double fat, String? foodItemId}) => _client.from('meal_entries').update(_mealValues(date: date, mealType: mealType, foodName: foodName, amount: amount, unit: unit, calories: calories, protein: protein, carbohydrate: carbohydrate, fat: fat, foodItemId: foodItemId)).eq('id', id).eq('user_id', _userId);
  Future<void> deleteMeal(String id) => _client.from('meal_entries').delete().eq('id', id).eq('user_id', _userId);

  Future<void> addExercise({required DateTime date, required String name, int? sets, int? repetitions, double? weight, int? durationSeconds}) async {
    final day = _dateOnly(date);
    final status = await _client.from('fitness_day_statuses').select('status').eq('user_id', _userId).eq('local_date', day).maybeSingle();
    if (status?['status'] != 'training') throw StateError('休息中不能添加训练动作。');
    final sessions = List<Map<String, dynamic>>.from(await _client.from('workout_sessions').select('id').eq('user_id', _userId).eq('local_date', day).neq('status', 'cancelled').order('created_at').limit(1));
    final sessionId = sessions.isEmpty ? (await _client.from('workout_sessions').insert({'user_id': _userId, 'local_date': day, 'status': 'planned'}).select('id').single())['id'] as String : sessions.first['id'] as String;
    final logs = await _client.from('workout_exercise_logs').select('id').eq('session_id', sessionId);
    await _client.from('workout_exercise_logs').insert({'session_id': sessionId, 'exercise_name': name, 'position': (logs as List).length, 'sets_count': sets, 'repetitions': repetitions, 'weight_kg': weight, 'duration_seconds': durationSeconds});
  }
  Future<void> updateExercise({required String id, required String name, int? sets, int? repetitions, double? weight, int? durationSeconds}) => _client.from('workout_exercise_logs').update({'exercise_name': name, 'sets_count': sets, 'repetitions': repetitions, 'weight_kg': weight, 'duration_seconds': durationSeconds}).eq('id', id);
  Future<void> deleteExercise(String id) => _client.from('workout_exercise_logs').delete().eq('id', id);

  Map<String, dynamic> _mealValues({required DateTime date, required String mealType, required String foodName, required double amount, required String unit, required double calories, required double protein, required double carbohydrate, required double fat, String? foodItemId}) => {'local_date': _dateOnly(date), 'meal_type': mealType, 'food_name': foodName, 'amount': amount, 'unit': unit, 'calorie_kcal': calories, 'protein_g': protein, 'carbohydrate_g': carbohydrate, 'fat_g': fat, 'food_item_id': foodItemId};
  MealEntry _mealFromRow(Map<String, dynamic> row) => MealEntry(id: row['id'] as String, mealType: row['meal_type'] as String, foodName: row['food_name'] as String, amount: (row['amount'] as num).toDouble(), unit: row['unit'] as String, calories: (row['calorie_kcal'] as num).toDouble(), protein: (row['protein_g'] as num).toDouble(), carbohydrate: (row['carbohydrate_g'] as num).toDouble(), fat: (row['fat_g'] as num).toDouble());
  WorkoutExercise _exerciseFromRow(Map<String, dynamic> row) => WorkoutExercise(id: row['id'] as String, name: row['exercise_name'] as String, sets: row['sets_count'] as int?, repetitions: row['repetitions'] as int?, weight: (row['weight_kg'] as num?)?.toDouble(), durationSeconds: row['duration_seconds'] as int?);
  FoodItem _foodFromRow(Map<String, dynamic> row, bool system) => FoodItem(id: row['id'] as String, name: row['name'] as String, category: row['category'] as String, caloriesPer100g: (row['calories_per_100g'] as num?)?.toDouble(), proteinPer100g: (row['protein_per_100g'] as num?)?.toDouble(), carbohydratePer100g: (row['carbohydrate_per_100g'] as num?)?.toDouble(), fatPer100g: (row['fat_per_100g'] as num?)?.toDouble(), isSystem: system, sourceName: row['source_name'] as String? ?? '个人录入', needsNutritionCompletion: !system && row['calories_per_100g'] == null);
  String _dateOnly(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
