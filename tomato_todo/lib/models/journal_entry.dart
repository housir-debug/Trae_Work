// models/journal_entry.dart - 每日复盘记录
import 'package:uuid/uuid.dart';

class JournalEntry {
  final String id;
  final String dateKey;
  int mood; // 1-5
  int energy; // 1-5
  String highlight; // 今日高光
  String gratitude; // 值得感恩
  String note; // 复盘与反思
  DateTime updatedAt;

  JournalEntry({
    String? id,
    required this.dateKey,
    this.mood = 3,
    this.energy = 3,
    this.highlight = '',
    this.gratitude = '',
    this.note = '',
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now();

  static const List<String> moodEmojis = ['😞', '😐', '🙂', '😄', '🤩'];

  String get moodEmoji => moodEmojis[(mood - 1).clamp(0, 4).toInt()];

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'mood': mood,
        'energy': energy,
        'highlight': highlight,
        'gratitude': gratitude,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        dateKey: json['dateKey'] as String,
        mood: (json['mood'] as int? ?? 3).clamp(1, 5).toInt(),
        energy: (json['energy'] as int? ?? 3).clamp(1, 5).toInt(),
        highlight: json['highlight'] as String? ?? '',
        gratitude: json['gratitude'] as String? ?? '',
        note: json['note'] as String? ?? '',
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );
}
