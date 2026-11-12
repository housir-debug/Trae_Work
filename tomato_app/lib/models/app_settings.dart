// models/app_settings.dart - 应用设置模型
class AppSettings {
  // 时长配置(分钟)
  int workDuration;
  int shortBreakDuration;
  int longBreakDuration;

  // 行为
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

  // 安全
  bool appLockEnabled;
  String? pinHash;
  String? pinSalt;

  /// 回前台后多久重新上锁(秒), 0 表示立即
  int relockDelaySeconds;

  // 提醒
  bool remindersEnabled; // 总开关
  int defaultEventReminder; // 日程默认提前分钟
  bool dailyPlanReminderEnabled;
  int dailyPlanReminderMinute; // 分钟数, 510 = 08:30
  bool dailyReviewReminderEnabled;
  int dailyReviewReminderMinute; // 1290 = 21:30

  AppSettings({
    this.workDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 15,
    this.showNotification = true,
    this.enableVibrate = true,
    this.tickSound = 'tick',
    this.completeSound = 'bell',
    this.themeIndex = 0,
    this.customBackgroundPath,
    this.backgroundOpacity = 0.55,
    this.dailyFocusGoal = 120,
    this.appLockEnabled = false,
    this.pinHash,
    this.pinSalt,
    this.relockDelaySeconds = 30,
    this.remindersEnabled = true,
    this.defaultEventReminder = 10,
    this.dailyPlanReminderEnabled = true,
    this.dailyPlanReminderMinute = 510,
    this.dailyReviewReminderEnabled = false,
    this.dailyReviewReminderMinute = 1290,
  });

  AppSettings copyWith({
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    bool? showNotification,
    bool? enableVibrate,
    String? tickSound,
    String? completeSound,
    int? themeIndex,
    String? customBackgroundPath,
    bool clearBackground = false,
    double? backgroundOpacity,
    int? dailyFocusGoal,
    bool? appLockEnabled,
    String? pinHash,
    String? pinSalt,
    bool clearPin = false,
    int? relockDelaySeconds,
    bool? remindersEnabled,
    int? defaultEventReminder,
    bool? dailyPlanReminderEnabled,
    int? dailyPlanReminderMinute,
    bool? dailyReviewReminderEnabled,
    int? dailyReviewReminderMinute,
  }) {
    return AppSettings(
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
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
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      pinSalt: clearPin ? null : (pinSalt ?? this.pinSalt),
      relockDelaySeconds: relockDelaySeconds ?? this.relockDelaySeconds,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      defaultEventReminder:
          defaultEventReminder ?? this.defaultEventReminder,
      dailyPlanReminderEnabled:
          dailyPlanReminderEnabled ?? this.dailyPlanReminderEnabled,
      dailyPlanReminderMinute:
          dailyPlanReminderMinute ?? this.dailyPlanReminderMinute,
      dailyReviewReminderEnabled:
          dailyReviewReminderEnabled ?? this.dailyReviewReminderEnabled,
      dailyReviewReminderMinute:
          dailyReviewReminderMinute ?? this.dailyReviewReminderMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'workDuration': workDuration,
        'shortBreakDuration': shortBreakDuration,
        'longBreakDuration': longBreakDuration,
        'showNotification': showNotification,
        'enableVibrate': enableVibrate,
        'tickSound': tickSound,
        'completeSound': completeSound,
        'themeIndex': themeIndex,
        'customBackgroundPath': customBackgroundPath,
        'backgroundOpacity': backgroundOpacity,
        'dailyFocusGoal': dailyFocusGoal,
        'appLockEnabled': appLockEnabled,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'relockDelaySeconds': relockDelaySeconds,
        'remindersEnabled': remindersEnabled,
        'defaultEventReminder': defaultEventReminder,
        'dailyPlanReminderEnabled': dailyPlanReminderEnabled,
        'dailyPlanReminderMinute': dailyPlanReminderMinute,
        'dailyReviewReminderEnabled': dailyReviewReminderEnabled,
        'dailyReviewReminderMinute': dailyReviewReminderMinute,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        workDuration: json['workDuration'] as int? ?? 25,
        shortBreakDuration: json['shortBreakDuration'] as int? ?? 5,
        longBreakDuration: json['longBreakDuration'] as int? ?? 15,
        showNotification: json['showNotification'] as bool? ?? true,
        enableVibrate: json['enableVibrate'] as bool? ?? true,
        tickSound: json['tickSound'] as String? ?? 'tick',
        completeSound: json['completeSound'] as String? ?? 'bell',
        themeIndex: json['themeIndex'] as int? ?? 0,
        customBackgroundPath: json['customBackgroundPath'] as String?,
        backgroundOpacity:
            (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.55,
        dailyFocusGoal: json['dailyFocusGoal'] as int? ?? 120,
        appLockEnabled: json['appLockEnabled'] as bool? ?? false,
        pinHash: json['pinHash'] as String?,
        pinSalt: json['pinSalt'] as String?,
        relockDelaySeconds: json['relockDelaySeconds'] as int? ?? 30,
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
        defaultEventReminder: json['defaultEventReminder'] as int? ?? 10,
        dailyPlanReminderEnabled:
            json['dailyPlanReminderEnabled'] as bool? ?? true,
        dailyPlanReminderMinute:
            json['dailyPlanReminderMinute'] as int? ?? 510,
        dailyReviewReminderEnabled:
            json['dailyReviewReminderEnabled'] as bool? ?? false,
        dailyReviewReminderMinute:
            json['dailyReviewReminderMinute'] as int? ?? 1290,
      );
}
