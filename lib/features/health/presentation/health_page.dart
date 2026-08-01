import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/feedback/user_message.dart';
import '../data/health_repository.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final _repository = HealthRepository(Supabase.instance.client);
  DateTime _selectedDate = DateTime.now();
  late Future<HealthDayData> _dayFuture;
  late Future<List<WeightPoint>> _weightsFuture;
  late Future<List<FoodItem>> _foodItemsFuture;
  late final RealtimeChannel _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _reload();
    _listenForChanges();
  }

  void _listenForChanges() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    _realtimeChannel = client
        .channel('health:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fitness_day_statuses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _reloadFromCloud(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'workout_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _reloadFromCloud(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'workout_exercise_logs',
          callback: (_) => _reloadFromCloud(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meal_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _reloadFromCloud(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'body_weight_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _reloadFromCloud(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'food_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _reloadFromCloud(),
        )
        .subscribe();
  }

  void _reloadFromCloud() {
    if (mounted) {
      setState(_reload);
    }
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_realtimeChannel);
    super.dispose();
  }

  void _reload() {
    _dayFuture = _repository.loadDay(_selectedDate);
    _weightsFuture = _repository.loadRecentWeights();
    _foodItemsFuture = _repository.loadFoodItems();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _selectedDate,
    );
    if (date == null) return;
    setState(() {
      _selectedDate = date;
      _reload();
    });
  }

  Future<void> _changeStatus(String status) async {
    try {
      await _repository.setFitnessStatus(date: _selectedDate, status: status);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(status == 'training' ? '已切换为健身中。' : '已切换为休息中。')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _saveWeight() async {
    final value =
        await _numberDialog(title: '记录体重（kg）', label: '体重', allowDecimal: true);
    if (value == null) return;
    try {
      await _repository.saveWeight(date: _selectedDate, weight: value);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('体重已保存。')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _addMeal() async {
    final draft = await showDialog<_MealDraft>(
      context: context,
      builder: (_) => _MealDialog(foodItemsFuture: _foodItemsFuture),
    );
    if (draft == null) return;
    try {
      await _repository.addMeal(
        date: _selectedDate,
        mealType: draft.mealType,
        foodName: draft.foodName,
        amount: draft.amount,
        unit: draft.unit,
        calories: draft.calories,
        protein: draft.protein,
        carbohydrate: draft.carbohydrate,
        fat: draft.fat,
        foodItemId: draft.foodItemId,
      );
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('饮食已保存。')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _manageFoodItems() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FoodLibraryDialog(repository: _repository),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _addExercise() async {
    final draft = await showDialog<_ExerciseDraft>(
      context: context,
      builder: (_) => const _ExerciseDialog(),
    );
    if (draft == null) return;
    try {
      await _repository.addExercise(
        date: _selectedDate,
        name: draft.name,
        sets: draft.sets,
        repetitions: draft.repetitions,
        weight: draft.weight,
        durationSeconds: draft.durationSeconds,
      );
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('训练动作已保存。')));
      }
    } catch (error) {
      if (mounted) {
        _showError(error, fallback: '训练动作保存失败，请确认今天是健身中，并完成训练数据库迁移。');
      }
    }
  }

  Future<double?> _numberDialog(
      {required String title,
      required String label,
      required bool allowDecimal}) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.pop(context, parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  void _showError(Object error, {String fallback = '保存失败，请稍后重试。'}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(toChineseError(error, fallback: fallback))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HealthDayData>(
      future: _dayFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text(toChineseError(snapshot.error!,
                  fallback: '暂时无法读取健康记录，请稍后重试。')));
        }
        final data = snapshot.data!;
        final calories =
            data.meals.fold<double>(0, (sum, meal) => sum + meal.calories);
        final protein =
            data.meals.fold<double>(0, (sum, meal) => sum + meal.protein);
        final carbohydrate =
            data.meals.fold<double>(0, (sum, meal) => sum + meal.carbohydrate);
        final fat = data.meals.fold<double>(0, (sum, meal) => sum + meal.fat);
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(
                          DateFormat('yyyy年MM月dd日').format(_selectedDate),
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: '选择日期',
                      onPressed: _chooseDate,
                      icon: const Icon(Icons.calendar_month_outlined)),
                ],
              ),
              _SectionCard(
                title: '今日训练状态',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'training',
                            label: Text('健身中'),
                            icon: Icon(Icons.fitness_center)),
                        ButtonSegment(
                            value: 'rest',
                            label: Text('休息中'),
                            icon: Icon(Icons.hotel)),
                      ],
                      selected: {data.fitnessStatus},
                      onSelectionChanged: (value) => _changeStatus(value.first),
                    ),
                    const SizedBox(height: 12),
                    if (data.fitnessStatus == 'rest')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Text('休息中~不需要规划健身任务。'),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data.exercises.isEmpty)
                            const Text('今天还没有训练动作。')
                          else
                            ...data.exercises.map((exercise) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.fitness_center),
                                  title: Text(exercise.name),
                                  subtitle: Text(_exerciseSummary(exercise)),
                                )),
                          const SizedBox(height: 6),
                          FilledButton.tonalIcon(
                            onPressed: _addExercise,
                            icon: const Icon(Icons.add),
                            label: const Text('添加训练动作'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              _SectionCard(
                title: '今日饮食',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '管理常用食物',
                      onPressed: _manageFoodItems,
                      icon: const Icon(Icons.restaurant_menu_outlined),
                    ),
                    IconButton(
                      tooltip: '添加饮食',
                      onPressed: _addMeal,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${calories.toStringAsFixed(0)} 千卡  ·  蛋白质 ${protein.toStringAsFixed(1)}g  ·  碳水 ${carbohydrate.toStringAsFixed(1)}g  ·  脂肪 ${fat.toStringAsFixed(1)}g'),
                    const SizedBox(height: 8),
                    if (data.meals.isEmpty)
                      const Text('还没有饮食记录。')
                    else
                      ...data.meals.map((meal) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                '${_mealLabel(meal.mealType)} · ${meal.foodName}'),
                            subtitle: Text(
                                '${meal.amount}${meal.unit} · ${meal.calories.toStringAsFixed(0)} 千卡'),
                          )),
                  ],
                ),
              ),
              _SectionCard(
                title: '今日体重',
                trailing: IconButton(
                    tooltip: '记录体重',
                    onPressed: _saveWeight,
                    icon: const Icon(Icons.edit_outlined)),
                child: Text(data.weight == null
                    ? '今天未记录体重。'
                    : '${data.weight!.toStringAsFixed(1)} kg'),
              ),
              FutureBuilder<List<WeightPoint>>(
                future: _weightsFuture,
                builder: (context, snapshot) {
                  final points = snapshot.data ?? const <WeightPoint>[];
                  if (points.length < 2) return const SizedBox.shrink();
                  final min = points
                      .map((point) => point.weight)
                      .reduce((a, b) => a < b ? a : b);
                  final max = points
                      .map((point) => point.weight)
                      .reduce((a, b) => a > b ? a : b);
                  return _SectionCard(
                    title: '近 30 天体重趋势',
                    child: SizedBox(
                      height: 190,
                      child: LineChart(
                        LineChartData(
                          minY: min - 1,
                          maxY: max + 1,
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (var i = 0; i < points.length; i++)
                                  FlSpot(i.toDouble(), points[i].weight)
                              ],
                              isCurved: true,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                          titlesData: const FlTitlesData(show: false),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _mealLabel(String value) => switch (value) {
        'breakfast' => '早餐',
        'lunch' => '午餐',
        'dinner' => '晚餐',
        _ => '加餐',
      };

  String _exerciseSummary(WorkoutExercise exercise) {
    final parts = <String>[];
    if (exercise.sets != null) parts.add('${exercise.sets} 组');
    if (exercise.repetitions != null) parts.add('${exercise.repetitions} 次');
    if (exercise.weight != null)
      parts.add('${exercise.weight!.toStringAsFixed(1)} kg');
    if (exercise.durationSeconds != null)
      parts.add('${exercise.durationSeconds} 秒');
    return parts.isEmpty ? '未填写训练参数' : parts.join(' · ');
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium)),
              if (trailing != null) trailing!
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MealDraft {
  const _MealDraft(
      {required this.mealType,
      required this.foodName,
      required this.amount,
      required this.unit,
      required this.calories,
      required this.protein,
      required this.carbohydrate,
      required this.fat,
      this.foodItemId});

  final String mealType;
  final String foodName;
  final double amount;
  final String unit;
  final double calories;
  final double protein;
  final double carbohydrate;
  final double fat;
  final String? foodItemId;
}

class _ExerciseDraft {
  const _ExerciseDraft(
      {required this.name,
      this.sets,
      this.repetitions,
      this.weight,
      this.durationSeconds});

  final String name;
  final int? sets;
  final int? repetitions;
  final double? weight;
  final int? durationSeconds;
}

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog();

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  static const _actionsByBodyPart = <String, List<String>>{
    '胸': ['卧推', '上斜哑铃卧推', '俯卧撑', '夹胸'],
    '背': ['高位下拉', '坐姿划船', '引体向上', '硬拉'],
    '肩': ['推举', '侧平举', '面拉', '俯身飞鸟'],
    '手臂': ['二头弯举', '锤式弯举', '绳索下压', '臂屈伸'],
    '腿': ['深蹲', '腿举', '箭步蹲', '腿弯举', '提踵'],
    '臀': ['臀桥', '臀推', '罗马尼亚硬拉', '保加利亚分腿蹲'],
    '核心': ['平板支撑', '卷腹', '举腿', '俄罗斯转体'],
    '有氧': ['跑步', '骑行', '跳绳', '椭圆机'],
  };

  static const _setRepOptions = [
    (sets: 3, repetitions: 8),
    (sets: 3, repetitions: 10),
    (sets: 3, repetitions: 12),
    (sets: 4, repetitions: 8),
    (sets: 4, repetitions: 10),
    (sets: 4, repetitions: 12),
    (sets: 5, repetitions: 5),
    (sets: 5, repetitions: 10),
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _setsController = TextEditingController();
  final _repetitionsController = TextEditingController();
  final _weightController = TextEditingController();
  final _durationController = TextEditingController();
  String _selectedBodyPart = '胸';
  String? _selectedAction;
  ({int sets, int repetitions})? _selectedSetRep;

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _setsController,
      _repetitionsController,
      _weightController,
      _durationController
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ExerciseDraft(
        name: _nameController.text.trim(),
        sets: int.tryParse(_setsController.text.trim()),
        repetitions: int.tryParse(_repetitionsController.text.trim()),
        weight: double.tryParse(_weightController.text.trim()),
        durationSeconds: int.tryParse(_durationController.text.trim()),
      ),
    );
  }

  void _selectAction(String action) {
    setState(() {
      _selectedAction = action;
      _nameController.text = action;
    });
  }

  void _selectSetRep(({int sets, int repetitions}) option) {
    setState(() {
      _selectedSetRep = option;
      _setsController.text = option.sets.toString();
      _repetitionsController.text = option.repetitions.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加训练动作'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('训练部位'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final bodyPart in _actionsByBodyPart.keys)
                    ChoiceChip(
                      label: Text(bodyPart),
                      selected: _selectedBodyPart == bodyPart,
                      onSelected: (_) => setState(() {
                        _selectedBodyPart = bodyPart;
                        _selectedAction = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('常用动作'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final action in _actionsByBodyPart[_selectedBodyPart]!)
                    ChoiceChip(
                      label: Text(action),
                      selected: _selectedAction == action,
                      onSelected: (_) => _selectAction(action),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '动作名称（可自定义）'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入动作名称。' : null,
              ),
              const SizedBox(height: 14),
              const Text('常用组次数'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final option in _setRepOptions)
                    ChoiceChip(
                      label: Text('${option.sets} × ${option.repetitions}'),
                      selected: _selectedSetRep == option,
                      onSelected: (_) => _selectSetRep(option),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _setsController,
                      decoration: const InputDecoration(labelText: '组数（可选）'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _selectedSetRep = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _repetitionsController,
                      decoration: const InputDecoration(labelText: '每组次数（可选）'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _selectedSetRep = null),
                    ),
                  ),
                ],
              ),
              TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(labelText: '重量 kg（可选）'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(labelText: '时长 秒（可选）'),
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _MealDialog extends StatefulWidget {
  const _MealDialog({required this.foodItemsFuture});

  final Future<List<FoodItem>> foodItemsFuture;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  final _formKey = GlobalKey<FormState>();
  final _foodController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: '份');
  final _calorieController = TextEditingController();
  final _proteinController = TextEditingController(text: '0');
  final _carbohydrateController = TextEditingController(text: '0');
  final _fatController = TextEditingController(text: '0');
  String _mealType = 'breakfast';
  FoodItem? _selectedFood;

  @override
  void dispose() {
    for (final controller in [
      _foodController,
      _amountController,
      _unitController,
      _calorieController,
      _proteinController,
      _carbohydrateController,
      _fatController
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  String? _nonNegativeValidator(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return '请输入非负数字。';
    return null;
  }

  void _selectFood(FoodItem? food) {
    setState(() {
      _selectedFood = food;
      if (food != null) _applyFood(food, food.defaultAmount);
    });
  }

  void _applyFood(FoodItem food, double amount) {
    final ratio = amount / food.defaultAmount;
    _foodController.text = food.name;
    _amountController.text = amount.toStringAsFixed(1);
    _unitController.text = food.defaultUnit;
    _calorieController.text = (food.calories * ratio).toStringAsFixed(1);
    _proteinController.text = (food.protein * ratio).toStringAsFixed(1);
    _carbohydrateController.text =
        (food.carbohydrate * ratio).toStringAsFixed(1);
    _fatController.text = (food.fat * ratio).toStringAsFixed(1);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final values = [
      _number(_amountController),
      _number(_calorieController),
      _number(_proteinController),
      _number(_carbohydrateController),
      _number(_fatController)
    ];
    if (values.any((value) => value == null || value < 0) || values[0] == 0)
      return;
    Navigator.pop(
        context,
        _MealDraft(
            mealType: _mealType,
            foodName: _foodController.text.trim(),
            amount: values[0]!,
            unit: _unitController.text.trim(),
            calories: values[1]!,
            protein: values[2]!,
            carbohydrate: values[3]!,
            fat: values[4]!,
            foodItemId: _selectedFood?.id));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加饮食记录'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                  value: _mealType,
                  decoration: const InputDecoration(labelText: '餐次'),
                  items: const [
                    DropdownMenuItem(value: 'breakfast', child: Text('早餐')),
                    DropdownMenuItem(value: 'lunch', child: Text('午餐')),
                    DropdownMenuItem(value: 'dinner', child: Text('晚餐')),
                    DropdownMenuItem(value: 'snack', child: Text('加餐'))
                  ],
                  onChanged: (value) => setState(() => _mealType = value!)),
              FutureBuilder<List<FoodItem>>(
                future: widget.foodItemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(toChineseError(snapshot.error!,
                          fallback: '暂时无法读取常用食物，可手动填写。')),
                    );
                  }
                  final foods = snapshot.data ?? const <FoodItem>[];
                  return DropdownButtonFormField<String?>(
                    value: _selectedFood?.id,
                    decoration: const InputDecoration(labelText: '选择常用食物'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('手动填写'),
                      ),
                      for (final food in foods)
                        DropdownMenuItem<String?>(
                          value: food.id,
                          child: Text('${food.name} · ${food.category}'),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) {
                        _selectFood(null);
                        return;
                      }
                      _selectFood(foods.firstWhere((food) => food.id == id));
                    },
                  );
                },
              ),
              TextFormField(
                  controller: _foodController,
                  decoration: const InputDecoration(labelText: '食物名称'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '请输入食物名称。'
                      : null),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(labelText: '份量'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          final amount = double.tryParse(value?.trim() ?? '');
                          return amount == null || amount <= 0
                              ? '请输入大于 0 的数字。'
                              : null;
                        },
                        onChanged: (value) {
                          final amount = double.tryParse(value);
                          final food = _selectedFood;
                          if (food != null && amount != null && amount > 0) {
                            _applyFood(food, amount);
                          }
                        })),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(labelText: '单位'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? '请输入单位。'
                                : null))
              ]),
              TextFormField(
                  controller: _calorieController,
                  decoration: const InputDecoration(labelText: '热量（千卡）'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: _nonNegativeValidator),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _proteinController,
                        decoration: const InputDecoration(labelText: '蛋白质 g'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: _nonNegativeValidator)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: _carbohydrateController,
                        decoration: const InputDecoration(labelText: '碳水 g'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: _nonNegativeValidator)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: _fatController,
                        decoration: const InputDecoration(labelText: '脂肪 g'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: _nonNegativeValidator))
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存'))
      ],
    );
  }
}

class _FoodLibraryDialog extends StatefulWidget {
  const _FoodLibraryDialog({required this.repository});

  final HealthRepository repository;

  @override
  State<_FoodLibraryDialog> createState() => _FoodLibraryDialogState();
}

class _FoodLibraryDialogState extends State<_FoodLibraryDialog> {
  late Future<List<FoodItem>> _foodItemsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _foodItemsFuture = widget.repository.loadFoodItems();
  }

  Future<void> _addFoodItem() async {
    final draft = await showDialog<_FoodItemDraft>(
      context: context,
      builder: (_) => const _FoodItemEditor(),
    );
    if (draft == null) return;
    try {
      await widget.repository.saveFoodItem(
        name: draft.name,
        category: draft.category,
        defaultAmount: draft.defaultAmount,
        defaultUnit: draft.defaultUnit,
        calories: draft.calories,
        protein: draft.protein,
        carbohydrate: draft.carbohydrate,
        fat: draft.fat,
      );
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('常用食物已保存。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(toChineseError(error, fallback: '常用食物保存失败，请稍后重试。'))),
        );
      }
    }
  }

  Future<void> _deleteFoodItem(FoodItem food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除常用食物'),
        content: Text('确认删除“${food.name}”？历史饮食记录不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteFoodItem(food.id);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('常用食物已删除。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(toChineseError(error, fallback: '常用食物删除失败，请稍后重试。'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('我的常用食物'),
      content: SizedBox(
        width: 460,
        height: 360,
        child: FutureBuilder<List<FoodItem>>(
          future: _foodItemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  toChineseError(snapshot.error!, fallback: '暂时无法读取常用食物。'),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final foods = snapshot.data ?? const <FoodItem>[];
            if (foods.isEmpty) {
              return const Center(child: Text('还没有常用食物，点击下方按钮添加。'));
            }
            return ListView.separated(
              itemCount: foods.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final food = foods[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(food.name),
                  subtitle: Text(
                    '${food.category} · ${food.defaultAmount.toStringAsFixed(1)}${food.defaultUnit} · ${food.calories.toStringAsFixed(0)} 千卡',
                  ),
                  trailing: IconButton(
                    tooltip: '删除常用食物',
                    onPressed: () => _deleteFoodItem(food),
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: _addFoodItem,
          icon: const Icon(Icons.add),
          label: const Text('添加食物'),
        ),
      ],
    );
  }
}

class _FoodItemDraft {
  const _FoodItemDraft({
    required this.name,
    required this.category,
    required this.defaultAmount,
    required this.defaultUnit,
    required this.calories,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
  });

  final String name;
  final String category;
  final double defaultAmount;
  final String defaultUnit;
  final double calories;
  final double protein;
  final double carbohydrate;
  final double fat;
}

class _FoodItemEditor extends StatefulWidget {
  const _FoodItemEditor();

  @override
  State<_FoodItemEditor> createState() => _FoodItemEditorState();
}

class _FoodItemEditorState extends State<_FoodItemEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '100');
  final _unitController = TextEditingController(text: 'g');
  final _calorieController = TextEditingController();
  final _proteinController = TextEditingController(text: '0');
  final _carbohydrateController = TextEditingController(text: '0');
  final _fatController = TextEditingController(text: '0');
  String _category = '其他';

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _amountController,
      _unitController,
      _calorieController,
      _proteinController,
      _carbohydrateController,
      _fatController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  String? _numberValidator(String? value, {bool positive = false}) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number < 0 || (positive && number == 0)) {
      return '请输入有效数字。';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _FoodItemDraft(
        name: _nameController.text.trim(),
        category: _category,
        defaultAmount: _number(_amountController)!,
        defaultUnit: _unitController.text.trim(),
        calories: _number(_calorieController)!,
        protein: _number(_proteinController)!,
        carbohydrate: _number(_carbohydrateController)!,
        fat: _number(_fatController)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加常用食物'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '食物名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入食物名称。' : null,
              ),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: '分类'),
                items: const [
                  DropdownMenuItem(value: '主食', child: Text('主食')),
                  DropdownMenuItem(value: '肉蛋奶', child: Text('肉蛋奶')),
                  DropdownMenuItem(value: '蔬菜水果', child: Text('蔬菜水果')),
                  DropdownMenuItem(value: '饮品', child: Text('饮品')),
                  DropdownMenuItem(value: '零食', child: Text('零食')),
                  DropdownMenuItem(value: '其他', child: Text('其他')),
                ],
                onChanged: (value) => setState(() => _category = value!),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: '基准份量'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) =>
                          _numberValidator(value, positive: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: '单位'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入单位。'
                              : null,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _calorieController,
                decoration: const InputDecoration(labelText: '热量（千卡）'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _numberValidator,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      decoration: const InputDecoration(labelText: '蛋白质 g'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _carbohydrateController,
                      decoration: const InputDecoration(labelText: '碳水 g'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      decoration: const InputDecoration(labelText: '脂肪 g'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
