// screens/habits_screen.dart - 习惯养成
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/ui.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final provider = context.watch<HabitProvider>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('习惯养成',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: theme.foreground)),
                    const SizedBox(height: 3),
                    Text(
                      '小习惯，日拱一卒 · 今天 ${provider.todayDone}/${provider.todayTotal}',
                      style: TextStyle(fontSize: 11, color: theme.muted),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => showHabitEditor(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          // 概览
          AppCard(
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: '今日完成率',
                    value: '${(provider.todayRate * 100).round()}%',
                    color: theme.primary,
                  ),
                ),
                _sep(theme),
                Expanded(
                  child: _Stat(
                    label: '最长连续',
                    value: '${provider.bestStreak} 天',
                    color: const Color(0xFFF06292),
                  ),
                ),
                _sep(theme),
                Expanded(
                  child: _Stat(
                    label: '30天坚持率',
                    value:
                        '${(provider.averageRate(30) * 100).round()}%',
                    color: theme.accent,
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: '我的习惯',
            subtitle: provider.habits.isEmpty ? '' : '共 ${provider.habits.length} 个',
          ),
          if (provider.habits.isEmpty)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: const EmptyHint(
                icon: Icons.repeat,
                text: '从一个小习惯开始\n例如: 每天喝水、阅读 10 分钟、早睡',
              ),
            )
          else
            ...provider.habits.map((h) => _HabitCard(habit: h)),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _sep(ThemeDef theme) => Container(
        width: 1,
        height: 36,
        color: theme.foreground.withOpacity(0.08),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, color: theme.muted)),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;

  const _HabitCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final color = Color(habit.colorValue);
    final done = habit.doneToday;
    final days = habit.lastDays(7);
    final todayIndex = 6;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      onTap: () => context.read<HabitProvider>().toggleToday(habit.id),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(habit.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          habit.isDaily
                              ? '每天'
                              : '每周 ${habit.targetPerWeek} 次',
                          style:
                              TextStyle(fontSize: 10, color: theme.muted),
                        ),
                        if (habit.streak > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.local_fire_department,
                              size: 11, color: color),
                          Text(
                            '连续 ${habit.streak} 天',
                            style: TextStyle(fontSize: 10, color: color),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () =>
                    context.read<HabitProvider>().toggleToday(habit.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: done ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? color : color.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    done ? Icons.check : Icons.add,
                    size: 18,
                    color: done ? Colors.white : color,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: theme.muted),
                padding: EdgeInsets.zero,
                color: theme.cardBackground,
                onSelected: (v) {
                  if (v == 'edit') showHabitEditor(context, habit: habit);
                  if (v == 'delete') _delete(context);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑',
                        style: TextStyle(
                            fontSize: 13, color: theme.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('删除',
                        style: TextStyle(
                            fontSize: 13, color: theme.foreground)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.asMap().entries.map((e) {
              final isToday = e.key == todayIndex;
              final checked = e.value;
              final d = DateTime.now()
                  .subtract(Duration(days: todayIndex - e.key));
              return Column(
                children: [
                  Text(
                    weekdayShort(d),
                    style: TextStyle(
                      fontSize: 9,
                      color: isToday ? theme.primary : theme.muted,
                      fontWeight:
                          isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: checked ? color : color.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: color, width: 1.5)
                          : null,
                    ),
                    child: checked
                        ? const Icon(Icons.check,
                            size: 11, color: Colors.white)
                        : null,
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: habit.targetPerWeek == 0
                        ? 0
                        : (habit.thisWeekCount / habit.targetPerWeek)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                    minHeight: 4,
                    backgroundColor: color.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '本周 ${habit.thisWeekCount}/${habit.targetPerWeek}',
                style: TextStyle(fontSize: 9, color: theme.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showConfirmDialog(context,
        title: '删除习惯「${habit.name}」?',
        content: '打卡记录会一并删除',
        danger: true,
        confirmText: '删除');
    if (ok && context.mounted) {
      await context.read<HabitProvider>().delete(habit.id);
    }
  }
}

// ---------------- 习惯编辑器 ----------------
Future<void> showHabitEditor(BuildContext context, {Habit? habit}) async {
  await showAppSheet<void>(
    context,
    child: _HabitEditor(existing: habit),
  );
}

class _HabitEditor extends StatefulWidget {
  final Habit? existing;

  const _HabitEditor({this.existing});

  @override
  State<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<_HabitEditor> {
  late final TextEditingController _name;
  late String _emoji;
  late int _color;
  late int _target;

  static const _emojis = [
    '📖', '🏃', '💧', '🧘', '🥗', '😴', '✍️', '🎯', '💪', '🎧', '☀️', '🦷',
  ];
  static const _colors = [
    0xFF6BCB9D,
    0xFF4A90E2,
    0xFFFF6B6B,
    0xFFFFA726,
    0xFF9575CD,
    0xFFF06292,
    0xFF26C6DA,
    0xFF85929E,
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    _name = TextEditingController(text: h?.name ?? '');
    _emoji = h?.emoji ?? '📖';
    _color = h?.colorValue ?? _colors.first;
    _target = h?.targetPerWeek ?? 7;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final isEditing = widget.existing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isEditing ? '编辑习惯' : '新建习惯',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.foreground),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: !isEditing,
          maxLength: 30,
          style: TextStyle(fontSize: 14, color: theme.foreground),
          decoration: appInput(context: context, hint: '习惯名称, 例如: 阅读 30 分钟')
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        Text('图标', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emojis.map((e) {
            final selected = _emoji == e;
            return GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.primary.withOpacity(0.14)
                      : theme.foreground.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: theme.primary, width: 1.5)
                      : null,
                ),
                child: Text(e, style: const TextStyle(fontSize: 19)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text('颜色', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: _colors.map((c) {
            final selected = _color == c;
            return GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: theme.foreground, width: 2)
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('频率', style: TextStyle(fontSize: 12, color: theme.muted)),
            const Spacer(),
            Text(
              _target >= 7 ? '每天' : '每周 $_target 次',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.primary),
            ),
          ],
        ),
        Slider(
          value: _target.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          activeColor: theme.primary,
          label: _target >= 7 ? '每天' : '$_target 次/周',
          onChanged: (v) => setState(() => _target = v.round()),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.muted)),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _save,
              child: Text(isEditing ? '保存' : '创建习惯'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, '请填写习惯名称');
      return;
    }
    final provider = context.read<HabitProvider>();
    if (widget.existing != null) {
      await provider.update(widget.existing!.copyWith(
        name: name,
        emoji: _emoji,
        colorValue: _color,
        targetPerWeek: _target,
      ));
    } else {
      await provider.add(Habit(
        name: name,
        emoji: _emoji,
        colorValue: _color,
        targetPerWeek: _target,
      ));
    }
    if (mounted) {
      showToast(context, '习惯已保存');
      Navigator.pop(context);
    }
  }
}
