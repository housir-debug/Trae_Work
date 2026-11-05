// models/pomodoro_record.dart - 番茄钟完成记录
import 'package:uuid/uuid.dart';

enum PomodoroType { work, shortBreak, longBreak }

class PomodoroRecord {
  final String id;
  final PomodoroType type;
  final int durationMinutes; // 实际持续时长
  final DateTime startedAt;
  final DateTime completedAt;
  final String? taskId; // 关联的任务(可为空)
  final String? note;

  PomodoroRecord({
    String? id,
    required this.type,
    required this.durationMinutes,
    required this.startedAt,
    required this.completedAt,
    this.taskId,
    this.note,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'durationMinutes': durationMinutes,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
        'taskId': taskId,
        'note': note,
      };

  factory PomodoroRecord.fromJson(Map<String, dynamic> json) =>
      PomodoroRecord(
        id: json['id'] as String,
        type: PomodoroType.values[json['type'] as int],
        durationMinutes: json['durationMinutes'] as int,
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: DateTime.parse(json['completedAt'] as String),
        taskId: json['taskId'] as String?,
        note: json['note'] as String?,
      );

  bool isSameDay(DateTime day) {
    return completedAt.year == day.year &&
        completedAt.month == day.month &&
        completedAt.day == day.day;
  }
}
