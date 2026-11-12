// core/utils.dart - 通用日期/文本工具
import 'package:intl/intl.dart';

/// 统一的日期键: yyyy-MM-dd
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime startOfWeek(DateTime d) =>
    startOfDay(d.subtract(Duration(days: d.weekday - 1)));

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const List<String> kWeekdayCN = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayShort(DateTime d) => ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];

String weekdayFull(DateTime d) => kWeekdayCN[d.weekday - 1];

/// 友好日期: 今天 / 明天 / 昨天 / 月日
String friendlyDate(DateTime d) {
  final today = startOfDay(DateTime.now());
  final target = startOfDay(d);
  final diff = target.difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  if (diff == 2) return '后天';
  return '${d.month}月${d.day}日';
}

String shortDate(DateTime d) => DateFormat('M月d日').format(d);

/// 分钟数 -> HH:mm (1440 显示为 24:00)
String timeText(int minutes) {
  if (minutes >= 24 * 60) return '24:00';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// HH:mm -> 分钟数, 解析失败返回 null; 24:00 视为 1440
int? parseTimeText(String text) {
  final parts = text.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 24 || m < 0 || m > 59) return null;
  if (h == 24 && m != 0) return null;
  return h * 60 + m;
}

/// 分钟数 -> 时长描述
String durationText(int minutes) {
  if (minutes < 60) return '$minutes 分钟';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h 小时' : '$h 小时 $m 分';
}

/// 稳定的字符串哈希(用于通知 ID), 返回非负整数
int fnvHash(String input) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < input.length; ++i) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// 某年某月的天数
int daysInMonth(int year, int month) =>
    DateTime(year, month + 1, 0).day;

/// ISO 周序号(用于按月统计的横坐标, 如「54周」)
int isoWeekNumber(DateTime date) {
  final day = startOfDay(date);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final jan1 = DateTime(thursday.year, 1, 1);
  return (thursday.difference(jan1).inDays / 7).floor() + 1;
}

String greetingByHour() {
  final h = DateTime.now().hour;
  if (h < 6) return '夜深了';
  if (h < 9) return '早安';
  if (h < 12) return '上午好';
  if (h < 14) return '午安';
  if (h < 18) return '下午好';
  if (h < 23) return '晚上好';
  return '夜深了';
}
