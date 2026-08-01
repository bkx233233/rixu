import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/feedback/user_message.dart';
import '../data/schedule_repository.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _repository = ScheduleRepository(Supabase.instance.client);
  DateTime _selectedDate = DateTime.now();
  String _view = 'day';
  String _goalType = 'week';
  late Future<List<ScheduleItem>> _itemsFuture;
  late Future<List<List<ScheduleItem>>> _weekFuture;
  late Future<String?> _reviewFuture;
  late Future<List<PeriodGoal>> _goalsFuture;
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
        .channel('schedule:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'schedule_events',
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
          table: 'task_occurrences',
          callback: (_) => _reloadFromCloud(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'daily_reviews',
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
          table: 'period_goals',
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
    _itemsFuture = _repository.loadForDate(_selectedDate);
    _weekFuture = _loadWeek();
    _reviewFuture = _repository.loadDailyReview(_selectedDate);
    _goalsFuture = _repository.loadGoals(_goalType);
  }

  DateTime get _weekStart {
    final day =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Future<List<List<ScheduleItem>>> _loadWeek() async {
    return Future.wait([
      for (var i = 0; i < 7; i++)
        _repository.loadForDate(_weekStart.add(Duration(days: i))),
    ]);
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _selectedDate,
    );
    if (date == null) {
      return;
    }
    setState(() {
      _selectedDate = date;
      _reload();
    });
  }

  Future<void> _addTask() async {
    final result = await showDialog<_TaskDraft>(
      context: context,
      builder: (_) => _TaskDialog(date: _selectedDate),
    );
    if (result == null) {
      return;
    }
    try {
      await _repository.addTask(
        title: result.title,
        note: result.note,
        startAt: result.startAt,
        endAt: result.endAt,
      );
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('日程已添加。')));
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _saveReview(String summary) async {
    try {
      await _repository.saveDailyReview(date: _selectedDate, summary: summary);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('每日总结已保存。')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(toChineseError(error, fallback: '保存失败，请稍后重试。'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDate);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(dateLabel,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'day', label: Text('日')),
                  ButtonSegment(value: 'week', label: Text('周')),
                ],
                selected: {_view},
                onSelectionChanged: (value) =>
                    setState(() => _view = value.first),
              ),
              IconButton(
                tooltip: '选择日期',
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              IconButton(
                tooltip: '添加任务',
                onPressed: _addTask,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: _view == 'day' ? _buildDayView() : _buildWeekView(),
        ),
      ],
    );
  }

  Widget _buildDayView() {
    return FutureBuilder<List<ScheduleItem>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(
              error: snapshot.error!, onRetry: () => setState(_reload));
        }
        final items = snapshot.data ?? const <ScheduleItem>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('今天还没有安排，点击右上角添加任务。')),
              )
            else
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ScheduleTile(
                      item: item,
                      onChanged: (value) =>
                          _toggleTask(item, value ?? false, _selectedDate),
                      onDelete: () => _deleteTask(item),
                    ),
                  )),
            _DailyReviewEditor(
              key: ValueKey(_selectedDate),
              reviewFuture: _reviewFuture,
              onSave: _saveReview,
            ),
            _GoalsSection(
              periodType: _goalType,
              goalsFuture: _goalsFuture,
              onTypeChanged: (value) {
                setState(() {
                  _goalType = value;
                  _goalsFuture = _repository.loadGoals(value);
                });
              },
              onReload: () => setState(_reload),
              repository: _repository,
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeekView() {
    return FutureBuilder<List<List<ScheduleItem>>>(
      future: _weekFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(
              error: snapshot.error!, onRetry: () => setState(_reload));
        }
        final days = snapshot.data ?? const <List<ScheduleItem>>[];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < days.length; i++)
                _WeekDayColumn(
                  date: _weekStart.add(Duration(days: i)),
                  items: days[i],
                  onChanged: (item, value) => _toggleTask(
                      item, value, _weekStart.add(Duration(days: i))),
                  onDelete: _deleteTask,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleTask(
      ScheduleItem item, bool completed, DateTime date) async {
    try {
      await _repository.setCompleted(
          eventId: item.id, date: date, completed: completed);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteTask(ScheduleItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确认删除“${item.title}”？此操作无法撤销。'),
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
      await _repository.deleteTask(item.id);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('日程已删除。')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile(
      {required this.item, required this.onChanged, required this.onDelete});

  final ScheduleItem item;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(item.startAt);
    final endTime = item.endAt == null
        ? ''
        : ' - ${DateFormat('HH:mm').format(item.endAt!)}';
    return Card(
      child: ListTile(
        leading: Checkbox(value: item.isCompleted, onChanged: onChanged),
        title: Text(
          item.title,
          style: TextStyle(
              decoration: item.isCompleted ? TextDecoration.lineThrough : null),
        ),
        subtitle:
            Text('$time$endTime${item.note.isEmpty ? '' : '\n${item.note}'}'),
        isThreeLine: item.note.isNotEmpty,
        trailing: IconButton(
          tooltip: '删除日程',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn(
      {required this.date,
      required this.items,
      required this.onChanged,
      required this.onDelete});

  final DateTime date;
  final List<ScheduleItem> items;
  final void Function(ScheduleItem item, bool completed) onChanged;
  final ValueChanged<ScheduleItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return SizedBox(
      width: 190,
      child: Card(
        color: isToday ? Theme.of(context).colorScheme.primaryContainer : null,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEE', 'zh_CN').format(date),
                  style: Theme.of(context).textTheme.titleMedium),
              Text(DateFormat('MM月dd日').format(date)),
              const Divider(),
              if (items.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('暂无安排'))
              else
                ...items.map((item) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: item.isCompleted,
                      title: Text(item.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(DateFormat('HH:mm').format(item.startAt)),
                      onChanged: (value) => onChanged(item, value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: IconButton(
                        tooltip: '删除日程',
                        onPressed: () => onDelete(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyReviewEditor extends StatefulWidget {
  const _DailyReviewEditor(
      {super.key, required this.reviewFuture, required this.onSave});

  final Future<String?> reviewFuture;
  final Future<void> Function(String summary) onSave;

  @override
  State<_DailyReviewEditor> createState() => _DailyReviewEditorState();
}

class _DailyReviewEditorState extends State<_DailyReviewEditor> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text.trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: widget.reviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator()));
        }
        if (!_initialized) {
          _controller.text = snapshot.data ?? '';
          _initialized = true;
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('每日总结', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      hintText: '记录今天完成了什么、哪里需要调整。',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? '保存中…' : '保存总结'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection(
      {required this.periodType,
      required this.goalsFuture,
      required this.onTypeChanged,
      required this.onReload,
      required this.repository});

  final String periodType;
  final Future<List<PeriodGoal>> goalsFuture;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onReload;
  final ScheduleRepository repository;

  Future<void> _addGoal(BuildContext context) async {
    final draft = await showDialog<_GoalDraft>(
        context: context, builder: (_) => _GoalDialog(periodType: periodType));
    if (draft == null) return;
    try {
      await repository.addGoal(
          title: draft.title,
          periodType: periodType,
          startDate: draft.startDate,
          endDate: draft.endDate);
      onReload();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(toChineseError(error, fallback: '目标保存失败，请稍后重试。'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('周期目标',
                        style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                    tooltip: '添加目标',
                    onPressed: () => _addGoal(context),
                    icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'week', label: Text('本周目标')),
                ButtonSegment(value: 'month', label: Text('本月目标'))
              ],
              selected: {periodType},
              onSelectionChanged: (value) => onTypeChanged(value.first),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<PeriodGoal>>(
              future: goalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const LinearProgressIndicator();
                if (snapshot.hasError) return const Text('暂时无法读取周期目标。');
                final goals = snapshot.data ?? const <PeriodGoal>[];
                if (goals.isEmpty) return const Text('还没有目标，点击右上角添加。');
                return Column(
                  children: goals
                      .map((goal) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: goal.isCompleted,
                            title: Text(goal.title),
                            subtitle: Text(
                                '${DateFormat('MM月dd日').format(goal.startDate)} - ${DateFormat('MM月dd日').format(goal.endDate)}'),
                            onChanged: (value) async {
                              await repository.setGoalCompleted(
                                  goalId: goal.id, completed: value ?? false);
                              onReload();
                            },
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalDraft {
  const _GoalDraft(
      {required this.title, required this.startDate, required this.endDate});

  final String title;
  final DateTime startDate;
  final DateTime endDate;
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.periodType});

  final String periodType;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now();
    final start = widget.periodType == 'week'
        ? DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - DateTime.monday))
        : DateTime(now.year, now.month, 1);
    final end = widget.periodType == 'week'
        ? start.add(const Duration(days: 6))
        : DateTime(now.year, now.month + 1, 0);
    Navigator.pop(
        context, _GoalDraft(title: title, startDate: start, endDate: end));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.periodType == 'week' ? '添加本周目标' : '添加本月目标'),
      content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '目标内容')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暂时无法读取日程。'),
            const SizedBox(height: 8),
            Text(toChineseError(error, fallback: '暂时无法读取日程，请稍后重试。'),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft(
      {required this.title,
      required this.note,
      required this.startAt,
      required this.endAt});

  final String title;
  final String note;
  final DateTime startAt;
  final DateTime? endAt;
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.date});

  final DateTime date;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _end;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime _combine(TimeOfDay time) => DateTime(widget.date.year,
      widget.date.month, widget.date.day, time.hour, time.minute);

  Future<void> _pickStart() async {
    final value = await showTimePicker(context: context, initialTime: _start);
    if (value != null) setState(() => _start = value);
  }

  Future<void> _pickEnd() async {
    final value =
        await showTimePicker(context: context, initialTime: _end ?? _start);
    if (value != null) setState(() => _end = value);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final start = _combine(_start);
    final end = _end == null ? null : _combine(_end!);
    if (end != null && !end.isAfter(start)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间。')));
      return;
    }
    Navigator.of(context).pop(_TaskDraft(
        title: _titleController.text.trim(),
        note: _noteController.text.trim(),
        startAt: start,
        endAt: end));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加日程任务'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '任务名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入任务名称。' : null,
              ),
              TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: '备注（可选）')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: _pickStart,
                          child: Text('开始 ${_start.format(context)}'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: OutlinedButton(
                          onPressed: _pickEnd,
                          child: Text(_end == null
                              ? '结束时间'
                              : '结束 ${_end!.format(context)}'))),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
