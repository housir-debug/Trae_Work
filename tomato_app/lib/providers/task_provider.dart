// providers/task_provider.dart - 待办任务状态
// v3.0: 单一优先级列表; 周期任务完成后休眠、满周期自动回归;
//       加载时自动裁剪 366 天前的已完成任务
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/completion_record.dart';
import '../models/task.dart';
import '../services/storage_service.dart';
import 'completion_provider.dart';

class TaskProvider extends ChangeNotifier {
  final StorageService _storage;
  List<Task> _tasks = [];

  /// 完成记录(时间轴), 由 main 注入
  CompletionProvider? completions;

  /// 日程联动(日程完成 -> 任务完成 反向同步), 由 main 注入
  void Function(String taskId, bool done)? onTaskLinkedEvent;

  static const int keepCompletedDays = 366;

  TaskProvider(this._storage);

  List<Task> get tasks => _tasks;

  /// 按 id 查找任务(日程联动反向同步用)
  Task? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  // --------- 派生字段缓存 ---------
  int _activeRevision = 0;
  int _activeLastRevision = -1;
  List<Task>? _activeCache;

  /// 进行中的任务(不含休眠中的周期任务), 置顶优先, 再按有效优先级
  List<Task> get activeTasks {
    if (_activeLastRevision == _activeRevision && _activeCache != null) {
      return _activeCache!;
    }
    final active = _tasks.where((t) => !t.isCompleted && !t.isDormant).toList();
    active.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final cmp = a.effectivePriority.rank.compareTo(b.effectivePriority.rank);
      if (cmp != 0) return cmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    _activeCache = active;
    _activeLastRevision = _activeRevision;
    return active;
  }

  int _completedRevision = 0;
  int _completedLastRevision = -1;
  List<Task>? _completedCache;

  /// 已完成任务(含休眠中的周期任务), 按完成时间倒序
  List<Task> get completedTasks {
    if (_completedLastRevision == _completedRevision && _completedCache != null) {
      return _completedCache!;
    }
    final done = _tasks.where((t) => t.isCompleted).toList();
    done.sort((a, b) => (b.completedAt ?? DateTime.now())
        .compareTo(a.completedAt ?? DateTime.now()));
    _completedCache = done;
    _completedLastRevision = _completedRevision;
    return done;
  }

  List<Task> get overdueTasks =>
      activeTasks.where((t) => t.isOverdue).toList();

  int get activeCount => activeTasks.length;

  /// 全部周期任务(含休眠中), 周期管理页用
  List<Task> get recurringTasks =>
      _tasks.where((t) => t.isRecurring).toList();

  /// 进行中任务里出现过的全部标签(按使用频次降序)
  List<String> get activeTags {
    final counter = <String, int>{};
    for (final t in activeTasks) {
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
    _pruneOld();
    refreshRecurring(notify: false);
    _invalidateCaches();
    notifyListeners();
  }

  /// 自动裁剪 366 天前已完成的普通任务(周期任务保留, 它还要循环)
  void _pruneOld() {
    final cutoff = DateTime.now().subtract(const Duration(days: keepCompletedDays));
    final before = _tasks.length;
    _tasks.removeWhere((t) =>
        t.isCompleted &&
        !t.isRecurring &&
        t.completedAt != null &&
        t.completedAt!.isBefore(cutoff));
    if (_tasks.length != before) {
      _storage.saveTasks(_tasks);
    }
  }

  /// 到期的休眠周期任务重新激活(满周期自动回归)
  void refreshRecurring({bool notify = true}) {
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _tasks.length; ++i) {
      final t = _tasks[i];
      if (t.isDormant && !t.nextAppearanceAt!.isAfter(now)) {
        _tasks[i] = t.copyWith(
          isCompleted: false,
          clearCompletedAt: true,
          clearNextAppearance: true,
          cycleStartAt: now,
          subtasks: t.subtasks
              .map((s) => s.copyWith(isDone: false))
              .toList(growable: false),
        );
        changed = true;
      }
    }
    if (changed) {
      _invalidateCaches();
      _storage.saveTasks(_tasks);
      if (notify) notifyListeners();
    }
  }

  void _invalidateCaches() {
    _activeRevision++;
    _completedRevision++;
    _activeCache = null;
    _completedCache = null;
  }

  Future<void> _persist() => _storage.saveTasks(_tasks);

  /// 切后台时确保落盘(本 provider 没有 debounce, 立即持久化)
  Future<void> flush() async => _persist();

  Future<void> addTask(Task task) async {
    if (task.isRecurring && task.cycleStartAt == null) {
      task.cycleStartAt = DateTime.now();
    }
    _tasks.insert(0, task);
    _invalidateCaches();
    await _persist();
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;
    _tasks[idx] = task;
    _invalidateCaches();
    await _persist();
    notifyListeners();
  }

  /// 完成/取消完成. fromSchedule=true 表示由日程勾选触发, 避免反向同步死循环
  Future<void> toggleComplete(String id, {bool fromSchedule = false}) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _tasks[idx];
    final completing = !t.isCompleted;
    final now = DateTime.now();

    if (completing) {
      if (t.isRecurring) {
        // 周期任务: 完成后休眠, 满周期后自动回归(周期从完成时刻起算)
        _tasks[idx] = t.copyWith(
          isCompleted: true,
          completedAt: now,
          nextAppearanceAt: now.add(Duration(days: t.repeatIntervalDays)),
        );
      } else {
        _tasks[idx] = t.copyWith(isCompleted: true, completedAt: now);
      }
      completions?.add(CompletionRecord(
        title: t.title,
        kind: CompletionKind.task,
        timestamp: now,
        note: t.isRecurring ? '周期:${t.repeatLabel}' : '',
      ));
    } else {
      _tasks[idx] = t.copyWith(
        isCompleted: false,
        clearCompletedAt: true,
        clearNextAppearance: true,
        cycleStartAt: t.isRecurring ? now : t.cycleStartAt,
      );
    }

    _invalidateCaches();
    await _persist();
    notifyListeners();

    // 反向同步: 日程联动任务完成时, 把对应日程块标记完成
    if (!fromSchedule) {
      onTaskLinkedEvent?.call(id, completing);
    }
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
    _invalidateCaches();
    await _persist();
    notifyListeners();
    return removed;
  }

  /// 撤销删除
  Future<void> restoreTask(Task task) async {
    if (_tasks.any((t) => t.id == task.id)) return;
    _tasks.insert(0, task);
    _invalidateCaches();
    await _persist();
    notifyListeners();
  }

  /// 置顶 / 取消置顶
  Future<void> togglePin(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _tasks[idx] = _tasks[idx].copyWith(isPinned: !_tasks[idx].isPinned);
    _invalidateCaches();
    await _persist();
    notifyListeners();
  }

  /// 取消周期(变成普通一次性任务)
  Future<void> cancelRepeat(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _tasks[idx] = _tasks[idx].copyWith(
      repeatIntervalDays: 0,
      clearNextAppearance: true,
      clearCycleStart: true,
    );
    _invalidateCaches();
    await _persist();
    notifyListeners();
  }

  /// 休眠中的周期任务立即重新激活
  Future<void> activateNow(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _tasks[idx];
    if (!t.isDormant) return;
    _tasks[idx] = t.copyWith(
      isCompleted: false,
      clearCompletedAt: true,
      clearNextAppearance: true,
      cycleStartAt: DateTime.now(),
      subtasks: t.subtasks
          .map((s) => s.copyWith(isDone: false))
          .toList(growable: false),
    );
    _invalidateCaches();
    await _persist();
    notifyListeners();
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
      repeatIntervalDays: t.repeatIntervalDays,
      cycleStartAt: t.isRecurring ? DateTime.now() : null,
    );
    _tasks.insert(0, copy);
    _invalidateCaches();
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

  /// 导入备份后重新读取本地数据
  void reloadFromStorage() {
    load();
  }
}
