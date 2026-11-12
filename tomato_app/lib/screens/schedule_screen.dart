// 周视图日程
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/schedule_event.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/schedule_editor.dart';
import '../widgets/ui.dart';

class ScheduleScreen extends StatefulWidget {
  /// 打开时默认选中的日期(通知点击跳转时使用)
  final DateTime? initialDate;

  const ScheduleScreen({super.key, this.initialDate});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const int _startHour = 0;
  static const int _endHour = 24;
  static const double _hourHeight = 62.0;
  static const double _labelWidth = 48.0;

  late DateTime _selected =
      startOfDay(widget.initialDate ?? DateTime.now());
  late DateTime _weekStart =
      startOfWeek(widget.initialDate ?? DateTime.now());

  /// 首次打开自动滚到早上 7 点附近
  late final ScrollController _scroll =
      ScrollController(initialScrollOffset: 7 * _hourHeight);

  String? _dragId;
  double _dragOffset = 0;
  int _dragBaseStart = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _selectDate(DateTime d) {
    setState(() {
      _selected = startOfDay(d);
      _weekStart = startOfWeek(d);
    });
    _jumpToMorning();
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
      _selected = _weekStart;
    });
    _jumpToMorning();
  }

  void _jumpToMorning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        7 * _hourHeight,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final sp = context.watch<SettingsProvider>();
    final settings = sp.settings;
    final provider = context.watch<ScheduleProvider>();
    final events = provider.eventsFor(_selected);
    final planned = provider.plannedMinutesOn(_selected);

    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          theme.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          theme.isDark ? Brightness.dark : Brightness.light,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        AppBackground(settings: settings, theme: theme),
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: theme.foreground,
              title: Text('周视图',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: theme.foreground)),
              actions: [
                TextButton(
                  onPressed: () => _selectDate(DateTime.now()),
                  child: Text('今天',
                      style: TextStyle(fontSize: 12, color: theme.primary)),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: theme.primary,
              onPressed: () => showScheduleEditor(
                context,
                date: _selected,
                startMinute: 9 * 60,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            body: Column(
              children: [
                _weekStrip(theme, provider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        '${shortDate(_selected)} ${weekdayFull(_selected)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.foreground),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${events.length} 项 · 已规划 ${durationText(planned)}',
                        style: TextStyle(fontSize: 10, color: theme.muted),
                      ),
                      const Spacer(),
                      Text('长按拖动调整',
                          style: TextStyle(fontSize: 9, color: theme.muted)),
                    ],
                  ),
                ),
                Expanded(
                  child: _timeline(theme, events),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekStrip(ThemeDef theme, ScheduleProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          _arrow(Icons.chevron_left, () => _shiftWeek(-1), theme),
          Expanded(
            child: Row(
              children: List.generate(7, (i) {
                final d = _weekStart.add(Duration(days: i));
                final selected = isSameDate(d, _selected);
                final isToday = isSameDate(d, DateTime.now());
                final count = provider.eventsFor(d).length;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.primary.withOpacity(0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? theme.primary.withOpacity(0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekdayShort(d),
                            style: TextStyle(
                              fontSize: 10,
                              color: isToday ? theme.accent : theme.muted,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? theme.primary
                                  : theme.foreground.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: count > 0
                                  ? theme.primary.withOpacity(0.7)
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _arrow(Icons.chevron_right, () => _shiftWeek(1), theme),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap, ThemeDef theme) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(icon, size: 20, color: theme.muted),
      ),
    );
  }

  Widget _timeline(ThemeDef theme, List<ScheduleEvent> events) {
    const startMinute = _startHour * 60;
    const totalHeight = (_endHour - _startHour) * _hourHeight;

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 100),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            // 背景与小时刻度
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final minutes =
                    startMinute + details.localPosition.dy / _hourHeight * 60;
                final snapped = ((minutes + 14) ~/ 15) * 15;
                final clamped =
                    snapped.clamp(0, _endHour * 60 - 15).toInt();
                showScheduleEditor(
                  context,
                  date: _selected,
                  startMinute: clamped,
                );
              },
              child: Stack(
                children: [
                  for (int h = _startHour; h <= _endHour; ++h)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (h - _startHour) * _hourHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                h == _endHour
                                    ? '24:00'
                                    : '${h.toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 9.5, color: theme.muted),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: theme.foreground.withOpacity(
                                  h == _startHour ? 0.02 : 0.07),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 当前时间线
            if (isSameDate(_selected, DateTime.now()))
              Positioned(
                left: _labelWidth,
                right: 8,
                top: (DateTime.now().hour * 60 + DateTime.now().minute -
                        startMinute) /
                       60 *
                       _hourHeight,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1.5,
                        color: const Color(0xFFFF5252).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            // 时间块
            for (final e in events) _eventBlock(theme, e, startMinute),
          ],
        ),
      ),
    );
  }

  Widget _eventBlock(ThemeDef theme, ScheduleEvent e, int startMinute) {
    final top = (e.startMinute - startMinute) / 60 * _hourHeight;
    final height = (e.durationMinutes / 60 * _hourHeight).clamp(24.0, 600.0);
    final dragging = _dragId == e.id;
    final color = e.category.color;

    return Positioned(
      left: _labelWidth + 4,
      right: 8,
      top: top + (dragging ? _dragOffset : 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showScheduleEditor(context, event: e),
        onVerticalDragStart: (_) => setState(() {
          _dragId = e.id;
          _dragOffset = 0;
          _dragBaseStart = e.startMinute;
        }),
        onVerticalDragUpdate: (details) => setState(() {
          _dragOffset += details.delta.dy;
        }),
        onVerticalDragEnd: (_) async {
          final movedMinutes = (_dragOffset / _hourHeight * 60).round();
          final snapped = ((movedMinutes + 7) ~/ 15) * 15;
          final rawStart = _dragBaseStart + snapped;
          final newStart = rawStart
              .clamp(startMinute, (_endHour * 60) - e.durationMinutes)
              .toInt();
          setState(() {
            _dragId = null;
            _dragOffset = 0;
          });
          if (newStart == e.startMinute) return;

          final newEnd = newStart + e.durationMinutes;
          final conflicts = context
              .read<ScheduleProvider>()
              .conflictsOn(_selected, newStart, newEnd, excludeId: e.id);
          if (conflicts.isNotEmpty) {
            final ok = await showConfirmDialog(
              context,
              title: '时间冲突',
              content:
                  '与「${conflicts.first.title}」(${timeText(conflicts.first.startMinute)}-${timeText(conflicts.first.endMinute)}) 重叠, 仍要移动吗?',
              confirmText: '仍然移动',
            );
            if (!ok || !mounted) return;
          }
          await context.read<ScheduleProvider>().update(e.copyWith(
                startMinute: newStart,
                endMinute: newEnd,
              ));
        },
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.16),
            borderRadius: BorderRadius.circular(9),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
            boxShadow: dragging
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                e.title,
                maxLines: height < 38 ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: e.isDone ? theme.muted : theme.foreground,
                  decoration:
                      e.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              if (height >= 34)
                Text(
                  '${timeText(e.startMinute)}-${timeText(e.endMinute)}'
                  '${e.isDone ? ' · 已完成' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: theme.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
