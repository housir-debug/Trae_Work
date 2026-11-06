// providers/settings_provider.dart - 设置 & 主题全局状态
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/security.dart';
import '../services/storage_service.dart';
import '../theme/backgrounds.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  AppSettings _settings = AppSettings();

  SettingsProvider(this._storage);

  AppSettings get settings => _settings;

  ThemeDef get currentTheme {
    final idx =
        _settings.themeIndex.clamp(0, kBuiltinThemes.length - 1).toInt();
    return kBuiltinThemes[idx];
  }

  bool get isDark => _settings.customBackgroundPath != null
      ? false
      : currentTheme.background.computeLuminance() < 0.5;

  void load() {
    _settings = _storage.loadSettings();
    notifyListeners();
  }

  Future<void> update(AppSettings newSettings) async {
    _settings = newSettings;
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setTheme(int index) async {
    await update(_settings.copyWith(themeIndex: index));
  }

  Future<void> setBackgroundOpacity(double v) async {
    await update(_settings.copyWith(backgroundOpacity: v));
  }

  Future<void> setCustomBackground(String? path) async {
    await update(_settings.copyWith(
      customBackgroundPath: path,
      clearBackground: path == null,
    ));
  }

  Future<void> updateDuration({
    int? work,
    int? shortBreak,
    int? longBreak,
    int? longBreakInterval,
  }) async {
    await update(_settings.copyWith(
      workDuration: work,
      shortBreakDuration: shortBreak,
      longBreakDuration: longBreak,
      longBreakInterval: longBreakInterval,
    ));
  }

  Future<void> setDailyGoals({int? focus, int? tasks}) async {
    await update(_settings.copyWith(
      dailyFocusGoal: focus,
      dailyTaskGoal: tasks,
    ));
  }

  Future<void> toggleAutoStart() async {
    await update(_settings.copyWith(autoStartNext: !_settings.autoStartNext));
  }

  Future<void> toggleNotification() async {
    await update(
        _settings.copyWith(showNotification: !_settings.showNotification));
  }

  Future<void> toggleVibrate() async {
    await update(_settings.copyWith(enableVibrate: !_settings.enableVibrate));
  }

  // ---------- 应用锁 ----------
  Future<void> enableAppLock(String pin) async {
    final salt = generateSalt();
    await update(_settings.copyWith(
      appLockEnabled: true,
      pinSalt: salt,
      pinHash: hashPin(pin, salt),
    ));
  }

  Future<void> disableAppLock() async {
    await update(_settings.copyWith(
      appLockEnabled: false,
      clearPin: true,
    ));
  }

  bool verifyPin(String pin) {
    final salt = _settings.pinSalt;
    final hash = _settings.pinHash;
    if (salt == null || hash == null) return false;
    return hashPin(pin, salt) == hash;
  }
}
