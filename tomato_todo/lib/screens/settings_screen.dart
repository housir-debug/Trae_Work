// screens/settings_screen.dart - 设置 & 主题自由定制
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../theme/backgrounds.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              '设置 & 主题',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.foreground,
              ),
            ),
          ),
          // ==== 主题选择 ====
          _SectionHeader(title: '🎨 主题', theme: theme),
          _ThemePicker(),
          const SizedBox(height: 16),

          // ==== 背景图 ====
          _SectionHeader(title: '🖼 背景图(任意可用)', theme: theme),
          _BackgroundPicker(),
          const SizedBox(height: 16),

          // ==== 计时时长 ====
          _SectionHeader(title: '⏱ 计时时长', theme: theme),
          _DurationSliders(),
          const SizedBox(height: 16),

          // ==== 番茄设置 ====
          _SectionHeader(title: '🍅 番茄规则', theme: theme),
          _LongBreakInterval(),
          const SizedBox(height: 16),

          // ==== 提醒 ====
          _SectionHeader(title: '🔔 提醒方式', theme: theme),
          _ReminderToggles(),
          const SizedBox(height: 16),

          // ==== 声音 ====
          _SectionHeader(title: '🔊 提示音', theme: theme),
          _SoundPicker(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeDef theme;
  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.foreground.withOpacity(0.7))),
    );
  }
}

// ------- 主题选择器 -------
class _ThemePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kBuiltinThemes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (ctx, idx) {
              final t = kBuiltinThemes[idx];
              final selected = sp.settings.themeIndex == idx;
              return GestureDetector(
                onTap: () => sp.setTheme(idx),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [t.primary, t.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: selected
                            ? Border.all(color: theme.foreground, width: 3)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 22)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: theme.foreground),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ------- 背景图选择 -------
class _BackgroundPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预设渐变
          const Text('预设渐变(全部免费)',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kGradientBackgrounds.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (ctx, idx) {
              final colors = kGradientBackgrounds[idx];
              final key = 'grad_$idx';
              final selected = sp.settings.customBackgroundPath == key ||
                  (sp.settings.customBackgroundPath == null &&
                      sp.settings.themeIndex == idx);
              return GestureDetector(
                onTap: () {
                  // 选中渐变背景,清空 customBackgroundPath 会使 UI 用主题色
                  // 这里用特殊 key 让 UI 识别为渐变
                  sp.setCustomBackground(key);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: selected
                        ? Border.all(color: theme.foreground, width: 3)
                        : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // 自定义图片
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      sp.setCustomBackground(picked.path);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(color: theme.primary),
                    foregroundColor: theme.primary,
                  ),
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('从相册选图'),
                ),
              ),
              const SizedBox(width: 10),
              // 清除自定义
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    sp.setCustomBackground(null);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(color: theme.foreground.withOpacity(0.3)),
                    foregroundColor: theme.foreground.withOpacity(0.7),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('清除自定义'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 透明度
          Row(
            children: [
              Text('遮罩透明度',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.foreground.withOpacity(0.7))),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: sp.settings.backgroundOpacity,
                  min: 0,
                  max: 1,
                  onChanged: sp.setBackgroundOpacity,
                  activeColor: theme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text('${(sp.settings.backgroundOpacity * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.foreground.withOpacity(0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

// ------- 时长滑块 -------
class _DurationSliders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;
    final s = sp.settings;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _sliderRow(
            label: '专注时长',
            value: s.workDuration.toDouble(),
            min: 5,
            max: 90,
            step: 5,
            unit: '分钟',
            theme: theme,
            onChanged: (v) => sp.updateDuration(work: v.toInt()),
          ),
          _sliderRow(
            label: '短休息',
            value: s.shortBreakDuration.toDouble(),
            min: 1,
            max: 20,
            step: 1,
            unit: '分钟',
            theme: theme,
            onChanged: (v) => sp.updateDuration(shortBreak: v.toInt()),
          ),
          _sliderRow(
            label: '长休息',
            value: s.longBreakDuration.toDouble(),
            min: 5,
            max: 45,
            step: 5,
            unit: '分钟',
            theme: theme,
            onChanged: (v) => sp.updateDuration(longBreak: v.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required String unit,
    required ThemeDef theme,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: theme.foreground.withOpacity(0.8))),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              onChanged: onChanged,
              activeColor: theme.primary,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text('${value.toInt()} $unit',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.foreground)),
          ),
        ],
      ),
    );
  }
}

// ------- 长休息间隔 -------
class _LongBreakInterval extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('长休息间隔',
                style: TextStyle(color: theme.foreground)),
          ),
          Text('每 ${sp.settings.longBreakInterval} 个番茄后',
              style: TextStyle(
                  color: theme.foreground.withOpacity(0.7), fontSize: 13)),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: sp.settings.longBreakInterval,
              isDense: true,
              items: [2, 3, 4, 5, 6, 8]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
              onChanged: (v) {
                if (v != null) sp.updateDuration(longBreakInterval: v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------- 提醒开关 -------
class _ReminderToggles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;
    final s = sp.settings;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _toggleRow(
            label: '自动开始下一个番茄',
            value: s.autoStartNext,
            onChanged: (_) => sp.toggleAutoStart(),
            theme: theme,
          ),
          const Divider(height: 1),
          _toggleRow(
            label: '完成时显示系统通知',
            value: s.showNotification,
            onChanged: (_) => sp.toggleNotification(),
            theme: theme,
          ),
          const Divider(height: 1),
          _toggleRow(
            label: '完成时震动',
            value: s.enableVibrate,
            onChanged: (_) => sp.toggleVibrate(),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeDef theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: theme.foreground, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.primary,
          ),
        ],
      ),
    );
  }
}

// ------- 声音选择 -------
class _SoundPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;

    final tickSounds = ['tick', 'clock', 'none'];
    final completeSounds = ['bell', 'chime', 'ding', 'none'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _soundChipRow(
            label: '滴答声',
            sounds: tickSounds,
            current: sp.settings.tickSound,
            onSelect: (v) async {
              await sp.update(sp.settings.copyWith(tickSound: v));
            },
            theme: theme,
          ),
          const SizedBox(height: 12),
          _soundChipRow(
            label: '完成提示',
            sounds: completeSounds,
            current: sp.settings.completeSound,
            onSelect: (v) async {
              await sp.update(sp.settings.copyWith(completeSound: v));
            },
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _soundChipRow({
    required String label,
    required List<String> sounds,
    required String current,
    required ValueChanged<String> onSelect,
    required ThemeDef theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: theme.foreground.withOpacity(0.7))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sounds.map((s) {
            final selected = current == s;
            return GestureDetector(
              onTap: () => onSelect(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? theme.primary : theme.foreground.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  s == 'none' ? '静音' : s,
                  style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : theme.foreground.withOpacity(0.8)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
