// providers/schedule_provider.dart - 日程 / 时间块状态
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/completion_record.dart';
import '../models/schedule_event.dart';
import '../services/storage_service.dart';
import 'completion_provider.dart';

class ScheduleProvider extends ChangeNotifier {
  final StorageService _storage;
  List<ScheduleEvent> _events = [];

  ScheduleProvider(this._storage);

  /// 完成记录(时间轴), 由 main 注入
  CompletionProvider? completions;

  /// 创建日程时自动建立联动待办, 返回待办 id(由 main 注入)
  Future<String?> Function(ScheduleEvent event)? createLinkedTask;

  /// 勾选日程完成时同步联动待办(由 main 注入)
  void Function(String taskId, bool done)? toggleLinkedTask;

  // 写入防抖: 拖拽/批量操作时合并多次 _persist
  Timer? _saveTimer;
  List<ScheduleEvent>? _dirtyCache;

  List<ScheduleEvent> get events => _events;

  Future<void> _persist() async {
    _dirtyCache = List.of(_events);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 200), _flush);
  }

  /// 公开 flush: 切后台 / 退出时调用, 强制落盘
  Future<void> flush() async {
    if (_dirtyCache != null) {
      _flush();
    }
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final pending = _dirtyCache;
    _dirtyCache = null;
    if (pending != null) {
      _storage.saveEvents(pending);
    }
  }

  @override
  void dispose() {
    _flush();
    super.dispose();
  }

  List<ScheduleEvent> eventsFor(DateTime day) {
    final key = dateKey(day);
    final list = _events.where((e) => e.dateKey == key).toList();
    list.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return list;
  }

  List<ScheduleEvent> get todayEvents => eventsFor(DateTime.now());

  /// 某天与给定时间段重叠的日程
  List<ScheduleEvent> conflictsOn(
    DateTime day,
    int startMinute,
    int endMinute, {
    String? excludeId,
  }) {
    return eventsFor(day).where((e) {
      if (e.id == excludeId) return false;
      return e.startMinute < endMinute && startMinute < e.endMinute;
    }).toList();
  }

  /// 某天(按分钟)是否有时间块
  bool isBusy(DateTime day, int minute) =>
      eventsFor(day).any((e) => e.startMinute <= minute && minute < e.endMinute);

  /// 本周各分类投入分钟
  Map<ScheduleCategory, int> categoryMinutesThisWeek() {
    final start = dateKey(startOfWeek(DateTime.now()));
    final nowKey = dateKey(DateTime.now());
    final map = <ScheduleCategory, int>{};
    for (final e in _events) {
      if (e.dateKey.compareTo(start) < 0 || e.dateKey.compareTo(nowKey) > 0) {
        continue;
      }
      map[e.category] = (map[e.category] ?? 0) + e.durationMinutes;
    }
    return map;
  }

  /// 最近 n 天(含今天)各分类投入分钟
  Map<ScheduleCategory, int> categoryMinutesInDays(int days) {
    final today = startOfDay(DateTime.now());
    final startKey = dateKey(today.subtract(Duration(days: days - 1)));
    final endKey = dateKey(today);
    final map = <ScheduleCategory, int>{};
    for (final e in _events) {
      if (e.dateKey.compareTo(startKey) < 0 ||
          e.dateKey.compareTo(endKey) > 0) {
        continue;
      }
      map[e.category] = (map[e.category] ?? 0) + e.durationMinutes;
    }
    return map;
  }

  int plannedMinutesOn(DateTime day) =>
      eventsFor(day).fold(0, (sum, e) => sum + e.durationMinutes);

  int get todayDoneCount => todayEvents.where((e) => e.isDone).length;

  void load() {
    _events = _storage.loadEvents();
    // 自动裁剪 366 天前的历史日程, 避免无限增长
    final cutoff = dateKey(DateTime.now().subtract(const Duration(days: 366)));
    final before = _events.length;
    _events.removeWhere((e) => e.dateKey.compareTo(cutoff) < 0);
    if (_events.length != before) {
      _storage.saveEvents(_events);
    }
    notifyListeners();
  }

  Future<void> add(ScheduleEvent event) async {
    // 需求: 在日程中创建的日程等同于待办, 自动同步到待办列表
    if (event.taskId == null && createLinkedTask != null) {
      final taskId = await createLinkedTask!(event);
      if (taskId != null) event.taskId = taskId;
    }
    _events.add(event);
    await _persist();
    notifyListeners();
  }

  Future<void> update(ScheduleEvent event) async {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx < 0) return;
    _events[idx] = event;
    await _persist();
    notifyListeners();
  }

  /// 删除并返回被删除的日程(用于撤销)
  Future<ScheduleEvent?> delete(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final removed = _events.removeAt(idx);
    await _persist();
    notifyListeners();
    return removed;
  }

  /// 撤销删除
  Future<void> restore(ScheduleEvent event) async {
    if (_events.any((e) => e.id == event.id)) return;
    _events.add(event);
    await _persist();
    notifyListeners();
  }

  /// 勾选完成 / 取消完成
  Future<void> toggleDone(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final e = _events[idx];
    final done = !e.isDone;
    _events[idx] = e.copyWith(isDone: done);
    await _persist();
    notifyListeners();

    // 完成日程 = 写入时间轴; 有联动待办时由待办侧统一写, 避免重复记录
    if (e.taskId == null) {
      if (done) {
        await completions?.add(CompletionRecord(
          title: e.title,
          kind: CompletionKind.schedule,
          timestamp: DateTime.now(),
          note:
              '${e.dateKey} ${timeText(e.startMinute)}-${timeText(e.endMinute)}',
          refId: e.id,
        ));
      } else {
        await completions?.removeByRef(e.id);
      }
    }
    // 同步联动待办
    if (e.taskId != null) {
      toggleLinkedTask?.call(e.taskId!, done);
    }
  }

  /// 由待办侧触发: 把关联日程标记完成/取消(待办完成 -> 日程完成)
  void markDoneByTaskId(String taskId, bool done) {
    bool changed = false;
    for (var i = 0; i < _events.length; ++i) {
      final e = _events[i];
      if (e.taskId == taskId && e.isDone != done) {
        _events[i] = e.copyWith(isDone: done);
        changed = true;
      }
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }
}
