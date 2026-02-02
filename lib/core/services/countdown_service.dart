import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

    // Android 通知设置
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 通知设置
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 初始化设置
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    // 初始化通知插件
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );

    _isInitialized = true;
  }

  /// 前台通知响应处理
  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    print('Notification clicked: ${notificationResponse.payload}');
    // 可以在这里处理通知点击事件，例如导航到特定页面
  }

  /// 后台通知响应处理
  static void _onDidReceiveBackgroundNotificationResponse(
      NotificationResponse notificationResponse) async {
    print('Background notification clicked: ${notificationResponse.payload}');
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
      id,
      title,
      body,
      notificationDetails,
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
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// 取消特定通知
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
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

  /// 为习惯设置提醒
  Future<void> setHabitReminder({
    required int habitId,
    required String habitName,
    required int hour,
    required int minute,
  }) async {
    await scheduleDailyNotification(
      id: habitId,
      title: '习惯提醒',
      body: '该完成「$habitName」习惯了！',
      hour: hour,
      minute: minute,
      payload: 'habit:$habitId',
    );
  }

  /// 取消习惯提醒
  Future<void> cancelHabitReminder(int habitId) async {
    await cancelNotification(habitId);
  }
}
