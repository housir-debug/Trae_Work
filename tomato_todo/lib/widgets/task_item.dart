// widgets/task_item.dart - 待办列表项
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import 'ui.dart';

class TaskItemWidget extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onFocus;
  final bool showDate;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onFocus,
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
                    TinyBadge(
                      text: '${task.completedPomodoros}/${task.estimatedPomodoros} 番茄',
                      color: const Color(0xFFF06292),
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
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
                if (v == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑',
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
