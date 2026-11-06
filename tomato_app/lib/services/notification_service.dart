// services/notification_service.dart - 本地提醒(日程 / 每日 / 番茄钟)
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils.dart';
import '../models/app_settings.dart';
import '../models/schedule_event.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelReminders = 'reminders';
  static const String channelPomodoro = 'pomodoro';
  static const String channelDaily = 'daily';

  static const int _timerId = 300001;
  static const int _dailyPlanId = 200001;
  static const int _dailyReviewId = 200002;
  static const int _eventIdBase = 100000;

  static const String _kScheduledIds = 'scheduled_reminder_ids';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 时区获取失败时退回 UTC, 仅影响提醒的精确度
    }

    const android = AndroidInitializationSettings('ic_notification');
    const settings = InitializationSettings(android: android);
    try {
      await _plugin.initialize(settings);
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
        channelReminders,
        '日程提醒',
        description: '行程开始前的本地提醒',
        importance: Importance.high,
      ));
      await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
        channelPomodoro,
        '番茄钟',
        description: '专注与休息阶段结束提醒',
        importance: Importance.high,
      ));
      await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
        channelDaily,
        '每日提醒',
        description: '每日计划与复盘提醒',
        importance: Importance.defaultImportance,
      ));
      await androidImpl?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('通知初始化失败: $e');
    }
  }

  NotificationDetails _details(String channelId, {bool playSound = true}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == channelPomodoro
              ? '番茄钟'
              : channelId == channelDaily
                  ? '每日提醒'
                  : '日程提醒',
          icon: 'ic_notification',
          importance: Importance.high,
          priority: Priority.high,
          playSound: playSound,
          enableVibration: true,
        ),
      );

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String channelId,
    String? payload,
    bool repeatDaily = false,
    bool playSound = true,
  }) async {
    if (!_ready) return;
    final scheduled = tz.TZDateTime.from(at, tz.local);
    if (!repeatDaily && scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(channelId, playSound: playSound),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents:
            repeatDaily ? DateTimeComponents.time : null,
      );
    } catch (e) {
      debugPrint('安排通知失败: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kScheduledIds);
    } catch (_) {}
  }

  /// 每日本地时间 minute 的下一次触发时刻(当天已过则顺延到明天)
  DateTime _nextDaily(int minute) {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, minute ~/ 60, minute % 60);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  /// 同步日程提醒(会先取消上一次安排的全部日程提醒)
  Future<void> syncEventReminders(
    List<ScheduleEvent> events,
    AppSettings settings,
  ) async {
    if (!_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getStringList(_kScheduledIds) ?? [];
    for (final raw in previous) {
      final id = int.tryParse(raw);
      if (id != null) await cancel(id);
    }
    await prefs.remove(_kScheduledIds);

    if (!settings.remindersEnabled) return;

    final now = DateTime.now();
    final limit = now.add(const Duration(days: 60));
    final newIds = <String>[];

    for (final e in events) {
      if (e.isDone) continue;
      final reminder = e.reminderMinutes ?? settings.defaultEventReminder;
      if (reminder < 0) continue;
      final start = e.startDateTime;
      if (start.isBefore(now) || start.isAfter(limit)) continue;
      final notifyAt = start.subtract(Duration(minutes: reminder));
      if (notifyAt.isBefore(now)) continue;

      final id = _eventIdBase + fnvHash(e.id) % 90000;
      await _schedule(
        id: id,
        title: '${e.title} · ${timeText(e.startMinute)}',
        body: reminder == 0
            ? '现在开始, 专注当下'
            : '还有 $reminder 分钟开始, 提前准备一下',
        at: notifyAt,
        channelId: channelReminders,
        payload: 'event:${e.id}',
      );
      newIds.add('$id');
    }

    await prefs.setStringList(_kScheduledIds, newIds);
  }

  /// 同步每日计划 / 复盘提醒
  Future<void> syncDailyReminders(AppSettings settings) async {
    if (!_ready) return;
    await cancel(_dailyPlanId);
    await cancel(_dailyReviewId);
    if (!settings.remindersEnabled) return;

    if (settings.dailyPlanReminderEnabled) {
      await _schedule(
        id: _dailyPlanId,
        title: '今天想做点什么?',
        body: '花一分钟看看今天的待办与行程, 给今天定个重点',
        at: _nextDaily(settings.dailyPlanReminderMinute),
        channelId: channelDaily,
        repeatDaily: true,
        playSound: false,
      );
    }
    if (settings.dailyReviewReminderEnabled) {
      await _schedule(
        id: _dailyReviewId,
        title: '给今天一个收尾',
        body: '记录心情与收获, 让成长被看见',
        at: _nextDaily(settings.dailyReviewReminderMinute),
        channelId: channelDaily,
        repeatDaily: true,
        playSound: false,
      );
    }
  }

  /// 阶段结束提醒(与计时器绝对时间对齐)
  Future<void> scheduleTimerEnd({
    required DateTime end,
    required String title,
    required String body,
    bool playSound = true,
  }) async {
    await _schedule(
      id: _timerId,
      title: title,
      body: body,
      at: end,
      channelId: channelPomodoro,
      payload: 'pomodoro',
      playSound: playSound,
    );
  }

  Future<void> cancelTimerEnd() => cancel(_timerId);

  Future<void> cancelDailyReminders() async {
    await cancel(_dailyPlanId);
    await cancel(_dailyReviewId);
  }
}
