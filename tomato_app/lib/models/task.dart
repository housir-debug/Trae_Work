// models/task.dart - 待办任务数据模型
// v3.1: 待办分三类【单次 / 重复 / 固定】
//   单次: 手动优先级 + 预期时间
//   重复: 任意天数周期, 完成后休眠, 满周期回归, 优先级随周期自动递进
//   固定: 每天 / 每周某天 / 每月某日, 到点自动回到待办(单条复用, 不产生副本)
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

/// 待办类型
enum TaskType { single, repeat, fixed }

extension TaskTypeX on TaskType {
  String get label => switch (this) {
        TaskType.single => '单次',
        TaskType.repeat => '重复',
        TaskType.fixed => '固定',
      };
}

/// 固定重复规则
enum FixedRule { daily, weekly, monthly }

extension FixedRuleX on FixedRule {
  String get label => switch (this) {
        FixedRule.daily => '每天',
        FixedRule.weekly => '每周',
        FixedRule.monthly => '每月',
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

class Task {
  final String id;
  String title;
  String notes;

  /// 待办类型
  TaskType type;

  /// 单次待办的优先级(重复 / 固定由规则自动计算)
  TaskPriority priority;
  int estimatedPomodoros;
  int completedPomodoros;
  bool isCompleted;

  /// 关联日程的日期(仅日程联动任务使用)
  DateTime? dueDate;
  List<String> tags;
  List<Subtask> subtasks;
  bool isPinned;
  DateTime createdAt;
  DateTime? completedAt;

  /// 预期时间(用于同优先级排序, 默认当天 0 点)
  DateTime expectedAt;

  // ---------- 重复待办 ----------
  /// 重复周期(天), type == repeat 时有效
  int repeatIntervalDays;

  /// 当前周期起点(创建或上次重新出现的时间)
  DateTime? cycleStartAt;

  /// 周期任务完成后, 重新出现的时刻(为 null 表示当前处于活跃状态)
  DateTime? nextAppearanceAt;

  // ---------- 固定待办 ----------
  FixedRule fixedRule;

  /// 每周几(1 = 周一 ... 7 = 周日)
  int fixedWeekday;

  /// 每月几号(1-31, 超出当月天数时按月末处理)
  int fixedDayOfMonth;

  /// 最近一次被安排到待办的日期(yyyy-MM-dd), 用于避免同一天重复安排
  String? lastFixedDate;

  Task({
    String? id,
    required this.title,
    this.notes = '',
    this.type = TaskType.single,
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
    DateTime? expectedAt,
    this.repeatIntervalDays = 0,
    this.cycleStartAt,
    this.nextAppearanceAt,
    this.fixedRule = FixedRule.daily,
    this.fixedWeekday = 1,
    this.fixedDayOfMonth = 1,
    this.lastFixedDate,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        subtasks = subtasks ?? [],
        createdAt = createdAt ?? DateTime.now(),
        expectedAt = expectedAt ??
            startOfDay(createdAt ?? DateTime.now());

  bool get isRepeat => type == TaskType.repeat && repeatIntervalDays > 0;

  bool get isFixed => type == TaskType.fixed;

  /// 是否属于周期性待办(重复 / 固定)
  bool get isRecurring => isRepeat || isFixed;

  /// 重复任务当前是否处于「休眠期」(已完成, 等待周期结束后重新出现)
  bool get isDormant =>
      isRepeat && isCompleted && nextAppearanceAt != null;

  /// 周期进度 0.0 ~ 1.0(满周期), 超过 1.0 表示已超期
  double get cycleProgress {
    if (!isRepeat) return 0;
    final start = cycleStartAt ?? createdAt;
    final elapsed = DateTime.now().difference(start).inSeconds;
    final total = repeatIntervalDays * 86400;
    if (total <= 0) return 0;
    return elapsed / total;
  }

  /// 固定任务在某天是否到期
  bool fixedDueOn(DateTime day) {
    if (!isFixed) return false;
    switch (fixedRule) {
      case FixedRule.daily:
        return true;
      case FixedRule.weekly:
        return day.weekday == fixedWeekday.clamp(1, 7);
      case FixedRule.monthly:
        final last = daysInMonth(day.year, day.month);
        return day.day == fixedDayOfMonth.clamp(1, last);
    }
  }

  /// 固定任务今天是否需要出现在待办列表
  bool get isFixedActiveToday =>
      isFixed && fixedDueOn(DateTime.now());

  /// 是否逾期: 重复任务超过一个周期未完成; 日程联动任务过了当天未完成
  bool get isOverdue {
    if (isCompleted) return false;
    if (isRepeat) return cycleProgress > 1.0;
    if (isFixed) return false;
    if (dueDate != null) {
      final today = startOfDay(DateTime.now());
      return today.isAfter(startOfDay(dueDate!));
    }
    return false;
  }

  /// 有效优先级(展示与排序用):
  /// - 重复任务: 按周期进度递进(前 1/3 低, 中 1/3 中, 后 1/3 高, 超期保持高)
  /// - 固定任务: 到期当天为高
  /// - 日程联动任务(有 dueDate): 当天高, 明天中, 后天起低
  /// - 普通单次任务: 手动设置的优先级
  TaskPriority get effectivePriority {
    if (isRepeat) {
      final p = cycleProgress;
      if (p >= 2 / 3) return TaskPriority.high;
      if (p >= 1 / 3) return TaskPriority.medium;
      return TaskPriority.low;
    }
    if (isFixed) {
      return fixedDueOn(DateTime.now())
          ? TaskPriority.high
          : TaskPriority.low;
    }
    if (dueDate != null && !isCompleted) {
      final today = startOfDay(DateTime.now());
      final days = startOfDay(dueDate!).difference(today).inDays;
      if (days <= 0) return TaskPriority.high;
      if (days == 1) return TaskPriority.medium;
      return TaskPriority.low;
    }
    return priority;
  }

  /// 优先级是否由规则自动计算
  bool get isAutoPriority => isRecurring || dueDate != null;

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get subtaskDone => subtasks.where((s) => s.isDone).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : subtaskDone / subtasks.length;

  /// 周期描述文案
  String get repeatLabel {
    if (isFixed) {
      switch (fixedRule) {
        case FixedRule.daily:
          return '每天';
        case FixedRule.weekly:
          return '每周${weekdayShort(DateTime(2024, 1, fixedWeekday.clamp(1, 7)))}';
        case FixedRule.monthly:
          return '每月 ${fixedDayOfMonth.clamp(1, 31)} 号';
      }
    }
    if (!isRepeat) return '';
    if (repeatIntervalDays == 1) return '每天';
    if (repeatIntervalDays == 7) return '每 7 天';
    if (repeatIntervalDays == 30) return '每 30 天';
    return '每 $repeatIntervalDays 天';
  }

  Task copyWith({
    String? title,
    String? notes,
    TaskType? type,
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
    DateTime? expectedAt,
    int? repeatIntervalDays,
    DateTime? cycleStartAt,
    bool clearCycleStart = false,
    DateTime? nextAppearanceAt,
    bool clearNextAppearance = false,
    FixedRule? fixedRule,
    int? fixedWeekday,
    int? fixedDayOfMonth,
    String? lastFixedDate,
    bool clearLastFixedDate = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      type: type ?? this.type,
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
      expectedAt: expectedAt ?? this.expectedAt,
      repeatIntervalDays: repeatIntervalDays ?? this.repeatIntervalDays,
      cycleStartAt:
          clearCycleStart ? null : (cycleStartAt ?? this.cycleStartAt),
      nextAppearanceAt: clearNextAppearance
          ? null
          : (nextAppearanceAt ?? this.nextAppearanceAt),
      fixedRule: fixedRule ?? this.fixedRule,
      fixedWeekday: fixedWeekday ?? this.fixedWeekday,
      fixedDayOfMonth: fixedDayOfMonth ?? this.fixedDayOfMonth,
      lastFixedDate: clearLastFixedDate
          ? null
          : (lastFixedDate ?? this.lastFixedDate),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'type': type.index,
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
        'expectedAt': expectedAt.toIso8601String(),
        'repeatIntervalDays': repeatIntervalDays,
        'cycleStartAt': cycleStartAt?.toIso8601String(),
        'nextAppearanceAt': nextAppearanceAt?.toIso8601String(),
        'fixedRule': fixedRule.index,
        'fixedWeekday': fixedWeekday,
        'fixedDayOfMonth': fixedDayOfMonth,
        'lastFixedDate': lastFixedDate,
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    // 旧数据迁移: repeat 枚举 / repeatIntervalDays -> 重复类型
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
    var type = TaskType.values[
        (json['type'] as int? ?? (interval > 0 ? 1 : 0)).clamp(0, 2).toInt()];
    if (interval <= 0 && type == TaskType.repeat) type = TaskType.single;
    final created = DateTime.parse(json['createdAt'] as String);
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String? ?? json['description'] as String? ?? '',
      type: type,
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
      createdAt: created,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      expectedAt: json['expectedAt'] != null
          ? DateTime.parse(json['expectedAt'] as String)
          : startOfDay(created),
      repeatIntervalDays: interval,
      cycleStartAt: json['cycleStartAt'] != null
          ? DateTime.parse(json['cycleStartAt'] as String)
          : null,
      nextAppearanceAt: json['nextAppearanceAt'] != null
          ? DateTime.parse(json['nextAppearanceAt'] as String)
          : null,
      fixedRule: FixedRule.values[
          (json['fixedRule'] as int? ?? 0).clamp(0, 2).toInt()],
      fixedWeekday: (json['fixedWeekday'] as int? ?? 1).clamp(1, 7),
      fixedDayOfMonth: (json['fixedDayOfMonth'] as int? ?? 1).clamp(1, 31),
      lastFixedDate: json['lastFixedDate'] as String?,
    );
  }
}
