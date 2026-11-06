// screens/tasks_screen.dart - 待办管理
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/task.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_input.dart';
import '../widgets/task_item.dart';
import '../widgets/ui.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _tab = 0; // 0 进行中, 1 已完成
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final provider = context.watch<TaskProvider>();
    final tasks = provider.search(_search.text);

    final weekEnd = startOfWeek(DateTime.now()).add(const Duration(days: 7));

    final overdue = tasks.where((t) => t.isOverdue).toList();
    final dueToday = tasks.where((t) => !t.isOverdue && t.isDueToday).toList();
    final dueWeek = tasks
        .where((t) =>
            !t.isOverdue &&
            !t.isDueToday &&
            t.dueDate != null &&
            t.dueDate!.isBefore(weekEnd))
        .toList();
    final later = tasks
        .where((t) =>
            t.dueDate != null &&
            !t.isOverdue &&
            !t.isDueToday &&
            !t.dueDate!.isBefore(weekEnd))
        .toList();
    final noDue = tasks.where((t) => t.dueDate == null).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('待办清单',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: theme.foreground)),
                    const SizedBox(height: 3),
                    Text(
                      '${provider.activeCount} 项进行中 · 今日已完成 ${provider.completedToday} 项',
                      style: TextStyle(fontSize: 11, color: theme.muted),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => showTaskEditor(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 13, color: theme.foreground),
              decoration: appInput(
                context: context,
                hint: '搜索标题 / 备注 / 标签',
                dense: true,
                prefix: Icon(Icons.search, size: 17, color: theme.muted),
                suffix: _search.text.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() {});
                        },
                        child: Icon(Icons.close, size: 16, color: theme.muted),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                PillChip(
                  label: '进行中 ${provider.activeCount}',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: '已完成 ${provider.completedTasks.length}',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                const Spacer(),
                if (_tab == 0 && overdue.isNotEmpty)
                  TinyBadge(
                    text: '逾期 ${overdue.length}',
                    color: const Color(0xFFFF5252),
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),
          ),
          if (_tab == 0) ...[
            if (tasks.isEmpty)
              AppCard(
                margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: EmptyHint(
                  icon: _search.text.isEmpty
                      ? Icons.checklist_rtl
                      : Icons.search_off,
                  text: _search.text.isEmpty
                      ? '暂无进行中的待办\n点击「新建」或到今日页快速记录'
                      : '没有匹配的待办',
                ),
              )
            else ...[
              if (overdue.isNotEmpty) _group('已逾期', overdue),
              if (dueToday.isNotEmpty) _group('今天', dueToday),
              if (dueWeek.isNotEmpty) _group('本周', dueWeek),
              if (later.isNotEmpty) _group('之后', later),
              if (noDue.isNotEmpty) _group('无期限', noDue),
            ],
          ] else ...[
            if (provider.completedTasks.isEmpty)
              AppCard(
                margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: const EmptyHint(
                  icon: Icons.task_alt,
                  text: '还没有完成的待办 · 完成一项会有满满的成就感',
                ),
              )
            else ...[
              SectionHeader(title: '已完成', subtitle: '共 ${provider.completedTasks.length} 项'),
              ...provider.completedTasks.map(_tile),
            ],
          ],
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _group(String title, List<Task> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, subtitle: '${list.length} 项'),
        ...list.map(_tile),
      ],
    );
  }

  Widget _tile(Task t) {
    return TaskItemWidget(
      task: t,
      onToggle: () => context.read<TaskProvider>().toggleComplete(t.id),
      onEdit: () => showTaskEditor(context, task: t),
      onDelete: () => _delete(t),
      onFocus: () => context.read<PomodoroProvider>().assignTask(t),
    );
  }

  Future<void> _delete(Task t) async {
    final ok = await showConfirmDialog(context,
        title: '删除「${t.title}」?', danger: true, confirmText: '删除');
    if (ok && mounted) {
      await context.read<TaskProvider>().deleteTask(t.id);
    }
  }
}
