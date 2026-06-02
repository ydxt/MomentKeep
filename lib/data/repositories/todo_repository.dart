import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';

/// Todo Repository
/// Manages local SharedPreferences and Supabase data access and sync
class TodoRepository {
  /// Singleton instance
  static final TodoRepository _instance = TodoRepository._internal();

  /// Supabase service
  final SupabaseService _supabase = SupabaseService();

  /// Sync manager
  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  /// SharedPreferences Key
  static const String _prefsKey = 'todo_entries';

  /// Private constructor
  TodoRepository._internal();

  /// Factory constructor
  factory TodoRepository() => _instance;

  /// Get all todos
  Future<List<Todo>> getAll() async {
    try {
      final todos = await _queryLocal();
      _log('Retrieved ${todos.length} todos');
      return todos;
    } catch (e) {
      _log('Failed to get all todos: $e');
      return [];
    }
  }

  /// Get todo by ID
  Future<Todo?> getById(String id) async {
    try {
      final todos = await _queryLocal();
      final todo = todos.where((t) => t.id == id).toList().firstOrNull;
      _log('Get todo: $id');
      return todo;
    } catch (e) {
      _log('Failed to get todo: $e');
      return null;
    }
  }

  /// Insert a todo
  Future<String> insert(Todo item) async {
    try {
      final todos = await _queryLocal();
      todos.add(item);
      await _saveLocal(todos);
      _log('Insert todo: ${item.id}');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'todos',
              id: item.id,
              type: SyncOperationType.insert,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('Todo queued for Supabase: ${item.id}');
        } catch (e) {
          _log('Failed to queue todo to Supabase: $e');
        }
      }

      return item.id;
    } catch (e) {
      _log('Failed to insert todo: $e');
      rethrow;
    }
  }

  /// Update a todo
  Future<void> update(String id, Todo item) async {
    try {
      final todos = await _queryLocal();
      final index = todos.indexWhere((t) => t.id == id);
      if (index != -1) {
        todos[index] = item;
        await _saveLocal(todos);
        _log('Update todo: $id');

        if (_supabase.isInitialized) {
          try {
            await _syncManager.queueOperation(
              SyncOperation(
                table: 'todos',
                id: id,
                type: SyncOperationType.update,
                data: item.toJson(),
                timestamp: DateTime.now(),
              ),
            );
            _log('Todo queued for Supabase: $id');
          } catch (e) {
            _log('Failed to queue todo to Supabase: $e');
          }
        }
      } else {
        _log('Todo not found: $id');
      }
    } catch (e) {
      _log('Failed to update todo: $e');
      rethrow;
    }
  }

  /// Delete a todo
  Future<void> delete(String id) async {
    try {
      final todos = await _queryLocal();
      todos.removeWhere((t) => t.id == id);
      await _saveLocal(todos);
      _log('Delete todo: $id');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'todos',
              id: id,
              type: SyncOperationType.delete,
              timestamp: DateTime.now(),
            ),
          );
          _log('Todo delete queued for Supabase: $id');
        } catch (e) {
          _log('Failed to queue delete to Supabase: $e');
        }
      }
    } catch (e) {
      _log('Failed to delete todo: $e');
      rethrow;
    }
  }

  /// Insert multiple todos
  Future<void> insertAll(List<Todo> items) async {
    try {
      final todos = await _queryLocal();
      todos.addAll(items);
      await _saveLocal(todos);
      _log('Batch inserted ${items.length} todos');
    } catch (e) {
      _log('Failed to batch insert todos: $e');
      rethrow;
    }
  }

  /// Clear all todos
  Future<void> clearAll() async {
    try {
      await _saveLocal([]);
      _log('Cleared all todos');
    } catch (e) {
      _log('Failed to clear todos: $e');
      rethrow;
    }
  }

  /// Query from local SharedPreferences
  Future<List<Todo>> _queryLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => Todo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('Failed to parse todo data: $e');
      return [];
    }
  }

  /// Save to local SharedPreferences
  Future<void> _saveLocal(List<Todo> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = todos.map((todo) => todo.toJson()).toList();
    await prefs.setString(_prefsKey, json.encode(jsonList));
  }

  /// Find todos by title (case-insensitive)
  Future<List<Todo>> findByTitle(String title) async {
    try {
      final todos = await _queryLocal();
      final lowerTitle = title.trim().toLowerCase();
      return todos.where((t) => t.title.trim().toLowerCase() == lowerTitle).toList();
    } catch (e) {
      _log('Failed to find todo by title: $e');
      return [];
    }
  }

  /// Log output
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[TodoRepository] $message');
    }
  }
}