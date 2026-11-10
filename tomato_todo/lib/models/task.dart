// models/task.dart - 待办任务数据模型
// v3.0: 待办不再按今天/明天分组; 周期任务按「创建/完成时刻 + 周期天数」循环,
//       优先级随周期进度自动递进(1/3 -> 中, 2/3 -> 高, 满周期未完成 -> 逾期)
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

/// 旧版本重复规则(仅用于数据迁移, 新代码使用 repeatIntervalDays)
enum RepeatRule { none, daily, weekdays, weekly, monthly }

class Task {
  final String id;
  String title;
  String notes;
  TaskPriority priority;
  int estimatedPomodoros;
  int completedPomodoros;
  bool isCompleted;

  /// 关联日程的日期(仅日程联动任务使用), 也用于其优先级按日期递进
  DateTime? dueDate;
  List<String> tags;
  List<Subtask> subtasks;
  bool isPinned;
  DateTime createdAt;
  DateTime? completedAt;

  // --------- 周期性待办 ---------
  /// 重复周期(天), 0 表示不重复
  int repeatIntervalDays;

  /// 当前周期起点(创建或上次重新出现的时间)
  DateTime? cycleStartAt;

  /// 周期任务完成后, 重新出现的时刻(为 null 表示当前处于活跃状态)
  DateTime? nextAppearanceAt;

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
    this.isPinned = false,
    DateTime? createdAt,
    this.completedAt,
    this.repeatIntervalDays = 0,
    this.cycleStartAt,
    this.nextAppearanceAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        subtasks = subtasks ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isRecurring => repeatIntervalDays > 0;

  /// 周期任务当前是否处于「休眠期」(已完成, 等待周期结束后重新出现)
  bool get isDormant =>
      isRecurring && isCompleted && nextAppearanceAt != null;

  /// 周期进度 0.0 ~ 1.0(满周期), 超过 1.0 表示已超期
  double get cycleProgress {
    if (!isRecurring) return 0;
    final start = cycleStartAt ?? createdAt;
    final elapsed = DateTime.now().difference(start).inSeconds;
    final total = repeatIntervalDays * 86400;
    if (total <= 0) return 0;
    return elapsed / total;
  }

  /// 是否逾期: 周期任务超过一个周期未完成; 日程联动任务过了当天未完成
  bool get isOverdue {
    if (isCompleted) return false;
    if (isRecurring) return cycleProgress > 1.0;
    if (dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return today.isAfter(dueDate!);
    }
    return false;
  }

  /// 有效优先级(展示与排序用):
  /// - 周期任务: 按周期进度递进(前 1/3 低, 中 1/3 中, 后 1/3 高, 超期保持高)
  /// - 日程联动任务(有 dueDate): 当天高, 明天中, 后天起低
  /// - 普通任务: 手动设置的优先级
  TaskPriority get effectivePriority {
    if (isRecurring) {
      final p = cycleProgress;
      if (p >= 2 / 3) return TaskPriority.high;
      if (p >= 1 / 3) return TaskPriority.medium;
      return TaskPriority.low;
    }
    if (dueDate != null && !isCompleted) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final days = dueDate!.difference(today).inDays;
      if (days <= 0) return TaskPriority.high;
      if (days == 1) return TaskPriority.medium;
      return TaskPriority.low;
    }
    return priority;
  }

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get subtaskDone => subtasks.where((s) => s.isDone).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : subtaskDone / subtasks.length;

  /// 周期描述文案
  String get repeatLabel {
    if (!isRecurring) return '';
    if (repeatIntervalDays == 1) return '每天';
    if (repeatIntervalDays == 7) return '每周';
    if (repeatIntervalDays == 30) return '每月';
    return '每 $repeatIntervalDays 天';
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
    List<Subtask>? subtasks,
    bool? isPinned,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? repeatIntervalDays,
    DateTime? cycleStartAt,
    bool clearCycleStart = false,
    DateTime? nextAppearanceAt,
    bool clearNextAppearance = false,
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
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      repeatIntervalDays: repeatIntervalDays ?? this.repeatIntervalDays,
      cycleStartAt:
          clearCycleStart ? null : (cycleStartAt ?? this.cycleStartAt),
      nextAppearanceAt: clearNextAppearance
          ? null
          : (nextAppearanceAt ?? this.nextAppearanceAt),
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
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'repeatIntervalDays': repeatIntervalDays,
        'cycleStartAt': cycleStartAt?.toIso8601String(),
        'nextAppearanceAt': nextAppearanceAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    // 旧数据迁移: repeat 枚举 -> repeatIntervalDays
    var interval = json['repeatIntervalDays'] as int? ?? 0;
    if (interval <= 0 && json.containsKey('repeat')) {
      final legacy = (json['repeat'] as int? ?? 0).clamp(0, 4).toInt();
      interval = switch (legacy) {
        1 => 1, // daily
        2 => 1, // weekdays -> 每天(简化)
        3 => 7, // weekly
        4 => 30, // monthly
        _ => 0,
      };
    }
    return Task(
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
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      repeatIntervalDays: interval,
      cycleStartAt: json['cycleStartAt'] != null
          ? DateTime.parse(json['cycleStartAt'] as String)
          : null,
      nextAppearanceAt: json['nextAppearanceAt'] != null
          ? DateTime.parse(json['nextAppearanceAt'] as String)
          : null,
    );
  }
}
