// widgets/task_item.dart - 待办列表项
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import 'ui.dart';

class TaskItemWidget extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onFocus;
  final VoidCallback? onSchedule;
  final VoidCallback? onPin;
  final VoidCallback? onTomorrow;
  final VoidCallback? onNextWeek;
  final VoidCallback? onDuplicate;
  final bool showDate;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onFocus,
    this.onSchedule,
    this.onPin,
    this.onTomorrow,
    this.onNextWeek,
    this.onDuplicate,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final priorityColor = _priorityColor(task.priority);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
      padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
      onTap: onEdit,
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted ? theme.primary : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted
                        ? theme.primary
                        : theme.foreground.withOpacity(0.28),
                    width: 1.6,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: task.isCompleted
                        ? theme.muted
                        : theme.foreground,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (task.isPinned)
                      TinyBadge(
                        text: '置顶',
                        color: theme.primary,
                        icon: Icons.push_pin_outlined,
                      ),
                    TinyBadge(
                      text: task.priority.label,
                      color: priorityColor,
                    ),
                    if (showDate && task.dueDate != null)
                      TinyBadge(
                        text: task.isOverdue
                            ? '已逾期·${friendlyDate(task.dueDate!)}'
                            : friendlyDate(task.dueDate!),
                        color: task.isOverdue
                            ? const Color(0xFFFF5252)
                            : theme.primary,
                        icon: Icons.event_outlined,
                      ),
                    if (task.tags.isNotEmpty)
                      for (final tag in task.tags.take(3))
                        TinyBadge(text: '#$tag', color: theme.accent),
                    if (task.hasSubtasks)
                      TinyBadge(
                        text: '子任务 ${task.subtaskDone}/${task.subtasks.length}',
                        color: const Color(0xFF7E57C2),
                        icon: Icons.checklist_rtl,
                      ),
                    if (task.repeat.repeats)
                      TinyBadge(
                        text: task.repeat.label,
                        color: theme.primary,
                        icon: Icons.repeat,
                      ),
                    TinyBadge(
                      text: '${task.completedPomodoros}/${task.estimatedPomodoros} 番茄',
                      color: const Color(0xFFF06292),
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
                if (task.hasSubtasks) ...[
                  const SizedBox(height: 5),
                  for (final s in task.subtasks.take(4))
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context
                          .read<TaskProvider>()
                          .toggleSubtask(task.id, s.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              s.isDone
                                  ? Icons.check_circle_outline
                                  : Icons.circle_outlined,
                              size: 13,
                              color: s.isDone ? theme.primary : theme.muted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      s.isDone ? theme.muted : theme.foreground,
                                  decoration: s.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (task.subtasks.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '还有 ${task.subtasks.length - 4} 项…',
                        style: TextStyle(fontSize: 10, color: theme.muted),
                      ),
                    ),
                ],
                if (task.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: theme.muted),
                  ),
                ],
              ],
            ),
          ),
          if (onFocus != null && !task.isCompleted)
            IconButton(
              tooltip: '开始专注',
              icon: Icon(Icons.play_circle_outline,
                  size: 19,
                  color: theme.primary.withOpacity(0.85)),
              onPressed: onFocus,
              visualDensity: VisualDensity.compact,
            ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: theme.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 120),
              color: theme.cardBackground,
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'schedule') onSchedule?.call();
                if (v == 'pin') onPin?.call();
                if (v == 'tomorrow') onTomorrow?.call();
                if (v == 'nextWeek') onNextWeek?.call();
                if (v == 'duplicate') onDuplicate?.call();
                if (v == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (onPin != null && !task.isCompleted)
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(task.isPinned ? '取消置顶' : '置顶',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (onTomorrow != null && !task.isCompleted)
                  PopupMenuItem(
                    value: 'tomorrow',
                    child: Text('改到明天',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (onNextWeek != null && !task.isCompleted)
                  PopupMenuItem(
                    value: 'nextWeek',
                    child: Text('改到下周',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (onDuplicate != null)
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text('复制一份',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (onSchedule != null && !task.isCompleted)
                  PopupMenuItem(
                    value: 'schedule',
                    child: Text('安排到日程',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('删除',
                        style: TextStyle(
                            fontSize: 13, color: theme.foreground)),
                  ),
              ],
            ),
        ],
      ),
    );
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
}
