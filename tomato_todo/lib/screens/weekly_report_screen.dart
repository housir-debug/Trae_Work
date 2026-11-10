// screens/weekly_report_screen.dart - 一周回顾与分享
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils.dart';
import '../models/pomodoro_record.dart';
import '../providers/completion_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/ui.dart';

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  DateTime get _start => startOfDay(
      DateTime.now().subtract(const Duration(days: 6)));

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();
    final journal = context.watch<JournalProvider>();
    final schedule = context.watch<ScheduleProvider>();
    final completions = context.watch<CompletionProvider>();

    final now = DateTime.now();
    final start = _start;
    final end = startOfDay(now).add(const Duration(days: 1));

    final focusMinutes = pomo.workMinutesLastDays(7).fold<int>(0, (a, b) => a + b);
    final focusCount = pomo.workCountLastDays(7).fold<int>(0, (a, b) => a + b);
    final taskDone = tasks.completedBetween(start, end);
    final doneCount = completions.countBetween(start, end);
    final planned = schedule.events
        .where((e) {
          final d = DateTime.tryParse(e.dateKey);
          return d != null && !d.isBefore(start) && d.isBefore(end);
        })
        .fold<int>(0, (sum, e) => sum + e.durationMinutes);

    final workRecords = pomo.records
        .where((r) =>
            r.type == PomodoroType.work &&
            !r.completedAt.isBefore(start) &&
            r.completedAt.isBefore(end))
        .toList();
    final bestHour = _bestHour(workRecords);
    final activeDays = List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return pomo.workCountOn(d) > 0;
    }).where((e) => e).length;

    final weeklyJournals = journal.entries.where((e) {
      final d = DateTime.tryParse(e.dateKey);
      return d != null && !d.isBefore(start) && d.isBefore(end);
    }).toList();
    final avgMood = weeklyJournals.isEmpty
        ? 0.0
        : weeklyJournals.fold<int>(0, (s, e) => s + e.mood) /
            weeklyJournals.length;

    final report = _buildText(
      focusMinutes: focusMinutes,
      focusCount: focusCount,
      taskDone: taskDone,
      doneCount: doneCount,
      planned: planned,
      activeDays: activeDays,
      bestHour: bestHour,
      journalDays: weeklyJournals.length,
      avgMood: avgMood,
    );

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        foregroundColor: theme.foreground,
        title: Text('本周回顾',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: theme.foreground)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: theme.accent),
                      const SizedBox(width: 6),
                      Text('7 天小结',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.foreground)),
                      const Spacer(),
                      Text(
                        '${shortDate(start)} - ${shortDate(now)}',
                        style: TextStyle(fontSize: 10, color: theme.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: '专注',
                          value: durationText(focusMinutes),
                          sub: '$focusCount 个番茄',
                          color: theme.primary,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: '完成待办',
                          value: '$taskDone',
                          sub: '项',
                          color: theme.accent,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: '完成事项',
                          value: '$doneCount',
                          sub: '件',
                          color: const Color(0xFF6BCB9D),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: '专注天数',
                          value: '$activeDays',
                          sub: '/ 7 天',
                          color: theme.primary,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: '规划时长',
                          value: durationText(planned),
                          sub: '日历时间块',
                          color: const Color(0xFF7E57C2),
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: '平均心情',
                          value: avgMood == 0
                              ? '-'
                              : avgMood.toStringAsFixed(1),
                          sub: '${weeklyJournals.length} 天复盘',
                          color: const Color(0xFFF06292),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionHeader(
              title: '智能洞察',
              subtitle: '基于本周数据自动生成',
              margin: const EdgeInsets.fromLTRB(0, 22, 0, 8),
            ),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _insight(context, theme, Icons.schedule,
                      bestHour == null
                          ? '本周还没有专注记录, 试着开始第一个番茄。'
                          : '你的黄金专注时段在 ${_hourLabel(bestHour)}, 把最难的任务放在这里。'),
                  const SizedBox(height: 10),
                  _insight(
                    context,
                    theme,
                    Icons.insights_outlined,
                    activeDays >= 5
                        ? '本周有 $activeDays 天进入专注状态, 节奏很稳定, 保持下去。'
                        : activeDays >= 2
                            ? '本周专注了 $activeDays 天, 试着把专注变成每天的固定动作。'
                            : '专注天数偏少, 从每天 25 分钟开始, 比一次做很久更容易坚持。',
                  ),
                  const SizedBox(height: 10),
                  _insight(
                    context,
                    theme,
                    Icons.flag_outlined,
                    taskDone >= 10
                        ? '完成 $taskDone 项待办, 执行力在线。记得给重要但不紧急的事留时间。'
                        : taskDone > 0
                            ? '完成 $taskDone 项待办。下周可以只挑 1-2 件最重要的事优先推进。'
                            : '这周待办完成较少, 检查一下是否目标定得太多, 或者可以先拆小。',
                  ),
                  if (planned > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _insight(
                        context,
                        theme,
                        Icons.calendar_view_week,
                        planned > focusMinutes
                            ? '本周规划 ${durationText(planned)}, 实际专注 ${durationText(focusMinutes)}, 计划偏满, 留出一些缓冲更从容。'
                            : '本周规划 ${durationText(planned)}, 实际专注 ${durationText(focusMinutes)}, 执行率不错。',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: () => Share.share(report, subject: '时光秘书 · 本周回顾'),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('分享周报'),
            ),
            const SizedBox(height: 10),
            Text(
              '周报仅在你点击分享时才会离开设备',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: theme.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insight(
    BuildContext context,
    ThemeDef theme,
    IconData icon,
    String text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12, height: 1.55, color: theme.foreground),
          ),
        ),
      ],
    );
  }

  int? _bestHour(List<PomodoroRecord> records) {
    if (records.isEmpty) return null;
    final map = <int, int>{};
    for (final r in records) {
      final h = r.startedAt.hour;
      map[h] = (map[h] ?? 0) + r.durationMinutes;
    }
    final best = map.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.key;
  }

  String _hourLabel(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00-${((hour + 1) % 24).toString().padLeft(2, '0')}:00';

  String _buildText({
    required int focusMinutes,
    required int focusCount,
    required int taskDone,
    required int doneCount,
    required int planned,
    required int activeDays,
    required int? bestHour,
    required int journalDays,
    required double avgMood,
  }) {
    final b = StringBuffer()
      ..writeln('📊 时光秘书 · 本周回顾')
      ..writeln('${shortDate(_start)} - ${shortDate(DateTime.now())}')
      ..writeln()
      ..writeln('⏱ 专注 ${durationText(focusMinutes)} · $focusCount 个番茄 · $activeDays 天有专注');
    if (bestHour != null) {
      b.writeln('🕐 黄金时段 ${_hourLabel(bestHour)}');
    }
    b
      ..writeln('✅ 完成待办 $taskDone 项')
      ..writeln('🗓 完成事项 $doneCount 件(待办/日程/打卡/专注)')
      ..writeln('🗓 规划时长 ${durationText(planned)}');
    if (journalDays > 0) {
      b.writeln('📝 复盘 $journalDays 天 · 平均心情 ${avgMood.toStringAsFixed(1)}/5');
    }
    b
      ..writeln()
      ..writeln('下周继续, 把时间花在重要的事上。');
    return b.toString();
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: theme.muted)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: color)),
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: theme.muted)),
      ],
    );
  }
}
