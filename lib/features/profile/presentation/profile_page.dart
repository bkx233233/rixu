import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../health/data/health_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repository = HealthRepository(Supabase.instance.client);
  int _rangeDays = 30;
  late Future<List<WeightPoint>> _weightsFuture;
  late Future<ProfileData> _profileFuture;
  late Future<NutritionTarget?> _targetFuture;
  late Future<_ProfileViewData> _pageFuture;
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
        .channel('profile:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) => _reloadFromCloud(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'nutrition_targets',
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
    _weightsFuture = _repository.loadRecentWeights(days: _rangeDays);
    _profileFuture = _repository.loadProfile();
    _targetFuture = _repository.loadNutritionTarget();
    _pageFuture = Future.wait([_weightsFuture, _profileFuture, _targetFuture])
        .then((values) => _ProfileViewData(
              weights: values[0] as List<WeightPoint>,
              profile: values[1] as ProfileData,
              target: values[2] as NutritionTarget?,
            ));
  }

  Future<void> _openSetup(
      ProfileData profile, List<WeightPoint> weights) async {
    final result = await showDialog<_ProfileDraft>(
        context: context,
        builder: (_) => _ProfileEditor(
            profile: profile,
            initialWeight: weights.isEmpty ? null : weights.last.weight));
    if (result == null) return;
    try {
      await _repository.saveProfileAndTarget(
          heightCm: result.height,
          sex: result.sex,
          birthDate: result.birthDate,
          activityLevel: result.activityLevel,
          currentWeightKg: result.weight,
          target: result.target);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('个人资料和营养目标已保存。')));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请检查网络后重试。')));
    }
  }

  Future<void> _saveWeight() async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('记录今天体重'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '体重（kg）')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        final weight = double.tryParse(controller.text.trim());
                        if (weight != null && weight > 0)
                          Navigator.pop(context, weight);
                      },
                      child: const Text('保存'))
                ]));
    controller.dispose();
    if (value == null) return;
    await _repository.saveWeight(date: DateTime.now(), weight: value);
    if (mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('体重已保存。')));
    }
  }

  Future<void> _deleteWeight(WeightPoint point) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('删除体重记录'),
                content: Text(
                    '确认删除 ${DateFormat('MM月dd日').format(point.date)} 的记录吗？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除'))
                ]));
    if (confirmed != true) return;
    await _repository.deleteWeight(point.date);
    if (mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('体重记录已删除。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileViewData>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return const Center(child: Text('暂时无法读取个人资料，请稍后重试。'));
        }
        final viewData = snapshot.data;
        if (viewData == null) return const SizedBox.shrink();
        final weights = viewData.weights;
        final profile = viewData.profile;
        final target = viewData.target;
        return ListView(padding: const EdgeInsets.all(20), children: [
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          Text('我的', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                      Supabase.instance.client.auth.currentUser?.email ?? ''),
                  subtitle: Text(
                      profile.onboardingCompleted ? '资料已完善' : '请完善资料以生成营养建议'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSetup(profile, weights))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.track_changes_outlined),
                  title: const Text('每日营养目标'),
                  subtitle: Text(target == null
                      ? '尚未生成'
                      : '${target.calories.round()} 千卡 · 蛋白 ${target.protein.round()}g'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSetup(profile, weights))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: Text('体重变化',
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                onPressed: _saveWeight,
                tooltip: '记录体重',
                icon: const Icon(Icons.add_chart))
          ]),
          SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('近 7 天')),
                ButtonSegment(value: 30, label: Text('近 30 天')),
                ButtonSegment(value: 180, label: Text('近半年'))
              ],
              selected: {
                _rangeDays
              },
              onSelectionChanged: (values) => setState(() {
                    _rangeDays = values.first;
                    _reload();
                  })),
          const SizedBox(height: 12),
          _WeightChart(points: weights),
          const SizedBox(height: 8),
          if (weights.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('这个时间范围还没有真实体重记录。'))),
          for (final point in weights.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.monitor_weight_outlined),
              title: Text('${point.weight.toStringAsFixed(1)} kg'),
              subtitle: Text(_weightRecordLabel(point)),
              trailing: IconButton(
                  tooltip: '删除记录',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteWeight(point)),
            ),
        ]);
      },
    );
  }
}

class _ProfileViewData {
  const _ProfileViewData({
    required this.weights,
    required this.profile,
    required this.target,
  });

  final List<WeightPoint> weights;
  final ProfileData profile;
  final NutritionTarget? target;
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.points});

  final List<WeightPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty)
      return const SizedBox(
          height: 180, child: Center(child: Text('这个时间范围还没有真实体重记录。')));
    final sortedPoints = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final values = sortedPoints.map((item) => item.weight).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final tick = _tickInterval(min, max);
    final minY = ((min - tick) / tick).floorToDouble() * tick;
    final maxY = ((max + tick) / tick).ceilToDouble() * tick;
    final lineColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(8, 18, 4, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: sortedPoints.length == 1
              ? 1
              : (sortedPoints.length - 1).toDouble(),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.inverseSurface,
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final point = sortedPoints[index];
                final time = point.recordedAt == null
                    ? '时间未知'
                    : DateFormat('HH:mm').format(point.recordedAt!);
                return LineTooltipItem(
                  '${DateFormat('yyyy年MM月dd日').format(point.date)}\n$time\n${point.weight.toStringAsFixed(1)} kg',
                  TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.35),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var index = 0; index < sortedPoints.length; index++)
                  FlSpot(index.toDouble(), sortedPoints[index].weight)
              ],
              isCurved: false,
              color: lineColor,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData:
                  BarAreaData(show: true, color: lineColor.withOpacity(.12)),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: tick,
                getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  final last = sortedPoints.length - 1;
                  final middle = last ~/ 2;
                  if (index < 0 ||
                      index > last ||
                      (index != 0 && index != middle && index != last))
                    return const SizedBox.shrink();
                  return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                          DateFormat('MM/dd').format(sortedPoints[index].date),
                          style: Theme.of(context).textTheme.labelSmall));
                },
              ),
            ),
          ),
          gridData: FlGridData(
              show: true,
              horizontalInterval: tick,
              verticalInterval: 1,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context).dividerColor.withOpacity(.35),
                  strokeWidth: 1)),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  double _tickInterval(double min, double max) {
    final range = max - min;
    if (range <= 2) return .5;
    if (range <= 5) return 1;
    return 2;
  }
}

String _weightRecordLabel(WeightPoint point) {
  final date = DateFormat('yyyy年MM月dd日').format(point.date);
  final time = point.recordedAt == null
      ? ''
      : ' ${DateFormat('HH:mm').format(point.recordedAt!)}';
  return '$date$time';
}

class _ProfileDraft {
  const _ProfileDraft(
      {required this.height,
      required this.weight,
      required this.sex,
      required this.birthDate,
      required this.activityLevel,
      required this.target});
  final double height;
  final double weight;
  final String sex;
  final DateTime birthDate;
  final String activityLevel;
  final NutritionTarget target;
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.profile, required this.initialWeight});
  final ProfileData profile;
  final double? initialWeight;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _deficit;
  String _sex = 'male';
  String _activity = 'light';
  DateTime _birth = DateTime(2000, 1, 1);
  @override
  void initState() {
    super.initState();
    _height =
        TextEditingController(text: widget.profile.heightCm?.toString() ?? '');
    _weight =
        TextEditingController(text: widget.initialWeight?.toString() ?? '');
    _deficit = TextEditingController(text: '300');
    _sex = widget.profile.sex ?? _sex;
    _activity = widget.profile.activityLevel ?? _activity;
    _birth = widget.profile.birthDate ?? _birth;
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _deficit.dispose();
    super.dispose();
  }

  NutritionTarget _target(double height, double weight, int deficit) {
    final age = DateTime.now().year -
        _birth.year -
        (DateTime.now().month < _birth.month ||
                (DateTime.now().month == _birth.month &&
                    DateTime.now().day < _birth.day)
            ? 1
            : 0);
    final bmr =
        10 * weight + 6.25 * height - 5 * age + (_sex == 'male' ? 5 : -161);
    final factor = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'high': 1.725,
      'athlete': 1.9
    }[_activity]!;
    final calories = bmr * factor - deficit;
    final protein = weight * 1.8;
    final fat = weight * .8;
    final carbohydrate = (calories - protein * 4 - fat * 9) / 4;
    if (carbohydrate < 0) throw StateError('热量缺口过大，无法生成合理的营养目标。');
    return NutritionTarget(
        calories: calories,
        protein: protein,
        carbohydrate: carbohydrate,
        fat: fat,
        deficit: deficit,
        mode: 'calculated');
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final height = double.parse(_height.text);
    final weight = double.parse(_weight.text);
    final deficit = int.parse(_deficit.text);
    try {
      Navigator.pop(
          context,
          _ProfileDraft(
              height: height,
              weight: weight,
              sex: _sex,
              birthDate: _birth,
              activityLevel: _activity,
              target: _target(height, weight, deficit)));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('完善资料'),
          content: Form(
              key: _form,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: _height,
                    decoration: const InputDecoration(labelText: '身高（cm）'),
                    keyboardType: TextInputType.number,
                    validator: _positive),
                TextFormField(
                    controller: _weight,
                    decoration: const InputDecoration(labelText: '当前体重（kg）'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _positive),
                DropdownButtonFormField(
                    value: _sex,
                    decoration: const InputDecoration(labelText: '生理性别'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('男')),
                      DropdownMenuItem(value: 'female', child: Text('女'))
                    ],
                    onChanged: (value) => setState(() => _sex = value!)),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('出生日期'),
                    subtitle: Text(DateFormat('yyyy年MM月dd日').format(_birth)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final value = await showDatePicker(
                          context: context,
                          firstDate: DateTime(1920),
                          lastDate: DateTime.now(),
                          initialDate: _birth);
                      if (value != null) setState(() => _birth = value);
                    }),
                DropdownButtonFormField(
                    value: _activity,
                    decoration: const InputDecoration(labelText: '日常活动水平'),
                    items: const [
                      DropdownMenuItem(
                          value: 'sedentary', child: Text('久坐，几乎不运动')),
                      DropdownMenuItem(
                          value: 'light', child: Text('轻度活动，每周 1-3 次')),
                      DropdownMenuItem(
                          value: 'moderate', child: Text('中度活动，每周 3-5 次')),
                      DropdownMenuItem(
                          value: 'high', child: Text('高活动，每周 6-7 次')),
                      DropdownMenuItem(
                          value: 'athlete', child: Text('高强度训练或体力劳动'))
                    ],
                    onChanged: (value) => setState(() => _activity = value!)),
                TextFormField(
                    controller: _deficit,
                    decoration: const InputDecoration(labelText: '每日热量缺口（千卡）'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      return number == null || number < 0 || number > 1000
                          ? '请输入 0 到 1000。'
                          : null;
                    })
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(onPressed: _save, child: const Text('保存并计算'))
          ]);
  String? _positive(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number <= 0 ? '请输入大于 0 的数字。' : null;
  }
}
