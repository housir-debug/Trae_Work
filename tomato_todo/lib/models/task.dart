// models/task.dart - 待办任务数据模型
import 'package:uuid/uuid.dart';

import '../core/utils.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => '低',
        TaskPriority.medium => '中',
        TaskPriority.high => '高',
      };

  /// 排序权重, 越小越优先
  int get rank => switch (this) {
        TaskPriority.high => 0,
        TaskPriority.medium => 1,
        TaskPriority.low => 2,
      };
}

/// 子任务(清单项)
class Subtask {
  final String id;
  String title;
  bool isDone;

  Subtask({
    String? id,
    required this.title,
    this.isDone = false,
  }) : id = id ?? const Uuid().v4();

  Subtask copyWith({String? title, bool? isDone}) => Subtask(
        id: id,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
      };

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
        id: json['id'] as String? ?? const Uuid().v4(),
        title: json['title'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
      );
}

/// 重复规则
enum RepeatRule { none, daily, weekdays, weekly, monthly }

extension RepeatRuleX on RepeatRule {
  String get label => switch (this) {
        RepeatRule.none => '不重复',
        RepeatRule.daily => '每天',
        RepeatRule.weekdays => '工作日',
        RepeatRule.weekly => '每周',
        RepeatRule.monthly => '每月',
      };

  bool get repeats => this != RepeatRule.none;

  /// 由当前截止日期推算下一次截止日期
  DateTime nextOccurrence(DateTime due) {
    final base = startOfDay(due);
    switch (this) {
      case RepeatRule.none:
        return due;
      case RepeatRule.daily:
        return base.add(const Duration(days: 1));
      case RepeatRule.weekdays:
        var d = base.add(const Duration(days: 1));
        while (d.weekday >= DateTime.saturday) {
          d = d.add(const Duration(days: 1));
        }
        return d;
      case RepeatRule.weekly:
        return base.add(const Duration(days: 7));
      case RepeatRule.monthly:
        final year = base.month == 12 ? base.year + 1 : base.year;
        final month = base.month == 12 ? 1 : base.month + 1;
        final day = base.day.clamp(1, daysInMonth(year, month)).toInt();
        return DateTime(year, month, day, due.hour, due.minute);
    }
  }
}

class Task {
  final String id;
  String title;
  String notes;
  TaskPriority priority;
  int estimatedPomodoros;
  int completedPomodoros;
  bool isCompleted;
  DateTime? dueDate;
  List<String> tags;
  List<Subtask> subtasks;
  RepeatRule repeat;
  bool isPinned;
  DateTime createdAt;
  DateTime? completedAt;

  Task({
    String? id,
    required this.title,
    this.notes = '',
    this.priority = TaskPriority.medium,
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    this.isCompleted = false,
    this.dueDate,
    List<String>? tags,
    List<Subtask>? subtasks,
    this.repeat = RepeatRule.none,
    this.isPinned = false,
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        subtasks = subtasks ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    return startOfToday().isAfter(dueDate!);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  DateTime startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get subtaskDone => subtasks.where((s) => s.isDone).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : subtaskDone / subtasks.length;

  Task copyWith({
    String? title,
    String? notes,
    TaskPriority? priority,
    int? estimatedPomodoros,
    int? completedPomodoros,
    bool? isCompleted,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<String>? tags,
    List<Subtask>? subtasks,
    RepeatRule? repeat,
    bool? isPinned,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      repeat: repeat ?? this.repeat,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'priority': priority.index,
        'estimatedPomodoros': estimatedPomodoros,
        'completedPomodoros': completedPomodoros,
        'isCompleted': isCompleted,
        'dueDate': dueDate?.toIso8601String(),
        'tags': tags,
        'subtasks': subtasks.map((e) => e.toJson()).toList(),
        'repeat': repeat.index,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String? ?? json['description'] as String? ?? '',
        priority: TaskPriority.values[
            (json['priority'] as int? ?? 1).clamp(0, 2).toInt()],
        estimatedPomodoros: json['estimatedPomodoros'] as int? ?? 1,
        completedPomodoros: json['completedPomodoros'] as int? ?? 0,
        isCompleted: json['isCompleted'] as bool? ?? false,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        subtasks: (json['subtasks'] as List?)
                ?.map((e) => Subtask.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        repeat: RepeatRule.values[
            (json['repeat'] as int? ?? 0).clamp(0, 4).toInt()],
        isPinned: json['isPinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );
}
