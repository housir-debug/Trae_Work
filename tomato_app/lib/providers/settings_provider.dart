// providers/settings_provider.dart - 设置 & 主题全局状态
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/security.dart';
import '../services/storage_service.dart';
import '../theme/backgrounds.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  AppSettings _settings = AppSettings();

  /// 设置写盘防抖: 拖动滑块时避免频繁序列化/落盘
  Timer? _saveTimer;
  AppSettings? _dirty;

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
    _dirty = newSettings;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), flush);
    notifyListeners();
  }

  /// 立即落盘(退出/切后台时调用)
  void flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final pending = _dirty;
    _dirty = null;
    if (pending != null) _storage.saveSettings(pending);
  }

  @override
  void dispose() {
    flush();
    super.dispose();
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
  }) async {
    await update(_settings.copyWith(
      workDuration: work,
      shortBreakDuration: shortBreak,
      longBreakDuration: longBreak,
    ));
  }

  Future<void> setDailyGoals({int? focus}) async {
    await update(_settings.copyWith(dailyFocusGoal: focus));
  }

  Future<void> toggleNotification() async {
    await update(
        _settings.copyWith(showNotification: !_settings.showNotification));
  }

  Future<void> toggleVibrate() async {
    await update(_settings.copyWith(enableVibrate: !_settings.enableVibrate));
  }

  // ---------- 提醒 ----------
  Future<void> setRemindersEnabled(bool v) async {
    await update(_settings.copyWith(remindersEnabled: v));
  }

  Future<void> setDefaultEventReminder(int minutes) async {
    await update(_settings.copyWith(defaultEventReminder: minutes));
  }

  Future<void> setDailyPlanReminder({bool? enabled, int? minute}) async {
    await update(_settings.copyWith(
      dailyPlanReminderEnabled: enabled,
      dailyPlanReminderMinute: minute,
    ));
  }

  Future<void> setDailyReviewReminder({bool? enabled, int? minute}) async {
    await update(_settings.copyWith(
      dailyReviewReminderEnabled: enabled,
      dailyReviewReminderMinute: minute,
    ));
  }

  // ---------- 安全 ----------
  Future<void> setRelockDelay(int seconds) async {
    await update(_settings.copyWith(relockDelaySeconds: seconds));
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
