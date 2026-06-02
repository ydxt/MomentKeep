import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:moment_keep/domain/entities/category.dart' as entities;
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';
import 'package:moment_keep/services/database_service.dart';

class CategoryRepository {
  static final CategoryRepository _instance = CategoryRepository._internal();

  final SupabaseService _supabase = SupabaseService();

  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  final _dbService = DatabaseService();

  CategoryRepository._internal();

  factory CategoryRepository() => _instance;

  Future<List<entities.Category>> getAll() async {
    try {
      final categories = await _queryLocal();
      _log('获取${categories.length} 个分类');
      return categories;
    } catch (e) {
      _log('获取所有分类失败: $e');
      return [];
    }
  }

  Future<entities.Category?> getById(String id) async {
    try {
      final categories = await _queryLocal();
      final category =
          categories.where((c) => c.id == id).toList().firstOrNull;
      _log('获取分类: $id');
      return category;
    } catch (e) {
      _log('获取分类失败: $e');
      return null;
    }
  }

  Future<String> insert(entities.Category item) async {
    try {
      final userId = await _dbService.getCurrentUserId() ?? 'default_user';
      final dataJson = jsonEncode({
        'isExpanded': item.isExpanded,
        'isQuestionBank': item.isQuestionBank,
      });
      final rowId = await _dbService.insertCategory(userId, {
        'name': item.name,
        'icon': item.icon,
        'color': item.color,
        'type': item.type.toString().split('.').last,
        'sort_order': 0,
        'data': dataJson,
      });
      _log('插入分类: ${item.id} (db row: $rowId)');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'categories',
              id: item.id,
              type: SyncOperationType.insert,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('分类已推送到 Supabase: ${item.id}');
        } catch (e) {
          _log('推送分类到 Supabase 失败: $e');
        }
      }

      return rowId.toString();
    } catch (e) {
      _log('插入分类失败: $e');
      rethrow;
    }
  }

  Future<void> update(String id, entities.Category item) async {
    try {
      final dbId = int.tryParse(id);
      if (dbId != null) {
        final dataJson = jsonEncode({
          'isExpanded': item.isExpanded,
          'isQuestionBank': item.isQuestionBank,
        });
        await _dbService.updateCategory(dbId, {
          'name': item.name,
          'icon': item.icon,
          'color': item.color,
          'type': item.type.toString().split('.').last,
          'data': dataJson,
        });
        _log('更新分类: $id');
      }

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'categories',
              id: id,
              type: SyncOperationType.update,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('分类已推送到 Supabase: $id');
        } catch (e) {
          _log('推送分类到 Supabase 失败: $e');
        }
      }
    } catch (e) {
      _log('更新分类失败: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final dbId = int.tryParse(id);
      if (dbId != null) {
        await _dbService.deleteCategory(dbId);
        _log('删除分类: $id');
      }

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'categories',
              id: id,
              type: SyncOperationType.delete,
              timestamp: DateTime.now(),
            ),
          );
          _log('分类删除已推送到 Supabase: $id');
        } catch (e) {
          _log('推送删除到 Supabase 失败: $e');
        }
      }
    } catch (e) {
      _log('删除分类失败: $e');
      rethrow;
    }
  }

  Future<void> insertAll(List<entities.Category> items) async {
    try {
      final userId = await _dbService.getCurrentUserId() ?? 'default_user';
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final dataJson = jsonEncode({
          'isExpanded': item.isExpanded,
          'isQuestionBank': item.isQuestionBank,
        });
        await _dbService.insertCategory(userId, {
          'name': item.name,
          'icon': item.icon,
          'color': item.color,
          'type': item.type.toString().split('.').last,
          'sort_order': i,
          'data': dataJson,
        });
      }
      _log('批量插入 ${items.length} 个分类');
    } catch (e) {
      _log('批量插入分类失败: $e');
      rethrow;
    }
  }

  Future<List<entities.Category>> getByType(
      entities.CategoryType type) async {
    try {
      final categories = await _queryLocal();
      final filtered = categories.where((c) => c.type == type).toList();
      _log('按类型查询到 ${filtered.length} 个分类');
      return filtered;
    } catch (e) {
      _log('按类型查询分类失败: $e');
      return [];
    }
  }

  Future<void> clearAll() async {
    try {
      final userId = await _dbService.getCurrentUserId() ?? 'default_user';
      await _dbService.clearCategories(userId);
      _log('清空所有分类');
    } catch (e) {
      _log('清空分类失败: $e');
      rethrow;
    }
  }

  Future<List<entities.Category>> _queryLocal() async {
    final userId = await _dbService.getCurrentUserId() ?? 'default_user';
    final rows = await _dbService.getCategories(userId);
    return rows.map((row) {
      final data = <String, dynamic>{};
      if (row['data'] != null) {
        try {
          data.addAll(jsonDecode(row['data'] as String) as Map<String, dynamic>);
        } catch (_) {}
      }
      return entities.Category(
        id: row['id'].toString(),
        name: row['name'] as String,
        type: entities.CategoryType.values.firstWhere(
          (e) => e.toString().split('.').last == row['type'],
          orElse: () => entities.CategoryType.todo,
        ),
        icon: (row['icon'] as String?) ?? '',
        color: (row['color'] as int?) ?? 0,
        isExpanded: data['isExpanded'] as bool? ?? false,
        isQuestionBank: data['isQuestionBank'] as bool? ?? false,
      );
    }).toList();
  }

  Future<void> _saveLocal(List<entities.Category> categories) async {
    final userId = await _dbService.getCurrentUserId() ?? 'default_user';
    await _dbService.clearCategories(userId);
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final dataJson = jsonEncode({
        'isExpanded': cat.isExpanded,
        'isQuestionBank': cat.isQuestionBank,
      });
      await _dbService.insertCategory(userId, {
        'name': cat.name,
        'icon': cat.icon,
        'color': cat.color,
        'type': cat.type.toString().split('.').last,
        'sort_order': i,
        'data': dataJson,
      });
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[CategoryRepository] $message');
    }
  }
}
