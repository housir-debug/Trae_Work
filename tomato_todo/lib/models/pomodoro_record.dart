// models/pomodoro_record.dart - 番茄钟完成记录
import 'package:uuid/uuid.dart';

enum PomodoroType { work, shortBreak, longBreak }

extension PomodoroTypeX on PomodoroType {
  String get label => switch (this) {
        PomodoroType.work => '专注',
        PomodoroType.shortBreak => '短休',
        PomodoroType.longBreak => '长休',
      };
}

class PomodoroRecord {
  final String id;
  final PomodoroType type;
  final int durationMinutes; // 实际持续时长
  final DateTime startedAt;
  final DateTime completedAt;
  final String? taskId; // 关联的任务(可为空)
  final String? taskTitle; // 关联任务标题快照
  final String? note;

  PomodoroRecord({
    String? id,
    required this.type,
    required this.durationMinutes,
    required this.startedAt,
    required this.completedAt,
    this.taskId,
    this.taskTitle,
    this.note,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'durationMinutes': durationMinutes,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
        'taskId': taskId,
        'taskTitle': taskTitle,
        'note': note,
      };

  factory PomodoroRecord.fromJson(Map<String, dynamic> json) =>
      PomodoroRecord(
        id: json['id'] as String,
        type: PomodoroType.values[
            (json['type'] as int? ?? 0).clamp(0, 2).toInt()],
        durationMinutes: json['durationMinutes'] as int? ?? 0,
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: DateTime.parse(json['completedAt'] as String),
        taskId: json['taskId'] as String?,
        taskTitle: json['taskTitle'] as String?,
        note: json['note'] as String?,
      );

  bool isSameDay(DateTime day) {
    return completedAt.year == day.year &&
        completedAt.month == day.month &&
        completedAt.day == day.day;
  }
}
