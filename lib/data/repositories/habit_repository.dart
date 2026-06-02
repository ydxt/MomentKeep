import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';

/// Habit Repository
/// Manages local SharedPreferences and Supabase data access and sync
class HabitRepository {
  /// Singleton instance
  static final HabitRepository _instance = HabitRepository._internal();

  /// Supabase service
  final SupabaseService _supabase = SupabaseService();

  /// Sync manager
  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  /// SharedPreferences Key
  static const String _prefsKey = 'habits';

  /// Private constructor
  HabitRepository._internal();

  /// Factory constructor
  factory HabitRepository() => _instance;

  /// Get all habits
  Future<List<Habit>> getAll() async {
    try {
      final habits = await _queryLocal();
      _log('Retrieved ${habits.length} habits');
      return habits;
    } catch (e) {
      _log('Failed to get all habits: $e');
      return [];
    }
  }

  /// Get habit by ID
  Future<Habit?> getById(String id) async {
    try {
      final habits = await _queryLocal();
      final habit = habits.where((h) => h.id == id).toList().firstOrNull;
      _log('Get habit: $id');
      return habit;
    } catch (e) {
      _log('Failed to get habit: $e');
      return null;
    }
  }

  /// Insert a habit
  Future<String> insert(Habit item) async {
    try {
      final habits = await _queryLocal();
      habits.add(item);
      await _saveLocal(habits);
      _log('Insert habit: ${item.id}');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'habits',
              id: item.id,
              type: SyncOperationType.insert,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('Habit queued for Supabase: ${item.id}');
        } catch (e) {
          _log('Failed to queue habit to Supabase: $e');
        }
      }

      return item.id;
    } catch (e) {
      _log('Failed to insert habit: $e');
      rethrow;
    }
  }

  /// Update a habit
  Future<void> update(String id, Habit item) async {
    try {
      final habits = await _queryLocal();
      final index = habits.indexWhere((h) => h.id == id);
      if (index != -1) {
        habits[index] = item;
        await _saveLocal(habits);
        _log('Update habit: $id');

        if (_supabase.isInitialized) {
          try {
            await _syncManager.queueOperation(
              SyncOperation(
                table: 'habits',
                id: id,
                type: SyncOperationType.update,
                data: item.toJson(),
                timestamp: DateTime.now(),
              ),
            );
            _log('Habit queued for Supabase: $id');
          } catch (e) {
            _log('Failed to queue habit to Supabase: $e');
          }
        }
      } else {
        _log('Habit not found: $id');
      }
    } catch (e) {
      _log('Failed to update habit: $e');
      rethrow;
    }
  }

  /// Delete a habit
  Future<void> delete(String id) async {
    try {
      final habits = await _queryLocal();
      habits.removeWhere((h) => h.id == id);
      await _saveLocal(habits);
      _log('Delete habit: $id');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'habits',
              id: id,
              type: SyncOperationType.delete,
              timestamp: DateTime.now(),
            ),
          );
          _log('Habit delete queued for Supabase: $id');
        } catch (e) {
          _log('Failed to queue delete to Supabase: $e');
        }
      }
    } catch (e) {
      _log('Failed to delete habit: $e');
      rethrow;
    }
  }

  /// Insert multiple habits
  Future<void> insertAll(List<Habit> items) async {
    try {
      final habits = await _queryLocal();
      habits.addAll(items);
      await _saveLocal(habits);
      _log('Batch inserted ${items.length} habits');
    } catch (e) {
      _log('Failed to batch insert habits: $e');
      rethrow;
    }
  }

  /// Clear all habits
  Future<void> clearAll() async {
    try {
      await _saveLocal([]);
      _log('Cleared all habits');
    } catch (e) {
      _log('Failed to clear habits: $e');
      rethrow;
    }
  }

  /// Query from local SharedPreferences
  Future<List<Habit>> _queryLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => Habit.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('Failed to parse habit data: $e');
      return [];
    }
  }

  /// Save to local SharedPreferences
  Future<void> _saveLocal(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = habits.map((habit) => habit.toJson()).toList();
    await prefs.setString(_prefsKey, json.encode(jsonList));
  }

  /// Find habits by title (case-insensitive, matches name field)
  Future<List<Habit>> findByTitle(String title) async {
    try {
      final habits = await _queryLocal();
      final lowerTitle = title.trim().toLowerCase();
      return habits.where((h) => h.name.trim().toLowerCase() == lowerTitle).toList();
    } catch (e) {
      _log('Failed to find habit by title: $e');
      return [];
    }
  }

  /// Log output
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[HabitRepository] $message');
    }
  }
}