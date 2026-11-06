// models/goal.dart - 目标与里程碑数据模型
import 'package:uuid/uuid.dart';

class Milestone {
  final String id;
  String title;
  bool isDone;
  DateTime? doneAt;

  Milestone({
    String? id,
    required this.title,
    this.isDone = false,
    this.doneAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'doneAt': doneAt?.toIso8601String(),
      };

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String,
        title: json['title'] as String,
        isDone: json['isDone'] as bool? ?? false,
        doneAt: json['doneAt'] != null
            ? DateTime.parse(json['doneAt'] as String)
            : null,
      );
}

class Goal {
  final String id;
  String title;
  String description;
  String category;
  DateTime? targetDate;
  List<Milestone> milestones;
  DateTime createdAt;
  bool isCompleted;
  DateTime? completedAt;

  Goal({
    String? id,
    required this.title,
    this.description = '',
    this.category = '成长',
    this.targetDate,
    List<Milestone>? milestones,
    DateTime? createdAt,
    this.isCompleted = false,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        milestones = milestones ?? [],
        createdAt = createdAt ?? DateTime.now();

  double get progress {
    if (isCompleted) return 1.0;
    if (milestones.isEmpty) return 0.0;
    final done = milestones.where((m) => m.isDone).length;
    return done / milestones.length;
  }

  int get doneMilestones => milestones.where((m) => m.isDone).length;

  int? get daysLeft {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return targetDate!.difference(today).inDays;
  }

  Goal copyWith({
    String? title,
    String? description,
    String? category,
    DateTime? targetDate,
    bool clearTargetDate = false,
    List<Milestone>? milestones,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      Goal(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        targetDate:
            clearTargetDate ? null : (targetDate ?? this.targetDate),
        milestones: milestones ?? this.milestones,
        createdAt: createdAt,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'targetDate': targetDate?.toIso8601String(),
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? '成长',
        targetDate: json['targetDate'] != null
            ? DateTime.parse(json['targetDate'] as String)
            : null,
        milestones: (json['milestones'] as List?)
                ?.map((e) => Milestone.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        isCompleted: json['isCompleted'] as bool? ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );
}
