// widgets/task_input.dart - 新建 / 编辑待办
// v3.1: 三类待办(单次 / 重复 / 固定)
//   单次: 优先级(默认高) + 预期时间(默认当天 0 点)
//   重复: 仅设置天数周期(自动优先级)
//   固定: 每天 / 每周某天 / 每月某日(自动优先级)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import 'ui.dart';

Future<void> showTaskEditor(BuildContext context, {Task? task}) async {
  final result = await showAppSheet<Task>(
    context,
    child: _TaskEditor(existing: task),
  );
  if (result == null || !context.mounted) return;
  final provider = context.read<TaskProvider>();
  if (task == null) {
    await provider.addTask(result);
    if (context.mounted) showToast(context, '已创建待办');
  } else {
    await provider.updateTask(result);
    if (context.mounted) showToast(context, '已更新待办');
  }
}

class _TaskEditor extends StatefulWidget {
  final Task? existing;

  const _TaskEditor({this.existing});

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late final TextEditingController _subtaskInput;
  late TaskType _type;
  late TaskPriority _priority;
  late int _estimate;
  late List<Subtask> _subtasks;
  late int _repeatDays;
  late FixedRule _fixedRule;
  late int _fixedWeekday;
  late int _fixedDay;
  late DateTime _expectedAt;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _tags = TextEditingController(text: t?.tags.join(',') ?? '');
    _subtaskInput = TextEditingController();
    _type = t?.type ?? TaskType.single;
    _priority = t?.priority ?? TaskPriority.high;
    _estimate = t?.estimatedPomodoros ?? 2;
    _subtasks = List<Subtask>.from(t?.subtasks ?? []);
    _repeatDays = t != null && t.repeatIntervalDays > 0 ? t.repeatIntervalDays : 1;
    _fixedRule = t?.fixedRule ?? FixedRule.daily;
    _fixedWeekday = t?.fixedWeekday ?? DateTime.now().weekday;
    _fixedDay = t?.fixedDayOfMonth ?? DateTime.now().day;
    _expectedAt = t?.expectedAt ?? startOfDay(DateTime.now());
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tags.dispose();
    _subtaskInput.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final text = _subtaskInput.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(Subtask(title: text));
      _subtaskInput.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final isEditing = widget.existing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isEditing ? '编辑待办' : '新建待办',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.foreground,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: !isEditing,
          maxLength: 60,
          style: TextStyle(fontSize: 14, color: theme.foreground),
          decoration: appInput(
            context: context,
            hint: '要做什么? 例如: 完成接口文档',
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          maxLines: 2,
          style: TextStyle(fontSize: 13, color: theme.foreground),
          decoration: appInput(context: context, hint: '备注 / 具体步骤(可选)'),
        ),
        const SizedBox(height: 14),
        Text('待办类型', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final type in TaskType.values)
              PillChip(
                label: switch (type) {
                  TaskType.single => '单次',
                  TaskType.repeat => '重复',
                  TaskType.fixed => '固定',
                },
                selected: _type == type,
                onTap: () => setState(() => _type = type),
              ),
          ],
        ),
        // 单次: 手动优先级 + 预期时间
        if (_type == TaskType.single) ...[
          const SizedBox(height: 14),
          Text('优先级', style: TextStyle(fontSize: 12, color: theme.muted)),
          const SizedBox(height: 6),
          Row(
            children: TaskPriority.values.map((p) {
              final color = _priorityColor(p);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PillChip(
                  label: '${p.label}优先级',
                  color: color,
                  selected: _priority == p,
                  onTap: () => setState(() => _priority = p),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _ExpectedAtRow(
            theme: theme,
            value: _expectedAt,
            onChanged: (v) => setState(() => _expectedAt = v),
          ),
        ],
        // 重复: 以天为单位, 任意天数
        if (_type == TaskType.repeat) ...[
          const SizedBox(height: 14),
          Text('重复周期(完成后开始计算, 到期自动回归, 优先级随周期递进)',
              style: TextStyle(fontSize: 12, color: theme.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final days in [1, 3, 7, 14, 30])
                PillChip(
                  label: days == 1 ? '每天' : '每 $days 天',
                  selected: _repeatDays == days,
                  onTap: () => setState(() => _repeatDays = days),
                ),
              PillChip(
                label: [1, 3, 7, 14, 30].contains(_repeatDays)
                    ? '自定义'
                    : '每 $_repeatDays 天',
                icon: Icons.tune,
                selected: ![1, 3, 7, 14, 30].contains(_repeatDays),
                onTap: () => _pickCustomDays(),
              ),
            ],
          ),
        ],
        // 固定: 每天 / 每周某天 / 每月某日
        if (_type == TaskType.fixed) ...[
          const SizedBox(height: 14),
          Text('固定重复(按指定日期 0 点自动加入待办)',
              style: TextStyle(fontSize: 12, color: theme.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final rule in FixedRule.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PillChip(
                    label: rule.label,
                    selected: _fixedRule == rule,
                    onTap: () => setState(() => _fixedRule = rule),
                  ),
                ),
            ],
          ),
          if (_fixedRule == FixedRule.weekly) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 1; i <= 7; i++)
                  PillChip(
                    label: weekdayShort(DateTime(2024, 1, i)),
                    selected: _fixedWeekday == i,
                    onTap: () => setState(() => _fixedWeekday = i),
                  ),
              ],
            ),
          ],
          if (_fixedRule == FixedRule.monthly) ...[
            const SizedBox(height: 10),
            _MonthDayPicker(
              theme: theme,
              value: _fixedDay,
              onChanged: (v) => setState(() => _fixedDay = v),
            ),
          ],
        ],
        if (widget.existing?.dueDate != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 14, color: theme.primary),
              const SizedBox(width: 5),
              Text(
                '日程联动 · ${shortDate(widget.existing!.dueDate!)}(在日程中调整)',
                style: TextStyle(fontSize: 11, color: theme.primary),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Text('子任务', style: TextStyle(fontSize: 12, color: theme.muted)),
            if (_subtasks.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '${_subtasks.where((s) => s.isDone).length}/${_subtasks.length}',
                style: TextStyle(fontSize: 11, color: theme.primary),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ..._subtasks.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    final idx = _subtasks.indexWhere((e) => e.id == s.id);
                    if (idx >= 0) {
                      _subtasks[idx] = s.copyWith(isDone: !s.isDone);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      s.isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: s.isDone ? theme.primary : theme.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: s.isDone ? theme.muted : theme.foreground,
                      decoration:
                          s.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(
                      () => _subtasks.removeWhere((e) => e.id == s.id)),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 15, color: theme.muted),
                  ),
                ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subtaskInput,
                style: TextStyle(fontSize: 12, color: theme.foreground),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSubtask(),
                decoration: appInput(
                  context: context,
                  hint: '添加一个子任务, 回车确认',
                  dense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addSubtask,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.add, size: 17, color: theme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('预计番茄数', style: TextStyle(fontSize: 12, color: theme.muted)),
            const Spacer(),
            _Stepper(
              value: _estimate,
              min: 1,
              max: 20,
              onChanged: (v) => setState(() => _estimate = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tags,
          style: TextStyle(fontSize: 13, color: theme.foreground),
          decoration: appInput(
            context: context,
            hint: '标签, 用逗号分隔 (如: 工作,紧急)',
            prefix: Icon(Icons.tag, size: 16, color: theme.muted),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消', style: TextStyle(color: theme.muted)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _save,
                child: Text(isEditing ? '保存修改' : '创建待办'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCustomDays() async {
    final theme = context.read<SettingsProvider>().currentTheme;
    final controller = TextEditingController(text: '$_repeatDays');
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardBackground,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('自定义周期(天)',
            style: TextStyle(color: theme.foreground, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 14, color: theme.foreground),
          decoration:
              const InputDecoration(hintText: '如: 10 表示每 10 天一次'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: theme.muted)),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null && v >= 1 && v <= 365) {
                Navigator.pop(ctx, v);
              }
            },
            child: Text('确定',
                style: TextStyle(
                    color: theme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (days != null) setState(() => _repeatDays = days);
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return const Color(0xFFFF5252);
      case TaskPriority.medium:
        return const Color(0xFFFFA726);
      case TaskPriority.low:
        return const Color(0xFF6BCB9D);
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, '请填写待办标题');
      return;
    }
    final tags = _tags.text
        .split(RegExp(r'[,，\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final existing = widget.existing;
    final base = existing ?? Task(title: title, estimatedPomodoros: _estimate);
    final repeatChanged =
        existing == null || existing.repeatIntervalDays != _repeatDays;
    final now = DateTime.now();
    final fixedDueToday = _type == TaskType.fixed && _fixedDueToday(now);
    final result = base.copyWith(
      title: title,
      notes: _notes.text.trim(),
      type: _type,
      priority: _type == TaskType.single ? _priority : existing?.priority ?? TaskPriority.medium,
      estimatedPomodoros: _estimate,
      tags: tags,
      subtasks: _subtasks,
      expectedAt: _type == TaskType.single ? _expectedAt : startOfDay(now),
      repeatIntervalDays: _type == TaskType.repeat ? _repeatDays : 0,
      cycleStartAt:
          _type == TaskType.repeat && repeatChanged ? now : null,
      clearCycleStart: _type != TaskType.repeat,
      clearNextAppearance: true,
      fixedRule: _fixedRule,
      fixedWeekday: _fixedWeekday,
      fixedDayOfMonth: _fixedDay,
      lastFixedDate: fixedDueToday && !(existing?.isCompleted ?? false)
          ? dateKey(now)
          : null,
      clearLastFixedDate: !fixedDueToday,
    );
    Navigator.pop(context, result);
  }

  bool _fixedDueToday(DateTime day) {
    switch (_fixedRule) {
      case FixedRule.daily:
        return true;
      case FixedRule.weekly:
        return day.weekday == _fixedWeekday;
      case FixedRule.monthly:
        return day.day == _fixedDay.clamp(1, daysInMonth(day.year, day.month));
    }
  }
}

/// 预期时间选择(日期 + 时间, 默认当天 0 点)
class _ExpectedAtRow extends StatelessWidget {
  final ThemeDef theme;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const _ExpectedAtRow({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final timeText =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Text('预期时间', style: TextStyle(fontSize: 12, color: theme.muted)),
        const Spacer(),
        PillChip(
          label: friendlyDate(value),
          icon: Icons.calendar_today_outlined,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              helpText: '选择预期日期',
              cancelText: '取消',
              confirmText: '确定',
            );
            if (picked == null) return;
            onChanged(DateTime(picked.year, picked.month, picked.day,
                value.hour, value.minute));
          },
        ),
        const SizedBox(width: 6),
        PillChip(
          label: timeText,
          icon: Icons.schedule,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
              helpText: '选择预期时间',
              cancelText: '取消',
              confirmText: '确定',
            );
            if (picked == null) return;
            onChanged(DateTime(value.year, value.month, value.day,
                picked.hour, picked.minute));
          },
        ),
      ],
    );
  }
}

/// 每月几号选择
class _MonthDayPicker extends StatelessWidget {
  final ThemeDef theme;
  final int value;
  final ValueChanged<int> onChanged;

  const _MonthDayPicker({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var d = 1; d <= 31; d++)
          PillChip(
            label: '$d',
            selected: value == d,
            onTap: () => onChanged(d),
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Row(
      children: [
        _btn(Icons.remove, () {
          if (value > min) onChanged(value - 1);
        }, theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('$value',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.foreground)),
        ),
        _btn(Icons.add, () {
          if (value < max) onChanged(value + 1);
        }, theme),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, ThemeDef theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: theme.primary),
      ),
    );
  }
}
