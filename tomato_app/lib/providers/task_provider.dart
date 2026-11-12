// providers/task_provider.dart - 待办任务状态
// v3.1: 排序规则 置顶 > 优先级 > 预期时间 > 创建时间
//       支持 单次 / 重复 / 固定 三类待办; 固定待办到点自动回归(单条复用)
//       完成写入时间轴, 取消完成同步撤销记录
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

  /// 日程联动(待办完成 -> 日程完成 反向同步), 由 main 注入
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

  /// 进行中的任务(不含休眠中的重复任务; 固定任务仅在到期当天出现)
  List<Task> get activeTasks {
    if (_activeLastRevision == _activeRevision && _activeCache != null) {
      return _activeCache!;
    }
    final today = DateTime.now();
    final active = _tasks
        .where((t) =>
            !t.isCompleted &&
            !t.isDormant &&
            (!t.isFixed || t.fixedDueOn(today)))
        .toList();
    active.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final cmp = a.effectivePriority.rank.compareTo(b.effectivePriority.rank);
      if (cmp != 0) return cmp;
      final byExpected = a.expectedAt.compareTo(b.expectedAt);
      if (byExpected != 0) return byExpected;
      return a.createdAt.compareTo(b.createdAt);
    });
    _activeCache = active;
    _activeLastRevision = _activeRevision;
    return active;
  }

  int _completedRevision = 0;
  int _completedLastRevision = -1;
  List<Task>? _completedCache;

  /// 已完成任务, 按完成时间倒序
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

  /// 全部周期性任务(重复 + 固定), 周期管理页用
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
    refreshFixed(notify: false);
    _invalidateCaches();
    notifyListeners();
  }

  /// 自动裁剪 366 天前已完成的单次任务(周期任务保留, 它还要循环)
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

  /// 到期的休眠重复任务重新激活(满周期自动回归)
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

  /// 固定待办到点回归: 到期当天 0 点后第一次检查时重置为未完成
  /// 未完成的旧待办被原地复用(不会产生重复条目)
  void refreshFixed({bool notify = true}) {
    final now = DateTime.now();
    final todayKey = dateKey(now);
    var changed = false;
    for (var i = 0; i < _tasks.length; ++i) {
      final t = _tasks[i];
      if (!t.isFixed || !t.fixedDueOn(now)) continue;
      if (t.lastFixedDate == todayKey) continue;
      _tasks[i] = t.copyWith(
        isCompleted: false,
        clearCompletedAt: true,
        subtasks: t.subtasks
            .map((s) => s.copyWith(isDone: false))
            .toList(growable: false),
        lastFixedDate: todayKey,
        cycleStartAt: startOfDay(now),
      );
      changed = true;
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
    if (task.isRepeat && task.cycleStartAt == null) {
      task.cycleStartAt = DateTime.now();
    }
    if (task.isFixed && task.lastFixedDate == null && task.fixedDueOn(DateTime.now())) {
      task.lastFixedDate = dateKey(DateTime.now());
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
      if (t.isRepeat) {
        // 重复任务: 完成后休眠, 满周期后自动回归(周期从完成时刻起算)
        _tasks[idx] = t.copyWith(
          isCompleted: true,
          completedAt: now,
          nextAppearanceAt: now.add(Duration(days: t.repeatIntervalDays)),
        );
      } else {
        _tasks[idx] = t.copyWith(
          isCompleted: true,
          completedAt: now,
          lastFixedDate: t.isFixed ? dateKey(now) : null,
        );
      }
      await completions?.add(CompletionRecord(
        title: t.title,
        kind: CompletionKind.task,
        timestamp: now,
        note: t.isRecurring ? t.repeatLabel : '',
        refId: t.id,
      ));
    } else {
      _tasks[idx] = t.copyWith(
        isCompleted: false,
        clearCompletedAt: true,
        clearNextAppearance: true,
        cycleStartAt: t.isRepeat ? now : t.cycleStartAt,
      );
      await completions?.removeByRef(t.id);
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

  /// 取消周期(变成普通单次任务)
  Future<void> cancelRepeat(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _tasks[idx] = _tasks[idx].copyWith(
      type: TaskType.single,
      repeatIntervalDays: 0,
      clearNextAppearance: true,
      clearCycleStart: true,
      clearLastFixedDate: true,
    );
    _invalidateCaches();
    await _persist();
    notifyListeners();
  }

  /// 休眠中的重复任务立即重新激活
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
      type: t.type,
      priority: t.priority,
      estimatedPomodoros: t.estimatedPomodoros,
      dueDate: t.dueDate,
      expectedAt: t.expectedAt,
      tags: List<String>.from(t.tags),
      subtasks: t.subtasks
          .map((s) => s.copyWith(isDone: false))
          .toList(growable: false),
      repeatIntervalDays: t.repeatIntervalDays,
      cycleStartAt: t.isRepeat ? DateTime.now() : null,
      fixedRule: t.fixedRule,
      fixedWeekday: t.fixedWeekday,
      fixedDayOfMonth: t.fixedDayOfMonth,
      lastFixedDate:
          t.isFixed && t.fixedDueOn(DateTime.now()) ? dateKey(DateTime.now()) : null,
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
}
