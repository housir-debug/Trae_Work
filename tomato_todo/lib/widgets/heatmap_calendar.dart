// widgets/heatmap_calendar.dart - 周热力图日历
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pomodoro_record.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/settings_provider.dart';

class HeatmapCalendar extends StatelessWidget {
  const HeatmapCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final pomo = context.watch<PomodoroProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;

    // 统计最近 12 周每天的工作番茄数
    final today = DateTime.now();
    final startOfCalendar = today.subtract(const Duration(days: 7 * 12 - 1));

    final Map<String, int> dailyWork = {};
    for (final r in pomo.records) {
      if (r.type != PomodoroType.work) continue;
      if (r.completedAt.isBefore(startOfCalendar)) continue;
      final key = _dateKey(r.completedAt);
      dailyWork[key] = (dailyWork[key] ?? 0) + 1;
    }

    // 构造 12 周 x 7 天 网格
    final weeks = 12;
    final daysPerWeek = 7;

    // 调整起始日到周日
    final dow = startOfCalendar.weekday; // 1=Mon 7=Sun
    final offset = (7 - dow) % 7;
    final adjustedStart =
        startOfCalendar.subtract(Duration(days: offset));

    final cells = List<int>.filled(weeks * daysPerWeek, 0);
    for (int d = 0; d < weeks * daysPerWeek; ++d) {
      final date = adjustedStart.add(Duration(days: d));
      cells[d] = dailyWork[_dateKey(date)] ?? 0;
    }

    final maxVal = cells.isEmpty
        ? 1
        : cells.fold<int>(0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '近 12 周番茄热力图',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.foreground,
          ),
        ),
        const SizedBox(height: 12),
        // 星期标签行
        Row(
          children: [
            const SizedBox(width: 22),
            for (final w in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Text(w,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.foreground.withOpacity(0.5))),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // 网格
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月份标签(简化:仅标注每 2 周)
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  for (int w = 0; w < weeks; ++w) ...[
                    SizedBox(
                      height: 14 * daysPerWeek + 2 * (daysPerWeek - 1),
                      child: w % 2 == 0
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _monthLabel(adjustedStart, w * 7),
                                style: TextStyle(
                                    fontSize: 9,
                                    color:
                                        theme.foreground.withOpacity(0.5)),
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  for (int w = 0; w < weeks; ++w)
                    Expanded(
                      child: Column(
                        children: [
                          for (int d = 0; d < daysPerWeek; ++d) ...[
                            _dayCell(
                              cells[w * daysPerWeek + d],
                              maxVal,
                              theme.primary,
                            ),
                            if (d < daysPerWeek - 1)
                              const SizedBox(height: 2),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('少', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
            for (int i = 0; i < 5; ++i) ...[
              Container(
                width: 12,
                height: 12,
                color: _levelColor(i, 4, theme.primary),
              ),
              const SizedBox(width: 2),
            ],
            const SizedBox(width: 4),
            const Text('多', style: TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _dayCell(int count, int max, Color primary) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: _cellColor(count, max, primary),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Tooltip(
        message: count > 0 ? '$count 个番茄' : '无',
        child: const SizedBox.expand(),
      ),
    );
  }

  Color _cellColor(int count, int max, Color primary) {
    if (count == 0) return Colors.white.withOpacity(0.15);
    final level = (count / max * 4).clamp(0, 4).toInt();
    return _levelColor(level, 4, primary);
  }

  Color _levelColor(int level, int maxLevel, Color primary) {
    final t = (level + 1) / (maxLevel + 1);
    return primary.withOpacity(0.15 + t * 0.85);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime start, int dayOffset) {
    final d = start.add(Duration(days: dayOffset));
    return '${d.month}月';
  }
}
