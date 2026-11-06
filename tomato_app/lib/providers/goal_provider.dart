// providers/goal_provider.dart - 目标状态
import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../services/storage_service.dart';

class GoalProvider extends ChangeNotifier {
  final StorageService _storage;
  List<Goal> _goals = [];

  GoalProvider(this._storage);

  List<Goal> get goals => _goals;

  List<Goal> get activeGoals =>
      _goals.where((g) => !g.isCompleted).toList(growable: false);

  List<Goal> get completedGoals =>
      _goals.where((g) => g.isCompleted).toList(growable: false);

  double get averageProgress {
    if (_goals.isEmpty) return 0;
    final sum = _goals.map((g) => g.progress).reduce((a, b) => a + b);
    return sum / _goals.length;
  }

  int get totalMilestones =>
      _goals.fold(0, (sum, g) => sum + g.milestones.length);

  int get doneMilestones =>
      _goals.fold(0, (sum, g) => sum + g.doneMilestones);

  void load() {
    _goals = _storage.loadGoals();
    notifyListeners();
  }

  Future<void> _persist() => _storage.saveGoals(_goals);

  Future<void> add(Goal goal) async {
    _goals.insert(0, goal);
    await _persist();
    notifyListeners();
  }

  Future<void> update(Goal goal) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx < 0) return;
    _goals[idx] = goal;
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleMilestone(String goalId, String milestoneId) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;
    final goal = _goals[idx];
    for (final m in goal.milestones) {
      if (m.id == milestoneId) {
        m.isDone = !m.isDone;
        m.doneAt = m.isDone ? DateTime.now() : null;
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> addMilestone(String goalId, String title) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0 || title.trim().isEmpty) return;
    _goals[idx].milestones.add(Milestone(title: title.trim()));
    await _persist();
    notifyListeners();
  }

  Future<void> removeMilestone(String goalId, String milestoneId) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;
    _goals[idx].milestones.removeWhere((m) => m.id == milestoneId);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleComplete(String goalId) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;
    final g = _goals[idx];
    _goals[idx] = g.isCompleted
        ? g.copyWith(isCompleted: false, clearCompletedAt: true)
        : g.copyWith(isCompleted: true, completedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }
}
