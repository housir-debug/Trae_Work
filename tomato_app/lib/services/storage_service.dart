// services/storage_service.dart - 本地持久化(SharedPreferences)
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/pomodoro_record.dart';
import '../models/app_settings.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ------- 设置 -------
  static const _kSettings = 'app_settings';
  AppSettings loadSettings() {
    final s = _prefs.getString(_kSettings);
    if (s == null) return AppSettings();
    return AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs.setString(_kSettings, jsonEncode(s.toJson()));
  }

  // ------- 任务 -------
  static const _kTasks = 'tasks';
  List<Task> loadTasks() {
    final s = _prefs.getString(_kTasks);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    await _prefs.setString(_kTasks,
        jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  // ------- 番茄记录 -------
  static const _kRecords = 'pomodoro_records';
  List<PomodoroRecord> loadRecords() {
    final s = _prefs.getString(_kRecords);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list
        .map((e) => PomodoroRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRecords(List<PomodoroRecord> records) async {
    await _prefs.setString(_kRecords,
        jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  // ------- 最近完成数 -------
  static const _kCompletedWorkCount = 'completed_work_count';
  int loadCompletedWorkCount() => _prefs.getInt(_kCompletedWorkCount) ?? 0;
  Future<void> saveCompletedWorkCount(int n) async {
    await _prefs.setInt(_kCompletedWorkCount, n);
  }
}
