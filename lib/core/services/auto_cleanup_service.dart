import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/services/storage_service.dart';

/// 自动清理服务，用于清理过期的商品和相关文件
class AutoCleanupService {
  /// 单例实例
  static final AutoCleanupService _instance = AutoCleanupService._internal();

  /// 工厂构造函数
  factory AutoCleanupService() => _instance;

  /// 私有构造函数
  AutoCleanupService._internal();
  
  /// 初始化服务
  Future<void> initialize() async {
    await _initializeNotifications();
  }

  /// 清理天数
  static const int _cleanupDays = 30;
  /// 一天的毫秒数
  static const int _millisecondsPerDay = 24 * 60 * 60 * 1000;
  
  /// 本地通知插件实例
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  /// 初始化通知服务
  Future<void> _initializeNotifications() async {
    // 只有在非Web平台上初始化通知服务
    if (kIsWeb) {
      debugPrint('Web平台不支持本地通知');
      return;
    }
    
    // 根据不同平台设置初始化参数
    final InitializationSettings initializationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      const AndroidInitializationSettings androidInitializationSettings = 
          AndroidInitializationSettings('app_icon');
      initializationSettings = const InitializationSettings(android: androidInitializationSettings);
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      const DarwinInitializationSettings iosInitializationSettings = 
          DarwinInitializationSettings();
      initializationSettings = const InitializationSettings(iOS: iosInitializationSettings);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      const WindowsInitializationSettings windowsInitializationSettings = 
          WindowsInitializationSettings(
        appName: '每日打卡',
        appUserModelId: 'com.example.moment_keep',
        guid: '12345678-1234-1234-1234-123456789012',
      );
      initializationSettings = const InitializationSettings(windows: windowsInitializationSettings);
    } else {
      initializationSettings = const InitializationSettings();
    }
    
    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
      );
      debugPrint('通知服务已初始化');
    } catch (e) {
      debugPrint('初始化通知服务失败: $e');
    }
  }
  
  /// 发送清理结果通知
  Future<void> _sendCleanupNotification(int successCount, int failedCount) async {
    final title = failedCount > 0 ? '商品清理完成，部分失败' : '商品清理完成';
    final body = '成功清理 $successCount 个商品，失败 $failedCount 个商品';
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics = 
        AndroidNotificationDetails(
      'cleanup_channel',
      '商品清理通知',
      channelDescription: '用于通知商品清理结果',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ticker: 'ticker',
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics = 
        DarwinNotificationDetails();
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'cleanup_result',
    );
    
    debugPrint('已发送清理结果通知: $title - $body');
  }

  /// 获取清理时间配置（天数）
  Future<int> getCleanupDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('cleanup_days') ?? _cleanupDays;
  }

  /// 设置清理时间配置（天数）
  Future<void> setCleanupDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cleanup_days', days);
  }

  /// 获取最后清理时间
  Future<int?> getLastCleanupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_cleanup_time');
  }

  /// 设置最后清理时间
  Future<void> setLastCleanupTime(int time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_cleanup_time', time);
  }

  /// 后台任务定时器
  Timer? _backgroundTimer;
  
  /// 启动后台清理任务调度
  void startBackgroundCleanup() {
    // 取消之前的定时器
    _backgroundTimer?.cancel();
    
    // 每分钟检查一次是否需要清理
    _backgroundTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndCleanup();
    });
    
    // 立即执行一次检查
    _checkAndCleanup();
    
    debugPrint('后台清理任务调度已启动');
  }
  
  /// 停止后台清理任务调度
  void stopBackgroundCleanup() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    debugPrint('后台清理任务调度已停止');
  }
  
  /// 检查并执行清理任务
  Future<void> _checkAndCleanup() async {
    try {
      // 获取最后清理时间
      final lastCleanupTime = await getLastCleanupTime();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 如果距离上次清理时间不足24小时，则不执行清理
      if (lastCleanupTime != null) {
        final timeSinceLastCleanup = now - lastCleanupTime;
        if (timeSinceLastCleanup < _millisecondsPerDay) {
          debugPrint('距离上次清理时间不足24小时，跳过本次清理');
          return;
        }
      }
      
      // 执行清理任务
      await cleanupExpiredProducts();
    } catch (e) {
      debugPrint('检查清理任务失败: $e');
    }
  }
  
  /// 清理过期商品
  /// 检查商品表中is_deleted=1且deleted_at超过_cleanupDays天的商品
  /// 然后删除相关的媒体文件和数据库记录
  Future<void> cleanupExpiredProducts() async {
    try {
      debugPrint('开始清理过期商品...');
      
      final DatabaseService dbService = DatabaseService();
      final ProductDatabaseService productDb = ProductDatabaseService();
      final StorageService storageService = StorageService();

      // 获取配置的清理时间
      final cleanupDays = await getCleanupDays();
      
      // 计算清理阈值时间
      final now = DateTime.now().millisecondsSinceEpoch;
      final threshold = now - (cleanupDays * _millisecondsPerDay);
      
      // 获取最后清理时间
      final lastCleanupTime = await getLastCleanupTime();
      
      // 获取所有软删除的商品
      final allProducts = await dbService.getAllStarProducts();
      
      // 增量清理：只处理在最后清理时间之后被删除且超过清理天数的商品
      final expiredProducts = allProducts.where((product) {
        final deletedAt = product.deletedAt?.millisecondsSinceEpoch ?? 0;
        return product.isDeleted && 
               deletedAt < threshold &&
               (lastCleanupTime == null || deletedAt > lastCleanupTime);
      }).toList();

      debugPrint('找到 ${expiredProducts.length} 个过期商品需要清理');

      int successCount = 0;
      int failedCount = 0;
      final details = <String>[];

      for (final product in expiredProducts) {
        try {
          debugPrint('清理商品: ${product.name} (ID: ${product.id})');
          
          // 删除商品媒体文件
          await _deleteProductMediaFiles(product, storageService);
          
          // 彻底删除商品
          await productDb.permanentlyDeleteProduct(product.id!);
          
          successCount++;
          details.add('成功清理商品: ${product.name} (ID: ${product.id})');
          debugPrint('商品 ${product.name} 清理完成');
        } catch (e) {
          failedCount++;
          details.add('清理失败商品: ${product.name} (ID: ${product.id}), 错误: $e');
          debugPrint('清理商品 ${product.name} 失败: $e');
        }
      }
      
      // 记录清理日志
      try {
        await productDb.insertCleanupLog({
          'cleanup_time': now,
          'total_products': expiredProducts.length,
          'success_count': successCount,
          'failed_count': failedCount,
          'details': jsonEncode(details),
          'created_at': now,
        });
      } catch (logError) {
        debugPrint('插入清理日志失败: $logError');
        // 忽略日志插入错误，不影响主流程
      }
      
      // 更新最后清理时间
      await setLastCleanupTime(now);
      
      // 发送清理结果通知
      try {
        await _sendCleanupNotification(successCount, failedCount);
      } catch (notificationError) {
        debugPrint('发送清理通知失败: $notificationError');
        // 忽略通知发送错误，不影响主流程
      }
      
      debugPrint('过期商品清理完成，成功: $successCount, 失败: $failedCount');
    } catch (e) {
      debugPrint('清理过期商品失败: $e');
      
      // 记录清理失败日志
      final ProductDatabaseService productDb = ProductDatabaseService();
      try {
        await productDb.insertCleanupLog({
          'cleanup_time': DateTime.now().millisecondsSinceEpoch,
          'total_products': 0,
          'success_count': 0,
          'failed_count': 0,
          'details': '清理过程中发生错误: $e',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (logError) {
        debugPrint('插入清理日志失败: $logError');
        // 忽略日志插入错误，不影响主流程
      }
      
      // 发送清理失败通知
      await _sendCleanupNotification(0, 1);
    }
  }

  /// 删除商品媒体文件
  /// [product] 商品对象
  /// [storageService] 存储服务实例
  Future<void> _deleteProductMediaFiles(StarProduct product, StorageService storageService) async {
    try {
      debugPrint('开始删除商品媒体文件...');
      
      // 删除主图
      if (product.image.isNotEmpty) {
        debugPrint('删除主图: ${product.image}');
        await storageService.deleteFile(product.image);
      }
      
      // 删除详情图
      for (final image in product.detailImages) {
        debugPrint('删除详情图: $image');
        await storageService.deleteFile(image);
      }
      
      // 删除视频
      final video = product.video;
      if (video != null && video.isNotEmpty) {
        debugPrint('删除视频: $video');
        await storageService.deleteFile(video);
      }
      
      // 删除视频封面
      final videoCover = product.videoCover;
      if (videoCover != null && videoCover.isNotEmpty) {
        debugPrint('删除视频封面: $videoCover');
        await storageService.deleteFile(videoCover);
      }
      
      // 删除SKU图片
      final skus = product.skus;
      if (skus != null) {
        for (final sku in skus) {
          final skuImage = sku.image;
          if (skuImage != null && skuImage.isNotEmpty) {
            debugPrint('删除SKU图片: $skuImage');
            await storageService.deleteFile(skuImage);
          }
        }
      }
      
      debugPrint('商品媒体文件删除完成');
    } catch (e) {
      debugPrint('删除商品媒体文件失败: $e');
    }
  }
}