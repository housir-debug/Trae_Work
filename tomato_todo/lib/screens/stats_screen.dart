// screens/stats_screen.dart - 数据统计看板
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/pomodoro_record.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/heatmap_calendar.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;
    final pomo = context.watch<PomodoroProvider>();

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    // 按天统计最近 7 天工作番茄
    final weekLabels = <String>[];
    final weekWork = <int>[];
    for (int i = 0; i < 7; ++i) {
      final d = weekStart.add(Duration(days: i));
      weekLabels.add(DateFormat('E').format(d));
      weekWork.add(pomo.records
          .where((r) => r.type == PomodoroType.work && r.isSameDay(d))
          .length);
    }

    // 按类型统计所有记录
    final workTotal = pomo.records
        .where((r) => r.type == PomodoroType.work)
        .fold<int>(0, (sum, r) => sum + r.durationMinutes);
    final shortTotal = pomo.records
        .where((r) => r.type == PomodoroType.shortBreak)
        .fold<int>(0, (sum, r) => sum + r.durationMinutes);
    final longTotal = pomo.records
        .where((r) => r.type == PomodoroType.longBreak)
        .fold<int>(0, (sum, r) => sum + r.durationMinutes);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              '统计看板',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.foreground,
              ),
            ),
          ),
          // 今日 vs 本周 vs 本月 概览
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _OverviewCards(theme: theme, pomo: pomo),
          ),
          const SizedBox(height: 20),
          // 本周番茄柱状图
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardBackground.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本周每日番茄数',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: (weekWork.fold<int>(0, (m, v) => v > m ? v : m) + 1)
                            .toDouble(),
                        barGroups: weekWork.asMap().entries.map((e) {
                          return BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(
                              toY: e.value.toDouble(),
                              color: theme.primary,
                              borderRadius: BorderRadius.circular(6),
                              width: 28,
                            ),
                          ]);
                        }).toList(),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) => Text(
                                weekLabels[v.toInt()],
                                style: TextStyle(
                                    color: theme.foreground.withOpacity(0.6),
                                    fontSize: 11),
                              ),
                              reservedSize: 24,
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: 1,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.black.withOpacity(0.05),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (_) => FlLine(
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 时间分配饼图
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardBackground.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '时间分配(分钟)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: workTotal.toDouble(),
                            title: '专注',
                            color: theme.primary,
                            radius: 70,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          PieChartSectionData(
                            value: shortTotal.toDouble(),
                            title: '短休',
                            color: theme.primary.withOpacity(0.6),
                            radius: 60,
                            titleStyle: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          PieChartSectionData(
                            value: longTotal.toDouble(),
                            title: '长休',
                            color: theme.accent,
                            radius: 55,
                            titleStyle: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _legend(theme.primary, '专注 $workTotal 分'),
                      _legend(theme.primary.withOpacity(0.6),
                          '短休 $shortTotal 分'),
                      _legend(theme.accent, '长休 $longTotal 分'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 热力图
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardBackground.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const HeatmapCalendar(),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _legend(Color c, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: c),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final ThemeDef theme;
  final PomodoroProvider pomo;

  const _OverviewCards({required this.theme, required this.pomo});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final todayWork = pomo.records
        .where((r) => r.type == PomodoroType.work && r.isSameDay(now))
        .length;

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekWork = pomo.records
        .where((r) =>
            r.type == PomodoroType.work &&
            r.completedAt.isAfter(weekStart.subtract(const Duration(seconds: 1))))
        .length;

    final monthStart = DateTime(now.year, now.month, 1);
    final monthWork = pomo.records
        .where((r) =>
            r.type == PomodoroType.work &&
            r.completedAt.isAfter(monthStart.subtract(const Duration(seconds: 1))))
        .length;

    final cards = [
      ('今日', '$todayWork', '个', theme.primary),
      ('本周', '$weekWork', '个', theme.accent),
      ('本月', '$monthWork', '个', Colors.pinkAccent),
      ('累计', '${pomo.completedWorkCount}', '个', Colors.amber),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; ++i) ...[
          Expanded(child: _miniCard(cards[i])),
          if (i < cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _miniCard((String, String, String, Color) data) {
    final (label, value, unit, color) = data;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: theme.foreground.withOpacity(0.5))),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.foreground.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
