// models/app_settings.dart - 应用设置模型
class AppSettings {
  // 时长配置(分钟)
  int workDuration;
  int shortBreakDuration;
  int longBreakDuration;
  int longBreakInterval; // 每几个番茄后长休息

  // 行为
  bool autoStartNext; // 完成后自动开始下一个
  bool showNotification;
  bool enableVibrate;

  // 声音
  String tickSound;
  String completeSound;

  // 主题
  int themeIndex;
  String? customBackgroundPath; // grad_xx 或本地图片路径
  double backgroundOpacity;

  // 目标
  int dailyFocusGoal; // 每日专注目标(分钟)
  int dailyTaskGoal; // 每日完成任务目标(个)

  // 安全
  bool appLockEnabled;
  String? pinHash;
  String? pinSalt;

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
    this.dailyFocusGoal = 120,
    this.dailyTaskGoal = 5,
    this.appLockEnabled = false,
    this.pinHash,
    this.pinSalt,
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
    bool clearBackground = false,
    double? backgroundOpacity,
    int? dailyFocusGoal,
    int? dailyTaskGoal,
    bool? appLockEnabled,
    String? pinHash,
    String? pinSalt,
    bool clearPin = false,
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
      customBackgroundPath: clearBackground
          ? null
          : (customBackgroundPath ?? this.customBackgroundPath),
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      dailyFocusGoal: dailyFocusGoal ?? this.dailyFocusGoal,
      dailyTaskGoal: dailyTaskGoal ?? this.dailyTaskGoal,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      pinSalt: clearPin ? null : (pinSalt ?? this.pinSalt),
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
        'dailyFocusGoal': dailyFocusGoal,
        'dailyTaskGoal': dailyTaskGoal,
        'appLockEnabled': appLockEnabled,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
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
        backgroundOpacity:
            (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.55,
        dailyFocusGoal: json['dailyFocusGoal'] as int? ?? 120,
        dailyTaskGoal: json['dailyTaskGoal'] as int? ?? 5,
        appLockEnabled: json['appLockEnabled'] as bool? ?? false,
        pinHash: json['pinHash'] as String?,
        pinSalt: json['pinSalt'] as String?,
      );
}
