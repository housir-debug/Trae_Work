// providers/journal_provider.dart - 每日复盘状态
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/journal_entry.dart';
import '../services/storage_service.dart';

class JournalProvider extends ChangeNotifier {
  final StorageService _storage;
  List<JournalEntry> _entries = [];

  JournalProvider(this._storage);

  List<JournalEntry> get entries => _entries;

  JournalEntry? entryFor(DateTime day) {
    final key = dateKey(day);
    for (final e in _entries) {
      if (e.dateKey == key) return e;
    }
    return null;
  }

  JournalEntry? get todayEntry => entryFor(DateTime.now());

  JournalEntry? entryForKey(String key) {
    for (final e in _entries) {
      if (e.dateKey == key) return e;
    }
    return null;
  }

  List<JournalEntry> entriesInMonth(int year, int month) {
    return _entries.where((e) {
      final d = DateTime.tryParse(e.dateKey);
      return d != null && d.year == year && d.month == month;
    }).toList();
  }

  int get entriesThisMonth {
    final now = DateTime.now();
    return _entries.where((e) {
      final d = DateTime.tryParse(e.dateKey);
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
  }

  double get averageMood {
    if (_entries.isEmpty) return 0;
    final sum = _entries.fold(0, (s, e) => s + e.mood);
    return sum / _entries.length;
  }

  void load() {
    _entries = _storage.loadJournals();
    notifyListeners();
  }

  Future<void> save(JournalEntry entry) async {
    final idx = _entries.indexWhere((e) => e.dateKey == entry.dateKey);
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
    _entries.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    await _storage.saveJournals(_entries);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _storage.saveJournals(_entries);
    notifyListeners();
  }

  Future<void> flush() async {
    await _storage.saveJournals(_entries);
  }
}
