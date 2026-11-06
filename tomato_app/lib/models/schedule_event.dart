// models/schedule_event.dart - 时间块 / 日程数据模型
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum ScheduleCategory { work, study, life, rest, exercise, other }

extension ScheduleCategoryX on ScheduleCategory {
  String get label => switch (this) {
        ScheduleCategory.work => '工作',
        ScheduleCategory.study => '学习',
        ScheduleCategory.life => '生活',
        ScheduleCategory.rest => '休息',
        ScheduleCategory.exercise => '运动',
        ScheduleCategory.other => '其他',
      };

  Color get color => switch (this) {
        ScheduleCategory.work => const Color(0xFF4A90E2),
        ScheduleCategory.study => const Color(0xFF9575CD),
        ScheduleCategory.life => const Color(0xFFFFA726),
        ScheduleCategory.rest => const Color(0xFF6BCB9D),
        ScheduleCategory.exercise => const Color(0xFFFF6B6B),
        ScheduleCategory.other => const Color(0xFF85929E),
      };

  IconData get icon => switch (this) {
        ScheduleCategory.work => Icons.work_outline,
        ScheduleCategory.study => Icons.menu_book_outlined,
        ScheduleCategory.life => Icons.home_outlined,
        ScheduleCategory.rest => Icons.self_improvement,
        ScheduleCategory.exercise => Icons.directions_run,
        ScheduleCategory.other => Icons.more_horiz,
      };
}

class ScheduleEvent {
  final String id;
  String dateKey;
  String title;
  int startMinute;
  int endMinute;
  ScheduleCategory category;
  String note;
  bool isDone;

  /// 提醒提前分钟数: null 表示使用默认值, -1 表示不提醒, 0 表示准时
  int? reminderMinutes;

  /// 关联的待办任务 id
  String? taskId;

  ScheduleEvent({
    String? id,
    required this.dateKey,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    this.category = ScheduleCategory.work,
    this.note = '',
    this.isDone = false,
    this.reminderMinutes,
    this.taskId,
  }) : id = id ?? const Uuid().v4();

  int get durationMinutes => endMinute - startMinute;

  DateTime get startDateTime {
    final d = DateTime.tryParse(dateKey) ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, startMinute ~/ 60, startMinute % 60);
  }

  DateTime get endDateTime {
    final d = DateTime.tryParse(dateKey) ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, endMinute ~/ 60, endMinute % 60);
  }

  ScheduleEvent copyWith({
    String? dateKey,
    String? title,
    int? startMinute,
    int? endMinute,
    ScheduleCategory? category,
    String? note,
    bool? isDone,
    int? reminderMinutes,
    bool clearReminder = false,
    String? taskId,
    bool clearTask = false,
  }) =>
      ScheduleEvent(
        id: id,
        dateKey: dateKey ?? this.dateKey,
        title: title ?? this.title,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
        category: category ?? this.category,
        note: note ?? this.note,
        isDone: isDone ?? this.isDone,
        reminderMinutes:
            clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
        taskId: clearTask ? null : (taskId ?? this.taskId),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'title': title,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'category': category.index,
        'note': note,
        'isDone': isDone,
        'reminderMinutes': reminderMinutes,
        'taskId': taskId,
      };

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
        id: json['id'] as String,
        dateKey: json['dateKey'] as String,
        title: json['title'] as String,
        startMinute: json['startMinute'] as int,
        endMinute: json['endMinute'] as int,
        category: ScheduleCategory.values[
            (json['category'] as int? ?? 0).clamp(0, 5).toInt()],
        note: json['note'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
        reminderMinutes: json['reminderMinutes'] as int?,
        taskId: json['taskId'] as String?,
      );
}
