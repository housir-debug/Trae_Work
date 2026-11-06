// theme/backgrounds.dart - 内置主题 & 预设背景
import 'package:flutter/material.dart';

class ThemeDef {
  final String name;
  final Color primary;
  final Color accent;
  final Color background;
  final Color cardBackground;
  final Color foreground;

  const ThemeDef({
    required this.name,
    required this.primary,
    required this.accent,
    required this.background,
    required this.cardBackground,
    required this.foreground,
  });

  ColorScheme toColorScheme(Brightness brightness) => ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: accent,
      );

  bool get isDark => background.computeLuminance() < 0.5;

  Color get muted => foreground.withOpacity(isDark ? 0.55 : 0.45);

  Color get card => cardBackground.withOpacity(isDark ? 0.92 : 0.88);
}

/// 全部内置主题 - 自由切换,无付费墙
const List<ThemeDef> kBuiltinThemes = [
  ThemeDef(
    name: '番茄经典',
    primary: Color(0xFFFF6B6B),
    accent: Color(0xFFFF8E53),
    background: Color(0xFFFFF5F5),
    cardBackground: Color(0xFFFFFFFF),
    foreground: Color(0xFF2D2D2D),
  ),
  ThemeDef(
    name: '薄荷清新',
    primary: Color(0xFF6BCB9D),
    accent: Color(0xFFA7E5BE),
    background: Color(0xFFF0FFF5),
    cardBackground: Color(0xFFFFFFFF),
    foreground: Color(0xFF1F3A2C),
  ),
  ThemeDef(
    name: '深海蓝调',
    primary: Color(0xFF4A90E2),
    accent: Color(0xFF6AB0FF),
    background: Color(0xFFF0F7FF),
    cardBackground: Color(0xFFFFFFFF),
    foreground: Color(0xFF1A2F4F),
  ),
  ThemeDef(
    name: '晨曦橙光',
    primary: Color(0xFFFFA726),
    accent: Color(0xFFFFCC80),
    background: Color(0xFFFFFBF2),
    cardBackground: Color(0xFFFFFFFF),
    foreground: Color(0xFF3D2B00),
  ),
  ThemeDef(
    name: '薰衣草紫',
    primary: Color(0xFF9575CD),
    accent: Color(0xFFB39DDB),
    background: Color(0xFFF8F5FF),
    cardBackground: Color(0xFFFFFFFF),
    foreground: Color(0xFF2A1F4F),
  ),
  ThemeDef(
    name: '暗夜模式',
    primary: Color(0xFF81D4FA),
    accent: Color(0xFF4FC3F7),
    background: Color(0xFF121212),
    cardBackground: Color(0xFF1E1E1E),
    foreground: Color(0xFFE0E0E0),
  ),
  ThemeDef(
    name: '赛博朋克',
    primary: Color(0xFFFF00FF),
    accent: Color(0xFF00FFFF),
    background: Color(0xFF0A0A1A),
    cardBackground: Color(0xFF151530),
    foreground: Color(0xFFE0FFFF),
  ),
  ThemeDef(
    name: '水墨国风',
    primary: Color(0xFF5D6D7E),
    accent: Color(0xFF85929E),
    background: Color(0xFFFAFAF5),
    cardBackground: Color(0xFFFFFFFF),
    foreground: Color(0xFF2C2C2C),
  ),
];

/// 预设渐变背景(不需要图片资源即可生效)
const List<List<Color>> kGradientBackgrounds = [
  [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  [Color(0xFF6BCB9D), Color(0xFF4ECDC4)],
  [Color(0xFF4A90E2), Color(0xFF90CAF9)],
  [Color(0xFFFFA726), Color(0xFFFF7043)],
  [Color(0xFF9575CD), Color(0xFFD1C4E9)],
  [Color(0xFF81D4FA), Color(0xFF263238)],
  [Color(0xFFFF00FF), Color(0xFF00FFFF)],
  [Color(0xFF5D6D7E), Color(0xFF2C3E50)],
  [Color(0xFFF093FB), Color(0xFFF5576C)],
  [Color(0xFF4FACFE), Color(0xFF00F2FE)],
  [Color(0xFF43E97B), Color(0xFF38F9D7)],
  [Color(0xFFFA709A), Color(0xFFFEE140)],
];
