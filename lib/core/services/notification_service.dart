import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:moment_keep/domain/entities/todo.dart';

/// 通知服务
class TodoNotificationService {
  static final TodoNotificationService _instance = TodoNotificationService._internal();
  factory TodoNotificationService() => _instance;
  TodoNotificationService._internal();

  /// 本地通知插件实例
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// 是否已初始化本地通知
  bool _isInitialized = false;

  /// 定时器
  Timer? _checkTimer;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化设置
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
      const WindowsInitializationSettings initializationSettingsWindows = WindowsInitializationSettings(
        appName: '每日打卡',
        appUserModelId: 'com.example.momentkeep',
        guid: '{12345678-1234-1234-1234-123456789012}',
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
        windows: initializationSettingsWindows,
      );

      // 初始化本地通知插件
      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
      _isInitialized = true;
      debugPrint('待办事项通知服务初始化成功');

      // 启动定时检查
      _startCheckTimer();
    } catch (e) {
      debugPrint('待办事项通知服务初始化失败: $e');
    }
  }

  /// 启动定时检查
  void _startCheckTimer() {
    // 每分钟检查一次
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkTodoReminders([]); // 这里需要传入待办事项列表，实际使用时需要从TodoBloc获取
    });
  }

  /// 检查待办事项提醒
  void _checkTodoReminders(List<Todo> todos) {
    final now = DateTime.now();
    
    for (final todo in todos) {
      // 跳过已完成的任务
      if (todo.isCompleted) continue;
      
      // 检查是否有提醒时间
      if (todo.reminderTime == null) continue;
      
      // 检查是否到达提醒时间
      final reminderTime = todo.reminderTime!;
      final difference = reminderTime.difference(now);
      
      // 如果提醒时间在1分钟内，则触发提醒
      if (difference.inMinutes >= 0 && difference.inMinutes < 1) {
        _showTodoNotification(todo);
      }
    }
  }

  /// 显示待办事项通知
  Future<void> _showTodoNotification(Todo todo) async {
    try {
      // 构建通知详情
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'todo_reminder_channel',
        '待办事项提醒',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails();
      const WindowsNotificationDetails windowsPlatformChannelSpecifics = WindowsNotificationDetails();
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
        windows: windowsPlatformChannelSpecifics,
      );

      // 发送通知
      await _flutterLocalNotificationsPlugin.show(
        id: int.parse(todo.id),
        title: '待办事项提醒',
        body: todo.title,
        notificationDetails: platformChannelSpecifics,
        payload: todo.id,
      );
      debugPrint('待办事项通知发送成功: ${todo.id}');
    } catch (e) {
      debugPrint('待办事项通知发送失败: $e');
    }
  }

  /// 为单个待办事项设置提醒
  Future<void> scheduleTodoReminder(Todo todo) async {
    if (!_isInitialized) await initialize();

    try {
      // 检查是否有提醒时间
      if (todo.reminderTime == null) return;
      
      // 检查是否已完成
      if (todo.isCompleted) return;

      // 计算延迟时间
      final now = DateTime.now();
      final reminderTime = todo.reminderTime!;
      final delay = reminderTime.difference(now);

      // 如果提醒时间已过，跳过
      if (delay.isNegative) return;

      // 构建通知详情
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'todo_reminder_channel',
        '待办事项提醒',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails();
      const WindowsNotificationDetails windowsPlatformChannelSpecifics = WindowsNotificationDetails();
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
        windows: windowsPlatformChannelSpecifics,
      );

      // 调度通知
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: int.parse(todo.id),
        title: '待办事项提醒',
        body: todo.title,
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: todo.id,
      );
      debugPrint('待办事项提醒已设置: ${todo.id}');
    } catch (e) {
      debugPrint('设置待办事项提醒失败: $e');
    }
  }

  /// 取消待办事项提醒
  Future<void> cancelTodoReminder(String todoId) async {
    if (!_isInitialized) await initialize();

    try {
      await _flutterLocalNotificationsPlugin.cancel(
        id: int.parse(todoId),
      );
      debugPrint('待办事项提醒已取消: $todoId');
    } catch (e) {
      debugPrint('取消待办事项提醒失败: $e');
    }
  }

  /// 取消所有待办事项提醒
  Future<void> cancelAllTodoReminders() async {
    if (!_isInitialized) await initialize();

    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('所有待办事项提醒已取消');
    } catch (e) {
      debugPrint('取消所有待办事项提醒失败: $e');
    }
  }

  /// 更新待办事项提醒
  Future<void> updateTodoReminder(Todo todo) async {
    // 先取消旧的提醒
    await cancelTodoReminder(todo.id);
    
    // 再设置新的提醒
    await scheduleTodoReminder(todo);
  }

  /// 检查并更新所有待办事项提醒
  Future<void> updateAllTodoReminders(List<Todo> todos) async {
    // 先取消所有提醒
    await cancelAllTodoReminders();

    // 再为每个待办事项设置提醒
    for (final todo in todos) {
      await scheduleTodoReminder(todo);
    }
  }

  /// 清理资源
  void dispose() {
    _checkTimer?.cancel();
  }
}
