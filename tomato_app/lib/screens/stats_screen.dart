// screens/stats_screen.dart - 多维度数据统计(周期切换 + 数据洞察)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/utils.dart';
import '../models/completion_record.dart';
import '../models/journal_entry.dart';
import '../models/pomodoro_record.dart';
import '../models/schedule_event.dart';
import '../providers/completion_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/heatmap_calendar.dart';
import '../widgets/ui.dart';
import 'weekly_report_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _ChartPoint {
  final String label;
  final int value;
  final bool highlight;

  const _ChartPoint(this.label, this.value, this.highlight);
}

class _StatsScreenState extends State<StatsScreen> {
  int _days = 7;
  bool _yearMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();
    final completions = context.watch<CompletionProvider>();
    final goals = context.watch<GoalProvider>();
    final schedule = context.watch<ScheduleProvider>();
    final journal = context.watch<JournalProvider>();

    final now = DateTime.now();
    final today = startOfDay(now);
    final year = now.year;
    final start = _yearMode
        ? DateTime(year, 1, 1)
        : today.subtract(Duration(days: _days - 1));
    final end = _yearMode
        ? DateTime(year + 1, 1, 1)
        : today.add(const Duration(days: 1));

    final focusData =
        _yearMode ? _yearlyFocus(pomo, year) : pomo.workMinutesLastDays(_days);
    final focusTotal = focusData.fold<int>(0, (a, b) => a + b);
    final focusCount = _yearMode
        ? pomo.records
            .where(
                (r) => r.type == PomodoroType.work && r.completedAt.year == year)
            .length
        : pomo.workCountLastDays(_days).fold<int>(0, (a, b) => a + b);
    final taskDone = tasks.completedBetween(start, end);
    final doneCount = completions.countBetween(start, end);
    final points =
        _yearMode ? _monthBuckets(focusData, now) : _buckets(focusData, _days);

    final activity = <String, int>{};
    for (final r in pomo.records) {
      if (r.type != PomodoroType.work) continue;
      final key = dateKey(r.completedAt);
      activity[key] = (activity[key] ?? 0) + r.durationMinutes;
    }
    for (final t in tasks.tasks) {
      final c = t.completedAt;
      if (c == null) continue;
      final key = dateKey(c);
      activity[key] = (activity[key] ?? 0) + 30;
    }
    for (final r in completions.records) {
      if (r.kind == CompletionKind.pomodoro) continue;
      final key = dateKey(r.timestamp);
      activity[key] = (activity[key] ?? 0) + 20;
    }

    final bestHour = _bestHour(pomo.records, start, end);
    final accuracy = _accuracy(tasks, start, end);
    final bestDay = _bestDay(focusData);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WeeklyReportScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 13, color: theme.primary),
                        const SizedBox(width: 4),
                        Text('周报',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                PillChip(
                  label: '7 天',
                  selected: !_yearMode && _days == 7,
                  onTap: () => setState(() {
                    _days = 7;
                    _yearMode = false;
                  }),
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: '30 天',
                  selected: !_yearMode && _days == 30,
                  onTap: () => setState(() {
                    _days = 30;
                    _yearMode = false;
                  }),
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: '90 天',
                  selected: !_yearMode && _days == 90,
                  onTap: () => setState(() {
                    _days = 90;
                    _yearMode = false;
                  }),
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: '今年',
                  selected: _yearMode,
                  onTap: () => setState(() => _yearMode = true),
                ),
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
                        label: '专注时长',
                        value: focusTotal >= 60
                            ? (focusTotal / 60).toStringAsFixed(1)
                            : '$focusTotal',
                        unit: focusTotal >= 60 ? '小时' : '分钟',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewCard(
                        icon: Icons.task_alt,
                        color: theme.accent,
                        label: '完成待办',
                        value: '$taskDone',
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
                        icon: Icons.done_all,
                        color: const Color(0xFF6BCB9D),
                        label: '完成事项',
                        value: '$doneCount',
                        unit: '件',
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
          // 专注柱状图
          SectionHeader(
            title: _yearMode ? '今年各月专注' : '近 $_days 天专注趋势',
            subtitle: '共 $focusTotal 分钟 · $focusCount 个番茄',
          ),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(10, 18, 14, 10),
            child: SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: _maxY(points),
                  barGroups: List.generate(points.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].value.toDouble(),
                          color: points[i].highlight
                              ? theme.accent
                              : theme.primary.withOpacity(0.75),
                          width: points.length <= 7
                              ? 20
                              : (points.length <= 5 ? 26 : 10),
                          borderRadius: BorderRadius.circular(6),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _maxY(points),
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
                          final idx = v.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          if (points.length > 7 && idx.isOdd) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              points[idx].label,
                              style: TextStyle(
                                fontSize: points.length > 7 ? 8.5 : 10,
                                color: points[idx].highlight
                                    ? theme.accent
                                    : theme.muted,
                                fontWeight: points[idx].highlight
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
                    horizontalInterval: _maxY(points) / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.foreground.withOpacity(0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          theme.foreground.withOpacity(0.85),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${rod.toY.round()} 分钟',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 数据洞察
          SectionHeader(title: '数据洞察', subtitle: '帮你调整节奏'),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                _InsightRow(
                  icon: Icons.schedule,
                  color: theme.primary,
                  title: '最佳专注时段',
                  value: bestHour == null
                      ? '暂无记录'
                      : _hourLabel(bestHour),
                  hint: '把最难的事放在这里',
                ),
                _InsightRow(
                  icon: Icons.track_changes,
                  color: theme.accent,
                  title: '估时准确度',
                  value: accuracy == null
                      ? '暂无数据'
                      : '${(accuracy * 100).round()}%',
                  hint: '完成番茄 / 预计番茄',
                ),
                _InsightRow(
                  icon: Icons.local_fire_department_outlined,
                  color: const Color(0xFFFF8E53),
                  title: '连续专注天数',
                  value: '${pomo.focusStreak} 天',
                  hint: '每天一个番茄也算',
                ),
                _InsightRow(
                  icon: Icons.event_busy,
                  color: const Color(0xFFFF5252),
                  title: '逾期未完成',
                  value: '${tasks.overdueTasks.length} 项',
                  hint: '及时调整或放弃',
                ),
                _InsightRow(
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFF6BCB9D),
                  title: '最高光的一天',
                  value: bestDay ?? '暂无记录',
                  hint: '专注时长最长',
                  showDivider: false,
                ),
              ],
            ),
          ),
          // 年度完成节奏(仅年视图)
          if (_yearMode) ...[
            SectionHeader(
              title: '年度完成节奏',
              subtitle: '各月完成事项数(待办/日程/打卡/专注)',
            ),
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(10, 18, 14, 10),
              child: SizedBox(
                height: 150,
                child: _YearlyCompletionChart(
                  counts: completions.monthlyCounts(year),
                  currentMonth: now.month,
                ),
              ),
            ),
          ],
          // 时间分配
          SectionHeader(
            title: _yearMode ? '今年时间投入' : '近 $_days 天时间投入',
            subtitle: '来自你规划的时间块',
          ),
          _TimeAllocationCard(
            categoryMinutes:
                schedule.categoryMinutesInDays(_yearMode ? 366 : _days),
            theme: theme,
            emptyText: '这段时间还没有时间块安排\n到今日页规划你的行程',
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
          SectionHeader(
              title: '复盘与心情', subtitle: '本月 ${journal.entriesThisMonth} 天'),
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

  List<int> _yearlyFocus(PomodoroProvider pomo, int year) {
    final m = List<int>.filled(12, 0);
    for (final r in pomo.records) {
      if (r.type != PomodoroType.work) continue;
      if (r.completedAt.year == year) {
        m[r.completedAt.month - 1] += r.durationMinutes;
      }
    }
    return m;
  }

  List<_ChartPoint> _monthBuckets(List<int> monthly, DateTime now) {
    return List.generate(12, (i) {
      return _ChartPoint('${i + 1}月', monthly[i], i == now.month - 1);
    });
  }

  List<_ChartPoint> _buckets(List<int> daily, int days) {
    final today = startOfDay(DateTime.now());
    if (days <= 7) {
      return List.generate(days, (i) {
        final d = today.subtract(Duration(days: days - 1 - i));
        return _ChartPoint(weekdayShort(d), daily[i], isSameDate(d, today));
      });
    }
    final count = (days / 7).ceil();
    return List.generate(count, (i) {
      final startIdx = i * 7;
      final endIdx = ((i + 1) * 7).clamp(startIdx, days);
      final sum = daily.sublist(startIdx, endIdx).fold<int>(0, (a, b) => a + b);
      final d = today.subtract(Duration(days: days - 1 - startIdx));
      return _ChartPoint(shortDate(d), sum, i == count - 1);
    });
  }

  double _maxY(List<_ChartPoint> points) {
    final maxVal =
        points.fold<int>(0, (a, b) => a > b.value ? a : b.value);
    if (maxVal <= 0) return 60;
    return (maxVal * 1.25).toDouble();
  }

  int? _bestHour(List<PomodoroRecord> records, DateTime start, DateTime end) {
    final map = <int, int>{};
    for (final r in records) {
      if (r.type != PomodoroType.work) continue;
      if (r.completedAt.isBefore(start) || !r.completedAt.isBefore(end)) {
        continue;
      }
      final h = r.startedAt.hour;
      map[h] = (map[h] ?? 0) + r.durationMinutes;
    }
    if (map.isEmpty) return null;
    return map.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _hourLabel(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00-${((hour + 1) % 24).toString().padLeft(2, '0')}:00';

  double? _accuracy(TaskProvider tasks, DateTime start, DateTime end) {
    final finished = tasks.tasks.where((t) {
      if (!t.isCompleted || t.estimatedPomodoros <= 0) return false;
      final c = t.completedAt;
      return c != null && !c.isBefore(start) && c.isBefore(end);
    }).toList();
    if (finished.isEmpty) return null;
    final sum = finished.fold<double>(0, (acc, t) {
      final ratio = t.completedPomodoros / t.estimatedPomodoros;
      return acc + (ratio > 1 ? 1.0 : ratio);
    });
    return sum / finished.length;
  }

  String? _bestDay(List<int> daily) {
    if (daily.isEmpty) return null;
    var maxIdx = -1;
    var maxVal = 0;
    for (var i = 0; i < daily.length; i++) {
      if (daily[i] > maxVal) {
        maxVal = daily[i];
        maxIdx = i;
      }
    }
    if (maxIdx < 0 || maxVal == 0) return null;
    if (_yearMode) return '${maxIdx + 1} 月 ($maxVal 分钟)';
    final d = startOfDay(DateTime.now())
        .subtract(Duration(days: daily.length - 1 - maxIdx));
    return '${shortDate(d)} ($maxVal 分钟)';
  }
}

class _YearlyCompletionChart extends StatelessWidget {
  final List<int> counts; // 12 个元素
  final int currentMonth;

  const _YearlyCompletionChart({
    required this.counts,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final maxVal = counts.fold<int>(1, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(12, (i) {
        final v = counts[i];
        final isCurrent = i == currentMonth - 1;
        final h = v == 0 ? 4.0 : (v / maxVal) * 110.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (v > 0)
                  Text('$v',
                      style: TextStyle(
                          fontSize: 8,
                          color: isCurrent ? theme.accent : theme.muted)),
                const SizedBox(height: 2),
                Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? theme.accent
                        : theme.primary.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 8.5,
                        color: isCurrent ? theme.accent : theme.muted,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String hint;
  final bool showDivider;

  const _InsightRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.hint,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 11.5, color: theme.foreground)),
                    Text(hint,
                        style:
                            TextStyle(fontSize: 9, color: theme.muted)),
                  ],
                ),
              ),
              Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: theme.foreground.withOpacity(0.05),
          ),
      ],
    );
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
  final String emptyText;

  const _TimeAllocationCard({
    required this.categoryMinutes,
    required this.theme,
    this.emptyText = '还没有时间块安排',
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
          ? EmptyHint(
              icon: Icons.pie_chart_outline,
              text: emptyText,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
