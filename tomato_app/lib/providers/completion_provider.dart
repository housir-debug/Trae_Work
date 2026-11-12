// providers/completion_provider.dart - 完成记录(时间轴数据源)
// 所有「已经完成的事」统一写这里: 任务完成 / 日程完成 / 习惯打卡 / 番茄专注
// 加载时自动裁剪 366 天前的记录, 避免无限增长
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/completion_record.dart';
import '../services/storage_service.dart';

class CompletionProvider extends ChangeNotifier {
  final StorageService _storage;
  List<CompletionRecord> _records = [];

  /// 记录保留天数, 超过自动裁剪
  static const int keepDays = 366;

  CompletionProvider(this._storage);

  List<CompletionRecord> get records => _records;

  void load() {
    _records = _storage.loadCompletionLog();
    _prune(notify: false);
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _persist() => _storage.saveCompletionLog(_records);

  /// 切后台时确保落盘(本 provider 立即持久化, flush 仅为统一步调)
  Future<void> flush() => _persist();

  void _prune({bool notify = true}) {
    final cutoff = DateTime.now().subtract(const Duration(days: keepDays));
    final before = _records.length;
    _records.removeWhere((r) => r.timestamp.isBefore(cutoff));
    if (_records.length != before) {
      _storage.saveCompletionLog(_records);
      if (notify) notifyListeners();
    }
  }

  Future<void> add(CompletionRecord record) async {
    _records.insert(0, record);
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _prune(notify: false);
    await _persist();
    notifyListeners();
  }

  /// 撤销某条来源对象最近的一条完成记录(取消完成时调用)
  Future<void> removeByRef(String refId) async {
    final idx = _records.indexWhere((r) => r.refId == refId);
    if (idx < 0) return;
    _records.removeAt(idx);
    await _persist();
    notifyListeners();
  }

  /// 某天的全部完成记录(按时间升序)
  List<CompletionRecord> forDay(DateTime day) {
    final list =
        _records.where((r) => isSameDate(r.timestamp, day)).toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  /// 某月有完成记录的日期集合(月历打点用)
  Set<String> daysWithRecordsIn(int year, int month) {
    final prefix =
        '$year-${month.toString().padLeft(2, '0')}-';
    final set = <String>{};
    for (final r in _records) {
      final key = dateKey(r.timestamp);
      if (key.startsWith(prefix)) set.add(key);
    }
    return set;
  }

  int countOn(DateTime day) =>
      _records.where((r) => isSameDate(r.timestamp, day)).length;

  int countBetween(DateTime start, DateTime end) => _records.where((r) {
        return !r.timestamp.isBefore(start) && r.timestamp.isBefore(end);
      }).length;

  /// 某年各月完成数量(年统计用), 返回 12 个元素
  List<int> monthlyCounts(int year) {
    final counts = List<int>.filled(12, 0);
    for (final r in _records) {
      if (r.timestamp.year == year) counts[r.timestamp.month - 1]++;
    }
    return counts;
  }
}
