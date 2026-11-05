// providers/task_provider.dart - 任务管理状态
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final StorageService _storage;
  List<Task> _tasks = [];

  TaskProvider(this._storage);

  List<Task> get tasks => _tasks;

  // 按优先级排序的未完成任务
  List<Task> get activeTasks {
    final priorityOrder = {
      TaskPriority.high: 0,
      TaskPriority.medium: 1,
      TaskPriority.low: 2,
    };
    final active = _tasks.where((t) => !t.isCompleted).toList();
    active.sort((a, b) {
      final cmp = (priorityOrder[a.priority] ?? 1)
          .compareTo(priorityOrder[b.priority] ?? 1);
      if (cmp != 0) return cmp;
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

  void load() {
    _tasks = _storage.loadTasks();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.saveTasks(_tasks);
  }

  Future<void> addTask(Task task) async {
    _tasks.insert(0, task);
    await _persist();
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      _tasks[idx] = task;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> completeTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tasks[idx] = _tasks[idx].copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> incrementPomodoro(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tasks[idx] = _tasks[idx].copyWith(
        completedPomodoros: _tasks[idx].completedPomodoros + 1,
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }
}
