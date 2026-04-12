import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/category.dart' as entities;
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';

/// 分类 Repository
/// 负责本地 SharedPreferences �?Supabase 之间的数据访问和同步
class CategoryRepository {
  /// 单例实例
  static final CategoryRepository _instance = CategoryRepository._internal();

  /// Supabase 服务
  final SupabaseService _supabase = SupabaseService();

  /// 同步管理�?  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  /// SharedPreferences Key
  static const String _prefsKey = 'categories';

  /// 私有构造函�?  CategoryRepository._internal();

  /// 工厂构造函�?  factory CategoryRepository() => _instance;

  /// 获取所有分�?  Future<List<entities.Category>> getAll() async {
    try {
      final categories = await _queryLocal();
      _log('获取�?${categories.length} 个分�?);
      return categories;
    } catch (e) {
      _log('获取所有分类失�? $e');
      return [];
    }
  }

  /// 根据 ID 获取分类
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

  /// 插入分类
  Future<String> insert(entities.Category item) async {
    try {
      final categories = await _queryLocal();
      categories.add(item);
      await _saveLocal(categories);
      _log('插入分类: ${item.id}');

      // 如果启用了同步，推送到服务�?      if (_supabase.isInitialized) {
        try {
          await _syncManager.pushOperation(
            table: 'categories',
            id: item.id,
            type: SyncOperationType.insert,
            data: item.toJson(),
          );
          _log('分类已推送到 Supabase: ${item.id}');
        } catch (e) {
          _log('推送分类到 Supabase 失败: $e');
        }
      }

      return item.id;
    } catch (e) {
      _log('插入分类失败: $e');
      rethrow;
    }
  }

  /// 更新分类
  Future<void> update(String id, entities.Category item) async {
    try {
      final categories = await _queryLocal();
      final index = categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        categories[index] = item;
        await _saveLocal(categories);
        _log('更新分类: $id');

        // 如果启用了同步，推送到服务�?        if (_supabase.isInitialized) {
          try {
            await _syncManager.pushOperation(
              table: 'categories',
              id: id,
              type: SyncOperationType.update,
              data: item.toJson(),
            );
            _log('分类已推送到 Supabase: $id');
          } catch (e) {
            _log('推送分类到 Supabase 失败: $e');
          }
        }
      } else {
        _log('未找到分�? $id');
      }
    } catch (e) {
      _log('更新分类失败: $e');
      rethrow;
    }
  }

  /// 删除分类
  Future<void> delete(String id) async {
    try {
      final categories = await _queryLocal();
      categories.removeWhere((c) => c.id == id);
      await _saveLocal(categories);
      _log('删除分类: $id');

      // 如果启用了同步，从服务器删除
      if (_supabase.isInitialized) {
        try {
          await _syncManager.pushOperation(
            table: 'categories',
            id: id,
            type: SyncOperationType.delete,
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

  /// 批量插入分类
  Future<void> insertAll(List<entities.Category> items) async {
    try {
      final categories = await _queryLocal();
      categories.addAll(items);
      await _saveLocal(categories);
      _log('批量插入 ${items.length} 个分�?);
    } catch (e) {
      _log('批量插入分类失败: $e');
      rethrow;
    }
  }

  /// 根据类型获取分类
  Future<List<entities.Category>> getByType(
      entities.CategoryType type) async {
    try {
      final categories = await _queryLocal();
      final filtered = categories.where((c) => c.type == type).toList();
      _log('按类型查询到 ${filtered.length} 个分�?);
      return filtered;
    } catch (e) {
      _log('按类型查询分类失�? $e');
      return [];
    }
  }

  /// 清空所有分�?  Future<void> clearAll() async {
    try {
      await _saveLocal([]);
      _log('清空所有分�?);
    } catch (e) {
      _log('清空分类失败: $e');
      rethrow;
    }
  }

  /// 从本�?SharedPreferences 查询的辅助方�?  Future<List<entities.Category>> _queryLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) =>
              entities.Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('解析分类数据失败: $e');
      return [];
    }
  }

  /// 保存到本�?SharedPreferences
  Future<void> _saveLocal(List<entities.Category> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = categories.map((category) => category.toJson()).toList();
    await prefs.setString(_prefsKey, json.encode(jsonList));
  }

  /// 日志打印
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[CategoryRepository] $message');
    }
  }
}
