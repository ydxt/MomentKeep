import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 推送通知服务
/// 支持本地通知和云端推送（FCM）
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android 设置
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 设置
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      debugPrint('PushNotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing PushNotificationService: $e');
    }
  }

  /// 初始化 FCM（需要 Firebase 配置）
  Future<void> initializeFCM() async {
    // TODO: 接入 Firebase Cloud Messaging
    debugPrint('FCM initialization - Not implemented yet. Requires Firebase configuration.');
  }

  /// 发送本地通知
  Future<void> sendLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'moment_keep_channel',
        '拾光记通知',
        channelDescription: '拾光记应用通知',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('Notification sent: $title - $body');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// 发送习惯提醒通知
  Future<void> sendHabitReminder({
    required String habitName,
    required int habitId,
  }) async {
    await sendLocalNotification(
      id: habitId.hashCode,
      title: '💪 习惯提醒',
      body: '该进行"$habitName"打卡啦！坚持就是胜利！',
      payload: jsonEncode({
        'type': 'habit_reminder',
        'habitId': habitId,
      }),
    );
  }

  /// 发送待办截止提醒
  Future<void> sendTodoReminder({
    required String todoTitle,
    required int todoId,
    required bool isUrgent,
  }) async {
    await sendLocalNotification(
      id: todoId.hashCode + 10000,
      title: isUrgent ? '⚠️ 紧急提醒' : '📋 待办提醒',
      body: isUrgent 
          ? '"$todoTitle"即将到期，请尽快完成！'
          : '"$todoTitle"待办事项提醒你',
      payload: jsonEncode({
        'type': 'todo_reminder',
        'todoId': todoId,
        'isUrgent': isUrgent,
      }),
    );
  }

  /// 发送番茄钟完成通知
  Future<void> sendPomodoroComplete({
    required int duration,
  }) async {
    final minutes = duration ~/ 60;
    await sendLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🎉 专注完成',
      body: '太棒了！你专注了 $minutes 分钟，休息一下吧！',
      payload: jsonEncode({
        'type': 'pomodoro_complete',
        'duration': duration,
      }),
    );
  }

  /// 发送系统公告通知
  Future<void> sendSystemAnnouncement({
    required String title,
    required String content,
  }) async {
    await sendLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 20000,
      title: '📢 $title',
      body: content,
      payload: jsonEncode({
        'type': 'system_announcement',
      }),
    );
  }

  /// 发送订单状态通知
  Future<void> sendOrderNotification({
    required String orderTitle,
    required String status,
    required int orderId,
  }) async {
    String emoji;
    String message;
    
    switch (status) {
      case 'shipped':
        emoji = '📦';
        message = '"$orderTitle"已发货，请注意查收';
        break;
      case 'delivered':
        emoji = '✅';
        message = '"$orderTitle"已签收，希望你喜欢！';
        break;
      case 'refund_approved':
        emoji = '💰';
        message = '"$orderTitle"退款已通过，请注意查收';
        break;
      default:
        emoji = '📋';
        message = '"$orderTitle"状态更新: $status';
    }

    await sendLocalNotification(
      id: orderId + 30000,
      title: '$emoji 订单通知',
      body: message,
      payload: jsonEncode({
        'type': 'order_notification',
        'orderId': orderId,
        'status': status,
      }),
    );
  }

  /// 取消指定通知
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationAction(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// 处理通知操作
  void _handleNotificationAction(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'habit_reminder':
        final habitId = data['habitId'] as int?;
        debugPrint('Navigate to habit $habitId');
        break;
      case 'todo_reminder':
        final todoId = data['todoId'] as int?;
        debugPrint('Navigate to todo $todoId');
        break;
      case 'pomodoro_complete':
        debugPrint('Navigate to pomodoro stats');
        break;
      case 'order_notification':
        final orderId = data['orderId'] as int?;
        debugPrint('Navigate to order $orderId');
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  /// 保存通知设置
  Future<void> saveNotificationSettings({
    bool enableHabitReminders = true,
    bool enableTodoReminders = true,
    bool enablePomodoroReminders = true,
    bool enableOrderNotifications = true,
    bool enableSystemNotifications = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('enable_habit_reminders', enableHabitReminders);
    await prefs.setBool('enable_todo_reminders', enableTodoReminders);
    await prefs.setBool('enable_pomodoro_reminders', enablePomodoroReminders);
    await prefs.setBool('enable_order_notifications', enableOrderNotifications);
    await prefs.setBool('enable_system_notifications', enableSystemNotifications);
  }

  /// 获取通知设置
  Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'enableHabitReminders': prefs.getBool('enable_habit_reminders') ?? true,
      'enableTodoReminders': prefs.getBool('enable_todo_reminders') ?? true,
      'enablePomodoroReminders': prefs.getBool('enable_pomodoro_reminders') ?? true,
      'enableOrderNotifications': prefs.getBool('enable_order_notifications') ?? true,
      'enableSystemNotifications': prefs.getBool('enable_system_notifications') ?? true,
    };
  }
}

/// 通知优先级枚举（保留以便将来使用）
enum NotificationPriority {
  low,
  defaultPriority,
  high,
  max,
}
