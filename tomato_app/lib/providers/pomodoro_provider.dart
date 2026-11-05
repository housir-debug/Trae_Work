// providers/pomodoro_provider.dart - 番茄钟状态 Provider
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/pomodoro_record.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';

class PomodoroProvider extends ChangeNotifier {
  final StorageService _storage;
  TimerService? _timer;
  List<PomodoroRecord> _records = [];
  int _completedWorkCount = 0;

  PomodoroProvider(this._storage);

  TimerState get state => _timer?.state ?? TimerState.idle;
  TimerPhase get phase => _timer?.phase ?? TimerPhase.work;
  int get remainingSeconds => _timer?.remainingSeconds ?? 0;
  double get progress => _timer?.progress ?? 0;
  String get phaseLabel => _timer?.phaseLabel ?? '专注中';
  int get completedWorkCount => _completedWorkCount;

  List<PomodoroRecord> get records => _records;

  String get timeDisplay {
    return _timer?.formatTime(remainingSeconds) ?? '25:00';
  }

  void init(AppSettings settings) {
    _completedWorkCount = _storage.loadCompletedWorkCount();
    _records = _storage.loadRecords();
    _timer = TimerService(
      settings: settings,
      onPhaseComplete: (record) {
        _records.add(record);
        _storage.saveRecords(_records);
        _completedWorkCount = _timer!.completedWorkCount;
        _storage.saveCompletedWorkCount(_completedWorkCount);
        notifyListeners();
      },
      onPhaseChange: (_) => notifyListeners(),
    );
    _timer!.start();
    _timer!.pause();
    notifyListeners();
  }

  void updateSettings(AppSettings settings) {
    // 重新创建计时器以应用新设置的时长
    final wasRunning = _timer?.state == TimerState.running;
    final currentPhase = _timer?.phase ?? TimerPhase.work;
    _timer = TimerService(
      settings: settings,
      onPhaseComplete: (record) {
        _records.add(record);
        _storage.saveRecords(_records);
        _completedWorkCount = _timer!.completedWorkCount;
        _storage.saveCompletedWorkCount(_completedWorkCount);
        notifyListeners();
      },
      onPhaseChange: (_) => notifyListeners(),
    );
    _timer!.setPhase(currentPhase);
    if (wasRunning) _timer!.resume();
    notifyListeners();
  }

  void start() {
    _timer?.start();
    notifyListeners();
  }

  void pause() {
    _timer?.pause();
    notifyListeners();
  }

  void resume() {
    _timer?.resume();
    notifyListeners();
  }

  void reset() {
    _timer?.reset();
    notifyListeners();
  }

  void skipPhase() {
    _timer?.skipPhase();
    notifyListeners();
  }

  void setPhase(TimerPhase p) {
    _timer?.setPhase(p);
    notifyListeners();
  }

  void setTaskId(String? taskId) {
    _currentTaskId = taskId;
  }

  String? _currentTaskId;
  String? get currentTaskId => _currentTaskId;
}
