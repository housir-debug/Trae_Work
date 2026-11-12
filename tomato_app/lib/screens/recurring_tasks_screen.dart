// 周期 / 固定待办管理
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/task_input.dart';
import '../widgets/ui.dart';

class RecurringTasksScreen extends StatelessWidget {
  const RecurringTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final sp = context.watch<SettingsProvider>();
    final settings = sp.settings;
    final provider = context.watch<TaskProvider>();
    final recurring = provider.recurringTasks;

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
              title: Text('周期 / 固定待办',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: theme.foreground)),
            ),
            body: recurring.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        '还没有周期性待办\n\n新建待办时选择「重复」或「固定」\n重复按天数循环, 固定按每周几 / 每月几号自动回归',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.muted,
                            height: 1.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: recurring.length,
                    itemBuilder: (_, i) =>
                        _tile(context, theme, provider, recurring[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, ThemeDef theme, TaskProvider provider,
      Task t) {
    final dormant = t.isDormant;
    final progress = t.cycleProgress.clamp(0.0, 1.0);
    final String subtitle;
    if (t.isFixed) {
      subtitle = t.isCompleted
          ? '本次已完成 · 下次 ${t.repeatLabel} 自动回归'
          : '${t.repeatLabel} · 到期当天自动加入待办';
    } else if (dormant) {
      subtitle = '休眠中 · ${friendlyDate(t.nextAppearanceAt!)} 回归';
    } else if (t.isOverdue) {
      subtitle = '已逾期 · 请尽快处理';
    } else {
      subtitle =
          '周期进度 ${(progress * 100).toInt()}% · 当前优先级 ${t.effectivePriority.label}';
    }
    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.foreground,
                      decoration:
                          dormant ? TextDecoration.lineThrough : null),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: theme.muted),
                padding: EdgeInsets.zero,
                color: theme.cardBackground,
                onSelected: (v) async {
                  if (v == 'edit') {
                    showTaskEditor(context, task: t);
                  } else if (v == 'activate') {
                    await provider.activateNow(t.id);
                    if (context.mounted) {
                      showToast(context, '已提前回归待办列表');
                    }
                  } else if (v == 'cancel') {
                    await provider.cancelRepeat(t.id);
                    if (context.mounted) {
                      showToast(context, '已取消周期, 转为普通待办');
                    }
                  } else if (v == 'delete') {
                    final ok = await showConfirmDialog(context,
                        title: '删除「${t.title}」?',
                        danger: true,
                        confirmText: '删除');
                    if (ok && context.mounted) {
                      await provider.deleteTask(t.id);
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑',
                        style:
                            TextStyle(fontSize: 13, color: theme.foreground)),
                  ),
                  if (dormant)
                    PopupMenuItem(
                      value: 'activate',
                      child: Text('立即回归待办',
                          style: TextStyle(
                              fontSize: 13, color: theme.foreground)),
                    ),
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text('取消周期(不再重复)',
                        style: TextStyle(
                            fontSize: 13, color: theme.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('删除',
                        style: TextStyle(
                            fontSize: 13, color: const Color(0xFFFF5252))),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TinyBadge(
                text: t.repeatLabel,
                color: theme.primary,
                icon: Icons.schedule,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: t.isOverdue
                          ? const Color(0xFFFF5252)
                          : theme.muted),
                ),
              ),
            ],
          ),
          if (!dormant && t.isRepeat) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: theme.primary.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 2 / 3
                      ? const Color(0xFFFF5252)
                      : progress >= 1 / 3
                          ? const Color(0xFFFFB300)
                          : theme.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
