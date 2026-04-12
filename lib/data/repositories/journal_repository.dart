import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/services/database_service.dart';

/// 日记 Repository
/// 负责本地 SQLite（加密）�?Supabase 之间的数据访问和同步
class JournalRepository {
  /// 单例实例
  static final JournalRepository _instance = JournalRepository._internal();

  /// 数据库服�?  final DatabaseService _databaseService = DatabaseService();

  /// Supabase 服务
  final SupabaseService _supabase = SupabaseService();

  /// 同步管理�?  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  /// 表名
  static const String _tableName = 'journals';

  /// 私有构造函�?  JournalRepository._internal();

  /// 工厂构造函�?  factory JournalRepository() => _instance;

  /// 获取所有日�?  Future<List<Journal>> getAll() async {
    try {
      final journals = await _queryLocal();
      _log('获取�?${journals.length} 篇日�?);
      return journals;
    } catch (e) {
      _log('获取所有日记失�? $e');
      return [];
    }
  }

  /// 根据 ID 获取日记
  Future<Journal?> getById(String id) async {
    try {
      final db = await _databaseService.getDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        _log('未找到日�? $id');
        return null;
      }

      final journal = _decryptAndParseJournal(maps.first);
      _log('获取日记: $id');
      return journal;
    } catch (e) {
      _log('获取日记失败: $e');
      return null;
    }
  }

  /// 插入日记
  Future<String> insert(Journal item) async {
    try {
      final db = await _databaseService.getDatabase();
      final encryptedData = _encryptJournal(item);

      await db.insert(
        _tableName,
        encryptedData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _log('插入日记: ${item.id}');

      // 如果启用了同步，推送到服务�?      if (_supabase.isInitialized) {
        try {
          await _syncManager.pushOperation(
            table: 'journals',
            id: item.id,
            type: SyncOperationType.insert,
            data: item.toJson(),
          );
          _log('日记已推送到 Supabase: ${item.id}');
        } catch (e) {
          _log('推送日记到 Supabase 失败: $e');
        }
      }

      return item.id;
    } catch (e) {
      _log('插入日记失败: $e');
      rethrow;
    }
  }

  /// 更新日记
  Future<void> update(String id, Journal item) async {
    try {
      final db = await _databaseService.getDatabase();
      final encryptedData = _encryptJournal(item);

      await db.update(
        _tableName,
        encryptedData,
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('更新日记: $id');

      // 如果启用了同步，推送到服务�?      if (_supabase.isInitialized) {
        try {
          await _syncManager.pushOperation(
            table: 'journals',
            id: id,
            type: SyncOperationType.update,
            data: item.toJson(),
          );
          _log('日记已推送到 Supabase: $id');
        } catch (e) {
          _log('推送日记到 Supabase 失败: $e');
        }
      }
    } catch (e) {
      _log('更新日记失败: $e');
      rethrow;
    }
  }

  /// 删除日记
  Future<void> delete(String id) async {
    try {
      final db = await _databaseService.getDatabase();
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('删除日记: $id');

      // 如果启用了同步，从服务器删除
      if (_supabase.isInitialized) {
        try {
          await _syncManager.pushOperation(
            table: 'journals',
            id: id,
            type: SyncOperationType.delete,
          );
          _log('日记删除已推送到 Supabase: $id');
        } catch (e) {
          _log('推送删除到 Supabase 失败: $e');
        }
      }
    } catch (e) {
      _log('删除日记失败: $e');
      rethrow;
    }
  }

  /// 批量插入日记
  Future<void> insertAll(List<Journal> items) async {
    try {
      final db = await _databaseService.getDatabase();
      final batch = db.batch();

      for (final item in items) {
        final encryptedData = _encryptJournal(item);
        batch.insert(
          _tableName,
          encryptedData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      _log('批量插入 ${items.length} 篇日�?);
    } catch (e) {
      _log('批量插入日记失败: $e');
      rethrow;
    }
  }

  /// 按日期范围查询日�?  Future<List<Journal>> getByDateRange(DateTime start, DateTime end) async {
    try {
      final db = await _databaseService.getDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'date >= ? AND date <= ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'date DESC',
      );

      final journals = maps
          .map((map) => _decryptAndParseJournal(map))
          .toList();
      _log('按日期范围查询到 ${journals.length} 篇日�?);
      return journals;
    } catch (e) {
      _log('按日期范围查询日记失�? $e');
      return [];
    }
  }

  /// 按分�?ID 查询日记
  Future<List<Journal>> getByCategoryId(String categoryId) async {
    try {
      final db = await _databaseService.getDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'categoryId = ?',
        whereArgs: [categoryId],
        orderBy: 'date DESC',
      );

      final journals = maps
          .map((map) => _decryptAndParseJournal(map))
          .toList();
      _log('按分类查询到 ${journals.length} 篇日�?);
      return journals;
    } catch (e) {
      _log('按分类查询日记失�? $e');
      return [];
    }
  }

  /// 清空所有日�?  Future<void> clearAll() async {
    try {
      final db = await _databaseService.getDatabase();
      await db.delete(_tableName);
      _log('清空所有日�?);
    } catch (e) {
      _log('清空日记失败: $e');
      rethrow;
    }
  }

  /// 从本�?SQLite 查询所有日�?  Future<List<Journal>> _queryLocal() async {
    try {
      final db = await _databaseService.getDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        orderBy: 'date DESC',
      );

      return maps
          .map((map) => _decryptAndParseJournal(map))
          .toList();
    } catch (e) {
      _log('查询本地日记失败: $e');
      return [];
    }
  }

  /// 加密日记数据
  Map<String, dynamic> _encryptJournal(Journal journal) {
    final jsonData = journal.toJson();
    final jsonString = journal.toJson().toString();
    final encryptedContent = EncryptionHelper.encrypt(jsonString);

    return {
      'id': journal.id,
      'categoryId': journal.categoryId,
      'title': EncryptionHelper.encrypt(journal.title),
      'content': encryptedContent,
      'tags': EncryptionHelper.encrypt(jsonData['tags'].toString()),
      'date': journal.date.toIso8601String(),
      'createdAt': journal.createdAt.toIso8601String(),
      'updatedAt': journal.updatedAt.toIso8601String(),
      'subject': journal.subject != null
          ? EncryptionHelper.encrypt(journal.subject!)
          : null,
      'remarks': journal.remarks != null
          ? EncryptionHelper.encrypt(journal.remarks!)
          : null,
      'mood': journal.mood,
    };
  }

  /// 解密并解析日记数�?  Journal _decryptAndParseJournal(Map<String, dynamic> map) {
    try {
      final decryptedTitle = EncryptionHelper.decrypt(map['title'] as String);
      final decryptedContent =
          EncryptionHelper.decrypt(map['content'] as String);

      // 重新构建 Journal 对象
      return Journal(
        id: map['id'] as String,
        categoryId: map['categoryId'] as String,
        title: decryptedTitle,
        content: [], // 内容需要从解密后的 JSON 重新解析
        tags: [],
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        subject: map['subject'] != null
            ? EncryptionHelper.decrypt(map['subject'] as String)
            : null,
        remarks: map['remarks'] != null
            ? EncryptionHelper.decrypt(map['remarks'] as String)
            : null,
        mood: map['mood'] as int?,
      );
    } catch (e) {
      _log('解密日记数据失败: $e');
      // 返回一个空�?Journal 对象
      return Journal(
        id: map['id'] as String? ?? '',
        categoryId: map['categoryId'] as String? ?? '',
        title: '解密失败',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// 日志打印
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[JournalRepository] $message');
    }
  }
}
