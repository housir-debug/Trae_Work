// screens/today_screen.dart - 今日秘书首页
// v3.0: 只保留 概览/番茄钟/今日行程/今日复盘;
//       待办与周期习惯在「待办」页管理, 完成记录看「时间轴」页;
//       番茄钟工作阶段完成后弹出选择: 继续工作(下一轮后强制休息) / 去休息
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/schedule_event.dart';
import '../providers/journal_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/journal_sheet.dart';
import '../widgets/pomodoro_timer.dart';
import '../widgets/schedule_editor.dart';
import '../widgets/ui.dart';
import 'journal_history_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback? onOpenTasks;

  const TodayScreen({super.key, this.onOpenTasks});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _completionDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // 监听番茄钟阶段完成信号, 弹出「继续工作 / 去休息」选择
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PomodoroProvider>().completionSignal.addListener(_onPomodoroPhaseDone);
    });
  }

  @override
  void dispose() {
    // provider 可能先 dispose, 用 try 容错
    super.dispose();
  }

  void _onPomodoroPhaseDone() {
    if (!mounted || _completionDialogShowing) return;
    final pomo = context.read<PomodoroProvider>();
    if (pomo.lastCompletedKind == 'work') {
      _showWorkDoneChoice(pomo);
    } else if (pomo.lastCompletedKind == 'break') {
      pomo.lastCompletedKind = null;
      showToast(context, '休息结束，本轮周期完成 ✓');
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
          '工作完成了吗？\n选择「继续工作」将再专注一轮，之后强制休息。',
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                  label: const Text('去休息',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
    final schedule = context.watch<ScheduleProvider>();
    final journal = context.watch<JournalProvider>();

    final now = DateTime.now();
    final focusGoal = settings.settings.dailyFocusGoal;
    final focusPercent = focusGoal <= 0
        ? 0.0
        : (pomo.todayWorkMinutes / focusGoal).clamp(0.0, 1.0).toDouble();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(theme: theme),
          // 今日概览
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
          // 番茄钟
          AppCard(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
            child: const PomodoroTimerWidget(),
          ),
          // 今日行程
          SectionHeader(
            title: '今日行程',
            subtitle:
                '${schedule.todayEvents.length} 项 · 已规划 ${durationText(schedule.plannedMinutesOn(now))}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: '复制昨日行程',
                  child: GestureDetector(
                    onTap: () => _copyYesterday(context),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(Icons.content_copy,
                          size: 17, color: theme.muted),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScheduleScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.calendar_view_week,
                        size: 18, color: theme.primary),
                  ),
                ),
                _AddButton(
                  onTap: () => showScheduleEditor(context),
                  theme: theme,
                  label: '规划',
                ),
              ],
            ),
          ),
          if (schedule.todayEvents.isEmpty)
            const AppCard(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: EmptyHint(
                icon: Icons.view_timeline_outlined,
                text: '还没有安排 · 点击「规划」为今天划定时间块',
              ),
            )
          else
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (int i = 0; i < schedule.todayEvents.length; ++i) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: theme.foreground.withOpacity(0.06)),
                    _EventTile(
                      event: schedule.todayEvents[i],
                      onTap: () => showScheduleEditor(
                          context,
                          event: schedule.todayEvents[i]),
                      onToggle: () => schedule
                          .toggleDone(schedule.todayEvents[i].id),
                    ),
                  ],
                ],
              ),
            ),
          // 今日复盘
          SectionHeader(
            title: '今日复盘',
            subtitle: journal.entriesThisMonth == 0
                ? '记录一天, 看见成长'
                : '本月已记录 ${journal.entriesThisMonth} 天',
            trailing: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const JournalHistoryScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text('历史',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.primary)),
              ),
            ),
          ),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => showJournalEditor(context),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    journal.todayEntry?.moodEmoji ?? '📝',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journal.todayEntry == null
                            ? '今天过得怎么样?'
                            : '心情 ${journal.todayEntry!.mood}/5 · 精力 ${journal.todayEntry!.energy}/5',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.foreground),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        journal.todayEntry?.highlight.isNotEmpty == true
                            ? journal.todayEntry!.highlight
                            : '写下高光时刻、感恩与反思, 给今天一个收尾',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: theme.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: theme.muted),
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

  Future<void> _copyYesterday(BuildContext context) async {
    final now = DateTime.now();
    final today = startOfDay(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final count =
        await context.read<ScheduleProvider>().copyDay(yesterday, today);
    if (!context.mounted) return;
    showToast(
      context,
      count == 0 ? '昨天没有可复制的行程' : '已把昨日 $count 项行程复制到今天',
    );
  }
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
                  '${greetingByHour()}，今天也要好好生活',
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

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final ThemeDef theme;
  final String label;

  const _AddButton({
    required this.onTap,
    required this.theme,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 13, color: theme.primary),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.primary)),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _EventTile({
    required this.event,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final color = event.category.color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText(event.startMinute),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.foreground),
                  ),
                  Text(
                    timeText(event.endMinute),
                    style: TextStyle(fontSize: 10, color: theme.muted),
                  ),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: event.isDone ? theme.muted : theme.foreground,
                      decoration:
                          event.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(event.category.icon, size: 10, color: color),
                      const SizedBox(width: 3),
                      Text(
                        '${event.category.label} · ${durationText(event.durationMinutes)}',
                        style: TextStyle(fontSize: 10, color: theme.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: event.isDone ? color : Colors.transparent,
                    border: Border.all(
                      color: event.isDone
                          ? color
                          : theme.foreground.withOpacity(0.2),
                    ),
                  ),
                  child: event.isDone
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
