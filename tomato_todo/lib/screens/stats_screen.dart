// screens/stats_screen.dart - 多维度数据统计
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/utils.dart';
import '../models/journal_entry.dart';
import '../models/schedule_event.dart';
import '../providers/goal_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/heatmap_calendar.dart';
import '../widgets/ui.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();
    final habits = context.watch<HabitProvider>();
    final goals = context.watch<GoalProvider>();
    final schedule = context.watch<ScheduleProvider>();
    final journal = context.watch<JournalProvider>();

    final now = DateTime.now();
    final weekStart = startOfWeek(now);
    final weekFocus = pomo.workMinutesLastDays(7);
    final weekTotal = weekFocus.fold<int>(0, (a, b) => a + b);
    final today = startOfDay(now);

    final weekTaskDone = tasks.completedBetween(weekStart, today.add(const Duration(days: 1)));
    final weekChecks = habits.totalChecksBetween(
        weekStart, today.add(const Duration(days: 1)));

    final activity = <String, int>{};
    for (final r in pomo.records) {
      if (r.type.name != 'work') continue;
      final key = dateKey(r.completedAt);
      activity[key] = (activity[key] ?? 0) + r.durationMinutes;
    }
    for (final t in tasks.tasks) {
      final c = t.completedAt;
      if (c == null) continue;
      final key = dateKey(c);
      activity[key] = (activity[key] ?? 0) + 30;
    }
    for (final h in habits.habits) {
      for (final k in h.checkIns) {
        activity[k] = (activity[k] ?? 0) + 20;
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('数据中心',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.foreground)),
                const SizedBox(height: 3),
                Text('用数据看见自己的节奏与成长',
                    style: TextStyle(fontSize: 11, color: theme.muted)),
              ],
            ),
          ),
          // 概览
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        icon: Icons.timer_outlined,
                        color: theme.primary,
                        label: '本周专注',
                        value: weekTotal >= 60
                            ? '${(weekTotal / 60).toStringAsFixed(1)}'
                            : '$weekTotal',
                        unit: weekTotal >= 60 ? '小时' : '分钟',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewCard(
                        icon: Icons.task_alt,
                        color: theme.accent,
                        label: '本周完成待办',
                        value: '$weekTaskDone',
                        unit: '项',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        icon: Icons.repeat,
                        color: const Color(0xFF6BCB9D),
                        label: '本周习惯打卡',
                        value: '$weekChecks',
                        unit: '次',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewCard(
                        icon: Icons.flag_outlined,
                        color: const Color(0xFFF06292),
                        label: '目标平均进度',
                        value: '${(goals.averageProgress * 100).round()}',
                        unit: '%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 本周专注柱状图
          SectionHeader(title: '本周专注趋势', subtitle: '共 $weekTotal 分钟'),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(10, 18, 14, 10),
            child: SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: _maxY(weekFocus),
                  barGroups: List.generate(7, (i) {
                    final d = weekStart.add(Duration(days: i));
                    final isToday = isSameDate(d, now);
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: weekFocus[i].toDouble(),
                          color: isToday
                              ? theme.accent
                              : theme.primary.withOpacity(0.75),
                          width: 20,
                          borderRadius: BorderRadius.circular(6),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _maxY(weekFocus),
                            color: theme.primary.withOpacity(0.04),
                          ),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (v, meta) {
                          final d = weekStart.add(Duration(days: v.toInt()));
                          final isToday = isSameDate(d, now);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              weekdayShort(d),
                              style: TextStyle(
                                fontSize: 10,
                                color: isToday
                                    ? theme.accent
                                    : theme.muted,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _maxY(weekFocus) / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.foreground.withOpacity(0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => theme.foreground.withOpacity(0.85),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${rod.toY.round()} 分钟',
                        const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 时间分配
          SectionHeader(title: '本周时间投入', subtitle: '来自你规划的时间块'),
          _TimeAllocationCard(
            categoryMinutes: schedule.categoryMinutesThisWeek(),
            theme: theme,
          ),
          // 习惯坚持率
          SectionHeader(title: '习惯坚持率', subtitle: '近 30 天'),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: habits.habits.isEmpty
                ? const EmptyHint(
                    icon: Icons.repeat,
                    text: '还没有习惯数据',
                    padding: EdgeInsets.symmetric(vertical: 14),
                  )
                : Column(
                    children: habits.habits.take(6).map((h) {
                      final color = Color(h.colorValue);
                      final rate = h.rate(30);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text(h.emoji,
                                style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 76,
                              child: Text(
                                h.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.foreground),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: rate,
                                  minHeight: 5,
                                  backgroundColor: color.withOpacity(0.08),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(rate * 100).round()}%',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: color),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          // 目标进度
          SectionHeader(title: '目标进度', subtitle: '${goals.goals.length} 个目标'),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: goals.goals.isEmpty
                ? const EmptyHint(
                    icon: Icons.flag_outlined,
                    text: '还没有目标数据',
                    padding: EdgeInsets.symmetric(vertical: 14),
                  )
                : Column(
                    children: goals.goals.take(6).map((g) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              g.isCompleted
                                  ? Icons.emoji_events_outlined
                                  : Icons.flag_outlined,
                              size: 15,
                              color: g.isCompleted
                                  ? const Color(0xFF6BCB9D)
                                  : theme.primary,
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 100,
                              child: Text(
                                g.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.foreground),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: g.progress,
                                  minHeight: 5,
                                  backgroundColor:
                                      theme.primary.withOpacity(0.06),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(g.progress * 100).round()}%',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          // 复盘回顾
          SectionHeader(title: '复盘与心情', subtitle: '本月 ${journal.entriesThisMonth} 天'),
          _JournalOverviewCard(journal: journal, theme: theme),
          // 热力图
          SectionHeader(title: '活动热力图', subtitle: '近 12 周'),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: HeatmapCalendar(
              values: activity,
              baseColor: theme.primary,
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  double _maxY(List<int> data) {
    final maxVal = data.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return 60;
    return (maxVal * 1.25).toDouble();
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  const _OverviewCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: theme.muted)),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: theme.foreground),
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(fontSize: 9, color: theme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeAllocationCard extends StatelessWidget {
  final Map<ScheduleCategory, int> categoryMinutes;
  final ThemeDef theme;

  const _TimeAllocationCard({
    required this.categoryMinutes,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final entries = categoryMinutes.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: entries.isEmpty
          ? const EmptyHint(
              icon: Icons.pie_chart_outline,
              text: '本周还没有时间块安排\n到今日页规划你的行程',
              padding: EdgeInsets.symmetric(vertical: 12),
            )
          : Column(
              children: [
                SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: entries.map((e) {
                        final percent = total == 0
                            ? 0
                            : (e.value / total * 100).round();
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          color: e.key.color,
                          radius: 58,
                          title: '$percent%',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                          titlePositionPercentageOffset: 0.68,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: entries.map((e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: e.key.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${e.key.label} ${durationText(e.value)}',
                          style: TextStyle(
                              fontSize: 10, color: theme.muted),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

class _JournalOverviewCard extends StatelessWidget {
  final JournalProvider journal;
  final ThemeDef theme;

  const _JournalOverviewCard({required this.journal, required this.theme});

  @override
  Widget build(BuildContext context) {
    final latest = journal.entries.isEmpty ? null : journal.entries.first;
    final avg = journal.averageMood;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      child: latest == null
          ? const EmptyHint(
              icon: Icons.edit_note,
              text: '还没有复盘记录\n今天结束时, 给自己几分钟',
              padding: EdgeInsets.symmetric(vertical: 12),
            )
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Text(latest.moodEmoji,
                      style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.highlight.isEmpty
                            ? '${friendlyDate(DateTime.parse(latest.dateKey))}的复盘'
                            : latest.highlight,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.foreground),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '本月记录 ${journal.entriesThisMonth} 天 · 平均心情 ${avg.toStringAsFixed(1)}/5',
                        style:
                            TextStyle(fontSize: 10, color: theme.muted),
                      ),
                    ],
                  ),
                ),
                ...JournalEntry.moodEmojis.reversed
                    .take(3)
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(e,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.muted)),
                        )),
              ],
            ),
    );
  }
}
