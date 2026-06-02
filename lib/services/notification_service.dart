import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart' as sqflite_package;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 仅在非Web平台导入sqflite_common_ffi
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) 'package:moment_keep/services/empty_sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

/// 通知类型枚举
enum NotificationType {
  reminderShip, // 催发货
  modifyAddress, // 修改地址
  applyCancel, // 申请取消
  applyAfterSales, // 申请售后
  review, // 评价
  system, // 系统通知
}

/// 通知状态枚举
enum NotificationStatus {
  unread, // 未读
  read, // 已读
  processed, // 已处理
}

/// 通知模型
class NotificationInfo {
  final String id;
  final String orderId;
  final String? productName;
  final String? productImage;
  final NotificationType type;
  final NotificationStatus status;
  final String content;
  final DateTime createdAt;
  final DateTime? processedAt;

  NotificationInfo({
    required this.id,
    required this.orderId,
    this.productName,
    this.productImage,
    required this.type,
    this.status = NotificationStatus.unread,
    required this.content,
    required this.createdAt,
    this.processedAt,
  });

  /// 从Map转换为NotificationInfo对象
  factory NotificationInfo.fromMap(Map<String, dynamic> map) {
    return NotificationInfo(
      id: map['id'] ?? '',
      orderId: map['order_id'] ?? '',
      productName: map['product_name'],
      productImage: map['product_image'],
      type: _stringToNotificationType(map['type'] ?? ''),
      status: _stringToNotificationStatus(map['status'] ?? ''),
      content: map['content'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      processedAt: map['processed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['processed_at'])
          : null,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_name': productName,
      'product_image': productImage,
      'type': _notificationTypeToString(type),
      'status': _notificationStatusToString(status),
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'processed_at': processedAt?.millisecondsSinceEpoch,
    };
  }

  /// 将字符串转换为NotificationType
  static NotificationType _stringToNotificationType(String type) {
    switch (type) {
      case 'reminderShip':
        return NotificationType.reminderShip;
      case 'modifyAddress':
        return NotificationType.modifyAddress;
      case 'applyCancel':
        return NotificationType.applyCancel;
      case 'applyAfterSales':
        return NotificationType.applyAfterSales;
      case 'review':
        return NotificationType.review;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }

  /// 将NotificationType转换为字符串
  static String _notificationTypeToString(NotificationType type) {
    switch (type) {
      case NotificationType.reminderShip:
        return 'reminderShip';
      case NotificationType.modifyAddress:
        return 'modifyAddress';
      case NotificationType.applyCancel:
        return 'applyCancel';
      case NotificationType.applyAfterSales:
        return 'applyAfterSales';
      case NotificationType.review:
        return 'review';
      case NotificationType.system:
        return 'system';
    }
  }

  /// 将字符串转换为NotificationStatus
  static NotificationStatus _stringToNotificationStatus(String status) {
    switch (status) {
      case 'unread':
        return NotificationStatus.unread;
      case 'read':
        return NotificationStatus.read;
      case 'processed':
        return NotificationStatus.processed;
      default:
        return NotificationStatus.unread;
    }
  }

  /// 将NotificationStatus转换为字符串
  static String _notificationStatusToString(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.unread:
        return 'unread';
      case NotificationStatus.read:
        return 'read';
      case NotificationStatus.processed:
        return 'processed';
    }
  }

  /// 获取通知类型的显示文本
  String get typeText {
    switch (type) {
      case NotificationType.reminderShip:
        return '催发货';
      case NotificationType.modifyAddress:
        return '修改地址';
      case NotificationType.applyCancel:
        return '申请取消';
      case NotificationType.applyAfterSales:
        return '申请售后';
      case NotificationType.review:
        return '评价';
      case NotificationType.system:
        return '系统通知';
    }
  }

  /// 获取通知状态的显示文本
  String get statusText {
    switch (status) {
      case NotificationStatus.unread:
        return '未读';
      case NotificationStatus.read:
        return '已读';
      case NotificationStatus.processed:
        return '已处理';
    }
  }
}

/// 通知数据库服务
class NotificationDatabaseService {
  static final NotificationDatabaseService _instance = NotificationDatabaseService._internal();
  factory NotificationDatabaseService() => _instance;
  NotificationDatabaseService._internal();

  sqflite_package.Database? _database;
  
  /// 本地通知插件实例
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  /// 是否已初始化本地通知
  bool _isLocalNotificationsInitialized = false;

  /// 获取数据库实例
  Future<sqflite_package.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    // 初始化本地通知
    await _initializeLocalNotifications();
    return _database!;
  }

  /// 初始化本地通知
  Future<void> _initializeLocalNotifications() async {
    if (_isLocalNotificationsInitialized) return;
    
    try {
      // 初始化设置
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
      const WindowsInitializationSettings initializationSettingsWindows = WindowsInitializationSettings(
        appName: 'momentkeep',
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
      _isLocalNotificationsInitialized = true;
      debugPrint('本地通知初始化成功');
    } catch (e) {
      debugPrint('本地通知初始化失败: $e');
    }
  }

  /// 初始化数据库
  Future<sqflite_package.Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = path_package.join(documentsDirectory.path, 'moment_keep_notifications.db');

    // 桌面平台处理 (Windows, Linux, macOS)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        // 初始化sqflite_ffi
        sqfliteFfiInit();
        // 设置全局数据库工厂为FFI实现
        sqflite_package.databaseFactory = databaseFactoryFfi;
      } catch (e) {
        debugPrint('FFi初始化错误: $e');
        // 继续执行，让openDatabase失败并使用模拟实现
      }
    }

    return await sqflite_package.openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            order_id TEXT NOT NULL,
            product_name TEXT,
            product_image TEXT,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            processed_at INTEGER
          )
        ''');

        // 创建索引
        await db.execute('CREATE INDEX idx_notifications_status ON notifications(status)');
        await db.execute('CREATE INDEX idx_notifications_type ON notifications(type)');
        await db.execute('CREATE INDEX idx_notifications_order_id ON notifications(order_id)');
      },
    );
  }

  /// 添加通知
  Future<void> addNotification(NotificationInfo notification) async {
    final db = await database;
    await db.insert('notifications', notification.toMap());
    
    // 发送本地通知
    await _sendLocalNotification(notification);
  }

  /// 发送本地通知
  Future<void> _sendLocalNotification(NotificationInfo notification) async {
    try {
      // 确保本地通知已初始化
      await _initializeLocalNotifications();
      
      // 构建通知详情
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'channel_id',
        '订单通知',
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
        id: int.parse(notification.id.split('_').last), // 使用通知ID的最后部分作为通知ID
        title: notification.productName ?? '订单通知',
        body: notification.content,
        notificationDetails: platformChannelSpecifics,
        payload: notification.id,
      );
      debugPrint('本地通知发送成功: ${notification.id}');
    } catch (e) {
      debugPrint('本地通知发送失败: $e');
    }
  }

  /// 获取所有通知
  Future<List<NotificationInfo>> getAllNotifications() async {
    final db = await database;
    final maps = await db.query('notifications', orderBy: 'created_at DESC');
    return List.generate(maps.length, (i) => NotificationInfo.fromMap(maps[i]));
  }

  /// 分页获取通知
  Future<List<NotificationInfo>> getNotificationsByPage(int page, int pageSize) async {
    final db = await database;
    final offset = (page - 1) * pageSize;
    final maps = await db.query(
      'notifications',
      orderBy: 'created_at DESC',
      limit: pageSize,
      offset: offset,
    );
    return List.generate(maps.length, (i) => NotificationInfo.fromMap(maps[i]));
  }

  /// 获取未读通知数量
  Future<int> getUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM notifications WHERE status = ?',
      [_notificationStatusToString(NotificationStatus.unread)],
    );
    return result.isNotEmpty ? (result.first['count'] as int? ?? 0) : 0;
  }

  /// 将通知标记为已读
  Future<void> markAsRead(String notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {
        'status': _notificationStatusToString(NotificationStatus.read),
      },
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  /// 将通知标记为已处理
  Future<void> markAsProcessed(String notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {
        'status': _notificationStatusToString(NotificationStatus.processed),
        'processed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  /// 标记所有通知为已读
  Future<void> markAllAsRead() async {
    final db = await database;
    await db.update(
      'notifications',
      {
        'status': _notificationStatusToString(NotificationStatus.read),
      },
      where: 'status = ?',
      whereArgs: [_notificationStatusToString(NotificationStatus.unread)],
    );
  }

  /// 根据订单ID获取通知
  Future<List<NotificationInfo>> getNotificationsByOrderId(String orderId) async {
    final db = await database;
    final maps = await db.query(
      'notifications',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => NotificationInfo.fromMap(maps[i]));
  }

  /// 删除通知
  Future<void> deleteNotification(String notificationId) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  /// 清理过期通知（超过30天）
  Future<void> cleanupOldNotifications() async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    await db.delete(
      'notifications',
      where: 'created_at < ?',
      whereArgs: [thirtyDaysAgo.millisecondsSinceEpoch],
    );
  }

  /// 将字符串转换为NotificationStatus
  static String _notificationStatusToString(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.unread:
        return 'unread';
      case NotificationStatus.read:
        return 'read';
      case NotificationStatus.processed:
        return 'processed';
    }
  }
}
