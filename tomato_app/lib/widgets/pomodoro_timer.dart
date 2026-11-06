// widgets/pomodoro_timer.dart - 情境化番茄钟
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/timer_service.dart';
import '../theme/backgrounds.dart';
import 'ui.dart';

class PomodoroTimerWidget extends StatelessWidget {
  const PomodoroTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final pomo = context.watch<PomodoroProvider>();

    return Column(
      children: [
        _PhaseTabs(theme: theme, pomo: pomo),
        const SizedBox(height: 18),
        _TimerRing(theme: theme, pomo: pomo),
        const SizedBox(height: 18),
        _Controls(theme: theme, pomo: pomo),
        const SizedBox(height: 14),
        _TaskLink(theme: theme, pomo: pomo),
      ],
    );
  }
}

class _PhaseTabs extends StatelessWidget {
  final ThemeDef theme;
  final PomodoroProvider pomo;

  const _PhaseTabs({required this.theme, required this.pomo});

  @override
  Widget build(BuildContext context) {
    final items = [
      (TimerPhase.work, '专注'),
      (TimerPhase.shortBreak, '短休'),
      (TimerPhase.longBreak, '长休'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((e) {
        final active = pomo.phase == e.$1;
        return GestureDetector(
          onTap: () => pomo.setPhase(e.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? theme.primary : theme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              e.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? Colors.white : theme.primary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimerRing extends StatelessWidget {
  final ThemeDef theme;
  final PomodoroProvider pomo;

  const _TimerRing({required this.theme, required this.pomo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primary.withOpacity(0.04),
            ),
          ),
          SizedBox(
            width: 212,
            height: 212,
            child: CircularProgressIndicator(
              value: pomo.progress,
              strokeWidth: 9,
              backgroundColor: theme.primary.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(
                pomo.phase == TimerPhase.work
                    ? theme.primary
                    : theme.accent,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pomo.timeDisplay,
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: 1.5,
                  color: theme.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: pomo.isRunning ? theme.primary : theme.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    pomo.phaseLabel,
                    style: TextStyle(fontSize: 12, color: theme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '累计 ${pomo.completedWorkCount} 个番茄',
                style: TextStyle(fontSize: 10, color: theme.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final ThemeDef theme;
  final PomodoroProvider pomo;

  const _Controls({required this.theme, required this.pomo});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: Icons.replay,
          size: 44,
          background: theme.primary.withOpacity(0.10),
          iconColor: theme.primary,
          onTap: pomo.reset,
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: pomo.toggle,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: theme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              pomo.isRunning ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 20),
        _RoundButton(
          icon: Icons.skip_next,
          size: 44,
          background: theme.primary.withOpacity(0.10),
          iconColor: theme.primary,
          onTap: pomo.skipPhase,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.size,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

class _TaskLink extends StatelessWidget {
  final ThemeDef theme;
  final PomodoroProvider pomo;

  const _TaskLink({required this.theme, required this.pomo});

  @override
  Widget build(BuildContext context) {
    final hasTask = pomo.currentTaskTitle != null;
    return GestureDetector(
      onTap: () => _pickTask(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.primary.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 14, color: theme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                pomo.currentTaskTitle ?? '关联一个任务, 专注更聚焦',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: hasTask ? theme.foreground : theme.muted,
                ),
              ),
            ),
            if (hasTask) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => pomo.assignTask(null),
                child: Icon(Icons.close, size: 14, color: theme.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pickTask(BuildContext context) {
    final tasks = context.read<TaskProvider>().activeTasks;
    showAppSheet(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '选择要专注的任务',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.foreground,
              ),
            ),
          ),
          if (tasks.isEmpty)
            const EmptyHint(
              icon: Icons.task_alt,
              text: '还没有进行中的待办, 可先到待办页创建',
            )
          else
            ...tasks.take(12).map((t) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Icon(Icons.radio_button_unchecked,
                      size: 18, color: theme.primary),
                  title: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: theme.foreground),
                  ),
                  subtitle: Text(
                    '${t.priority.label}优先级 · ${t.completedPomodoros}/${t.estimatedPomodoros} 番茄',
                    style: TextStyle(fontSize: 10, color: theme.muted),
                  ),
                  onTap: () {
                    context.read<PomodoroProvider>().assignTask(t);
                    Navigator.pop(context);
                  },
                )),
        ],
      ),
    );
  }
}
