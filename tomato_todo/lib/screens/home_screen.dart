// screens/home_screen.dart - 主界面:番茄钟 + 任务列表
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pomodoro_record.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/pomodoro_timer.dart';
import '../widgets/task_item.dart';
import '../widgets/task_input.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0; // 0 = 全部任务, 1 = 已完成

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部:今日统计
          _TodaySummary(),
          const SizedBox(height: 20),
          // 番茄钟
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardBackground.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const PomodoroTimerWidget(),
          ),
          const SizedBox(height: 20),
          // 任务区域
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                _buildTab(
                  label: '全部任务 (${tasks.activeTasks.length + tasks.completedTasks.length})',
                  active: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _buildTab(
                  label: '已完成 (${tasks.completedTasks.length})',
                  active: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                  theme: theme,
                ),
              ],
            ),
          ),
          // 任务输入
          const TaskInputWidget(),
          // 任务列表
          ...(_tab == 0 ? tasks.activeTasks : tasks.completedTasks)
              .map((t) => TaskItemWidget(task: t)),
          if ((_tab == 0 ? tasks.activeTasks : tasks.completedTasks)
              .isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                _tab == 0 ? '还没有任务,添加一个吧 ✨' : '暂无已完成任务',
                style: TextStyle(
                  color: theme.foreground.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 100), // 底部导航留白
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
    required ThemeDef theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? theme.primary : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : theme.foreground.withOpacity(0.6),
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;
    final pomo = context.watch<PomodoroProvider>();
    final tasks = context.watch<TaskProvider>();

    final today = DateTime.now();
    final todayWork = pomo.records
        .where((r) =>
            r.type == PomodoroType.work && r.isSameDay(today))
        .length;

    final completedToday = tasks.tasks.where((t) {
      if (t.completedAt == null) return false;
      return t.completedAt!.year == today.year &&
          t.completedAt!.month == today.month &&
          t.completedAt!.day == today.day;
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              icon: Icons.timer,
              color: theme.primary,
              label: '今日番茄',
              value: '$todayWork',
              unit: '个',
            ),
          ),
          Container(width: 1, height: 48, color: Colors.grey.withOpacity(0.2)),
          Expanded(
            child: _StatBlock(
              icon: Icons.check_circle_outline,
              color: theme.accent,
              label: '今日完成',
              value: '$completedToday',
              unit: '项',
            ),
          ),
          Container(width: 1, height: 48, color: Colors.grey.withOpacity(0.2)),
          Expanded(
            child: _StatBlock(
              icon: Icons.favorite_border,
              color: Colors.pinkAccent,
              label: '累计番茄',
              value: '${pomo.completedWorkCount}',
              unit: '个',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  const _StatBlock({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: theme.foreground.withOpacity(0.5)),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: TextStyle(color: theme.foreground),
            children: [
              TextSpan(
                text: value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: unit,
                style: TextStyle(
                    fontSize: 11,
                    color: theme.foreground.withOpacity(0.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
