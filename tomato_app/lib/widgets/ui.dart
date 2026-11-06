// widgets/ui.dart - 统一的卡片 / 标题 / 弹层等基础组件
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';

ThemeDef appTheme(BuildContext context) =>
    context.watch<SettingsProvider>().currentTheme;

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: theme.isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: theme.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
    final wrapped = onTap == null
        ? content
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: content,
          );
    return Padding(padding: margin, child: wrapped);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.margin = const EdgeInsets.fromLTRB(20, 22, 20, 10),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Padding(
      padding: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.foreground,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: theme.muted),
              ),
            ),
          ] else
            const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final EdgeInsetsGeometry padding;

  const EmptyHint({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.text,
    this.padding = const EdgeInsets.symmetric(vertical: 22),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Padding(
      padding: padding,
      child: Column(
        children: [
          Icon(icon, size: 34, color: theme.muted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.muted),
          ),
        ],
      ),
    );
  }
}

class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  const PillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final c = color ?? theme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c : c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : c.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? Colors.white : c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TinyBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const TinyBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用底部弹层, 自适应键盘高度
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
  bool singleChildScroll = true,
}) {
  final theme = context.read<SettingsProvider>().currentTheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: theme.foreground.withOpacity(0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: singleChildScroll ? SingleChildScrollView(child: child) : child,
          ),
        ],
      );
      return Container(
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: content,
          ),
        ),
      );
    },
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String content = '',
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final theme = context.read<SettingsProvider>().currentTheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: TextStyle(color: theme.foreground, fontSize: 17)),
      content: content.isEmpty
          ? null
          : Text(content,
              style: TextStyle(color: theme.foreground.withOpacity(0.7), fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText, style: TextStyle(color: theme.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmText,
            style: TextStyle(
              color: danger ? const Color(0xFFFF5252) : theme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xEE2D2D2D),
    ));
}

/// 带撤销操作的提示
void showUndoToast(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xEE2D2D2D),
      action: SnackBarAction(
        label: '撤销',
        textColor: const Color(0xFF9BB8FF),
        onPressed: onUndo,
      ),
    ));
}

InputDecoration appInput({
  required BuildContext context,
  String? hint,
  String? label,
  Widget? suffix,
  Widget? prefix,
  bool dense = false,
}) {
  final theme = context.watch<SettingsProvider>().currentTheme;
  return InputDecoration(
    hintText: hint,
    labelText: label,
    hintStyle: TextStyle(color: theme.muted, fontSize: 13),
    labelStyle: TextStyle(color: theme.muted, fontSize: 13),
    prefixIcon: prefix,
    suffixIcon: suffix,
    isDense: dense,
    contentPadding:
        EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 12 : 14),
    filled: true,
    fillColor: theme.primary.withOpacity(0.06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.primary.withOpacity(0.4)),
    ),
  );
}
