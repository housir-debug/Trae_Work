// models/task.dart - 待办任务数据模型
import 'package:uuid/uuid.dart';

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
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
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
        createdAt: DateTime.parse(json['createdAt'] as String),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );
}
