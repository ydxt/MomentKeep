import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:moment_keep/domain/entities/pomodoro.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';
import 'package:moment_keep/services/database_service.dart';

/// 番茄钟Repository
/// 负责本地 SQLite 和 Supabase 之间的数据访问和同步
class PomodoroRepository {
  /// 单例实例
  static final PomodoroRepository _instance = PomodoroRepository._internal();

  /// 数据库服务
  final DatabaseService _databaseService = DatabaseService();

  /// Supabase 服务
  final SupabaseService _supabase = SupabaseService();

  /// 同步管理
  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  /// 表名
  static const String _tableName = 'pomodoro_records';

  /// 私有构造函数
  PomodoroRepository._internal();

  /// 工厂构造函数
  factory PomodoroRepository() => _instance;

  /// 获取所有番茄钟记录
  Future<List<Pomodoro>> getAll() async {
    try {
      final records = await _queryLocal();
      _log('获取${records.length} 个番茄钟记录');
      return records;
    } catch (e) {
      _log('获取所有番茄钟记录失败: $e');
      return [];
    }
  }

  /// 根据 ID 获取番茄钟记录
  Future<Pomodoro?> getById(String id) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        _log('未找到番茄钟记录: $id');
        return null;
      }

      final record = Pomodoro.fromJson(maps.first);
      _log('获取番茄钟记录: $id');
      return record;
    } catch (e) {
      _log('获取番茄钟记录失败: $e');
      return null;
    }
  }

  /// 插入番茄钟记录
  Future<String> insert(Pomodoro item) async {
    try {
      final db = await _databaseService.database;
      await db.insert(
        _tableName,
        item.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _log('插入番茄钟记录: ${item.id}');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'pomodoro_records',
              id: item.id,
              type: SyncOperationType.insert,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('番茄钟记录已推送到 Supabase: ${item.id}');
        } catch (e) {
          _log('推送番茄钟记录到 Supabase 失败: $e');
        }
      }

      return item.id;
    } catch (e) {
      _log('插入番茄钟记录失败: $e');
      rethrow;
    }
  }

  /// 更新番茄钟记录
  Future<void> update(String id, Pomodoro item) async {
    try {
      final db = await _databaseService.database;
      await db.update(
        _tableName,
        item.toJson(),
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('更新番茄钟记录: $id');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'pomodoro_records',
              id: id,
              type: SyncOperationType.update,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('番茄钟记录已推送到 Supabase: $id');
        } catch (e) {
          _log('推送番茄钟记录到 Supabase 失败: $e');
        }
      }
    } catch (e) {
      _log('更新番茄钟记录失败: $e');
      rethrow;
    }
  }

  /// 删除番茄钟记录
  Future<void> delete(String id) async {
    try {
      final db = await _databaseService.database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('删除番茄钟记录: $id');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'pomodoro_records',
              id: id,
              type: SyncOperationType.delete,
              timestamp: DateTime.now(),
            ),
          );
          _log('番茄钟记录删除已推送到 Supabase: $id');
        } catch (e) {
          _log('推送删除到 Supabase 失败: $e');
        }
      }
    } catch (e) {
      _log('删除番茄钟记录失败: $e');
      rethrow;
    }
  }

  /// 批量插入番茄钟记录
  Future<void> insertAll(List<Pomodoro> items) async {
    try {
      final db = await _databaseService.database;
      final batch = db.batch();

      for (final item in items) {
        batch.insert(
          _tableName,
          item.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      _log('批量插入 ${items.length} 个番茄钟记录');
    } catch (e) {
      _log('批量插入番茄钟记录失败: $e');
      rethrow;
    }
  }

  /// 按日期范围查询番茄钟记录
  Future<List<Pomodoro>> getByDateRange(DateTime start, DateTime end) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'start_time >= ? AND start_time <= ?',
        whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
        orderBy: 'start_time DESC',
      );

      final records =
          maps.map((map) => Pomodoro.fromJson(map)).toList();
      _log('按日期范围查询到 ${records.length} 个番茄钟记录');
      return records;
    } catch (e) {
      _log('按日期范围查询番茄钟记录失败: $e');
      return [];
    }
  }

  /// 按标签查询番茄钟记录
  Future<List<Pomodoro>> getByTag(String tag) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'tag = ?',
        whereArgs: [tag],
        orderBy: 'start_time DESC',
      );

      final records =
          maps.map((map) => Pomodoro.fromJson(map)).toList();
      _log('按标签查询到 ${records.length} 个番茄钟记录');
      return records;
    } catch (e) {
      _log('按标签查询番茄钟记录失败: $e');
      return [];
    }
  }

  /// 获取总专注时长（秒）
  Future<int> getTotalDuration() async {
    try {
      final records = await _queryLocal();
      final total = records.fold<int>(
        0,
        (sum, record) => sum + record.duration,
      );
      _log('总专注时长: $total 秒');
      return total;
    } catch (e) {
      _log('获取总专注时长失败: $e');
      return 0;
    }
  }

  /// 清空所有番茄钟记录
  Future<void> clearAll() async {
    try {
      final db = await _databaseService.database;
      await db.delete(_tableName);
      _log('清空所有番茄钟记录');
    } catch (e) {
      _log('清空番茄钟记录失败: $e');
      rethrow;
    }
  }

  /// 从本SQLite 查询所有番茄钟记录
  Future<List<Pomodoro>> _queryLocal() async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        orderBy: 'start_time DESC',
      );

      return maps.map((map) => Pomodoro.fromJson(map)).toList();
    } catch (e) {
      _log('查询本地番茄钟记录失败: $e');
      return [];
    }
  }

  /// 日志打印
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[PomodoroRepository] $message');
    }
  }
}
