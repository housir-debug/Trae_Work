// models/habit.dart - 习惯打卡数据模型
import 'package:uuid/uuid.dart';

import '../core/utils.dart';

class Habit {
  final String id;
  String name;
  String emoji;
  int colorValue;
  int targetPerWeek; // 1-7
  Set<String> checkIns; // yyyy-MM-dd
  DateTime createdAt;
  bool archived;

  Habit({
    String? id,
    required this.name,
    this.emoji = '✅',
    this.colorValue = 0xFF6BCB9D,
    this.targetPerWeek = 7,
    Set<String>? checkIns,
    DateTime? createdAt,
    this.archived = false,
  })  : id = id ?? const Uuid().v4(),
        checkIns = checkIns ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  bool get isDaily => targetPerWeek >= 7;

  bool checkedOn(DateTime day) => checkIns.contains(dateKey(day));

  bool get doneToday => checkedOn(DateTime.now());

  int get thisWeekCount {
    final start = startOfWeek(DateTime.now());
    var n = 0;
    for (int i = 0; i < 7; ++i) {
      if (checkedOn(start.add(Duration(days: i)))) n++;
    }
    return n;
  }

  /// 连续打卡天数(今天未打卡时从昨天开始计算, 保留尚未中断的连续)
  int get streak {
    var cursor = startOfDay(DateTime.now());
    if (!checkedOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (checkedOn(cursor)) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// 最近 n 天的打卡情况, 末尾为今天
  List<bool> lastDays(int n) {
    final today = startOfDay(DateTime.now());
    return List<bool>.generate(
      n,
      (i) => checkedOn(today.subtract(Duration(days: n - 1 - i))),
      growable: false,
    );
  }

  double rate(int days) {
    if (days <= 0) return 0;
    final list = lastDays(days);
    final hit = list.where((e) => e).length;
    return hit / days;
  }

  bool get weeklyGoalReached => targetPerWeek >= 7
      ? thisWeekCount >= 7
      : thisWeekCount >= targetPerWeek;

  Habit copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    int? targetPerWeek,
    Set<String>? checkIns,
    bool? archived,
  }) =>
      Habit(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        colorValue: colorValue ?? this.colorValue,
        targetPerWeek: targetPerWeek ?? this.targetPerWeek,
        checkIns: checkIns ?? this.checkIns,
        createdAt: createdAt,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorValue': colorValue,
        'targetPerWeek': targetPerWeek,
        'checkIns': checkIns.toList(),
        'createdAt': createdAt.toIso8601String(),
        'archived': archived,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '✅',
        colorValue: json['colorValue'] as int? ?? 0xFF6BCB9D,
        targetPerWeek:
            (json['targetPerWeek'] as int? ?? 7).clamp(1, 7).toInt(),
        checkIns: (json['checkIns'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{},
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        archived: json['archived'] as bool? ?? false,
      );
}
