// main.dart - 时光秘书 入口 / 主题 / 底部导航
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_navigator.dart';
import 'core/utils.dart';
import 'models/app_settings.dart';
import 'models/completion_record.dart';
import 'models/task.dart';
import 'providers/completion_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/task_provider.dart';
import 'screens/focus_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/schedule_day_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/timeline_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/backgrounds.dart';
import 'widgets/journal_sheet.dart';

/// 跨页面切换 Tab 的请求(通知点击回到专注页时使用)
final ValueNotifier<int> appTabRequest = ValueNotifier<int>(-1);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await StorageService.instance.init();
  await NotificationService.instance.init();
  runApp(const ShiguangApp());
}

class ShiguangApp extends StatefulWidget {
  const ShiguangApp({super.key});

  @override
  State<ShiguangApp> createState() => _ShiguangAppState();
}

class _ShiguangAppState extends State<ShiguangApp> {
  late final SettingsProvider _settingsProv;
  late final TaskProvider _taskProv;
  late final CompletionProvider _completionProv;
  late final GoalProvider _goalProv;
  late final ScheduleProvider _scheduleProv;
  late final JournalProvider _journalProv;
  late final PomodoroProvider _pomoProv;
  Timer? _syncDebounce;

  @override
  void initState() {
    super.initState();
    _settingsProv = SettingsProvider(StorageService.instance)..load();
    _completionProv = CompletionProvider(StorageService.instance)..load();
    _taskProv = TaskProvider(StorageService.instance)
      ..completions = _completionProv
      ..load();
    _goalProv = GoalProvider(StorageService.instance)..load();
    _scheduleProv = ScheduleProvider(StorageService.instance)
      ..completions = _completionProv
      ..load();
    _journalProv = JournalProvider(StorageService.instance)..load();
    _pomoProv = PomodoroProvider(StorageService.instance)
      ..completions = _completionProv
      ..notifications = NotificationService.instance
      ..init(_settingsProv.settings);

    // 完成专注 -> 累加关联任务的番茄
    _pomoProv.onWorkCompleted = (record, taskId) {
      if (taskId != null) {
        _taskProv.incrementPomodoro(taskId);
      }
    };

    // ---- 日程 <-> 待办 双向联动 ----
    // 待办勾选完成 -> 同步日程勾选状态
    _taskProv.onTaskLinkedEvent = _scheduleProv.markDoneByTaskId;
    // 新建日程 -> 自动生成一条联动待办(优先级由 dueDate 自动递进)
    _scheduleProv.createLinkedTask = (event) async {
      final day = DateTime.tryParse(event.dateKey) ?? DateTime.now();
      final task = Task(title: event.title, dueDate: startOfDay(day));
      await _taskProv.addTask(task);
      return task.id;
    };
    // 日程勾选完成 -> 同步待办完成状态
    _scheduleProv.toggleLinkedTask = (taskId, done) {
      final task = _taskProv.taskById(taskId);
      if (task == null || task.isCompleted == done) return;
      _taskProv.toggleComplete(taskId, fromSchedule: true);
    };

    // 设置变化时同步计时器参数与提醒
    _settingsProv.addListener(() {
      _pomoProv.updateSettings(_settingsProv.settings);
      _scheduleNotificationSync();
    });
    // 日程变化时重新安排提醒
    _scheduleProv.addListener(_scheduleNotificationSync);

    _migrateHabits();
    _syncNotifications();
  }

  /// v3.0 迁移: 习惯打卡合并为「重复待办」, 打卡历史进入时间轴
  Future<void> _migrateHabits() async {
    final storage = StorageService.instance;
    if (storage.habitsMigrated) return;
    final habits = storage.loadHabits();
    for (final h in habits) {
      final interval = (7 / h.targetPerWeek).round().clamp(1, 30);
      await _taskProv.addTask(Task(
        title: h.name,
        type: TaskType.repeat,
        repeatIntervalDays: interval,
        cycleStartAt: DateTime.now(),
      ));
      for (final key in h.checkIns) {
        final day = DateTime.tryParse(key);
        if (day == null) continue;
        await _completionProv.add(CompletionRecord(
          title: h.name,
          kind: CompletionKind.habit,
          timestamp: h.checkInTimes[key] ?? day,
          note: '习惯打卡',
        ));
      }
    }
    await storage.saveHabits([]);
    await storage.markHabitsMigrated();
  }

  /// 合并短时间内的多次变更, 避免频繁取消/重排通知
  void _scheduleNotificationSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), () {
      _syncNotifications();
    });
  }

  Future<void> _syncNotifications() async {
    final notifications = NotificationService.instance;
    final settings = _settingsProv.settings;
    await notifications.syncDailyReminders(settings);
    await notifications.syncEventReminders(_scheduleProv.events, settings);
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _settingsProv.dispose();
    _taskProv.dispose();
    _completionProv.dispose();
    _goalProv.dispose();
    _scheduleProv.dispose();
    _journalProv.dispose();
    _pomoProv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsProv),
        ChangeNotifierProvider.value(value: _taskProv),
        ChangeNotifierProvider.value(value: _completionProv),
        ChangeNotifierProvider.value(value: _goalProv),
        ChangeNotifierProvider.value(value: _scheduleProv),
        ChangeNotifierProvider.value(value: _journalProv),
        ChangeNotifierProvider.value(value: _pomoProv),
      ],
      child: Consumer<SettingsProvider>(
        builder: (ctx, sp, _) {
          final theme = sp.currentTheme;
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: '时光秘书',
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: theme.toColorScheme(
                theme.isDark ? Brightness.dark : Brightness.light,
              ),
              scaffoldBackgroundColor: theme.background,
              appBarTheme: AppBarTheme(
                backgroundColor: theme.background,
                foregroundColor: theme.foreground,
                elevation: 0,
              ),
              snackBarTheme: const SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
              ),
            ),
            home: RootGate(
              initiallyLocked: sp.settings.appLockEnabled &&
                  sp.settings.pinHash != null,
            ),
          );
        },
      ),
    );
  }
}

// ============ 应用锁入口 ============
class RootGate extends StatefulWidget {
  final bool initiallyLocked;

  const RootGate({super.key, required this.initiallyLocked});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  late bool _locked = widget.initiallyLocked;
  bool _wasBackground = false;
  Timer? _relockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 通知点击: 统一走 RootGate, 避免绕过应用锁
    NotificationService.instance.onEventTap = _openPendingEvent;
    // 冷启动时由通知进入: 首帧后跳到对应日期的周视图
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingEvent());
  }

  void _openPendingEvent() {
    if (_locked) return;
    final notifications = NotificationService.instance;
    final key = notifications.peekPendingEventDate();
    if (key != null) {
      appNavigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => ScheduleScreen(initialDate: DateTime.tryParse(key)),
      ));
      notifications.clearPendingEventDate();
      return;
    }
    // 番茄结束通知: 回到专注页并弹出「继续工作 / 休息」
    if (notifications.hasPendingPomodoro) {
      notifications.clearPendingPomodoro();
      appTabRequest.value = 2;
      Future.delayed(const Duration(milliseconds: 320), () {
        try {
          context.read<PomodoroProvider>().showCompletionChoiceIfPending();
        } catch (_) {}
      });
      return;
    }
    // 每日复盘提醒: 直接打开今日复盘
    if (notifications.hasPendingReview) {
      notifications.clearPendingReview();
      showJournalEditor(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackground = true;
      _relockTimer?.cancel();
      _relockTimer = null;
      // 离开应用即视为不在专注页: 取消常亮, 保持通知栏常驻
      try {
        context.read<PomodoroProvider>().setFocusPageVisible(false);
      } catch (_) {}
      // 统一落盘: 确保所有 Provider 的最后一次写入不会丢
      try { context.read<SettingsProvider>().flush(); } catch (_) {}
      try { context.read<TaskProvider>().flush(); } catch (_) {}
      try { context.read<ScheduleProvider>().flush(); } catch (_) {}
      try { context.read<CompletionProvider>().flush(); } catch (_) {}
      try { context.read<GoalProvider>().flush(); } catch (_) {}
      try { context.read<JournalProvider>().flush(); } catch (_) {}
      try { context.read<PomodoroProvider>().flush(); } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      // 回到前台先按真实时间校准番茄钟
      try {
        context.read<PomodoroProvider>().syncFromClock();
      } catch (_) {}
      if (_wasBackground && !_locked) {
        final settings = context.read<SettingsProvider>().settings;
        if (settings.appLockEnabled && settings.pinHash != null) {
          final delay = settings.relockDelaySeconds;
          _relockTimer?.cancel();
          if (delay <= 0) {
            _lockNow();
          } else {
            _relockTimer = Timer(Duration(seconds: delay), _lockNow);
          }
        }
      }
      _wasBackground = false;
    }
  }

  /// 收起已打开的页面并上锁
  void _lockNow() {
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return LockScreen(
        onUnlocked: () {
          _relockTimer?.cancel();
          setState(() => _locked = false);
          _openPendingEvent();
        },
      );
    }
    return const RootPage();
  }
}

// ============ 根页面: 背景 + 导航 ============
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  int _idx = 2;

  List<Widget> get _screens => [
        const ScheduleDayScreen(),
        const TasksScreen(),
        const FocusScreen(),
        const GoalsScreen(),
        const TimelineScreen(),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appTabRequest.addListener(_onTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PomodoroProvider>().setFocusPageVisible(_idx == 2);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appTabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final target = appTabRequest.value;
    if (target < 0 || target >= _screens.length) return;
    appTabRequest.value = -1;
    _switchTab(target);
  }

  void _switchTab(int i) {
    if (!mounted) return;
    setState(() => _idx = i);
    final pomo = context.read<PomodoroProvider>();
    pomo.setFocusPageVisible(i == 2);
    if (i == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        pomo.showCompletionChoiceIfPending();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        final pomo = context.read<PomodoroProvider>();
        pomo.setFocusPageVisible(_idx == 2);
        if (_idx == 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            pomo.showCompletionChoiceIfPending();
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppBackground(settings: sp.settings, theme: theme),
          SafeArea(
            bottom: false,
            child: IndexedStack(index: _idx, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _idx,
        onTap: _switchTab,
        theme: theme,
      ),
    );
  }
}

// ============ 底部导航 ============
class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final ThemeDef theme;

  const _BottomBar({
    required this.index,
    required this.onTap,
    required this.theme,
  });

  static const _items = [
    (Icons.event_note_outlined, '日程'),
    (Icons.checklist_rtl, '待办'),
    (Icons.timer_outlined, '专注'),
    (Icons.flag_outlined, '目标'),
    (Icons.auto_graph_outlined, '记录'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardBackground.withOpacity(0.78),
            border: Border(
              top: BorderSide(
                  color: theme.foreground.withOpacity(0.06), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  for (int i = 0; i < _items.length; ++i)
                    Expanded(
                      child: _BottomButton(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        active: i == index,
                        emphasized: i == 2,
                        onTap: () => onTap(i),
                        theme: theme,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool emphasized;
  final VoidCallback onTap;
  final ThemeDef theme;

  const _BottomButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    if (emphasized) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primary.withOpacity(active ? 0.42 : 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: theme.primary,
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: active
                    ? theme.primary.withOpacity(0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: active
                    ? theme.primary
                    : theme.foreground.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active
                    ? theme.primary
                    : theme.foreground.withOpacity(0.45),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
