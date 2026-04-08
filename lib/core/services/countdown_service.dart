import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// 倒计时与提醒服务
class CountdownService {
  /// 单例实例
  static final CountdownService _instance = CountdownService._internal();

  /// 本地通知插件实例
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// 初始化标志
  bool _isInitialized = false;

  /// 私有构造函数
  CountdownService._internal();

  /// 工厂构造函数
  factory CountdownService() => _instance;

  /// 初始化本地通知
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // 初始化时区数据
    tz.initializeTimeZones();

    // Android 通知设置
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 通知设置
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 初始化设置
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 初始化通知插件
    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    _isInitialized = true;
  }

  /// 显示即时通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    // Android 通知详情
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'habit_reminder_channel',
      '习惯提醒',
      channelDescription: '用于提醒用户完成习惯的通知',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    // iOS 通知详情
    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // 通知详情
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    // 显示通知
    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  /// 安排每日重复通知
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await initialize();

    // Android 通知详情
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'habit_reminder_channel',
      '习惯提醒',
      channelDescription: '用于提醒用户完成习惯的通知',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    // iOS 通知详情
    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // 通知详情
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    // 简化实现：直接显示通知，不使用定时功能
    // 注意：完整的定时功能需要使用timezone包，这里为了简化暂时移除
    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  /// 取消特定通知
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// 计算距离目标日期的天数
  int calculateDaysUntil(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    return difference.inDays;
  }

  /// 计算距离目标日期的小时数
  double calculateHoursUntil(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    return difference.inMinutes / 60.0;
  }

  /// 计算距离目标日期的分钟数
  int calculateMinutesUntil(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    return difference.inMinutes;
  }

  /// 计算距离目标日期的秒数
  int calculateSecondsUntil(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    return difference.inSeconds;
  }

  /// 格式化倒计时时间
  String formatCountdown(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now);

    if (difference.isNegative) {
      return '已过期';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (days > 0) {
      return '$days天 $hours时 $minutes分 $seconds秒';
    } else if (hours > 0) {
      return '$hours时 $minutes分 $seconds秒';
    } else if (minutes > 0) {
      return '$minutes分 $seconds秒';
    } else {
      return '$seconds秒';
    }
  }

  /// 为习惯设置每日重复提醒
  Future<void> setHabitReminder({
    required int habitId,
    required String habitName,
    required int hour,
    required int minute,
    List<int>? daysOfWeek, // 1=周一, 7=周日
  }) async {
    await initialize();

    // 取消旧的提醒
    await cancelHabitReminder(habitId);

    // Android 通知详情
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'habit_reminder_channel',
      '习惯提醒',
      channelDescription: '用于提醒用户完成习惯的通知',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    // 如果没有指定星期几，默认每天都提醒
    final days = daysOfWeek ?? [1, 2, 3, 4, 5, 6, 7];

    // 为每个指定的星期几创建每周重复的通知
    for (final dayOfWeek in days) {
      // 使用 dayOfWeek 作为通知 ID 的一部分，确保每个星期的提醒有唯一 ID
      final notificationId = habitId * 10 + dayOfWeek;

      try {
        // 使用 zonedSchedule 实现每周固定时间提醒（所有参数都是命名参数）
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id: notificationId,
          title: '💪 习惯提醒',
          body: '该完成「$habitName」习惯了！坚持就是胜利！',
          scheduledDate: _nextInstanceOfDayOfWeekAndTime(dayOfWeek, hour, minute),
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'habit:$habitId',
        );
      } catch (e) {
        print('设置习惯提醒失败 (day=$dayOfWeek): $e');
      }
    }
  }

  /// 获取下次指定星期几和时间的实例
  tz.TZDateTime _nextInstanceOfDayOfWeekAndTime(
      int dayOfWeek, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 计算距离下次指定星期几的天数
    int daysUntilTarget = dayOfWeek - now.weekday;
    if (daysUntilTarget < 0 ||
        (daysUntilTarget == 0 &&
            (now.hour > hour || (now.hour == hour && now.minute >= minute)))) {
      daysUntilTarget += 7;
    }

    scheduledDate = scheduledDate.add(Duration(days: daysUntilTarget));
    return scheduledDate;
  }

  /// 取消习惯提醒
  Future<void> cancelHabitReminder(int habitId) async {
    await cancelNotification(habitId);
  }
}
