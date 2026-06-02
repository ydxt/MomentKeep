import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:moment_keep/domain/entities/todo.dart';

/// 位置服务类，用于处理位置权限、定位和地理围栏相关功能
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// 本地通知插件实例
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// 是否已初始化本地通知
  bool _isLocalNotificationsInitialized = false;

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

  /// 请求位置权限
  Future<bool> requestLocationPermission() async {
    try {
      // 检查是否已经授予位置权限
      var status = await Permission.location.status;
      
      if (status.isGranted) {
        debugPrint('位置权限已授予');
        return true;
      }
      
      // 如果权限被拒绝，请求权限
      if (status.isDenied) {
        status = await Permission.location.request();
        if (status.isGranted) {
          debugPrint('位置权限请求成功');
          return true;
        } else {
          debugPrint('位置权限请求被拒绝');
          return false;
        }
      }
      
      // 如果权限被永久拒绝，提示用户去设置页面手动开启
      if (status.isPermanentlyDenied || status.isRestricted) {
        debugPrint('位置权限被永久拒绝，请手动开启');
        await openAppSettings();
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('请求位置权限时发生错误: $e');
      return false;
    }
  }

  /// 获取当前位置
  Future<Position?> getCurrentLocation() async {
    try {
      // 检查位置权限
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('没有位置权限，无法获取当前位置');
        return null;
      }
      
      // 获取当前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint('获取当前位置成功: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('获取当前位置时发生错误: $e');
      return null;
    }
  }

  /// 计算两个坐标之间的距离（米）
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// 检查是否在地理围栏范围内
  bool isInGeofence(Position currentPosition, double targetLat, double targetLon, double radius) {
    double distance = calculateDistance(
      currentPosition.latitude, 
      currentPosition.longitude, 
      targetLat, 
      targetLon
    );
    return distance <= radius;
  }

  /// 发送位置提醒通知
  Future<void> sendLocationNotification(Todo todo) async {
    try {
      // 确保本地通知已初始化
      await _initializeLocalNotifications();
      
      // 构建通知详情
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'location_reminder_channel',
        '位置提醒',
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
        id: int.parse(todo.id.split('_').last), // 使用待办ID的最后部分作为通知ID
        title: '位置提醒',
        body: '您已到达 ${todo.locationName ?? '目标位置'}，记得完成任务：${todo.title}',
        notificationDetails: platformChannelSpecifics,
        payload: todo.id,
      );
      debugPrint('位置提醒通知发送成功: ${todo.id}');
    } catch (e) {
      debugPrint('发送位置提醒通知失败: $e');
    }
  }

  /// 启动位置监控服务
  /// 此方法会定期检查当前位置，并触发符合条件的位置提醒
  StreamSubscription<Position>? _positionStreamSubscription;
  
  /// 启动位置监控
  Future<void> startLocationMonitoring(List<Todo> todosWithLocationReminders) async {
    try {
      // 检查位置权限
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('没有位置权限，无法启动位置监控');
        return;
      }
      
      // 停止之前的监控
      await stopLocationMonitoring();
      
      // 配置位置服务
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 每移动10米更新一次位置
      );
      
      // 开始监听位置变化
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings
      ).listen((Position position) {
        debugPrint('位置更新: ${position.latitude}, ${position.longitude}');
        
        // 检查是否有符合条件的待办事项
        for (var todo in todosWithLocationReminders) {
          if (
            todo.isLocationReminderEnabled &&
            !todo.isCompleted &&
            todo.latitude != null &&
            todo.longitude != null &&
            todo.radius != null
          ) {
            bool isInFence = isInGeofence(
              position, 
              todo.latitude!, 
              todo.longitude!, 
              todo.radius!
            );
            
            if (isInFence) {
              // 发送位置提醒
              sendLocationNotification(todo);
            }
          }
        }
      });
      
      debugPrint('位置监控已启动');
    } catch (e) {
      debugPrint('启动位置监控失败: $e');
    }
  }

  /// 停止位置监控
  Future<void> stopLocationMonitoring() async {
    if (_positionStreamSubscription != null) {
      await _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      debugPrint('位置监控已停止');
    }
  }

  /// 获取所有带有位置提醒的待办事项
  Future<List<Todo>> getTodosWithLocationReminders(List<Todo> allTodos) async {
    return allTodos.where((todo) => 
      todo.isLocationReminderEnabled && 
      !todo.isCompleted &&
      todo.latitude != null &&
      todo.longitude != null &&
      todo.radius != null
    ).toList();
  }
}
