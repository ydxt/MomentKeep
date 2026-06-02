import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';

/// 习惯日期工具类
/// 用于处理习惯页面的周视图和月视图功能
class HabitDateUtils {
  HabitDateUtils._();

  /// 获取指定日期所在周的日期范围（从周一到周日）
  /// 
  /// [date] 指定日期，默认为当前日期
  /// 返回包含周一和周日的 DateTime 对象
  static DateTimeRange getWeekRange([DateTime? date]) {
    final now = date ?? DateTime.now();
    final localNow = _toLocal(now);
    
    // 计算周一的日期
    final int weekday = localNow.weekday;
    final monday = localNow.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    return DateTimeRange(
      start: _startOfDay(monday),
      end: _endOfDay(sunday),
    );
  }

  /// 获取指定日期的日期范围（当天开始到结束）
  static DateTimeRange getDayRange([DateTime? date]) {
    final now = date ?? DateTime.now();
    final localNow = _toLocal(now);
    return DateTimeRange(
      start: _startOfDay(localNow),
      end: _endOfDay(localNow),
    );
  }

  /// 获取指定日期所在月的日期范围
  /// 
  /// [date] 指定日期，默认为当前日期
  /// 返回包含月初和月末的 DateTime 对象
  static DateTimeRange getMonthRange([DateTime? date]) {
    final now = date ?? DateTime.now();
    final localNow = _toLocal(now);

    final startOfMonth = DateTime(localNow.year, localNow.month, 1);
    final endOfMonth = DateTime(localNow.year, localNow.month + 1, 0);

    return DateTimeRange(
      start: _startOfDay(startOfMonth),
      end: _endOfDay(endOfMonth),
    );
  }

  /// 获取指定日期所在周的所有日期（从周一到周日）
  /// 
  /// [date] 指定日期，默认为当前日期
  /// 返回包含周一到周日的 DateTime 列表
  static List<DateTime> getWeekDays([DateTime? date]) {
    final range = getWeekRange(date);
    final List<DateTime> days = [];

    for (int i = 0; i < 7; i++) {
      days.add(range.start.add(Duration(days: i)));
    }

    return days;
  }

  /// 获取指定日期所在月的所有日期
  /// 
  /// [date] 指定日期，默认为当前日期
  /// 返回包含整个月所有日期的 DateTime 列表
  static List<DateTime> getMonthDays([DateTime? date]) {
    final range = getMonthRange(date);
    final List<DateTime> days = [];

    final daysInMonth = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < daysInMonth; i++) {
      days.add(range.start.add(Duration(days: i)));
    }

    return days;
  }

  /// 检查习惯在特定日期是否已打卡
  /// 
  /// [habit] 习惯对象
  /// [date] 要检查的日期
  /// 返回是否已打卡
  static bool isHabitCheckedOnDate(Habit habit, DateTime date) {
    final localDate = _toLocal(date);
    final dateString = _formatDateString(localDate);
    return habit.history.contains(dateString);
  }

  /// 计算习惯在某个日期范围内的完成次数
  /// 
  /// [habit] 习惯对象
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// 返回完成次数
  static int countCompletionsInRange(
    Habit habit,
    DateTime startDate,
    DateTime endDate,
  ) {
    int count = 0;
    final localStart = _toLocal(startDate);
    final localEnd = _toLocal(endDate);

    for (final dateString in habit.history) {
      try {
        final date = DateTime.parse(dateString);
        if (date.isAfter(localStart.subtract(const Duration(days: 1))) &&
            date.isBefore(localEnd.add(const Duration(days: 1)))) {
          count++;
        }
      } catch (e) {
        // 忽略无效日期格式错误
      }
    }

    return count;
  }

  /// 计算习惯在某个日期范围内的完成次数
  /// 
  /// [habit] 习惯对象
  /// [range] 日期范围
  /// 返回完成次数
  static int countCompletionsInDateTimeRange(
    Habit habit,
    DateTimeRange range,
  ) {
    return countCompletionsInRange(habit, range.start, range.end);
  }

  /// 计算习惯在某个日期范围内的积分汇总
  /// 
  /// [habit] 习惯对象
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// 返回积分汇总（正数表示加分，负数表示扣分）
  static int calculatePointsInRange(
    Habit habit,
    DateTime startDate,
    DateTime endDate,
  ) {
    int totalPoints = 0;
    final localStart = _toLocal(startDate);
    final localEnd = _toLocal(endDate);

    for (final record in habit.checkInRecords) {
      final recordDate = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      final startDay = DateTime(localStart.year, localStart.month, localStart.day);
      final endDay = DateTime(localEnd.year, localEnd.month, localEnd.day);
      if (!recordDate.isBefore(startDay) && !recordDate.isAfter(endDay)) {
        totalPoints += record.score;
      }
    }

    return totalPoints;
  }

  /// 计算习惯在某个日期范围内的积分汇总
  /// 
  /// [habit] 习惯对象
  /// [range] 日期范围
  /// 返回积分汇总（正数表示加分，负数表示扣分）
  static int calculatePointsInDateTimeRange(
    Habit habit,
    DateTimeRange range,
  ) {
    return calculatePointsInRange(habit, range.start, range.end);
  }

  /// 计算多个习惯在某个日期范围内的总积分
  /// 
  /// [habits] 习惯列表
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// 返回总积分
  static int calculateTotalPointsInRange(
    List<Habit> habits,
    DateTime startDate,
    DateTime endDate,
  ) {
    int total = 0;
    for (final habit in habits) {
      total += calculatePointsInRange(habit, startDate, endDate);
    }
    return total;
  }

  /// 格式化日期为中文显示格式
  /// 
  /// [date] 要格式化的日期
  /// [includeYear] 是否包含年份
  /// 返回格式化后的字符串，例如 "2024年5月15日" 或 "5月15日"
  static String formatDateToChinese(DateTime date, {bool includeYear = true}) {
    final localDate = _toLocal(date);
    if (includeYear) {
      return '${localDate.year}年${localDate.month}月${localDate.day}日';
    }
    return '${localDate.month}月${localDate.day}日';
  }

  /// 获取星期的中文名称
  /// 
  /// [weekday] 星期几 (1=周一, 7=周日)
  /// 返回中文名称，例如 "星期一"
  static String getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return '星期一';
      case 2:
        return '星期二';
      case 3:
        return '星期三';
      case 4:
        return '星期四';
      case 5:
        return '星期五';
      case 6:
        return '星期六';
      case 7:
        return '星期日';
      default:
        return '';
    }
  }

  /// 获取星期的短中文名称
  /// 
  /// [weekday] 星期几 (1=周一, 7=周日)
  /// 返回短中文名称，例如 "一"
  static String getShortWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return '一';
      case 2:
        return '二';
      case 3:
        return '三';
      case 4:
        return '四';
      case 5:
        return '五';
      case 6:
        return '六';
      case 7:
        return '日';
      default:
        return '';
    }
  }

  /// 获取月份的中文名称
  /// 
  /// [month] 月份 (1-12)
  /// 返回中文名称，例如 "五月"
  static String getMonthName(int month) {
    switch (month) {
      case 1:
        return '一月';
      case 2:
        return '二月';
      case 3:
        return '三月';
      case 4:
        return '四月';
      case 5:
        return '五月';
      case 6:
        return '六月';
      case 7:
        return '七月';
      case 8:
        return '八月';
      case 9:
        return '九月';
      case 10:
        return '十月';
      case 11:
        return '十一月';
      case 12:
        return '十二月';
      default:
        return '';
    }
  }

  /// 检查两个日期是否为同一天
  /// 
  /// [date1] 第一个日期
  /// [date2] 第二个日期
  /// 返回是否为同一天
  static bool isSameDay(DateTime date1, DateTime date2) {
    final local1 = _toLocal(date1);
    final local2 = _toLocal(date2);
    return local1.year == local2.year &&
        local1.month == local2.month &&
        local1.day == local2.day;
  }

  /// 格式化日期为 ISO 8601 字符串（仅日期部分）
  /// 
  /// [date] 要格式化的日期
  /// 返回格式化后的字符串，例如 "2024-05-15"
  static String _formatDateString(DateTime date) {
    final localDate = _toLocal(date);
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
  }

  /// 获取日期的开始时间（00:00:00）
  static DateTime _startOfDay(DateTime date) {
    final localDate = _toLocal(date);
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  /// 获取日期的结束时间（23:59:59.999）
  static DateTime _endOfDay(DateTime date) {
    final localDate = _toLocal(date);
    return DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
      23,
      59,
      59,
      999,
    );
  }

  /// 转换为本地时间
  static DateTime _toLocal(DateTime date) {
    return date.toLocal();
  }

  /// 获取当前周的索引（相对于指定日期）
  /// 
  /// [date] 指定日期
  /// 返回当前周的日期列表
  static List<DateTime> getCurrentWeekDays([DateTime? date]) {
    return getWeekDays(date);
  }

  /// 获取当前月的索引（相对于指定日期）
  /// 
  /// [date] 指定日期
  /// 返回当前月的日期列表
  static List<DateTime> getCurrentMonthDays([DateTime? date]) {
    return getMonthDays(date);
  }

  /// 获取习惯在指定日期范围内的所有打卡日期
  /// 
  /// [habit] 习惯对象
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// 返回打卡日期列表
  static List<DateTime> getCheckedDatesInRange(
    Habit habit,
    DateTime startDate,
    DateTime endDate,
  ) {
    final List<DateTime> checkedDates = [];
    final localStart = _toLocal(startDate);
    final localEnd = _toLocal(endDate);

    for (final dateString in habit.history) {
      try {
        final date = DateTime.parse(dateString);
        final localDate = _toLocal(date);
        if (localDate.isAfter(localStart.subtract(const Duration(days: 1))) &&
            localDate.isBefore(localEnd.add(const Duration(days: 1)))) {
          checkedDates.add(localDate);
        }
      } catch (e) {
        // 忽略无效日期格式错误
      }
    }

    return checkedDates;
  }
}
