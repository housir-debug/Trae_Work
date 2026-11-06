// services/timer_service.dart - 番茄钟计时核心逻辑(绝对时间制, 支持后台恢复)
import 'dart:async';

import '../models/app_settings.dart';
import '../models/pomodoro_record.dart';

enum TimerState { idle, running, paused }

enum TimerPhase { work, shortBreak, longBreak }

/// 可持久化的计时快照
class TimerSnapshot {
  final TimerState state;
  final TimerPhase phase;
  final int remainingSeconds;
  final DateTime? phaseStart;
  final DateTime? phaseEnd;
  final int completedWorkCount;

  const TimerSnapshot({
    required this.state,
    required this.phase,
    required this.remainingSeconds,
    this.phaseStart,
    this.phaseEnd,
    required this.completedWorkCount,
  });

  Map<String, dynamic> toJson() => {
        'state': state.index,
        'phase': phase.index,
        'remainingSeconds': remainingSeconds,
        'phaseStart': phaseStart?.toIso8601String(),
        'phaseEnd': phaseEnd?.toIso8601String(),
        'completedWorkCount': completedWorkCount,
      };

  factory TimerSnapshot.fromJson(Map<String, dynamic> json) => TimerSnapshot(
        state: TimerState.values[
            (json['state'] as int? ?? 0).clamp(0, 2).toInt()],
        phase: TimerPhase.values[
            (json['phase'] as int? ?? 0).clamp(0, 2).toInt()],
        remainingSeconds: json['remainingSeconds'] as int? ?? 0,
        phaseStart: json['phaseStart'] != null
            ? DateTime.tryParse(json['phaseStart'] as String)
            : null,
        phaseEnd: json['phaseEnd'] != null
            ? DateTime.tryParse(json['phaseEnd'] as String)
            : null,
        completedWorkCount: json['completedWorkCount'] as int? ?? 0,
      );
}

class TimerService {
  AppSettings settings;
  final void Function(PomodoroRecord record)? onPhaseComplete;
  final void Function(TimerPhase phase)? onPhaseChange;
  final void Function()? onTick;

  /// 计时状态/剩余时间发生变化(用于持久化快照)
  final void Function()? onStateChanged;

  TimerService({
    required this.settings,
    this.onPhaseComplete,
    this.onPhaseChange,
    this.onTick,
    this.onStateChanged,
  }) {
    _remainingSeconds = _phaseTotalSeconds();
  }

  /// 更新设置; 时长变化且处于空闲时重置剩余时间
  void applySettings(AppSettings s, {bool resetDuration = false}) {
    settings = s;
    if (resetDuration && _state == TimerState.idle) {
      _remainingSeconds = _phaseTotalSeconds();
    }
    onStateChanged?.call();
  }

  TimerState _state = TimerState.idle;
  TimerPhase _phase = TimerPhase.work;
  int _remainingSeconds = 0;
  DateTime? _phaseStart;
  DateTime? _phaseEnd;
  int _completedWorkCount = 0;

  TimerState get state => _state;
  TimerPhase get phase => _phase;
  int get completedWorkCount => _completedWorkCount;

  /// 运行中按真实时钟计算, 暂停/空闲时使用缓存值
  int get remainingSeconds {
    if (_state == TimerState.running && _phaseEnd != null) {
      return _remainingFromClock();
    }
    return _remainingSeconds;
  }

  int _remainingFromClock() {
    final ms = _phaseEnd!.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  DateTime? get phaseStart => _phaseStart;

  DateTime? get phaseEnd => _state == TimerState.running ? _phaseEnd : null;

  double get progress {
    final total = _phaseTotalSeconds();
    if (total == 0) return 0;
    return (1 - remainingSeconds / total).clamp(0.0, 1.0).toDouble();
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

  /// 当前阶段总秒数(供进度展示)
  int get totalSeconds => _phaseTotalSeconds();

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

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTickTimer());
  }

  void _onTickTimer() {
    if (_state != TimerState.running) return;
    final remaining = _remainingFromClock();
    if (remaining <= 0) {
      _completeNaturally(at: _phaseEnd);
      return;
    }
    onTick?.call();
  }

  void start() {
    if (_state == TimerState.running) return;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = _phaseTotalSeconds();
    }
    final now = DateTime.now();
    _phaseStart ??= now.subtract(
      Duration(seconds: _phaseTotalSeconds() - _remainingSeconds),
    );
    _phaseEnd = now.add(Duration(seconds: _remainingSeconds));
    _state = TimerState.running;
    _startTicker();
    onTick?.call();
    onStateChanged?.call();
  }

  void pause() {
    if (_state != TimerState.running) return;
    _remainingSeconds = _remainingFromClock();
    _phaseEnd = null;
    _tick?.cancel();
    _tick = null;
    _state = TimerState.paused;
    onTick?.call();
    onStateChanged?.call();
  }

  void reset() {
    _tick?.cancel();
    _tick = null;
    _state = TimerState.idle;
    _remainingSeconds = _phaseTotalSeconds();
    _phaseStart = null;
    _phaseEnd = null;
    onTick?.call();
    onStateChanged?.call();
  }

  /// 跳过当前阶段(不写入专注记录)
  void skipPhase() {
    _tick?.cancel();
    _tick = null;
    _phase = _nextPhase();
    _remainingSeconds = _phaseTotalSeconds();
    _state = TimerState.idle;
    _phaseStart = null;
    _phaseEnd = null;
    onPhaseChange?.call(_phase);
    onTick?.call();
    onStateChanged?.call();
  }

  void setPhase(TimerPhase phase) {
    _tick?.cancel();
    _tick = null;
    _phase = phase;
    _remainingSeconds = _phaseTotalSeconds();
    _state = TimerState.idle;
    _phaseStart = null;
    _phaseEnd = null;
    onPhaseChange?.call(_phase);
    onTick?.call();
    onStateChanged?.call();
  }

  /// 回到前台时校准; 若阶段已结束则补记完成
  void syncFromClock() {
    if (_state != TimerState.running) return;
    if (_phaseEnd == null) return;
    if (!_phaseEnd!.isAfter(DateTime.now())) {
      _completeNaturally(at: _phaseEnd);
    } else {
      onTick?.call();
    }
  }

  /// 从本地快照恢复. 返回是否在恢复时补记了一个已结束的阶段
  bool restoreSnapshot(TimerSnapshot s) {
    _tick?.cancel();
    _tick = null;
    _state = s.state;
    _phase = s.phase;
    _completedWorkCount = s.completedWorkCount;
    _remainingSeconds = s.remainingSeconds;
    _phaseStart = s.phaseStart;
    _phaseEnd = s.phaseEnd;

    if (_state == TimerState.running) {
      final now = DateTime.now();
      _phaseEnd ??= now.add(Duration(seconds: _remainingSeconds));
      if (!_phaseEnd!.isAfter(now)) {
        _completeNaturally(at: _phaseEnd);
        return true;
      }
      _startTicker();
    }
    return false;
  }

  TimerSnapshot snapshot() => TimerSnapshot(
        state: _state,
        phase: _phase,
        remainingSeconds: remainingSeconds,
        phaseStart: _phaseStart,
        phaseEnd: _phaseEnd,
        completedWorkCount: _completedWorkCount,
      );

  void _completeNaturally({DateTime? at}) {
    _tick?.cancel();
    _tick = null;

    final now = at ?? DateTime.now();
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
    _phaseEnd = null;
    onPhaseChange?.call(_phase);
    onTick?.call();
    onStateChanged?.call();
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
