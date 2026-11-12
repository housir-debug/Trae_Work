// screens/schedule_day_screen.dart - 独立日程页(底部导航第一项)
// v3.1: 今日页的日程与今日复盘迁移至此;
//       取消「复制昨日行程」, 改为「从待办加入日程」
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/schedule_event.dart';
import '../models/task.dart';
import '../providers/journal_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/journal_sheet.dart';
import '../widgets/schedule_editor.dart';
import '../widgets/ui.dart';
import 'journal_history_screen.dart';
import 'schedule_screen.dart';

class ScheduleDayScreen extends StatefulWidget {
  const ScheduleDayScreen({super.key});

  @override
  State<ScheduleDayScreen> createState() => _ScheduleDayScreenState();
}

class _ScheduleDayScreenState extends State<ScheduleDayScreen> {
  DateTime _selected = startOfDay(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final schedule = context.watch<ScheduleProvider>();
    final journal = context.watch<JournalProvider>();
    final events = schedule.eventsFor(_selected);
    final isToday = isSameDate(_selected, DateTime.now());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('日程',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: theme.foreground)),
                      const SizedBox(height: 3),
                      Text('把时间留给重要的事',
                          style: TextStyle(fontSize: 11, color: theme.muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '周视图',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScheduleScreen(initialDate: _selected),
                    ),
                  ),
                  icon: Icon(Icons.calendar_view_week,
                      size: 20, color: theme.primary),
                ),
              ],
            ),
          ),
          // 日期切换
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() =>
                      _selected = _selected.subtract(const Duration(days: 1))),
                  child: Icon(Icons.chevron_left,
                      size: 20, color: theme.muted),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 14, color: theme.primary),
                        const SizedBox(width: 5),
                        Text(
                          isToday
                              ? '今天 · ${shortDate(_selected)}'
                              : '${shortDate(_selected)} ${weekdayShort(_selected)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() =>
                      _selected = _selected.add(const Duration(days: 1))),
                  child:
                      Icon(Icons.chevron_right, size: 20, color: theme.muted),
                ),
                const Spacer(),
                if (!isToday)
                  TextButton(
                    onPressed: () => setState(
                        () => _selected = startOfDay(DateTime.now())),
                    child: Text('回到今天',
                        style:
                            TextStyle(fontSize: 11, color: theme.primary)),
                  ),
              ],
            ),
          ),
          // 概览
          AppCard(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: '已规划',
                    value: durationText(schedule.plannedMinutesOn(_selected)),
                    icon: Icons.timelapse,
                    color: theme.primary,
                  ),
                ),
                Container(
                    width: 1,
                    height: 30,
                    color: theme.foreground.withOpacity(0.08)),
                Expanded(
                  child: _Stat(
                    label: '已完成',
                    value:
                        '${events.where((e) => e.isDone).length}/${events.length}',
                    icon: Icons.task_alt,
                    color: theme.accent,
                  ),
                ),
                Container(
                    width: 1,
                    height: 30,
                    color: theme.foreground.withOpacity(0.08)),
                Expanded(
                  child: _Stat(
                    label: '待办可安排',
                    value: '${context.watch<TaskProvider>().activeCount}',
                    icon: Icons.list_alt,
                    color: const Color(0xFF7E57C2),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: isToday ? '今日行程' : '当天行程',
            subtitle: events.isEmpty
                ? '空白的一天, 也可以很从容'
                : '${events.length} 项安排',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PillAction(
                  label: '从待办加入',
                  icon: Icons.playlist_add,
                  theme: theme,
                  onTap: _pickTaskToSchedule,
                ),
                const SizedBox(width: 8),
                _PillAction(
                  label: '新增',
                  icon: Icons.add,
                  theme: theme,
                  filled: true,
                  onTap: () => showScheduleEditor(context, date: _selected),
                ),
              ],
            ),
          ),
          if (events.isEmpty)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              onTap: () => showScheduleEditor(context, date: _selected),
              child: const EmptyHint(
                icon: Icons.view_timeline_outlined,
                text: '还没有安排\n点击「新增」划定时间块, 或从待办加入',
              ),
            )
          else
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < events.length; ++i) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: theme.foreground.withOpacity(0.06)),
                    _EventTile(
                      event: events[i],
                      onTap: () =>
                          showScheduleEditor(context, event: events[i]),
                      onToggle: () => schedule.toggleDone(events[i].id),
                    ),
                  ],
                ],
              ),
            ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    setState(() => _selected = startOfDay(picked));
  }

  /// 选择当前待办加入日程(替代原「复制昨日行程」)
  Future<void> _pickTaskToSchedule() async {
    final theme = context.read<SettingsProvider>().currentTheme;
    final tasks = context.read<TaskProvider>().activeTasks;
    final picked = await showModalBottomSheet<Task>(
      context: context,
      backgroundColor: theme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择待办加入日程',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.foreground)),
              const SizedBox(height: 4),
              Text('加入后可在日程中勾选完成, 待办会同步完成',
                  style: TextStyle(fontSize: 10, color: theme.muted)),
              const SizedBox(height: 10),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: Text('暂无进行中的待办',
                        style:
                            TextStyle(fontSize: 12, color: theme.muted)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    itemBuilder: (_, i) {
                      final t = tasks[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.pop(ctx, t),
                        leading: Icon(Icons.radio_button_unchecked,
                            size: 18, color: theme.muted),
                        title: Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: theme.foreground)),
                        subtitle: Text(
                          '${t.effectivePriority.label}优先级 · ${t.completedPomodoros}/${t.estimatedPomodoros} 番茄',
                          style: TextStyle(fontSize: 10, color: theme.muted),
                        ),
                        trailing: Icon(Icons.add_circle_outline,
                            size: 18, color: theme.primary),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await showScheduleEditor(
      context,
      date: _selected,
      title: picked.title,
      taskId: picked.id,
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(fontSize: 9.5, color: theme.muted)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.foreground)),
      ],
    );
  }
}

class _PillAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeDef theme;
  final VoidCallback onTap;
  final bool filled;

  const _PillAction({
    required this.label,
    required this.icon,
    required this.theme,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: filled
              ? theme.primary
              : theme.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 12, color: filled ? Colors.white : theme.primary),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : theme.primary)),
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
