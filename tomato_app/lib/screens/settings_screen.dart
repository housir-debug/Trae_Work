// 设置中心
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../theme/backgrounds.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final sp = context.watch<SettingsProvider>();
    final settings = sp.settings;

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
              title: Text('设置',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: theme.foreground)),
            ),
            body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- 每日目标 ----------------
            SectionHeader(
              title: '每日目标',
              subtitle: '给每天一个清晰的锚点',
              margin: const EdgeInsets.fromLTRB(0, 8, 0, 10),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  _SliderRow(
                    label: '专注时长目标',
                    value: durationText(settings.dailyFocusGoal),
                    child: Slider(
                      value: settings.dailyFocusGoal.toDouble(),
                      min: 30,
                      max: 480,
                      divisions: 15,
                      activeColor: theme.primary,
                      onChanged: (v) =>
                          sp.setDailyGoals(focus: (v / 30).round() * 30),
                    ),
                  ),
                ],
              ),
            ),
            // ---------------- 番茄钟 ----------------
            SectionHeader(
              title: '番茄钟',
              subtitle: '适配你自己的专注节奏',
              margin: const EdgeInsets.fromLTRB(0, 24, 0, 10),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  _SliderRow(
                    label: '专注时长',
                    value: '${settings.workDuration} 分钟',
                    child: Slider(
                      value: settings.workDuration.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      activeColor: theme.primary,
                      onChanged: (v) =>
                          sp.updateDuration(work: v.round()),
                    ),
                  ),
                  _SliderRow(
                    label: '短休息',
                    value: '${settings.shortBreakDuration} 分钟',
                    child: Slider(
                      value: settings.shortBreakDuration.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: theme.primary,
                      onChanged: (v) =>
                          sp.updateDuration(shortBreak: v.round()),
                    ),
                  ),
                  _SliderRow(
                    label: '长休息',
                    value: '${settings.longBreakDuration} 分钟',
                    child: Slider(
                      value: settings.longBreakDuration.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      activeColor: theme.primary,
                      onChanged: (v) =>
                          sp.updateDuration(longBreak: v.round()),
                    ),
                  ),
                ],
              ),
            ),
            // ---------------- 反馈与提醒 ----------------
            SectionHeader(
              title: '提醒与反馈',
              subtitle: '本地通知, 不依赖网络',
              margin: const EdgeInsets.fromLTRB(0, 24, 0, 10),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Column(
                children: [
                  _SwitchRow(
                    icon: Icons.notifications_active_outlined,
                    title: '提醒总开关',
                    subtitle: '关闭后不再发送日程与每日提醒',
                    value: settings.remindersEnabled,
                    onChanged: (v) => sp.setRemindersEnabled(v),
                  ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.schedule,
                            size: 18, color: theme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('日程默认提前提醒',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: theme.foreground)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final m in [0, 5, 10, 15, 30])
                                    PillChip(
                                      label: m == 0 ? '准时' : '$m 分钟',
                                      selected:
                                          settings.defaultEventReminder == m,
                                      onTap: () =>
                                          sp.setDefaultEventReminder(m),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  _ReminderRow(
                    icon: Icons.wb_sunny_outlined,
                    title: '每日计划提醒',
                    subtitle: '提醒你查看今天的待办与行程',
                    value: settings.dailyPlanReminderEnabled,
                    timeLabel: _minuteText(
                        settings.dailyPlanReminderMinute),
                    onChanged: (v) =>
                        sp.setDailyPlanReminder(enabled: v),
                    onTimeTap: () async {
                      final picked = await _pickMinute(context,
                          settings.dailyPlanReminderMinute);
                      if (picked != null) {
                        await sp.setDailyPlanReminder(enabled: true, minute: picked);
                      }
                    },
                  ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  _ReminderRow(
                    icon: Icons.nights_stay_outlined,
                    title: '每日复盘提醒',
                    subtitle: '晚上提醒你记录心情与收获',
                    value: settings.dailyReviewReminderEnabled,
                    timeLabel: _minuteText(
                        settings.dailyReviewReminderMinute),
                    onChanged: (v) =>
                        sp.setDailyReviewReminder(enabled: v),
                    onTimeTap: () async {
                      final picked = await _pickMinute(context,
                          settings.dailyReviewReminderMinute);
                      if (picked != null) {
                        await sp.setDailyReviewReminder(
                            enabled: true, minute: picked);
                      }
                    },
                  ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  _SwitchRow(
                    icon: Icons.vibration,
                    title: '完成时震动',
                    subtitle: '阶段结束时轻震提醒',
                    value: settings.enableVibrate,
                    onChanged: (_) => sp.toggleVibrate(),
                  ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  _SwitchRow(
                    icon: Icons.music_note_outlined,
                    title: '完成提示音',
                    subtitle: '阶段结束时播放系统提示音',
                    value: settings.showNotification,
                    onChanged: (_) => sp.toggleNotification(),
                  ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  const _NotificationStatusRow(),
                ],
              ),
            ),
            // ---------------- 外观 ----------------
            SectionHeader(
              title: '主题与背景',
              subtitle: '全部免费, 随心搭配',
              margin: const EdgeInsets.fromLTRB(0, 24, 0, 10),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主题配色',
                      style:
                          TextStyle(fontSize: 12, color: theme.muted)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: kBuiltinThemes.asMap().entries.map((e) {
                      final selected = settings.themeIndex == e.key;
                      return GestureDetector(
                        onTap: () => sp.setTheme(e.key),
                        child: SizedBox(
                          width: 64,
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      e.value.primary,
                                      e.value.accent
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: selected
                                      ? Border.all(
                                          color: theme.foreground,
                                          width: 2)
                                      : null,
                                ),
                                child: selected
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: selected
                                      ? theme.foreground
                                      : theme.muted,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text('渐变背景',
                      style:
                          TextStyle(fontSize: 12, color: theme.muted)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _bgItem(
                        context,
                        label: '默认',
                        selected:
                            settings.customBackgroundPath == null,
                        onTap: () =>
                            context.read<SettingsProvider>().setCustomBackground(null),
                        colorStart: theme.background,
                        colorEnd: theme.primary,
                      ),
                      for (int i = 0; i < kGradientBackgrounds.length; ++i)
                        _bgItem(
                          context,
                          label: '$i',
                          selected: settings.customBackgroundPath ==
                              'grad_$i',
                          onTap: () => context
                              .read<SettingsProvider>()
                              .setCustomBackground('grad_$i'),
                          colorStart: kGradientBackgrounds[i][0],
                          colorEnd: kGradientBackgrounds[i][1],
                        ),
                      GestureDetector(
                        onTap: () => _pickImage(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: theme.primary.withOpacity(0.2)),
                          ),
                          child: Icon(Icons.photo_library_outlined,
                              size: 18, color: theme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('背景遮罩',
                          style:
                              TextStyle(fontSize: 12, color: theme.muted)),
                      const Spacer(),
                      Text(
                          '${(settings.backgroundOpacity * 100).round()}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.primary)),
                    ],
                  ),
                  Slider(
                    value: settings.backgroundOpacity,
                    min: 0,
                    max: 0.85,
                    divisions: 17,
                    activeColor: theme.primary,
                    onChanged: (v) => sp.setBackgroundOpacity(v),
                  ),
                ],
              ),
            ),
            // ---------------- 安全 ----------------
            SectionHeader(
              title: '安全与隐私',
              subtitle: '数据只属于你',
              margin: const EdgeInsets.fromLTRB(0, 24, 0, 10),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SwitchRow(
                    icon: Icons.lock_outline,
                    title: '应用锁',
                    subtitle: '打开应用时需要 4 位密码',
                    value: settings.appLockEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final pin = await _askPin(context);
                        if (pin != null) {
                          await sp.enableAppLock(pin);
                          if (context.mounted) {
                            showToast(context, '应用锁已开启');
                          }
                        }
                      } else {
                        final ok = await showConfirmDialog(context,
                            title: '关闭应用锁?',
                            content: '关闭后打开应用不再需要密码',
                            danger: true,
                            confirmText: '关闭');
                        if (ok) await sp.disableAppLock();
                      }
                    },
                  ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  if (settings.appLockEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 17, color: theme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('回前台重新上锁',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: theme.foreground)),
                                const SizedBox(height: 2),
                                Text('离开应用超过设定时间后需要再次输入密码',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: theme.muted)),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    for (final s in [0, 30, 60, 300])
                                      PillChip(
                                        label: s == 0
                                            ? '立即'
                                            : s == 300
                                                ? '5 分钟'
                                                : s < 60
                                                    ? '$s 秒'
                                                    : '${s ~/ 60} 分钟',
                                        selected:
                                            settings.relockDelaySeconds == s,
                                        onTap: () => sp.setRelockDelay(s),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Divider(
                      height: 1,
                      color: theme.foreground.withOpacity(0.06)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 17, color: theme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '所有待办、目标、日程、复盘与专注记录均保存在本机, 不上传任何服务器; 超过一年的过期记录会自动清理。',
                            style: TextStyle(
                                fontSize: 10.5,
                                height: 1.5,
                                color: theme.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ---------------- 关于 ----------------
            SectionHeader(
              title: '关于',
              margin: const EdgeInsets.fromLTRB(0, 24, 0, 10),
            ),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.primary, theme.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('时',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('时光秘书',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.foreground)),
                        const SizedBox(height: 2),
                        Text('版本 3.1.0 · 专属个人的时间管理秘书',
                            style: TextStyle(
                                fontSize: 10, color: theme.muted)),
                        Text('无需会员 · 无广告 · 全部功能开放',
                            style: TextStyle(
                                fontSize: 10, color: theme.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bgItem(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color colorStart,
    required Color colorEnd,
  }) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorStart, colorEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: theme.foreground, width: 2)
              : Border.all(
                  color: theme.foreground.withOpacity(0.06)),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  Future<String?> _askPin(BuildContext context) async {
    final controller = TextEditingController();
    final theme = context.read<SettingsProvider>().currentTheme;
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('设置应用锁',
            style: TextStyle(fontSize: 17, color: theme.foreground)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: theme.foreground, letterSpacing: 6),
          decoration: appInput(
            context: context,
            hint: '输入 4 位数字密码',
          ).copyWith(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: theme.muted)),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => TextButton(
              onPressed: value.text.length == 4
                  ? () => Navigator.pop(ctx, value.text)
                  : null,
              child: Text('开启',
                  style: TextStyle(
                      color: value.text.length == 4
                          ? theme.primary
                          : theme.muted,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    return pin;
  }

  Future<void> _pickImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null && context.mounted) {
        await context
            .read<SettingsProvider>()
            .setCustomBackground(file.path);
        if (context.mounted) showToast(context, '背景已更新');
      }
    } catch (e) {
      if (context.mounted) showToast(context, '选择图片失败: $e');
    }
  }

  String _minuteText(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  Future<int?> _pickMinute(BuildContext context, int current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: '选择提醒时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return null;
    return picked.hour * 60 + picked.minute;
  }
}

/// 系统通知权限状态 + 测试提醒
class _NotificationStatusRow extends StatefulWidget {
  const _NotificationStatusRow();

  @override
  State<_NotificationStatusRow> createState() =>
      _NotificationStatusRowState();
}

class _NotificationStatusRowState extends State<_NotificationStatusRow> {
  bool? _enabled;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final v = await NotificationService.instance.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _checking = false;
    });
  }

  Future<void> _onTap() async {
    if (_enabled == true) {
      await NotificationService.instance.showTest();
      if (mounted) showToast(context, '已发送测试提醒, 请查看通知栏');
      return;
    }
    final ok = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    setState(() => _enabled = ok);
    if (ok) {
      await NotificationService.instance.showTest();
      if (mounted) showToast(context, '通知权限已开启, 已发送测试提醒');
    } else {
      showToast(context, '未获得通知权限, 请到系统设置中允许通知');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final status = _checking
        ? '检测中…'
        : (_enabled == true ? '已开启, 提醒可正常送达' : '未授权, 可能收不到提醒');
    final action = _checking
        ? null
        : (_enabled == true ? '发送测试' : '去开启');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.notifications_none, size: 18, color: theme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('通知权限',
                    style: TextStyle(fontSize: 13, color: theme.foreground)),
                const SizedBox(height: 2),
                Text(status,
                    style: TextStyle(
                        fontSize: 10,
                        color: _enabled == false
                            ? const Color(0xFFFF5252)
                            : theme.muted)),
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: _onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget child;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Column(
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: theme.foreground)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.primary)),
          ],
        ),
        child,
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, color: theme.foreground)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 10, color: theme.muted)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              activeColor: theme.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final String timeLabel;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTimeTap;

  const _ReminderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.timeLabel,
    required this.onChanged,
    required this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 13, color: theme.foreground)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(subtitle,
                          style:
                              TextStyle(fontSize: 10, color: theme.muted)),
                    ),
                    if (value)
                      GestureDetector(
                        onTap: onTimeTap,
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(timeLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primary)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              activeColor: theme.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
