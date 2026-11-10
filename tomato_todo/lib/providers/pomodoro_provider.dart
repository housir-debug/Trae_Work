// providers/pomodoro_provider.dart - 番茄钟状态(含后台恢复与通知)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/utils.dart';
import '../models/app_settings.dart';
import '../models/completion_record.dart';
import '../models/pomodoro_record.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';
import 'completion_provider.dart';

class PomodoroProvider extends ChangeNotifier {
  final StorageService _storage;
  TimerService? _timer;
  AppSettings _settings = AppSettings();
  List<PomodoroRecord> _records = [];
  int _completedWorkCount = 0;
  String? _currentTaskId;
  String? _currentTaskTitle;

  /// 可注入的通知服务(由 main 注入)
  NotificationService? notifications;

  /// 完成记录(时间轴), 由 main 注入
  CompletionProvider? completions;

  /// 每秒变化的剩余秒数(独立通知, 避免整页重建)
  final ValueNotifier<int> remainingNotifier = ValueNotifier<int>(0);

  /// 阶段完成信号(每次完成 +1, 专注页监听并弹选择框)
  final ValueNotifier<int> completionSignal = ValueNotifier<int>(0);

  /// 刚完成的阶段('work' / 'break'), 供弹窗判断
  String? lastCompletedKind;

  /// 选择「继续工作」后, 下一个工作完成时强制进入休息
  bool _forcedBreakPending = false;

  /// 完成一个专注阶段时回调(用于给任务累加番茄)
  void Function(PomodoroRecord record, String? taskId)? onWorkCompleted;

  PomodoroProvider(this._storage);

  TimerState get state => _timer?.state ?? TimerState.idle;
  TimerPhase get phase => _timer?.phase ?? TimerPhase.work;
  int get remainingSeconds => _timer?.remainingSeconds ?? 0;
  int get phaseTotalSeconds => _timer?.totalSeconds ?? 60;
  double get progress => _timer?.progress ?? 0;
  String get phaseLabel => _timer?.phaseLabel ?? '专注中';
  int get completedWorkCount => _completedWorkCount;
  bool get isRunning => state == TimerState.running;
  bool get isPaused => state == TimerState.paused;

  List<PomodoroRecord> get records => _records;

  String? get currentTaskId => _currentTaskId;
  String? get currentTaskTitle => _currentTaskTitle;

  String get timeDisplay => _timer?.formatTime(remainingSeconds) ?? '--:--';

  String formatSeconds(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  void init(AppSettings settings) {
    _settings = settings;
    _completedWorkCount = _storage.loadCompletedWorkCount();
    _records = _storage.loadRecords();
    // 自动裁剪 366 天前的番茄记录
    final cutoff = DateTime.now().subtract(const Duration(days: 366));
    final before = _records.length;
    _records.removeWhere((r) => r.completedAt.isBefore(cutoff));
    if (_records.length != before) {
      _storage.saveRecords(_records);
    }

    TimerSnapshot? snapshot;
    final raw = _storage.loadTimerSnapshot();
    if (raw != null) {
      try {
        snapshot =
            TimerSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        snapshot = null;
      }
    }

    _timer = _buildTimer(settings);
    if (snapshot != null) {
      _timer!.restoreSnapshot(snapshot);
    }
    _emitTick();
    _syncTimerNotification();
    notifyListeners();
  }

  void _emitTick() {
    remainingNotifier.value = _timer?.remainingSeconds ?? 0;
  }

  TimerService _buildTimer(AppSettings settings) => TimerService(
        settings: settings,
        onTick: _emitTick,
        onPhaseChange: (_) => notifyListeners(),
        onStateChanged: () {
          _persistTimer();
          _emitTick();
        },
        onPhaseComplete: (record) {
          final enriched = PomodoroRecord(
            id: record.id,
            type: record.type,
            durationMinutes: record.durationMinutes,
            startedAt: record.startedAt,
            completedAt: record.completedAt,
            taskId: _currentTaskId,
            taskTitle: _currentTaskTitle,
          );
          _records.add(enriched);
          _storage.saveRecords(_records);

          final wasWork = enriched.type == PomodoroType.work;
          if (wasWork) {
            _completedWorkCount++;
            _storage.saveCompletedWorkCount(_completedWorkCount);
            onWorkCompleted?.call(enriched, _currentTaskId);
            // 写入时间轴
            completions?.add(CompletionRecord(
              title: enriched.taskTitle?.isNotEmpty == true
                  ? enriched.taskTitle!
                  : '专注',
              kind: CompletionKind.pomodoro,
              timestamp: enriched.completedAt,
              note: '专注 ${enriched.durationMinutes} 分钟',
            ));
          }

          // 强提醒: 震动 + 提示音(重复一次更醒目)
          if (_settings.enableVibrate) {
            HapticFeedback.vibrate();
            Future.delayed(const Duration(milliseconds: 400), () {
              HapticFeedback.mediumImpact();
            });
          }
          if (_settings.showNotification) {
            SystemSound.play(SystemSoundType.alert);
            Future.delayed(const Duration(milliseconds: 700), () {
              SystemSound.play(SystemSoundType.alert);
            });
          }
          notifications?.cancelTimerEnd();

          // 专注期间保持屏幕常亮, 阶段结束后释放
          if (!isRunning) {
            WakelockPlus.disable();
          }

          if (wasWork) {
            lastCompletedKind = 'work';
            if (_forcedBreakPending) {
              // 「继续工作」后的强制休息: 不再询问, 直接进入休息
              _forcedBreakPending = false;
              _emitTick();
              notifyListeners();
              Future.delayed(const Duration(milliseconds: 600), () {
                start(); // 阶段已在 timer 内切换为长/短休息
              });
            } else {
              // 通知专注页弹选择框: 继续工作 / 去休息
              _emitTick();
              notifyListeners();
              completionSignal.value++;
            }
          } else {
            // 休息结束 = 周期完成, 停在工作就绪态, 等待用户手动开始
            lastCompletedKind = 'break';
            _emitTick();
            notifyListeners();
            completionSignal.value++;
          }
        },
      );

  /// 工作完成后选择「继续工作」: 立即开始下一个番茄, 完成后强制休息
  void continueWorking() {
    if (lastCompletedKind != 'work') return;
    _forcedBreakPending = true;
    _timer?.setPhase(TimerPhase.work);
    _applyWakelock();
    _persistTimer();
    _syncTimerNotification();
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), start);
  }

  /// 工作完成后选择「去休息」: 按算法进入短/长休息
  void takeBreak() {
    if (lastCompletedKind != 'work') return;
    // timer 内部已根据 longBreakInterval 算法切到短/长休息
    _persistTimer();
    _syncTimerNotification();
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), start);
  }

  void updateSettings(AppSettings settings) {
    final old = _settings;
    _settings = settings;
    final durationChanged = old.workDuration != settings.workDuration ||
        old.shortBreakDuration != settings.shortBreakDuration ||
        old.longBreakDuration != settings.longBreakDuration;
    _timer?.applySettings(settings, resetDuration: durationChanged);
    _applyWakelock();
    _syncTimerNotification();
    _emitTick();
    notifyListeners();
  }

  /// 专注运行中且开启「屏幕常亮」时, 保持屏幕不熄灭
  void _applyWakelock() {
    if (_settings.keepScreenOn &&
        _timer?.state == TimerState.running &&
        _timer?.phase == TimerPhase.work) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void start() {
    _timer?.start();
    _applyWakelock();
    _persistTimer();
    _syncTimerNotification();
    notifyListeners();
  }

  void pause() {
    _timer?.pause();
    WakelockPlus.disable();
    _persistTimer();
    _syncTimerNotification();
    notifyListeners();
  }

  void toggle() {
    switch (state) {
      case TimerState.running:
        pause();
        break;
      case TimerState.idle:
      case TimerState.paused:
        start();
        break;
    }
  }

  void reset() {
    _timer?.reset();
    _forcedBreakPending = false;
    WakelockPlus.disable();
    _persistTimer();
    notifications?.cancelTimerEnd();
    notifyListeners();
  }

  void skipPhase() {
    _timer?.skipPhase();
    _persistTimer();
    _syncTimerNotification();
    notifyListeners();
  }

  void setPhase(TimerPhase p) {
    _timer?.setPhase(p);
    _persistTimer();
    _syncTimerNotification();
    notifyListeners();
  }

  /// 回到前台时按真实时间校准
  void syncFromClock() {
    _timer?.syncFromClock();
    _persistTimer();
    _syncTimerNotification();
    notifyListeners();
  }

  void assignTask(Task? task) {
    _currentTaskId = task?.id;
    _currentTaskTitle = task?.title;
    notifyListeners();
  }

  void _persistTimer() {
    final t = _timer;
    if (t == null) return;
    _storage.saveTimerSnapshot(jsonEncode(t.snapshot().toJson()));
  }

  /// 切后台时确保 timer 快照、records 都落盘
  Future<void> flush() async {
    _persistTimer();
    _storage.saveRecords(_records);
    _storage.saveCompletedWorkCount(_completedWorkCount);
  }

  void _syncTimerNotification() {
    final t = _timer;
    if (t == null || notifications == null) return;
    if (t.state == TimerState.running &&
        t.phaseEnd != null &&
        _settings.showNotification) {
      final isWork = t.phase == TimerPhase.work;
      notifications!.scheduleTimerEnd(
        end: t.phaseEnd!,
        title: isWork ? '专注完成' : '休息结束',
        body: isWork ? '辛苦了, 起来走走, 让眼睛休息一下' : '休息结束, 继续专注吧',
      );
    } else {
      notifications!.cancelTimerEnd();
    }
  }

  // ---------- 统计 ----------
  int workMinutesOn(DateTime day) => _records
      .where((r) => r.type == PomodoroType.work && r.isSameDay(day))
      .fold(0, (sum, r) => sum + r.durationMinutes);

  int workCountOn(DateTime day) =>
      _records.where((r) => r.type == PomodoroType.work && r.isSameDay(day)).length;

  int get todayWorkMinutes => workMinutesOn(DateTime.now());

  int get todayWorkCount => workCountOn(DateTime.now());

  int get todayBreakMinutes => _records
      .where((r) => r.type != PomodoroType.work && r.isSameDay(DateTime.now()))
      .fold(0, (sum, r) => sum + r.durationMinutes);

  int get totalWorkMinutes =>
      _records.where((r) => r.type == PomodoroType.work)
          .fold(0, (sum, r) => sum + r.durationMinutes);

  /// 最近 n 天(含今天)每日专注分钟数, 按时间顺序
  List<int> workMinutesLastDays(int n) {
    final today = startOfDay(DateTime.now());
    return List<int>.generate(
        n, (i) => workMinutesOn(today.subtract(Duration(days: n - 1 - i))));
  }

  /// 最近 n 天每日专注次数
  List<int> workCountLastDays(int n) {
    final today = startOfDay(DateTime.now());
    return List<int>.generate(
        n, (i) => workCountOn(today.subtract(Duration(days: n - 1 - i))));
  }

  /// 连续专注天数(在最近 60 天内回溯)
  int get focusStreak {
    var cursor = startOfDay(DateTime.now());
    if (workCountOn(cursor) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (n < 60 && workCountOn(cursor) > 0) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }

  void clearAll() {
    _records = [];
    _completedWorkCount = 0;
    _storage.saveRecords(_records);
    _storage.saveCompletedWorkCount(0);
    _timer?.reset();
    _storage.saveTimerSnapshot(null);
    notifications?.cancelTimerEnd();
    notifyListeners();
  }

  /// 导入备份后重新读取本地数据
  void reloadFromStorage() {
    _records = _storage.loadRecords();
    _completedWorkCount = _storage.loadCompletedWorkCount();
    _timer?.reset();
    _storage.saveTimerSnapshot(null);
    notifications?.cancelTimerEnd();
    _emitTick();
    notifyListeners();
  }

  /// 清理超过 [days] 天的番茄记录, 返回清理条数(默认 365 天)
  Future<int> pruneRecordsOlderThan({int days = 365}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final before = _records.length;
    _records.removeWhere((r) => r.completedAt.isBefore(cutoff));
    final removed = before - _records.length;
    if (removed > 0) {
      await _storage.saveRecords(_records);
      notifyListeners();
    }
    return removed;
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    remainingNotifier.dispose();
    completionSignal.dispose();
    super.dispose();
  }
}
