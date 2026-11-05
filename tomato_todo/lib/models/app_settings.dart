// models/app_settings.dart - 应用设置模型
class AppSettings {
  // 时长配置(分钟)
  int workDuration;
  int shortBreakDuration;
  int longBreakDuration;
  int longBreakInterval; // 每几个番茄后长休息

  // 界面
  bool autoStartNext; // 完成后自动开始下一个
  bool showNotification;
  bool enableVibrate;

  // 声音
  String tickSound; // 滴答声(占位)
  String completeSound; // 完成提示音

  // 主题
  int themeIndex; // 内置主题索引
  String? customBackgroundPath; // 自定义背景图路径(null 用主题色)
  double backgroundOpacity; // 背景遮罩透明度 0-1

  AppSettings({
    this.workDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 15,
    this.longBreakInterval = 4,
    this.autoStartNext = false,
    this.showNotification = true,
    this.enableVibrate = true,
    this.tickSound = 'tick',
    this.completeSound = 'bell',
    this.themeIndex = 0,
    this.customBackgroundPath,
    this.backgroundOpacity = 0.55,
  });

  AppSettings copyWith({
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    int? longBreakInterval,
    bool? autoStartNext,
    bool? showNotification,
    bool? enableVibrate,
    String? tickSound,
    String? completeSound,
    int? themeIndex,
    String? customBackgroundPath,
    double? backgroundOpacity,
  }) {
    return AppSettings(
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      autoStartNext: autoStartNext ?? this.autoStartNext,
      showNotification: showNotification ?? this.showNotification,
      enableVibrate: enableVibrate ?? this.enableVibrate,
      tickSound: tickSound ?? this.tickSound,
      completeSound: completeSound ?? this.completeSound,
      themeIndex: themeIndex ?? this.themeIndex,
      customBackgroundPath: customBackgroundPath ?? this.customBackgroundPath,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'workDuration': workDuration,
        'shortBreakDuration': shortBreakDuration,
        'longBreakDuration': longBreakDuration,
        'longBreakInterval': longBreakInterval,
        'autoStartNext': autoStartNext,
        'showNotification': showNotification,
        'enableVibrate': enableVibrate,
        'tickSound': tickSound,
        'completeSound': completeSound,
        'themeIndex': themeIndex,
        'customBackgroundPath': customBackgroundPath,
        'backgroundOpacity': backgroundOpacity,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        workDuration: json['workDuration'] as int? ?? 25,
        shortBreakDuration: json['shortBreakDuration'] as int? ?? 5,
        longBreakDuration: json['longBreakDuration'] as int? ?? 15,
        longBreakInterval: json['longBreakInterval'] as int? ?? 4,
        autoStartNext: json['autoStartNext'] as bool? ?? false,
        showNotification: json['showNotification'] as bool? ?? true,
        enableVibrate: json['enableVibrate'] as bool? ?? true,
        tickSound: json['tickSound'] as String? ?? 'tick',
        completeSound: json['completeSound'] as String? ?? 'bell',
        themeIndex: json['themeIndex'] as int? ?? 0,
        customBackgroundPath: json['customBackgroundPath'] as String?,
        backgroundOpacity: (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.55,
      );
}
