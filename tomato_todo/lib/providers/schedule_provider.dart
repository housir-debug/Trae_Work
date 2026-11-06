// providers/schedule_provider.dart - 日程 / 时间块状态
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/schedule_event.dart';
import '../services/storage_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final StorageService _storage;
  List<ScheduleEvent> _events = [];

  ScheduleProvider(this._storage);

  List<ScheduleEvent> get events => _events;

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
    notifyListeners();
  }

  Future<void> _persist() => _storage.saveEvents(_events);

  Future<void> add(ScheduleEvent event) async {
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

  Future<void> delete(String id) async {
    _events.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleDone(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _events[idx] = _events[idx].copyWith(isDone: !_events[idx].isDone);
    await _persist();
    notifyListeners();
  }
}
