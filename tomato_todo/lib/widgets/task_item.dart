// widgets/task_item.dart - 单个任务卡片
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/pomodoro_provider.dart';

class TaskItemWidget extends StatelessWidget {
  final Task task;
  const TaskItemWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final taskProv = context.read<TaskProvider>();
    final pomoProv = context.read<PomodoroProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;

    final priorityColor = switch (task.priority) {
      TaskPriority.high => Colors.redAccent,
      TaskPriority.medium => Colors.orangeAccent,
      TaskPriority.low => Colors.grey,
    };

    final isSelected = pomoProv.currentTaskId == task.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.primary.withOpacity(0.15)
            : theme.cardBackground.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: isSelected
            ? Border.all(color: theme.primary, width: 2)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // 完成勾
            GestureDetector(
              onTap: () => taskProv.completeTask(task.id),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted
                      ? theme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted ? theme.primary : priorityColor,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: task.isCompleted
                          ? theme.foreground.withOpacity(0.4)
                          : theme.foreground,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          switch (task.priority) {
                            TaskPriority.high => '高',
                            TaskPriority.medium => '中',
                            TaskPriority.low => '低',
                          },
                          style: TextStyle(
                              fontSize: 10, color: priorityColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '🍅 ${task.completedPomodoros}/${task.estimatedPomodoros}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.foreground.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 选择按钮(关联当前番茄)
            IconButton(
              icon: Icon(
                isSelected ? Icons.star : Icons.star_border,
                color: isSelected ? theme.primary : theme.foreground.withOpacity(0.4),
              ),
              onPressed: () {
                if (isSelected) {
                  pomoProv.setTaskId(null);
                } else {
                  pomoProv.setTaskId(task.id);
                }
              },
              tooltip: isSelected ? '取消关联' : '关联到当前番茄',
            ),
            // 删除
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: theme.foreground.withOpacity(0.4)),
              onPressed: () => taskProv.deleteTask(task.id),
            ),
          ],
        ),
      ),
    );
  }
}
