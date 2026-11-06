// providers/habit_provider.dart - 习惯状态
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/habit.dart';
import '../services/storage_service.dart';

class HabitProvider extends ChangeNotifier {
  final StorageService _storage;
  List<Habit> _habits = [];

  HabitProvider(this._storage);

  List<Habit> get habits =>
      _habits.where((h) => !h.archived).toList(growable: false);

  int get todayDone => habits.where((h) => h.doneToday).length;
  int get todayTotal => habits.length;

  double get todayRate =>
      todayTotal == 0 ? 0 : todayDone / todayTotal;

  int get bestStreak => habits.isEmpty
      ? 0
      : habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);

  double averageRate(int days) {
    if (habits.isEmpty) return 0;
    final sum = habits.map((h) => h.rate(days)).reduce((a, b) => a + b);
    return sum / habits.length;
  }

  int checkedCountOn(DateTime day) =>
      habits.where((h) => h.checkedOn(day)).length;

  int totalChecksBetween(DateTime start, DateTime end) {
    var n = 0;
    for (final h in habits) {
      for (final key in h.checkIns) {
        final d = DateTime.tryParse(key);
        if (d == null) continue;
        if (!d.isBefore(start) && d.isBefore(end)) n++;
      }
    }
    return n;
  }

  void load() {
    _habits = _storage.loadHabits();
    notifyListeners();
  }

  Future<void> _persist() => _storage.saveHabits(_habits);

  Future<void> add(Habit habit) async {
    _habits.add(habit);
    await _persist();
    notifyListeners();
  }

  Future<void> update(Habit habit) async {
    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx < 0) return;
    _habits[idx] = habit;
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _habits.removeWhere((h) => h.id == id);
    await _persist();
    notifyListeners();
  }

  /// 打卡/取消今日打卡, 返回打卡后状态
  Future<bool> toggleToday(String id) async {
    final idx = _habits.indexWhere((h) => h.id == id);
    if (idx < 0) return false;
    final h = _habits[idx];
    final now = DateTime.now();
    final key = dateKey(now);
    final checked = h.checkIns.contains(key);
    final next = h.copyWith(checkIns: {...h.checkIns});
    if (checked) {
      next.checkIns.remove(key);
    } else {
      next.checkIns.add(key);
    }
    _habits[idx] = next;
    await _persist();
    notifyListeners();
    return !checked;
  }
}
