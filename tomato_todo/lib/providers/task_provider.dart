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
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
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

  /// 进行中任务里出现过的全部标签(按使用频次降序)
  List<String> get activeTags {
    final counter = <String, int>{};
    for (final t in _tasks) {
      if (t.isCompleted) continue;
      for (final tag in t.tags) {
        counter[tag] = (counter[tag] ?? 0) + 1;
      }
    }
    final tags = counter.keys.toList()
      ..sort((a, b) => counter[b]!.compareTo(counter[a]!));
    return tags;
  }

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
    final completing = !t.isCompleted;
    _tasks[idx] = completing
        ? t.copyWith(isCompleted: true, completedAt: DateTime.now())
        : t.copyWith(isCompleted: false, clearCompletedAt: true);

    // 重复任务完成后自动生成下一次
    if (completing && t.repeat.repeats) {
      final nextDue = t.repeat.nextOccurrence(t.dueDate ?? DateTime.now());
      _tasks.insert(
        0,
        Task(
          title: t.title,
          notes: t.notes,
          priority: t.priority,
          estimatedPomodoros: t.estimatedPomodoros,
          dueDate: nextDue,
          tags: List<String>.from(t.tags),
          subtasks: t.subtasks
              .map((s) => s.copyWith(isDone: false))
              .toList(growable: false),
          repeat: t.repeat,
        ),
      );
    }

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

  /// 删除并返回被删除的任务(用于撤销)
  Future<Task?> deleteTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return null;
    final removed = _tasks.removeAt(idx);
    await _persist();
    notifyListeners();
    return removed;
  }

  /// 撤销删除
  Future<void> restoreTask(Task task) async {
    if (_tasks.any((t) => t.id == task.id)) return;
    _tasks.insert(0, task);
    await _persist();
    notifyListeners();
  }

  /// 置顶 / 取消置顶
  Future<void> togglePin(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _tasks[idx] = _tasks[idx].copyWith(isPinned: !_tasks[idx].isPinned);
    await _persist();
    notifyListeners();
  }

  /// 调整截止日期(用于「明天」「下周」快捷操作)
  Future<void> setDueDate(String id, DateTime date) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _tasks[idx] = _tasks[idx].copyWith(dueDate: startOfDay(date));
    await _persist();
    notifyListeners();
  }

  /// 把所有逾期任务顺延到明天
  Future<int> postponeOverdueToTomorrow() async {
    final tomorrow = startOfDay(DateTime.now().add(const Duration(days: 1)));
    var count = 0;
    for (var i = 0; i < _tasks.length; ++i) {
      final t = _tasks[i];
      if (!t.isCompleted && t.isOverdue) {
        _tasks[i] = t.copyWith(dueDate: tomorrow);
        count++;
      }
    }
    if (count > 0) {
      await _persist();
      notifyListeners();
    }
    return count;
  }

  /// 复制一份任务(子任务进度重置)
  Future<Task?> duplicateTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return null;
    final t = _tasks[idx];
    final copy = Task(
      title: '${t.title} (副本)',
      notes: t.notes,
      priority: t.priority,
      estimatedPomodoros: t.estimatedPomodoros,
      dueDate: t.dueDate,
      tags: List<String>.from(t.tags),
      subtasks: t.subtasks
          .map((s) => s.copyWith(isDone: false))
          .toList(growable: false),
      repeat: t.repeat,
    );
    _tasks.insert(0, copy);
    await _persist();
    notifyListeners();
    return copy;
  }

  /// 勾选 / 取消子任务
  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;
    final t = _tasks[idx];
    _tasks[idx] = t.copyWith(
      subtasks: t.subtasks.map((s) {
        return s.id == subtaskId ? s.copyWith(isDone: !s.isDone) : s;
      }).toList(growable: false),
    );
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
