// screens/focus_screen.dart - 专注页(底部导航中间主入口)
// v3.1: 以番茄钟为主视觉; 屏幕常亮开关在卡片内;
//       工作阶段完成后弹出「继续工作 / 休息」, 选择继续则下次结束强制休息
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/pomodoro_record.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/pomodoro_timer.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _completionDialogShowing = false;
  late final PomodoroProvider _pomo;

  @override
  void initState() {
    super.initState();
    _pomo = context.read<PomodoroProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pomo.completionSignal.addListener(_onPomodoroPhaseDone);
      // 冷启动/通知回跳时, 若已存在待选择的完成状态, 补弹一次
      if (!_pomo.isRunning && _pomo.lastCompletedKind == 'work') {
        _onPomodoroPhaseDone();
      }
    });
  }

  @override
  void dispose() {
    _pomo.completionSignal.removeListener(_onPomodoroPhaseDone);
    super.dispose();
  }

  void _onPomodoroPhaseDone() {
    if (!mounted || _completionDialogShowing) return;
    final pomo = _pomo;
    // 不在专注页时不打断当前浏览, 由通知栏提醒, 回到专注页再弹出
    if (!pomo.focusPageVisible) return;
    if (pomo.lastCompletedKind == 'work') {
      _showWorkDoneChoice(pomo);
    } else if (pomo.lastCompletedKind == 'break') {
      pomo.lastCompletedKind = null;
      showToast(context, '休息结束，本轮周期完成');
    }
  }

  Future<void> _showWorkDoneChoice(PomodoroProvider pomo) async {
    _completionDialogShowing = true;
    final theme = context.read<SettingsProvider>().currentTheme;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.celebration_outlined, color: theme.primary, size: 22),
            const SizedBox(width: 8),
            Text('专注完成！',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.foreground)),
          ],
        ),
        content: Text(
          '工作完成了吗？\n选择「继续工作」会再专注一轮，本轮结束后将强制休息。',
          style: TextStyle(fontSize: 13, color: theme.muted, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primary,
                    side: BorderSide(color: theme.primary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('continue'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('继续工作',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('break'),
                  icon: const Icon(Icons.coffee_outlined, size: 18),
                  label: const Text('休息',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    _completionDialogShowing = false;
    if (!mounted) return;
    pomo.lastCompletedKind = null;
    if (choice == 'continue') {
      pomo.continueWorking();
      showToast(context, '继续专注，本轮结束后将强制休息');
    } else if (choice == 'break') {
      pomo.takeBreak();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();

    final now = DateTime.now();
    final focusGoal = settings.settings.dailyFocusGoal;
    final focusPercent = focusGoal <= 0
        ? 0.0
        : (pomo.todayWorkMinutes / focusGoal).clamp(0.0, 1.0).toDouble();

    final todayRecords = pomo.records
        .where((r) => r.type == PomodoroType.work && r.isSameDay(now))
        .toList()
        .reversed
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(theme: theme),
          AppCard(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.timer_outlined,
                        color: theme.primary,
                        label: '今日专注',
                        value: '${pomo.todayWorkMinutes}',
                        unit: '分钟',
                      ),
                    ),
                    _divider(theme),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.task_alt,
                        color: theme.accent,
                        label: '完成待办',
                        value: '${tasks.completedToday}',
                        unit: '项',
                      ),
                    ),
                    _divider(theme),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.local_fire_department_outlined,
                        color: const Color(0xFFF06292),
                        label: '连续专注',
                        value: '${pomo.focusStreak}',
                        unit: '天',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 13, color: theme.muted),
                    const SizedBox(width: 4),
                    Text(
                      '每日专注目标 ${durationText(focusGoal)}',
                      style: TextStyle(fontSize: 10, color: theme.muted),
                    ),
                    const Spacer(),
                    Text(
                      '${(focusPercent * 100).round()}%',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: focusPercent,
                    minHeight: 6,
                    backgroundColor: theme.primary.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            child: const PomodoroTimerWidget(),
          ),
          SectionHeader(
            title: '今日专注记录',
            subtitle: todayRecords.isEmpty
                ? '开始第一个番茄吧'
                : '${todayRecords.length} 个番茄 · ${pomo.todayWorkMinutes} 分钟',
          ),
          if (todayRecords.isEmpty)
            const AppCard(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: EmptyHint(
                icon: Icons.timer_outlined,
                text: '还没有专注记录\n点击上方开始，让今天有迹可循',
              ),
            )
          else
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < todayRecords.length; ++i) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: theme.foreground.withOpacity(0.06)),
                    _RecordRow(record: todayRecords[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _divider(ThemeDef theme) => Container(
        width: 1,
        height: 40,
        color: theme.foreground.withOpacity(0.08),
      );
}

class _Header extends StatelessWidget {
  final ThemeDef theme;

  const _Header({required this.theme});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final pomo = context.watch<PomodoroProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${greetingByHour()}，专注当下',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: theme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${shortDate(now)} ${weekdayFull(now)} · 已完成 ${pomo.todayWorkCount} 个专注',
                  style: TextStyle(fontSize: 11, color: theme.muted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.card,
                shape: BoxShape.circle,
                border: Border.all(color: theme.foreground.withOpacity(0.08)),
              ),
              child: Icon(Icons.settings_outlined,
                  size: 19, color: theme.foreground.withOpacity(0.75)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 10.5, color: theme.muted)),
          ],
        ),
        const SizedBox(height: 5),
        RichText(
          text: TextSpan(
            style: TextStyle(color: theme.foreground),
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 10, color: theme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  final PomodoroRecord record;

  const _RecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final hhmm =
        '${record.completedAt.hour.toString().padLeft(2, '0')}:${record.completedAt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: theme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              record.taskTitle?.isNotEmpty == true
                  ? record.taskTitle!
                  : '专注',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: theme.foreground),
            ),
          ),
          Text(
            '$hhmm · ${record.durationMinutes} 分钟',
            style: TextStyle(fontSize: 10, color: theme.muted),
          ),
        ],
      ),
    );
  }
}
