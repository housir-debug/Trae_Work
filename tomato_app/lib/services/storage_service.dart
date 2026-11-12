// services/storage_service.dart - 本地持久化(SharedPreferences) + 备份导入导出
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/completion_record.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import '../models/pomodoro_record.dart';
import '../models/schedule_event.dart';
import '../models/task.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  late SharedPreferences _prefs;

  static const kSettings = 'app_settings';
  static const kTasks = 'tasks';
  static const kRecords = 'pomodoro_records';
  static const kCompletedWorkCount = 'completed_work_count';
  static const kHabits = 'habits';
  static const kGoals = 'goals';
  static const kEvents = 'schedule_events';
  static const kJournals = 'journal_entries';
  static const kTimerState = 'timer_state';
  static const kCompletionLog = 'completion_log';
  static const kHabitsMigrated = 'habits_migrated_v3';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ------- 设置 -------
  AppSettings loadSettings() {
    final s = _prefs.getString(kSettings);
    if (s == null) return AppSettings();
    return AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs.setString(kSettings, jsonEncode(s.toJson()));
  }

  // ------- 任务 -------
  List<Task> loadTasks() {
    final s = _prefs.getString(kTasks);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    await _prefs.setString(
        kTasks, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  // ------- 番茄记录 -------
  List<PomodoroRecord> loadRecords() {
    final s = _prefs.getString(kRecords);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list
        .map((e) => PomodoroRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRecords(List<PomodoroRecord> records) async {
    await _prefs.setString(
        kRecords, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  int loadCompletedWorkCount() => _prefs.getInt(kCompletedWorkCount) ?? 0;

  Future<void> saveCompletedWorkCount(int n) async {
    await _prefs.setInt(kCompletedWorkCount, n);
  }

  // ------- 习惯 -------
  List<Habit> loadHabits() {
    final s = _prefs.getString(kHabits);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveHabits(List<Habit> habits) async {
    await _prefs.setString(
        kHabits, jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  // ------- 目标 -------
  List<Goal> loadGoals() {
    final s = _prefs.getString(kGoals);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list.map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveGoals(List<Goal> goals) async {
    await _prefs.setString(
        kGoals, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  // ------- 日程 -------
  List<ScheduleEvent> loadEvents() {
    final s = _prefs.getString(kEvents);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list
        .map((e) => ScheduleEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveEvents(List<ScheduleEvent> events) async {
    await _prefs.setString(
        kEvents, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  // ------- 复盘 -------
  List<JournalEntry> loadJournals() {
    final s = _prefs.getString(kJournals);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveJournals(List<JournalEntry> entries) async {
    await _prefs.setString(
        kJournals, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  // ------- 番茄钟计时快照 -------
  String? loadTimerSnapshot() => _prefs.getString(kTimerState);

  // ------- 完成记录(时间轴) -------
  List<CompletionRecord> loadCompletionLog() {
    final s = _prefs.getString(kCompletionLog);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list
        .map((e) => CompletionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCompletionLog(List<CompletionRecord> log) async {
    await _prefs.setString(
        kCompletionLog, jsonEncode(log.map((r) => r.toJson()).toList()));
  }

  bool get habitsMigrated => _prefs.getBool(kHabitsMigrated) ?? false;

  Future<void> markHabitsMigrated() async {
    await _prefs.setBool(kHabitsMigrated, true);
  }

  Future<void> saveTimerSnapshot(String? raw) async {
    if (raw == null) {
      await _prefs.remove(kTimerState);
    } else {
      await _prefs.setString(kTimerState, raw);
    }
  }
}
