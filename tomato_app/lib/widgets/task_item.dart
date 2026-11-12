// widgets/task_item.dart - 待办列表项
// v3.1: 优先级自动递进用颜色 + 小箭头表达; 子任务可下拉展开、上拉收起;
//       徽章顺序 优先级 > 番茄钟 > 周期/固定日期 > 子任务; 移除无用的播放按钮
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import 'ui.dart';

class TaskItemWidget extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSchedule;
  final VoidCallback? onPin;
  final VoidCallback? onDuplicate;
  final bool showDate;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onSchedule,
    this.onPin,
    this.onDuplicate,
    this.showDate = true,
  });

  @override
  State<TaskItemWidget> createState() => _TaskItemWidgetState();
}

class _TaskItemWidgetState extends State<TaskItemWidget> {
  bool _expanded = false;

  Task get task => widget.task;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final effectivePriority = task.effectivePriority;
    final priorityColor = _priorityColor(effectivePriority);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
      padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
      onTap: widget.onEdit,
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
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
                    color: task.isCompleted ? theme.muted : theme.foreground,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
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
                    // 优先级: 自动递进仅用颜色 + 小箭头, 减少文字噪音
                    if (task.isAutoPriority)
                      Tooltip(
                        message: '${effectivePriority.label}优先级(自动)',
                        child: TinyBadge(
                          text: '',
                          color: priorityColor,
                          icon: Icons.north_east,
                        ),
                      )
                    else
                      TinyBadge(
                        text: effectivePriority.label,
                        color: priorityColor,
                      ),
                    if (task.isOverdue)
                      const TinyBadge(
                        text: '已逾期',
                        color: Color(0xFFFF5252),
                        icon: Icons.warning_amber_rounded,
                      ),
                    TinyBadge(
                      text: '${task.completedPomodoros}/${task.estimatedPomodoros} 番茄',
                      color: const Color(0xFFF06292),
                      icon: Icons.timer_outlined,
                    ),
                    if (task.isRecurring)
                      TinyBadge(
                        text: task.isDormant
                            ? '${task.repeatLabel} · 休眠中'
                            : task.repeatLabel,
                        color: theme.primary,
                        icon: task.isFixed
                            ? Icons.event_repeat
                            : Icons.repeat,
                      ),
                    if (task.hasSubtasks)
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: TinyBadge(
                          text:
                              '子任务 ${task.subtaskDone}/${task.subtasks.length}',
                          color: const Color(0xFF7E57C2),
                          icon: _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                      ),
                    if (widget.showDate && task.dueDate != null)
                      TinyBadge(
                        text: '日程 ${friendlyDate(task.dueDate!)}',
                        color: theme.primary,
                        icon: Icons.event_outlined,
                      ),
                    if (task.tags.isNotEmpty)
                      for (final tag in task.tags.take(2))
                        TinyBadge(text: '#$tag', color: theme.accent),
                  ],
                ),
                // 子任务: 默认收起, 下拉展开后可逐项独立完成
                if (task.hasSubtasks && _expanded) ...[
                  const SizedBox(height: 6),
                  for (final s in task.subtasks)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context
                          .read<TaskProvider>()
                          .toggleSubtask(task.id, s.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              s.isDone
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 14,
                              color: s.isDone ? theme.primary : theme.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.isDone
                                      ? theme.muted
                                      : theme.foreground,
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
                ],
                if (task.notes.isNotEmpty && !task.hasSubtasks) ...[
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
          if (widget.onEdit != null || widget.onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: theme.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 120),
              color: theme.cardBackground,
              onSelected: (v) {
                if (v == 'edit') widget.onEdit?.call();
                if (v == 'schedule') widget.onSchedule?.call();
                if (v == 'pin') widget.onPin?.call();
                if (v == 'duplicate') widget.onDuplicate?.call();
                if (v == 'delete') widget.onDelete?.call();
              },
              itemBuilder: (_) => [
                if (widget.onEdit != null)
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (widget.onPin != null && !task.isCompleted)
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(task.isPinned ? '取消置顶' : '置顶',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (widget.onDuplicate != null)
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text('复制一份',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (widget.onSchedule != null && !task.isCompleted)
                  PopupMenuItem(
                    value: 'schedule',
                    child: Text('安排到日程',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                if (widget.onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('删除',
                        style: TextStyle(fontSize: 13, color: theme.foreground)),
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
