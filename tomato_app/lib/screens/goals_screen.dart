// screens/goals_screen.dart - 目标与里程碑
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/ui.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final provider = context.watch<GoalProvider>();

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
                    Text('目标管理',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: theme.foreground)),
                    const SizedBox(height: 3),
                    Text(
                      '${provider.activeGoals.length} 个进行中 · 里程碑 ${provider.doneMilestones}/${provider.totalMilestones}',
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
                  onPressed: () => showGoalEditor(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          AppCard(
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: '进行中',
                    value: '${provider.activeGoals.length}',
                    color: theme.primary,
                  ),
                ),
                _sep(theme),
                Expanded(
                  child: _Stat(
                    label: '平均进度',
                    value: '${(provider.averageProgress * 100).round()}%',
                    color: theme.accent,
                  ),
                ),
                _sep(theme),
                Expanded(
                  child: _Stat(
                    label: '已达成',
                    value: '${provider.completedGoals.length}',
                    color: const Color(0xFF6BCB9D),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: '进行中的目标',
            subtitle: provider.activeGoals.isEmpty
                ? ''
                : '保持聚焦, 一步步靠近',
          ),
          if (provider.activeGoals.isEmpty)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: const EmptyHint(
                icon: Icons.flag_outlined,
                text: '还没有目标\n设一个季度目标, 再拆成可执行的里程碑',
              ),
            )
          else
            ...provider.activeGoals.map((g) => _GoalCard(goal: g)),
          if (provider.completedGoals.isNotEmpty) ...[
            SectionHeader(title: '已达成', subtitle: '${provider.completedGoals.length} 个'),
            ...provider.completedGoals.map((g) => _GoalCard(goal: g)),
          ],
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

class _GoalCard extends StatefulWidget {
  final Goal goal;

  const _GoalCard({required this.goal});

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _expanded = false;
  bool _addingMilestone = false;
  final _milestoneInput = TextEditingController();

  @override
  void dispose() {
    _milestoneInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final goal = widget.goal;
    final color = _categoryColor(goal.category);
    final progress = goal.progress;
    final daysLeft = goal.daysLeft;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_categoryIcon(goal.category),
                    size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.foreground,
                        decoration: goal.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TinyBadge(text: goal.category, color: color),
                        if (daysLeft != null)
                          TinyBadge(
                            text: goal.isCompleted
                                ? '已达成'
                                : daysLeft < 0
                                    ? '已超期 ${-daysLeft} 天'
                                    : daysLeft == 0
                                        ? '今天截止'
                                        : '剩 $daysLeft 天',
                            color: goal.isCompleted
                                ? const Color(0xFF6BCB9D)
                                : daysLeft < 0
                                    ? const Color(0xFFFF5252)
                                    : theme.primary,
                            icon: Icons.schedule,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: theme.muted),
                padding: EdgeInsets.zero,
                color: theme.cardBackground,
                onSelected: (v) {
                  if (v == 'edit') showGoalEditor(context, goal: goal);
                  if (v == 'delete') _delete(context);
                  if (v == 'complete') {
                    context.read<GoalProvider>().toggleComplete(goal.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑',
                        style: TextStyle(
                            fontSize: 13, color: theme.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'complete',
                    child: Text(goal.isCompleted ? '重新开启' : '标记达成',
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
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              goal.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: theme.muted),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: color.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '里程碑 ${goal.doneMilestones}/${goal.milestones.length}',
                style: TextStyle(fontSize: 10, color: theme.muted),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Text(
                      _expanded ? '收起' : '查看',
                      style: TextStyle(fontSize: 10, color: theme.primary),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 15,
                      color: theme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            ...goal.milestones.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context
                            .read<GoalProvider>()
                            .toggleMilestone(goal.id, m.id),
                        child: Icon(
                          m.isDone
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 17,
                          color: m.isDone ? color : theme.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: m.isDone ? theme.muted : theme.foreground,
                            decoration: m.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context
                            .read<GoalProvider>()
                            .removeMilestone(goal.id, m.id),
                        child: Icon(Icons.close,
                            size: 14, color: theme.muted),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            if (_addingMilestone)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _milestoneInput,
                      autofocus: true,
                      style:
                          TextStyle(fontSize: 12, color: theme.foreground),
                      decoration: appInput(
                          context: context,
                          hint: '新的里程碑',
                          dense: true),
                      onSubmitted: (_) => _addMilestone(),
                    ),
                  ),
                  IconButton(
                    onPressed: _addMilestone,
                    icon: Icon(Icons.check, size: 18, color: theme.primary),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: () => setState(() => _addingMilestone = true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 13, color: color),
                      const SizedBox(width: 3),
                      Text('添加里程碑',
                          style: TextStyle(fontSize: 10, color: color)),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _addMilestone() async {
    final title = _milestoneInput.text.trim();
    if (title.isEmpty) return;
    await context.read<GoalProvider>().addMilestone(widget.goal.id, title);
    _milestoneInput.clear();
    if (mounted) setState(() => _addingMilestone = false);
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showConfirmDialog(context,
        title: '删除目标「${widget.goal.title}」?',
        danger: true,
        confirmText: '删除');
    if (ok && context.mounted) {
      await context.read<GoalProvider>().delete(widget.goal.id);
    }
  }
}

Color _categoryColor(String category) {
  switch (category) {
    case '健康':
      return const Color(0xFF6BCB9D);
    case '工作':
      return const Color(0xFF4A90E2);
    case '学习':
    case '成长':
      return const Color(0xFF9575CD);
    case '家庭':
      return const Color(0xFFF06292);
    case '财务':
      return const Color(0xFFFFA726);
    default:
      return const Color(0xFF26C6DA);
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case '健康':
      return Icons.favorite_border;
    case '工作':
      return Icons.work_outline;
    case '学习':
    case '成长':
      return Icons.menu_book_outlined;
    case '家庭':
      return Icons.home_outlined;
    case '财务':
      return Icons.savings_outlined;
    default:
      return Icons.flag_outlined;
  }
}

// ---------------- 目标编辑器 ----------------
Future<void> showGoalEditor(BuildContext context, {Goal? goal}) async {
  await showAppSheet<void>(
    context,
    child: _GoalEditor(existing: goal),
  );
}

class _GoalEditor extends StatefulWidget {
  final Goal? existing;

  const _GoalEditor({this.existing});

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late String _category;
  DateTime? _targetDate;

  static const _categories = ['成长', '健康', '工作', '学习', '家庭', '财务'];

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _title = TextEditingController(text: g?.title ?? '');
    _desc = TextEditingController(text: g?.description ?? '');
    _category = g?.category ?? '成长';
    _targetDate = g?.targetDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
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
          isEditing ? '编辑目标' : '新建目标',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.foreground),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: !isEditing,
          maxLength: 50,
          style: TextStyle(fontSize: 14, color: theme.foreground),
          decoration: appInput(
                  context: context,
                  hint: '想达成什么? 例如: 3 个月读完 10 本书')
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        Text('分类', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _categories.map((c) {
            return PillChip(
              label: c,
              color: _categoryColor(c),
              selected: _category == c,
              onTap: () => setState(() => _category = c),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _desc,
          maxLines: 2,
          style: TextStyle(fontSize: 13, color: theme.foreground),
          decoration: appInput(context: context, hint: '目标描述 / 为什么要达成它'),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _targetDate ??
                  DateTime.now().add(const Duration(days: 90)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) setState(() => _targetDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 17, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  _targetDate == null
                      ? '设定目标截止日期(可选)'
                      : '截止日期: ${shortDate(_targetDate!)}',
                  style: TextStyle(fontSize: 12, color: theme.foreground),
                ),
                const Spacer(),
                if (_targetDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _targetDate = null),
                    child: Icon(Icons.close, size: 15, color: theme.muted),
                  )
                else
                  Icon(Icons.chevron_right, size: 18, color: theme.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '创建后可在目标卡片中拆解里程碑, 逐步推进',
          style: TextStyle(fontSize: 10, color: theme.muted),
        ),
        const SizedBox(height: 16),
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
              child: Text(isEditing ? '保存' : '创建目标'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, '请填写目标标题');
      return;
    }
    final provider = context.read<GoalProvider>();
    if (widget.existing != null) {
      await provider.update(widget.existing!.copyWith(
        title: title,
        description: _desc.text.trim(),
        category: _category,
        targetDate: _targetDate,
        clearTargetDate: _targetDate == null,
      ));
    } else {
      await provider.add(Goal(
        title: title,
        description: _desc.text.trim(),
        category: _category,
        targetDate: _targetDate,
      ));
    }
    if (mounted) {
      showToast(context, '目标已保存');
      Navigator.pop(context);
    }
  }
}
