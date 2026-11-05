// providers/settings_provider.dart - 设置 & 主题全局状态
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../theme/backgrounds.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  AppSettings _settings = AppSettings();

  SettingsProvider(this._storage);

  AppSettings get settings => _settings;
  ThemeDef get currentTheme {
    final idx = _settings.themeIndex.clamp(0, kBuiltinThemes.length - 1);
    return kBuiltinThemes[idx];
  }

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
    await update(_settings.copyWith(customBackgroundPath: path));
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

  Future<void> toggleAutoStart() async {
    await update(_settings.copyWith(autoStartNext: !_settings.autoStartNext));
  }

  Future<void> toggleNotification() async {
    await update(_settings.copyWith(showNotification: !_settings.showNotification));
  }

  Future<void> toggleVibrate() async {
    await update(_settings.copyWith(enableVibrate: !_settings.enableVibrate));
  }
}
