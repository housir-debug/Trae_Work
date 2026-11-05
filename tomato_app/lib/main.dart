// main.dart - 入口 & MaterialApp & 背景 & 底部导航
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_settings.dart';
import 'models/task.dart';
import 'models/pomodoro_record.dart';
import 'providers/pomodoro_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/task_provider.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'services/storage_service.dart';
import 'services/timer_service.dart';
import 'theme/backgrounds.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 强制竖屏(手机应用体验)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // 初始化本地存储
  await StorageService.instance.init();

  runApp(const TomatoTodoApp());
}

class TomatoTodoApp extends StatefulWidget {
  const TomatoTodoApp({super.key});

  @override
  State<TomatoTodoApp> createState() => _TomatoTodoAppState();
}

class _TomatoTodoAppState extends State<TomatoTodoApp> {
  late final SettingsProvider _settingsProv;
  late final TaskProvider _taskProv;
  late final PomodoroProvider _pomoProv;

  @override
  void initState() {
    super.initState();
    _settingsProv = SettingsProvider(StorageService.instance)..load();
    _taskProv = TaskProvider(StorageService.instance)..load();
    _pomoProv = PomodoroProvider(StorageService.instance)
      ..init(_settingsProv.settings);
    // 当设置变化时,更新番茄钟配置
    _settingsProv.addListener(() {
      _pomoProv.updateSettings(_settingsProv.settings);
    });
  }

  @override
  void dispose() {
    _settingsProv.dispose();
    _taskProv.dispose();
    _pomoProv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsProv),
        ChangeNotifierProvider.value(value: _taskProv),
        ChangeNotifierProvider.value(value: _pomoProv),
      ],
      child: Consumer<SettingsProvider>(
        builder: (ctx, sp, _) {
          final theme = sp.currentTheme;
          final isDark = theme.background.computeLuminance() < 0.5;

          return MaterialApp(
            title: '番茄Todo',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: theme.toColorScheme(
                isDark ? Brightness.dark : Brightness.light,
              ),
              scaffoldBackgroundColor: Colors.transparent,
              fontFamily: 'PingFang SC',
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                foregroundColor: theme.foreground,
                elevation: 0,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.transparent,
                selectedItemColor: theme.primary,
                unselectedItemColor:
                    theme.foreground.withOpacity(0.4),
                elevation: 0,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            home: const RootPage(),
          );
        },
      ),
    );
  }
}

// ============ 根页面:背景 + 导航 ============
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _idx = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = sp.currentTheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景
          AppBackground(settings: sp.settings, theme: theme),
          // 页面
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _idx,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _idx,
        onTap: (i) => setState(() => _idx = i),
        theme: theme,
      ),
    );
  }
}

// ============ 背景实现 ============
class AppBackground extends StatelessWidget {
  final AppSettings settings;
  final ThemeDef theme;
  const AppBackground({super.key, required this.settings, required this.theme});

  @override
  Widget build(BuildContext context) {
    final path = settings.customBackgroundPath;

    Widget base;

    if (path != null && path.startsWith('grad_')) {
      // 预设渐变
      final idx = int.tryParse(path.substring(5)) ?? 0;
      final colors = kGradientBackgrounds[
          idx.clamp(0, kGradientBackgrounds.length - 1)];
      base = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    } else if (path != null && path.isNotEmpty) {
      // 自定义图片
      base = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _themeGradient(),
      );
    } else {
      // 主题默认渐变
      base = _themeGradient();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        // 遮罩层(用户可控透明度)
        Container(
          color: Colors.black.withOpacity(
            settings.backgroundOpacity.clamp(0.0, 0.85),
          ),
        ),
      ],
    );
  }

  Widget _themeGradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.background, theme.primary.withOpacity(0.3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

// ============ 底部导航 ============
class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final ThemeDef theme;

  const _BottomBar({
    required this.index,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _BNItem(Icons.timer, '专注'),
      _BNItem(Icons.bar_chart, '统计'),
      _BNItem(Icons.settings, '设置'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              for (int i = 0; i < items.length; ++i)
                Expanded(
                  child: _BottomButton(
                    icon: items[i].icon,
                    label: items[i].label,
                    active: i == index,
                    onTap: () => onTap(i),
                    theme: theme,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BNItem {
  final IconData icon;
  final String label;
  const _BNItem(this.icon, this.label);
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ThemeDef theme;

  const _BottomButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: active
              ? theme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: active ? theme.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: active ? Colors.white : theme.foreground.withOpacity(0.5),
                  size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active
                    ? theme.primary
                    : theme.foreground.withOpacity(0.5),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
