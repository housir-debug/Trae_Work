// screens/stats_screen.dart - 数据统计(周 / 月 / 季 / 年)
// v3.1: 入口移至「记录」页; 统计周期改为 周/月/季/年, 折线图随周期细化横坐标;
//       保留目标平均进度, 移除单目标进度列表
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/utils.dart';
import '../models/completion_record.dart';
import '../models/pomodoro_record.dart';
import '../models/schedule_event.dart';
import '../providers/completion_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/heatmap_calendar.dart';
import '../widgets/ui.dart';

enum _Period { week, month, quarter, year }

class _ChartPoint {
  final String label;
  final int value;
  final bool highlight;

  const _ChartPoint(this.label, this.value, this.highlight);
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Period _period = _Period.week;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();
    final completions = context.watch<CompletionProvider>();
    final goals = context.watch<GoalProvider>();
    final schedule = context.watch<ScheduleProvider>();

    final now = DateTime.now();
    final range = _range(now);
    final points = _points(now, pomo);
    final focusTotal = points.fold<int>(0, (a, b) => a + b.value);
    final focusCount = pomo.records
        .where((r) =>
            r.type == PomodoroType.work &&
            !r.completedAt.isBefore(range.$1) &&
            r.completedAt.isBefore(range.$2))
        .length;
    final taskDone = tasks.completedBetween(range.$1, range.$2);
    final doneCount = completions.countBetween(range.$1, range.$2);

    final activity = <String, int>{};
    for (final r in pomo.records) {
      if (r.type != PomodoroType.work) continue;
      final key = dateKey(r.completedAt);
      activity[key] = (activity[key] ?? 0) + r.durationMinutes;
    }
    for (final r in completions.records) {
      if (r.kind == CompletionKind.pomodoro) continue;
      final key = dateKey(r.timestamp);
      activity[key] = (activity[key] ?? 0) + 20;
    }

    final bestHour = _bestHour(pomo.records, range.$1, range.$2);
    final accuracy = _accuracy(tasks, range.$1, range.$2);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, size: 20,
                      color: theme.foreground),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('数据统计',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: theme.foreground)),
                      const SizedBox(height: 2),
                      Text('看见自己的节奏与积累',
                          style: TextStyle(fontSize: 11, color: theme.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                for (final p in _Period.values) ...[
                  PillChip(
                    label: switch (p) {
                      _Period.week => '周',
                      _Period.month => '月',
                      _Period.quarter => '季',
                      _Period.year => '年',
                    },
                    selected: _period == p,
                    onTap: () => setState(() => _period = p),
                  ),
                  if (p != _Period.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
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
          SectionHeader(
            title: '专注趋势',
            subtitle: '共 $focusTotal 分钟 · $focusCount 个番茄',
          ),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(10, 18, 16, 8),
            child: SizedBox(
              height: 180,
              child: _FocusLineChart(points: points, theme: theme),
            ),
          ),
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
                  value: bestHour == null ? '暂无记录' : _hourLabel(bestHour),
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
                  showDivider: false,
                ),
              ],
            ),
          ),
          SectionHeader(title: '时间投入', subtitle: '来自你规划的时间块'),
          _TimeAllocationCard(
            categoryMinutes: schedule.categoryMinutesInDays(
                range.$2.difference(range.$1).inDays.clamp(1, 366)),
            theme: theme,
            emptyText: '这段时间还没有时间块安排\n到日程页规划你的行程',
          ),
          SectionHeader(title: '活动热力图', subtitle: '近 12 周'),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: HeatmapCalendar(
              values: activity,
              baseColor: theme.primary,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ---------- 周期区间 ----------
  (DateTime, DateTime) _range(DateTime now) {
    final today = startOfDay(now);
    switch (_period) {
      case _Period.week:
        final start = startOfWeek(today);
        return (start, start.add(const Duration(days: 7)));
      case _Period.month:
        final start = DateTime(now.year, now.month, 1);
        return (start, DateTime(now.year, now.month + 1, 1));
      case _Period.quarter:
        final q = (now.month - 1) ~/ 3;
        final start = DateTime(now.year, q * 3 + 1, 1);
        return (start, DateTime(now.year, q * 3 + 4, 1));
      case _Period.year:
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
    }
  }

  // ---------- 折线数据 ----------
  List<_ChartPoint> _points(DateTime now, PomodoroProvider pomo) {
    int sum(DateTime start, DateTime end) => pomo.records
        .where((r) =>
            r.type == PomodoroType.work &&
            !r.completedAt.isBefore(start) &&
            r.completedAt.isBefore(end))
        .fold(0, (a, r) => a + r.durationMinutes);

    final today = startOfDay(now);
    switch (_period) {
      case _Period.week:
        final start = startOfWeek(today);
        return List.generate(7, (i) {
          final d = start.add(Duration(days: i));
          return _ChartPoint(
            weekdayShort(d),
            sum(d, d.add(const Duration(days: 1))),
            isSameDate(d, today),
          );
        });
      case _Period.month:
        final first = DateTime(now.year, now.month, 1);
        final next = DateTime(now.year, now.month + 1, 1);
        var cursor = startOfWeek(first);
        final points = <_ChartPoint>[];
        while (cursor.isBefore(next)) {
          final weekStart = cursor;
          final weekEnd = cursor.add(const Duration(days: 7));
          final value = sum(
            weekStart.isBefore(first) ? first : weekStart,
            weekEnd.isAfter(next) ? next : weekEnd,
          );
          points.add(_ChartPoint(
            '${isoWeekNumber(weekStart)}周',
            value,
            !weekStart.isAfter(today) && weekEnd.isAfter(today),
          ));
          cursor = weekEnd;
        }
        return points;
      case _Period.quarter:
        final q = (now.month - 1) ~/ 3;
        final startMonth = q * 3 + 1;
        return List.generate(3, (i) {
          final m = startMonth + i;
          final start = DateTime(now.year, m, 1);
          final end = DateTime(now.year, m + 1, 1);
          return _ChartPoint(
            '$m月',
            sum(start, end),
            now.month == m,
          );
        });
      case _Period.year:
        final names = ['春', '夏', '秋', '冬'];
        final currentQ = (now.month - 1) ~/ 3;
        return List.generate(4, (i) {
          final start = DateTime(now.year, i * 3 + 1, 1);
          final end = DateTime(now.year, i * 3 + 4, 1);
          return _ChartPoint(
            names[i],
            sum(start, end),
            i == currentQ,
          );
        });
    }
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
}

class _FocusLineChart extends StatelessWidget {
  final List<_ChartPoint> points;
  final ThemeDef theme;

  const _FocusLineChart({required this.points, required this.theme});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        points.fold<int>(0, (a, b) => a > b.value ? a : b.value);
    final maxY = maxVal <= 0 ? 60.0 : (maxVal * 1.25).toDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).clamp(1, 999).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.foreground.withOpacity(0.88),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${points[s.x.toInt()].label} · ${s.y.round()} 分钟',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ))
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                if (points.length > 10 && idx.isOdd) {
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
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.foreground.withOpacity(0.06),
            strokeWidth: 1,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              points.length,
              (i) => FlSpot(i.toDouble(), points[i].value.toDouble()),
            ),
            isCurved: true,
            curveSmoothness: 0.25,
            color: theme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: points[index].highlight ? 4 : 2.5,
                color: points[index].highlight ? theme.accent : theme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.primary.withOpacity(0.22),
                  theme.primary.withOpacity(0.01),
                ],
              ),
            ),
          ),
        ],
      ),
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
                        style: TextStyle(fontSize: 9, color: theme.muted)),
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
                          style: TextStyle(fontSize: 10, color: theme.muted),
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
