// screens/tasks_screen.dart - 待办管理
// v3.0: 单一列表, 按优先级排序(置顶 > 高 > 中 > 低);
//       逾期置顶区; 周期任务由「周期管理」入口统一管理
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/schedule_editor.dart';
import '../widgets/task_input.dart';
import '../widgets/task_item.dart';
import '../widgets/ui.dart';
import 'recurring_tasks_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String? _tag;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 打开待办页时检查是否有休眠周期任务到期回归 / 固定待办到点回归
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskProvider>().refreshRecurring();
      context.read<TaskProvider>().refreshFixed();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final provider = context.watch<TaskProvider>();
    var tasks = provider.search(_search.text);
    if (_tag != null) {
      tasks = tasks.where((t) => t.tags.contains(_tag)).toList();
    }

    final overdue = tasks.where((t) => t.isOverdue).toList();
    final recurringCount = provider.recurringTasks.length;

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
                if (recurringCount > 0)
                  IconButton(
                    tooltip: '周期管理',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RecurringTasksScreen()),
                    ),
                    icon: Icon(Icons.repeat, size: 20, color: theme.primary),
                  ),
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
          if (provider.activeTags.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                children: [
                  for (final tag in provider.activeTags.take(12))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PillChip(
                        label: '#$tag',
                        color: theme.accent,
                        selected: _tag == tag,
                        onTap: () => setState(
                            () => _tag = _tag == tag ? null : tag),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            AppCard(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: EmptyHint(
                icon: _search.text.isEmpty
                    ? Icons.checklist_rtl
                    : Icons.search_off,
                text: _search.text.isEmpty
                    ? '暂无进行中的待办\n点击「新建」添加第一件事'
                    : '没有匹配的待办',
              ),
            )
          else ...[
            if (overdue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 2, 22, 6),
                child: Text(
                  '${overdue.length} 项已逾期 · 排序: 优先级 > 预期时间 > 创建时间',
                  style: TextStyle(fontSize: 10, color: theme.muted),
                ),
              ),
            ...tasks.map(_tile),
          ],
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _tile(Task t) {
    final provider = context.read<TaskProvider>();
    return TaskItemWidget(
      task: t,
      onToggle: () => provider.toggleComplete(t.id),
      onEdit: () => showTaskEditor(context, task: t),
      onDelete: () => _delete(t),
      onPin: () => provider.togglePin(t.id),
      onDuplicate: () async {
        final copy = await provider.duplicateTask(t.id);
        if (copy != null && mounted) showToast(context, '已复制「${copy.title}」');
      },
      onSchedule: () => showScheduleEditor(
        context,
        date: t.dueDate ?? DateTime.now(),
        title: t.title,
        taskId: t.id,
      ),
    );
  }

  Future<void> _delete(Task t) async {
    final ok = await showConfirmDialog(context,
        title: '删除「${t.title}」?', danger: true, confirmText: '删除');
    if (!ok || !mounted) return;
    final removed = await context.read<TaskProvider>().deleteTask(t.id);
    if (removed == null || !mounted) return;
    showUndoToast(
      context,
      '已删除「${removed.title}」',
      onUndo: () => context.read<TaskProvider>().restoreTask(removed),
    );
  }
}
