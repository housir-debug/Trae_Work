// providers/task_provider.dart - 待办任务状态
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/task.dart';
import '../services/storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final StorageService _storage;
  List<Task> _tasks = [];

  TaskProvider(this._storage);

  List<Task> get tasks => _tasks;

  List<Task> get activeTasks {
    final active = _tasks.where((t) => !t.isCompleted).toList();
    active.sort((a, b) {
      final cmp = a.priority.rank.compareTo(b.priority.rank);
      if (cmp != 0) return cmp;
      final ad = a.dueDate, bd = b.dueDate;
      if (ad != null && bd != null) return ad.compareTo(bd);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return active;
  }

  List<Task> get completedTasks {
    final done = _tasks.where((t) => t.isCompleted).toList();
    done.sort((a, b) => (b.completedAt ?? DateTime.now())
        .compareTo(a.completedAt ?? DateTime.now()));
    return done;
  }

  List<Task> get overdueTasks =>
      activeTasks.where((t) => t.isOverdue).toList();

  List<Task> get todayTasks {
    final todays =
        activeTasks.where((t) => t.isOverdue || t.isDueToday).toList();
    final remaining = 5 - todays.length;
    final noDue = activeTasks
        .where((t) => t.dueDate == null)
        .take(remaining < 0 ? 0 : remaining)
        .toList();
    return [...todays, ...noDue];
  }

  int get activeCount => _tasks.where((t) => !t.isCompleted).length;

  int completedOn(DateTime day) => _tasks.where((t) {
        if (t.completedAt == null) return false;
        return isSameDate(t.completedAt!, day);
      }).length;

  int get completedToday => completedOn(DateTime.now());

  int completedBetween(DateTime start, DateTime end) => _tasks.where((t) {
        if (t.completedAt == null) return false;
        return !t.completedAt!.isBefore(start) && t.completedAt!.isBefore(end);
      }).length;

  void load() {
    _tasks = _storage.loadTasks();
    notifyListeners();
  }

  Future<void> _persist() => _storage.saveTasks(_tasks);

  Future<void> addTask(Task task) async {
    _tasks.insert(0, task);
    await _persist();
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;
    _tasks[idx] = task;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleComplete(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _tasks[idx];
    _tasks[idx] = t.isCompleted
        ? t.copyWith(isCompleted: false, clearCompletedAt: true)
        : t.copyWith(isCompleted: true, completedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> incrementPomodoro(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _tasks[idx] = _tasks[idx].copyWith(
      completedPomodoros: _tasks[idx].completedPomodoros + 1,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }

  List<Task> search(String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return activeTasks;
    return activeTasks.where((t) {
      return t.title.toLowerCase().contains(k) ||
          t.notes.toLowerCase().contains(k) ||
          t.tags.any((tag) => tag.toLowerCase().contains(k));
    }).toList();
  }
}
