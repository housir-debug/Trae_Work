// widgets/task_input.dart - 新建/编辑待办 与 快速录入
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
  late TaskPriority _priority;
  late int _estimate;
  DateTime? _dueDate;
  late List<Subtask> _subtasks;
  late RepeatRule _repeat;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _tags = TextEditingController(text: t?.tags.join(',') ?? '');
    _subtaskInput = TextEditingController();
    _priority = t?.priority ?? TaskPriority.medium;
    _estimate = t?.estimatedPomodoros ?? 2;
    _dueDate = t?.dueDate;
    _subtasks = List<Subtask>.from(t?.subtasks ?? []);
    _repeat = t?.repeat ?? RepeatRule.none;
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
        Text('优先级', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 6),
        Row(
          children: TaskPriority.values.map((p) {
            final color = p == TaskPriority.high
                ? const Color(0xFFFF5252)
                : p == TaskPriority.medium
                    ? const Color(0xFFFFA726)
                    : const Color(0xFF6BCB9D);
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
        Text('截止日期', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            PillChip(
              label: '无期限',
              selected: _dueDate == null,
              onTap: () => setState(() => _dueDate = null),
            ),
            PillChip(
              label: '今天',
              selected: _dueDate != null && isSameDate(_dueDate!, DateTime.now()),
              onTap: () => setState(() => _dueDate = startOfDay(DateTime.now())),
            ),
            PillChip(
              label: '明天',
              selected: _dueDate != null &&
                  isSameDate(_dueDate!,
                      DateTime.now().add(const Duration(days: 1))),
              onTap: () => setState(() => _dueDate =
                  startOfDay(DateTime.now().add(const Duration(days: 1)))),
            ),
            PillChip(
              label: _dueDate == null ||
                      isSameDate(_dueDate!, DateTime.now()) ||
                      isSameDate(_dueDate!,
                          DateTime.now().add(const Duration(days: 1)))
                  ? '选择日期'
                  : shortDate(_dueDate!),
              icon: Icons.calendar_today_outlined,
              selected: false,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (picked != null) setState(() => _dueDate = startOfDay(picked));
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('重复', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: RepeatRule.values.map((r) {
            return PillChip(
              label: r.label,
              selected: _repeat == r,
              onTap: () => setState(() => _repeat = r),
            );
          }).toList(),
        ),
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
    final due = _dueDate ??
        (_repeat.repeats ? startOfDay(DateTime.now()) : null);
    final base = widget.existing ??
        Task(title: title, estimatedPomodoros: _estimate);
    final result = base.copyWith(
      title: title,
      notes: _notes.text.trim(),
      priority: _priority,
      estimatedPomodoros: _estimate,
      dueDate: due,
      clearDueDate: due == null,
      tags: tags,
      subtasks: _subtasks,
      repeat: _repeat,
    );
    Navigator.pop(context, result);
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

/// 今日页的快速录入
class QuickTaskInput extends StatefulWidget {
  const QuickTaskInput({super.key});

  @override
  State<QuickTaskInput> createState() => _QuickTaskInputState();
}

class _QuickTaskInputState extends State<QuickTaskInput> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 13, color: theme.foreground),
              decoration: appInput(
                context: context,
                hint: '快速记录一个待办…',
                dense: true,
                prefix: Icon(Icons.add_circle_outline,
                    size: 17, color: theme.primary),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    await context.read<TaskProvider>().addTask(Task(title: text));
    _controller.clear();
    if (mounted) {
      setState(() => _busy = false);
      showToast(context, '已加入待办');
    }
  }
}
