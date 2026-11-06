// screens/today_screen.dart - 今日秘书首页
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/habit.dart';
import '../models/pomodoro_record.dart';
import '../models/schedule_event.dart';
import '../models/task.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/journal_sheet.dart';
import '../widgets/pomodoro_timer.dart';
import '../widgets/schedule_editor.dart';
import '../widgets/task_input.dart';
import '../widgets/task_item.dart';
import '../widgets/ui.dart';
import 'journal_history_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

class TodayScreen extends StatelessWidget {
  final VoidCallback? onOpenTasks;

  const TodayScreen({super.key, this.onOpenTasks});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();
    final habits = context.watch<HabitProvider>();
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
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: const EmptyHint(
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
          // 今日待办
          SectionHeader(
            title: '今日待办',
            subtitle: '今日 ${tasks.todayTasks.length} 项 · 进行中 ${tasks.activeCount} 项',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onOpenTasks != null)
                  GestureDetector(
                    onTap: onOpenTasks,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '全部 ${tasks.activeCount} 项',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.primary,
                        ),
                      ),
                    ),
                  ),
                _AddButton(
                  onTap: () => showTaskEditor(context),
                  theme: theme,
                  label: '新建',
                ),
              ],
            ),
          ),
          const QuickTaskInput(),
          if (tasks.todayTasks.isEmpty)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: const EmptyHint(
                icon: Icons.checklist_rtl,
                text: '今天还没有待办 · 快速记录或新建一项',
              ),
            )
          else ...[
            ...tasks.todayTasks.take(5).map((t) => TaskItemWidget(
                  task: t,
                  showDate: false,
                  onToggle: () => tasks.toggleComplete(t.id),
                  onEdit: () => showTaskEditor(context, task: t),
                  onDelete: () => _confirmDeleteTask(context, t),
                  onFocus: () => context.read<PomodoroProvider>().assignTask(t),
                  onSchedule: () => showScheduleEditor(
                    context,
                    date: now,
                    title: t.title,
                    taskId: t.id,
                  ),
                )),
            if (tasks.todayTasks.length > 5 && onOpenTasks != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
                child: GestureDetector(
                  onTap: onOpenTasks,
                  child: Text(
                    '查看全部 ${tasks.todayTasks.length} 项 ›',
                    style: TextStyle(fontSize: 11, color: theme.muted),
                  ),
                ),
              ),
          ],
          // 习惯打卡
          SectionHeader(
            title: '习惯打卡',
            subtitle: '今日 ${habits.todayDone}/${habits.todayTotal}',
            trailing: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                habits.todayTotal == 0
                    ? ''
                    : '${(habits.todayRate * 100).round()}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.primary),
              ),
            ),
          ),
          if (habits.habits.isEmpty)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: const EmptyHint(
                icon: Icons.repeat,
                text: '还没有习惯 · 到「习惯」页添加第一个小习惯',
              ),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: habits.habits.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final h = habits.habits[i];
                  return _HabitChip(
                    habit: h,
                    onTap: () => habits.toggleToday(h.id),
                  );
                },
              ),
            ),
          // 今日时间轴(已完成的事)
          _TodayDoneTimeline(
            theme: theme,
            today: now,
            tasks: tasks,
            habits: habits,
            pomo: pomo,
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

  Future<void> _confirmDeleteTask(BuildContext context, Task task) async {
    final ok = await showConfirmDialog(context,
        title: '删除「${task.title}」?', danger: true, confirmText: '删除');
    if (!ok || !context.mounted) return;
    final removed = await context.read<TaskProvider>().deleteTask(task.id);
    if (removed == null || !context.mounted) return;
    showUndoToast(
      context,
      '已删除「${removed.title}」',
      onUndo: () => context.read<TaskProvider>().restoreTask(removed),
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

class _HabitChip extends StatelessWidget {
  final Habit habit;
  final VoidCallback onTap;

  const _HabitChip({required this.habit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final done = habit.doneToday;
    final color = Color(habit.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: done ? color.withOpacity(0.16) : theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done
                ? color.withOpacity(0.5)
                : theme.foreground.withOpacity(0.06),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(habit.emoji, style: const TextStyle(fontSize: 21)),
            const SizedBox(height: 4),
            Text(
              habit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.foreground,
              ),
            ),
            const SizedBox(height: 5),
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: done ? color : theme.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ============== 今日时间轴(已完成的事) ==============

class _TimelineEntry {
  final DateTime time;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _TimelineEntry({
    required this.time,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  String get hhmm =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _TodayDoneTimeline extends StatelessWidget {
  final ThemeDef theme;
  final DateTime today;
  final TaskProvider tasks;
  final HabitProvider habits;
  final PomodoroProvider pomo;

  const _TodayDoneTimeline({
    required this.theme,
    required this.today,
    required this.tasks,
    required this.habits,
    required this.pomo,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_TimelineEntry>[];

    // 今天完成的任务(有精确时间)
    for (final t in tasks.completedTasks) {
      if (t.completedAt == null) continue;
      if (!isSameDate(t.completedAt!, today)) continue;
      entries.add(_TimelineEntry(
        time: t.completedAt!,
        title: t.title,
        subtitle: t.priority.label.isNotEmpty ? '任务 · ${t.priority.label}' : '任务',
        icon: Icons.task_alt,
        color: theme.primary,
      ));
    }

    // 今天打过卡的习惯(有精确时间, 新数据) / 老数据没时间时显示为 00:00
    for (final h in habits.habits) {
      if (!h.doneToday) continue;
      final time = h.checkInTimeOn(today) ??
          DateTime(today.year, today.month, today.day);
      entries.add(_TimelineEntry(
        time: time,
        title: h.name,
        subtitle: '习惯打卡',
        icon: Icons.task_alt,
        color: Color(h.colorValue),
      ));
    }

    // 今天完成的专注阶段
    for (final r in pomo.records) {
      if (r.type != PomodoroType.work) continue;
      if (!isSameDate(r.completedAt, today)) continue;
      entries.add(_TimelineEntry(
        time: r.completedAt,
        title: r.taskTitle?.isNotEmpty == true
            ? '${r.taskTitle} · 专注 ${r.durationMinutes}min'
            : '专注 ${r.durationMinutes}min',
        subtitle: '番茄钟',
        icon: Icons.timer_outlined,
        color: const Color(0xFFF06292),
      ));
    }

    entries.sort((a, b) => a.time.compareTo(b.time));

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '今日时间轴',
          subtitle: '已完成 ${entries.length} 件事',
          margin: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        ),
        AppCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (int i = 0; i < entries.length; ++i) ...[
                _timelineItem(entries[i], i == entries.length - 1),
                if (i < entries.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: Container(
                      width: 1,
                      height: 14,
                      color: theme.foreground.withOpacity(0.07),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _timelineItem(_TimelineEntry e, bool last) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 22,
            alignment: Alignment.centerRight,
            child: Text(
              e.hhmm,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.muted),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: e.color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(e.icon, size: 11, color: e.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.foreground),
                ),
                if (e.subtitle != null)
                  Text(
                    e.subtitle!,
                    style: TextStyle(fontSize: 10, color: theme.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
