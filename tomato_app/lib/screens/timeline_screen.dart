// screens/timeline_screen.dart - 时间轴: 上半部分当月日历, 下半部分当天完成的事
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/completion_record.dart';
import '../providers/completion_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/ui.dart';
import 'stats_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late DateTime _selected = startOfDay(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final completions = context.watch<CompletionProvider>();
    final dayRecords = completions.forDay(_selected);
    final markedDays =
        completions.daysWithRecordsIn(_month.year, _month.month);

    return Column(
      children: [
        // 标题栏(与其他 Tab 风格一致, 透明背景)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('记录',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.foreground)),
                  const SizedBox(height: 3),
                  Text('做过的事, 都看得见',
                      style: TextStyle(fontSize: 11, color: theme.muted)),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: '数据统计',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
                icon: Icon(Icons.insights, size: 20, color: theme.primary),
              ),
              IconButton(
                tooltip: '回到今天',
                onPressed: () => setState(() {
                  _selected = startOfDay(DateTime.now());
                  _month = DateTime(_selected.year, _selected.month);
                }),
                icon: Icon(Icons.today, size: 19, color: theme.muted),
              ),
            ],
          ),
        ),
        _calendar(theme, markedDays),
        Expanded(child: _dayList(theme, dayRecords)),
      ],
    );
  }

  // --------- 月历 ---------
  Widget _calendar(ThemeDef theme, Set<String> markedDays) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // 周一开头
    final leadingBlanks = (firstDay.weekday - 1) % 7;
    final today = startOfDay(DateTime.now());

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() =>
                    _month = DateTime(_month.year, _month.month - 1)),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.chevron_left,
                      size: 20, color: theme.muted),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_month.year} 年 ${_month.month} 月',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.foreground),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() =>
                    _month = DateTime(_month.year, _month.month + 1)),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.chevron_right,
                      size: 20, color: theme.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 9, color: theme.muted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 2),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              childAspectRatio: 1.65,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (_, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final day = DateTime(_month.year, _month.month,
                  i - leadingBlanks + 1);
              final key = dateKey(day);
              final isSelected = isSameDate(day, _selected);
              final isToday = isSameDate(day, today);
              final hasRecords = markedDays.contains(key);
              final isFuture = day.isAfter(today);
              return GestureDetector(
                onTap: () => setState(() => _selected = day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primary
                        : isToday
                            ? theme.primary.withOpacity(0.10)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : isFuture
                                  ? theme.muted.withOpacity(0.45)
                                  : theme.foreground,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasRecords
                              ? (isSelected
                                  ? Colors.white
                                  : theme.primary)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --------- 当天完成清单 ---------
  Widget _dayList(ThemeDef theme, List<CompletionRecord> records) {
    final isToday = isSameDate(_selected, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: isToday ? '今天完成了' : '${_selected.month}月${_selected.day}日完成了',
          subtitle: '${records.length} 件事',
        ),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    '这一天还没有完成记录',
                    style: TextStyle(fontSize: 12, color: theme.muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: records.length,
                  itemBuilder: (_, i) => _recordTile(theme, records[i],
                      isLast: i == records.length - 1),
                ),
        ),
      ],
    );
  }

  Widget _recordTile(ThemeDef theme, CompletionRecord r,
      {required bool isLast}) {
    final (icon, color) = switch (r.kind) {
      CompletionKind.task => (Icons.task_alt, theme.primary),
      CompletionKind.schedule => (Icons.event_note, const Color(0xFF42A5F5)),
      CompletionKind.habit => (Icons.favorite_border, const Color(0xFF6BCB9D)),
      CompletionKind.pomodoro => (Icons.timer_outlined, const Color(0xFFF06292)),
    };
    final hhmm =
        '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 34,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(hhmm,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.muted)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 12, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: theme.foreground.withOpacity(0.08),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.foreground)),
                    if (r.note.isNotEmpty)
                      Text(r.note,
                          style: TextStyle(
                              fontSize: 10, color: theme.muted)),
                    Text(r.kind.label,
                        style: TextStyle(
                            fontSize: 10, color: color)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
