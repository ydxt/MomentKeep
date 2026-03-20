import 'dart:async';
import 'dart:io';
import 'package:moment_keep/services/storage_path_service.dart';
import 'package:moment_keep/services/storage_service.dart';
import 'package:moment_keep/services/database_service.dart';

/// 同步服务
/// 负责在本地和服务器（cloud目录）之间同步数据
class SyncService {
  // 同步状态
  static bool _isSyncing = false;
  // 同步进度
  static double _syncProgress = 0.0;
  // 同步状态监听
  static final StreamController<double> _syncProgressController = StreamController<double>.broadcast();

  /// 获取同步进度流
  static Stream<double> get syncProgressStream => _syncProgressController.stream;

  /// 初始化同步服务
  static Future<void> initialize() async {
    // 确保存储路径服务已初始化
    await StoragePathService.initialize();
  }

  /// 同步所有数据
  static Future<bool> syncAllData() async {
    if (_isSyncing) {
      print('同步已在进行中');
      return false;
    }

    _isSyncing = true;
    _syncProgress = 0.0;
    _syncProgressController.add(_syncProgress);

    try {
      // 同步用户数据
      if (!await syncUserData()) {
        throw Exception('用户数据同步失败');
      }
      _syncProgress = 0.25;
      _syncProgressController.add(_syncProgress);

      // 同步商品数据
      if (!await syncProductData()) {
        throw Exception('商品数据同步失败');
      }
      _syncProgress = 0.5;
      _syncProgressController.add(_syncProgress);

      // 同步订单数据
      if (!await syncOrderData()) {
        throw Exception('订单数据同步失败');
      }
      _syncProgress = 0.75;
      _syncProgressController.add(_syncProgress);

      // 同步日记数据
      if (!await syncDiaryData()) {
        throw Exception('日记数据同步失败');
      }
      _syncProgress = 1.0;
      _syncProgressController.add(_syncProgress);

      print('所有数据同步成功');
      return true;
    } catch (e) {
      print('同步失败: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// 同步用户数据
  static Future<bool> syncUserData() async {
    try {
      print('开始同步用户数据');
      
      // 从本地数据库读取用户数据
      final localUsers = await DatabaseService.query(
        DatabaseType.local,
        'moment_keep.db',
        'users',
      );

      // 同步到服务器数据库
      for (final user in localUsers) {
        await DatabaseService.insert(
          DatabaseType.server,
          'moment_keep_users.db',
          'users',
          user,
        );

        // 同步用户扩展数据
        final userId = user['user_id'];
        final userType = user['user_type'];

        // 同步买家扩展数据
        if ((userType & 1) != 0) { // 买家
          final buyerData = await DatabaseService.query(
            DatabaseType.local,
            'moment_keep.db',
            'buyer_extensions',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          if (buyerData.isNotEmpty) {
            await DatabaseService.insert(
              DatabaseType.server,
              'moment_keep_users.db',
              'buyer_extensions',
              buyerData.first,
            );
          }
        }

        // 同步卖家扩展数据
        if ((userType & 2) != 0) { // 卖家
          final sellerData = await DatabaseService.query(
            DatabaseType.local,
            'moment_keep.db',
            'seller_extensions',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          if (sellerData.isNotEmpty) {
            await DatabaseService.insert(
              DatabaseType.server,
              'moment_keep_users.db',
              'seller_extensions',
              sellerData.first,
            );
          }
        }

        // 同步管理员扩展数据
        if ((userType & 4) != 0) { // 管理员
          final adminData = await DatabaseService.query(
            DatabaseType.local,
            'moment_keep.db',
            'admin_extensions',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          if (adminData.isNotEmpty) {
            await DatabaseService.insert(
              DatabaseType.server,
              'moment_keep_users.db',
              'admin_extensions',
              adminData.first,
            );
          }
        }

        // 同步信用积分数据
        final buyerCredit = await DatabaseService.query(
          DatabaseType.local,
          'moment_keep.db',
          'buyer_credit_scores',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        if (buyerCredit.isNotEmpty) {
          await DatabaseService.insert(
            DatabaseType.server,
            'moment_keep_users.db',
            'buyer_credit_scores',
            buyerCredit.first,
          );
        }

        final sellerCredit = await DatabaseService.query(
          DatabaseType.local,
          'moment_keep.db',
          'seller_credit_scores',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        if (sellerCredit.isNotEmpty) {
          await DatabaseService.insert(
            DatabaseType.server,
            'moment_keep_users.db',
            'seller_credit_scores',
            sellerCredit.first,
          );
        }
      }

      print('用户数据同步成功');
      return true;
    } catch (e) {
      print('用户数据同步失败: $e');
      return false;
    }
  }

  /// 同步商品数据
  static Future<bool> syncProductData() async {
    try {
      print('开始同步商品数据');
      
      // 从本地数据库读取商品数据
      final localProducts = await DatabaseService.query(
        DatabaseType.local,
        'moment_keep.db',
        'products',
      );

      // 同步到服务器数据库
      for (final product in localProducts) {
        await DatabaseService.insert(
          DatabaseType.server,
          'moment_keep_ecommerce.db',
          'products',
          product,
        );

        // 同步商品图片
        final productId = product['product_id'];
        final imageFiles = StorageService.getFileList(
          StorageType.local,
          subType: 'products/$productId',
        );

        for (final imageFile in imageFiles) {
          final imageData = await StorageService.readFile(
            StorageType.local,
            'products/$productId/$imageFile',
          );
          if (imageData != null) {
            await StorageService.saveFile(
              StorageType.product,
              '$productId/$imageFile',
              imageData,
            );
          }
        }
      }

      print('商品数据同步成功');
      return true;
    } catch (e) {
      print('商品数据同步失败: $e');
      return false;
    }
  }

  /// 同步订单数据
  static Future<bool> syncOrderData() async {
    try {
      print('开始同步订单数据');
      
      // 从本地数据库读取订单数据
      final localOrders = await DatabaseService.query(
        DatabaseType.local,
        'moment_keep.db',
        'orders',
      );

      // 同步到服务器数据库
      for (final order in localOrders) {
        await DatabaseService.insert(
          DatabaseType.server,
          'moment_keep_ecommerce.db',
          'orders',
          order,
        );

        // 同步订单商品
        final orderId = order['order_id'];
        final orderItems = await DatabaseService.query(
          DatabaseType.local,
          'moment_keep.db',
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );

        for (final item in orderItems) {
          await DatabaseService.insert(
            DatabaseType.server,
            'moment_keep_ecommerce.db',
            'order_items',
            item,
          );
        }
      }

      print('订单数据同步成功');
      return true;
    } catch (e) {
      print('订单数据同步失败: $e');
      return false;
    }
  }

  /// 同步日记数据
  static Future<bool> syncDiaryData() async {
    try {
      print('开始同步日记数据');
      
      // 从本地数据库读取日记数据
      final localDiaries = await DatabaseService.query(
        DatabaseType.local,
        'moment_keep.db',
        'diaries',
      );

      // 同步到服务器数据库
      for (final diary in localDiaries) {
        await DatabaseService.insert(
          DatabaseType.server,
          'moment_keep.db',
          'diaries',
          diary,
        );

        // 同步日记附件
        final diaryId = diary['diary_id'];
        final userId = diary['user_id'];
        final attachmentFiles = StorageService.getFileList(
          StorageType.user,
          userId: userId,
          subType: 'diaries/$diaryId',
        );

        for (final attachmentFile in attachmentFiles) {
          final attachmentData = await StorageService.readFile(
            StorageType.user,
            'diaries/$diaryId/$attachmentFile',
            userId: userId,
          );
          if (attachmentData != null) {
            await StorageService.saveFile(
              StorageType.cloud,
              'diaries/$userId/$diaryId/$attachmentFile',
              attachmentData,
            );
          }
        }
      }

      print('日记数据同步成功');
      return true;
    } catch (e) {
      print('日记数据同步失败: $e');
      return false;
    }
  }

  /// 同步文件
  /// [type] 文件类型
  /// [filename] 文件名
  /// [userId] 用户ID（当type为StorageType.user时需要）
  static Future<bool> syncFile(
    StorageType type,
    String filename,
    {String? userId},
  ) async {
    try {
      print('开始同步文件: $filename');

      // 从本地读取文件
      final fileData = await StorageService.readFile(
        type,
        filename,
        userId: userId,
      );

      if (fileData == null) {
        print('文件不存在: $filename');
        return false;
      }

      // 同步到服务器
      await StorageService.saveFile(
        StorageType.cloud,
        filename,
        fileData,
      );

      print('文件同步成功: $filename');
      return true;
    } catch (e) {
      print('文件同步失败: $e');
      return false;
    }
  }

  /// 从服务器同步到本地
  /// [type] 数据类型
  static Future<bool> syncFromServer(String type) async {
    try {
      print('开始从服务器同步数据: $type');

      switch (type) {
        case 'users':
          // 从服务器读取用户数据
          final serverUsers = await DatabaseService.query(
            DatabaseType.server,
            'moment_keep_users.db',
            'users',
          );

          // 同步到本地数据库
          for (final user in serverUsers) {
            await DatabaseService.insert(
              DatabaseType.local,
              'moment_keep.db',
              'users',
              user,
            );
          }
          break;

        case 'products':
          // 从服务器读取商品数据
          final serverProducts = await DatabaseService.query(
            DatabaseType.server,
            'moment_keep_ecommerce.db',
            'products',
          );

          // 同步到本地数据库
          for (final product in serverProducts) {
            await DatabaseService.insert(
              DatabaseType.local,
              'moment_keep.db',
              'products',
              product,
            );
          }
          break;

        case 'orders':
          // 从服务器读取订单数据
          final serverOrders = await DatabaseService.query(
            DatabaseType.server,
            'moment_keep_ecommerce.db',
            'orders',
          );

          // 同步到本地数据库
          for (final order in serverOrders) {
            await DatabaseService.insert(
              DatabaseType.local,
              'moment_keep.db',
              'orders',
              order,
            );
          }
          break;

        case 'diaries':
          // 从服务器读取日记数据
          final serverDiaries = await DatabaseService.query(
            DatabaseType.server,
            'moment_keep.db',
            'diaries',
          );

          // 同步到本地数据库
          for (final diary in serverDiaries) {
            await DatabaseService.insert(
              DatabaseType.local,
              'moment_keep.db',
              'diaries',
              diary,
            );
          }
          break;

        default:
          print('未知的数据类型: $type');
          return false;
      }

      print('从服务器同步数据成功: $type');
      return true;
    } catch (e) {
      print('从服务器同步数据失败: $e');
      return false;
    }
  }

  /// 取消同步
  static void cancelSync() {
    _isSyncing = false;
    _syncProgress = 0.0;
    _syncProgressController.add(_syncProgress);
    print('同步已取消');
  }

  /// 获取同步状态
  static bool get isSyncing => _isSyncing;

  /// 获取当前同步进度
  static double get syncProgress => _syncProgress;

  /// 关闭同步服务
  static void dispose() {
    _syncProgressController.close();
  }
}
