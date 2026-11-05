// widgets/task_input.dart - 新增/编辑任务输入框
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';

class TaskInputWidget extends StatefulWidget {
  const TaskInputWidget({super.key});

  @override
  State<TaskInputWidget> createState() => _TaskInputWidgetState();
}

class _TaskInputWidgetState extends State<TaskInputWidget> {
  final _titleCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  int _estimatedPomodoros = 1;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;
    final taskProv = context.read<TaskProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _titleCtrl,
            style: TextStyle(color: theme.foreground),
            decoration: InputDecoration(
              hintText: '添加新任务...',
              hintStyle:
                  TextStyle(color: theme.foreground.withOpacity(0.4)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onSubmitted: (_) => _submit(taskProv),
          ),
          Row(
            children: [
              // 优先级选择
              _PriorityChip(
                label: '高',
                color: Colors.redAccent,
                selected: _priority == TaskPriority.high,
                onTap: () => setState(() => _priority = TaskPriority.high),
              ),
              const SizedBox(width: 6),
              _PriorityChip(
                label: '中',
                color: Colors.orangeAccent,
                selected: _priority == TaskPriority.medium,
                onTap: () => setState(() => _priority = TaskPriority.medium),
              ),
              const SizedBox(width: 6),
              _PriorityChip(
                label: '低',
                color: Colors.grey,
                selected: _priority == TaskPriority.low,
                onTap: () => setState(() => _priority = TaskPriority.low),
              ),
              const Spacer(),
              // 预估番茄数
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍅', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _estimatedPomodoros,
                        isDense: true,
                        style: TextStyle(
                            color: theme.foreground, fontSize: 13),
                        items: List.generate(8, (i) => i + 1)
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('$n 个'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _estimatedPomodoros = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 添加按钮
              ElevatedButton(
                onPressed: () => _submit(taskProv),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
                child: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit(TaskProvider taskProv) {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    taskProv.addTask(Task(
      title: title,
      priority: _priority,
      estimatedPomodoros: _estimatedPomodoros,
    ));
    _titleCtrl.clear();
    setState(() {
      _priority = TaskPriority.medium;
      _estimatedPomodoros = 1;
    });
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
