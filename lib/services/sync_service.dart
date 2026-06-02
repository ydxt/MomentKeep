import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:moment_keep/services/storage_path_service.dart';
import 'package:moment_keep/services/storage_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:path/path.dart' as p;

class SyncService {
  static bool _isSyncing = false;
  static double _syncProgress = 0.0;
  static final StreamController<double> _syncProgressController = StreamController<double>.broadcast();
  static final StreamController<String> _syncStatusController = StreamController<String>.broadcast();

  static Stream<double> get syncProgressStream => _syncProgressController.stream;
  static Stream<String> get syncStatusStream => _syncStatusController.stream;
  static bool get isSyncing => _isSyncing;
  static double get syncProgress => _syncProgress;

  static Future<void> initialize() async {
    await StoragePathService.initialize();
  }

  static Future<bool> syncAllData() async {
    if (_isSyncing) {
      debugPrint('同步已在进行中');
      return false;
    }

    _isSyncing = true;
    _syncProgress = 0.0;
    _syncProgressController.add(_syncProgress);

    try {
      _updateStatus('同步用户数据...');
      if (!await syncUserData()) {
        throw Exception('用户数据同步失败');
      }
      _syncProgress = 0.2;
      _syncProgressController.add(_syncProgress);

      _updateStatus('同步商品数据...');
      if (!await syncProductData()) {
        throw Exception('商品数据同步失败');
      }
      _syncProgress = 0.4;
      _syncProgressController.add(_syncProgress);

      _updateStatus('同步订单数据...');
      if (!await syncOrderData()) {
        throw Exception('订单数据同步失败');
      }
      _syncProgress = 0.6;
      _syncProgressController.add(_syncProgress);

      _updateStatus('同步日记数据...');
      if (!await syncDiaryData()) {
        throw Exception('日记数据同步失败');
      }
      _syncProgress = 0.8;
      _syncProgressController.add(_syncProgress);

      _updateStatus('同步商店数据...');
      if (!await syncStoreData()) {
        throw Exception('商店数据同步失败');
      }
      _syncProgress = 1.0;
      _syncProgressController.add(_syncProgress);

      _updateStatus('同步完成');
      debugPrint('所有数据同步成功');
      return true;
    } catch (e) {
      debugPrint('同步失败: $e');
      _updateStatus('同步失败: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  static void _updateStatus(String status) {
    _syncStatusController.add(status);
    debugPrint(status);
  }

  static Future<String> _getCloudDbPath() async {
    final cloudDir = await StoragePathService.getServerDatabaseDirectory();
    return cloudDir;
  }

  static Future<bool> _exportTableToCloud(
    dynamic db,
    String tableName, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final cloudDbDir = await _getCloudDbPath();
      final rows = await db.query(tableName, where: where, whereArgs: whereArgs);
      final jsonData = jsonEncode(rows);
      final filePath = p.join(cloudDbDir, '$tableName.json');
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonData);
      debugPrint('导出 $tableName: ${rows.length} 条 → $filePath');
      return true;
    } catch (e) {
      debugPrint('导出 $tableName 失败: $e');
      return false;
    }
  }

  static Future<bool> _importTableFromCloud(
    dynamic db,
    String tableName, {
    List<String> conflictColumns = const ['id'],
  }) async {
    try {
      final cloudDbDir = await _getCloudDbPath();
      final filePath = p.join(cloudDbDir, '$tableName.json');
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('云端无 $tableName 数据，跳过导入');
        return true;
      }
      final jsonData = await file.readAsString();
      final List<dynamic> rows = jsonDecode(jsonData);
      if (rows.isEmpty) {
        debugPrint('云端 $tableName 数据为空，跳过导入');
        return true;
      }

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        final whereExpr = conflictColumns.map((c) => '$c = ?').join(' AND ');
        final whereValues = conflictColumns.map((c) => map[c]).toList();
        final existing = await db.query(tableName, where: whereExpr, whereArgs: whereValues, limit: 1);
        if (existing.isEmpty) {
          await db.insert(tableName, map);
        } else {
          await db.update(tableName, map, where: whereExpr, whereArgs: whereValues);
        }
      }
      debugPrint('导入 $tableName: ${rows.length} 条');
      return true;
    } catch (e) {
      debugPrint('导入 $tableName 失败: $e');
      return false;
    }
  }

  static Future<bool> syncUserData() async {
    try {
      debugPrint('开始同步用户数据');
      final db = await DatabaseService().database;
      if (!await _exportTableToCloud(db, 'users')) {
        return false;
      }
      debugPrint('用户数据同步成功');
      return true;
    } catch (e) {
      debugPrint('用户数据同步失败: $e');
      return false;
    }
  }

  static Future<bool> syncProductData() async {
    try {
      debugPrint('开始同步商品数据');
      final db = await ProductDatabaseService().database;
      final tables = [
        'star_categories',
        'star_products',
        'star_product_skus',
        'star_product_specs',
        'promotions',
        'card_secrets',
        'product_questions',
      ];
      for (final table in tables) {
        if (!await _exportTableToCloud(db, table)) {
          return false;
        }
      }
      debugPrint('商品数据同步成功');
      return true;
    } catch (e) {
      debugPrint('商品数据同步失败: $e');
      return false;
    }
  }

  static Future<bool> syncOrderData() async {
    try {
      debugPrint('开始同步订单数据');
      final db = await ProductDatabaseService().database;
      final tables = [
        'orders',
        'payment_records',
        'refund_requests',
        'refund_settings',
        'return_logistics',
        'invoices',
        'real_name_auth',
      ];
      for (final table in tables) {
        if (!await _exportTableToCloud(db, table)) {
          return false;
        }
      }
      debugPrint('订单数据同步成功');
      return true;
    } catch (e) {
      debugPrint('订单数据同步失败: $e');
      return false;
    }
  }

  static Future<bool> syncDiaryData() async {
    try {
      debugPrint('开始同步日记数据');
      final db = await DatabaseService().database;
      if (!await _exportTableToCloud(db, 'diaries')) {
        return false;
      }
      debugPrint('日记数据同步成功');
      return true;
    } catch (e) {
      debugPrint('日记数据同步失败: $e');
      return false;
    }
  }

  static Future<bool> syncStoreData() async {
    try {
      debugPrint('开始同步商店数据');
      final db = await ProductDatabaseService().database;
      final tables = [
        'cart_items',
        'addresses',
        'coupons',
        'user_coupons',
        'red_packets',
        'red_packet_claims',
        'shopping_cards',
        'shopping_card_transactions',
        'member_levels',
        'logistics_companies',
        'logistics_tracks',
        'merchants',
        'stock_records',
        'favorite_products',
        'browsing_history',
        'reviews',
        'cleanup_logs',
        'operation_logs',
      ];
      for (final table in tables) {
        if (!await _exportTableToCloud(db, table)) {
          return false;
        }
      }
      debugPrint('商店数据同步成功');
      return true;
    } catch (e) {
      debugPrint('商店数据同步失败: $e');
      return false;
    }
  }

  static Future<bool> syncFile(
    StorageType type,
    String filename, {
    String? userId,
  }) async {
    try {
      debugPrint('开始同步文件: $filename');
      final fileData = await StorageService.readFile(type, filename, userId: userId);
      if (fileData == null) {
        debugPrint('文件不存在: $filename');
        return false;
      }
      await StorageService.saveFile(StorageType.cloud, filename, fileData);
      debugPrint('文件同步成功: $filename');
      return true;
    } catch (e) {
      debugPrint('文件同步失败: $e');
      return false;
    }
  }

  static Future<bool> syncFromServer(String type) async {
    try {
      debugPrint('开始从服务器同步数据: $type');
      final db = await ProductDatabaseService().database;
      final mainDb = await DatabaseService().database;

      final tableMapping = <String, dynamic>{
        'users': mainDb,
        'diaries': mainDb,
        'star_categories': db,
        'star_products': db,
        'star_product_skus': db,
        'star_product_specs': db,
        'orders': db,
        'payment_records': db,
        'cart_items': db,
        'addresses': db,
        'coupons': db,
        'user_coupons': db,
        'red_packets': db,
        'red_packet_claims': db,
        'shopping_cards': db,
        'shopping_card_transactions': db,
        'member_levels': db,
        'logistics_companies': db,
        'logistics_tracks': db,
        'merchants': db,
        'stock_records': db,
        'favorite_products': db,
        'browsing_history': db,
        'reviews': db,
        'refund_requests': db,
        'refund_settings': db,
        'return_logistics': db,
        'invoices': db,
        'real_name_auth': db,
        'promotions': db,
        'card_secrets': db,
        'product_questions': db,
        'cleanup_logs': db,
        'operation_logs': db,
      };

      if (type == 'all') {
        for (final entry in tableMapping.entries) {
          if (!await _importTableFromCloud(entry.value, entry.key)) {
            debugPrint('从服务器同步 ${entry.key} 失败');
          }
        }
      } else if (tableMapping.containsKey(type)) {
        if (!await _importTableFromCloud(tableMapping[type]!, type)) {
          debugPrint('从服务器同步 $type 失败');
          return false;
        }
      } else {
        debugPrint('未知的数据类型: $type');
        return false;
      }

      debugPrint('从服务器同步数据成功: $type');
      return true;
    } catch (e) {
      debugPrint('从服务器同步数据失败: $e');
      return false;
    }
  }

  static Future<DateTime?> getLastSyncTime() async {
    try {
      final cloudDbDir = await _getCloudDbPath();
      final filePath = p.join(cloudDbDir, 'users.json');
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final stat = await file.stat();
      return stat.modified;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, int>> getCloudDataStats() async {
    try {
      final cloudDbDir = await _getCloudDbPath();
      final dir = Directory(cloudDbDir);
      if (!dir.existsSync()) return {};

      final stats = <String, int>{};
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final tableName = p.basenameWithoutExtension(entity.path);
          final content = await entity.readAsString();
          final List<dynamic> rows = jsonDecode(content);
          stats[tableName] = rows.length;
        }
      }
      return stats;
    } catch (e) {
      debugPrint('获取云端数据统计失败: $e');
      return {};
    }
  }

  static void cancelSync() {
    _isSyncing = false;
    _syncProgress = 0.0;
    _syncProgressController.add(_syncProgress);
    _updateStatus('同步已取消');
  }

  static void dispose() {
    _syncProgressController.close();
    _syncStatusController.close();
  }
}
