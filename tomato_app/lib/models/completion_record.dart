// models/completion_record.dart - 完成记录(时间轴数据源)
// 任务完成 / 日程完成 / 习惯打卡 / 番茄专注 都会写一条记录, 供时间轴页按日查看
import 'package:uuid/uuid.dart';

enum CompletionKind { task, schedule, habit, pomodoro }

extension CompletionKindX on CompletionKind {
  String get label => switch (this) {
        CompletionKind.task => '待办',
        CompletionKind.schedule => '日程',
        CompletionKind.habit => '打卡',
        CompletionKind.pomodoro => '专注',
      };
}

class CompletionRecord {
  final String id;
  String title;
  CompletionKind kind;
  DateTime timestamp;

  /// 附加说明(如番茄时长、日程时间段)
  String note;

  /// 来源对象 id(待办 / 日程), 取消完成时用于撤销对应记录
  final String? refId;

  CompletionRecord({
    String? id,
    required this.title,
    required this.kind,
    required this.timestamp,
    this.note = '',
    this.refId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.index,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
        'refId': refId,
      };

  factory CompletionRecord.fromJson(Map<String, dynamic> json) =>
      CompletionRecord(
        id: json['id'] as String? ?? const Uuid().v4(),
        title: json['title'] as String? ?? '',
        kind: CompletionKind
            .values[(json['kind'] as int? ?? 0).clamp(0, 3).toInt()],
        timestamp: DateTime.parse(json['timestamp'] as String),
        note: json['note'] as String? ?? '',
        refId: json['refId'] as String?,
      );
}
