// widgets/pomodoro_timer.dart - 核心番茄钟圆盘 + 控制
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/settings_provider.dart';
import '../services/timer_service.dart';

class PomodoroTimerWidget extends StatelessWidget {
  const PomodoroTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final pomo = context.watch<PomodoroProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;

    final isWork = pomo.phase == TimerPhase.work;
    final phaseColor = isWork
        ? theme.primary
        : (pomo.phase == TimerPhase.longBreak
            ? theme.accent
            : theme.primary.withOpacity(0.6));

    return Column(
      children: [
        // 阶段指示 Tab
        _PhaseTabs(phase: pomo.phase),
        const SizedBox(height: 24),
        // 圆盘计时器
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圈
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              // 进度圈
              SizedBox(
                width: 260,
                height: 260,
                child: CircularProgressIndicator(
                  value: pomo.progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: AlwaysStoppedAnimation(phaseColor),
                ),
              ),
              // 中央文字
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pomo.timeDisplay,
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w200,
                      color: theme.foreground,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pomo.phaseLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.foreground.withOpacity(0.6),
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // 控制按钮
        _ControlButtons(),
      ],
    );
  }
}

class _PhaseTabs extends StatelessWidget {
  final TimerPhase phase;
  const _PhaseTabs({required this.phase});

  @override
  Widget build(BuildContext context) {
    final pomo = context.read<PomodoroProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;

    final items = [
      _PhaseItem(TimerPhase.work, '专注'),
      _PhaseItem(TimerPhase.shortBreak, '短休息'),
      _PhaseItem(TimerPhase.longBreak, '长休息'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((it) {
          final active = it.phase == phase;
          return GestureDetector(
            onTap: () => pomo.setPhase(it.phase),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: active ? theme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                it.label,
                style: TextStyle(
                  color: active ? Colors.white : theme.foreground.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PhaseItem {
  final TimerPhase phase;
  final String label;
  const _PhaseItem(this.phase, this.label);
}

class _ControlButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pomo = context.watch<PomodoroProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = settings.currentTheme;

    final state = pomo.state;

    Widget centerBtn;
    if (state == TimerState.running) {
      centerBtn = ElevatedButton.icon(
        onPressed: () => pomo.pause(),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(180, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.pause, size: 28),
        label: const Text('暂停', style: TextStyle(fontSize: 18)),
      );
    } else if (state == TimerState.paused) {
      centerBtn = ElevatedButton.icon(
        onPressed: () => pomo.resume(),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(180, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.play_arrow, size: 28),
        label: const Text('继续', style: TextStyle(fontSize: 18)),
      );
    } else {
      centerBtn = ElevatedButton.icon(
        onPressed: () => pomo.start(),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(180, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.play_arrow, size: 28),
        label: const Text('开始', style: TextStyle(fontSize: 18)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 重置
        OutlinedButton.icon(
          onPressed: () => pomo.reset(),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.foreground,
            minimumSize: const Size(96, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('重置'),
        ),
        const SizedBox(width: 16),
        centerBtn,
        const SizedBox(width: 16),
        // 跳过
        OutlinedButton.icon(
          onPressed: () => pomo.skipPhase(),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.foreground,
            minimumSize: const Size(96, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          icon: const Icon(Icons.skip_next, size: 20),
          label: const Text('跳过'),
        ),
      ],
    );
  }
}
