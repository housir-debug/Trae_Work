// services/timer_service.dart - 番茄钟计时核心逻辑
import 'dart:async';

import '../models/app_settings.dart';
import '../models/pomodoro_record.dart';

enum TimerState { idle, running, paused }

enum TimerPhase { work, shortBreak, longBreak }

class TimerService {
  AppSettings settings;
  final void Function(PomodoroRecord record)? onPhaseComplete;
  final void Function(TimerPhase phase)? onPhaseChange;
  final void Function()? onTick;

  TimerService({
    required this.settings,
    this.onPhaseComplete,
    this.onPhaseChange,
    this.onTick,
  }) {
    _remainingSeconds = _phaseTotalSeconds();
  }

  /// 更新设置; 时长变化且处于空闲时重置剩余时间
  void applySettings(AppSettings s, {bool resetDuration = false}) {
    settings = s;
    if (resetDuration && _state == TimerState.idle) {
      _remainingSeconds = _phaseTotalSeconds();
    }
  }

  TimerState _state = TimerState.idle;
  TimerPhase _phase = TimerPhase.work;
  int _remainingSeconds = 0;
  DateTime? _phaseStart;
  int _completedWorkCount = 0;

  TimerState get state => _state;
  TimerPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  int get completedWorkCount => _completedWorkCount;

  double get progress {
    final total = _phaseTotalSeconds();
    if (total == 0) return 0;
    return 1 - _remainingSeconds / total;
  }

  String get phaseLabel {
    switch (_phase) {
      case TimerPhase.work:
        return '专注中';
      case TimerPhase.shortBreak:
        return '短休息';
      case TimerPhase.longBreak:
        return '长休息';
    }
  }

  int _phaseTotalSeconds() {
    switch (_phase) {
      case TimerPhase.work:
        return settings.workDuration * 60;
      case TimerPhase.shortBreak:
        return settings.shortBreakDuration * 60;
      case TimerPhase.longBreak:
        return settings.longBreakDuration * 60;
    }
  }

  Timer? _tick;

  void start() {
    if (_state == TimerState.running) return;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = _phaseTotalSeconds();
    }
    _phaseStart = DateTime.now();
    _state = TimerState.running;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      onTick?.call();
      if (_remainingSeconds <= 0) {
        _phaseComplete();
      }
    });
  }

  void pause() {
    _tick?.cancel();
    _tick = null;
    _state = TimerState.paused;
  }

  void resume() {
    _phaseStart = DateTime.now();
    start();
  }

  void reset() {
    _tick?.cancel();
    _tick = null;
    _state = TimerState.idle;
    _remainingSeconds = _phaseTotalSeconds();
    _phaseStart = null;
  }

  void skipPhase() {
    if (_state != TimerState.running && _phase == TimerPhase.work) {
      // 未开始的专注跳过不记录
      _phase = _nextPhase();
      _remainingSeconds = _phaseTotalSeconds();
      _state = TimerState.idle;
      onPhaseChange?.call(_phase);
      return;
    }
    _phaseComplete();
  }

  void setPhase(TimerPhase phase) {
    _tick?.cancel();
    _tick = null;
    _phase = phase;
    _remainingSeconds = _phaseTotalSeconds();
    _state = TimerState.idle;
    onPhaseChange?.call(_phase);
  }

  void _phaseComplete() {
    _tick?.cancel();
    _tick = null;

    final now = DateTime.now();
    final duration = _phaseTotalSeconds() ~/ 60;

    final record = PomodoroRecord(
      type: _phaseToRecordType(_phase),
      durationMinutes: duration,
      startedAt: _phaseStart ?? now.subtract(Duration(minutes: duration)),
      completedAt: now,
    );

    final wasWork = _phase == TimerPhase.work;
    if (wasWork) {
      _completedWorkCount++;
    }

    onPhaseComplete?.call(record);

    _phase = _nextPhase();
    _remainingSeconds = _phaseTotalSeconds();
    _state = TimerState.idle;
    _phaseStart = null;
    onPhaseChange?.call(_phase);
  }

  TimerPhase _nextPhase() {
    if (_phase == TimerPhase.work) {
      if (_completedWorkCount % settings.longBreakInterval == 0) {
        return TimerPhase.longBreak;
      }
      return TimerPhase.shortBreak;
    }
    return TimerPhase.work;
  }

  PomodoroType _phaseToRecordType(TimerPhase p) {
    switch (p) {
      case TimerPhase.work:
        return PomodoroType.work;
      case TimerPhase.shortBreak:
        return PomodoroType.shortBreak;
      case TimerPhase.longBreak:
        return PomodoroType.longBreak;
    }
  }

  String formatTime(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}
