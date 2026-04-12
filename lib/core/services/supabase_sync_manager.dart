import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:moment_keep/core/config/supabase_config.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/services/database_service.dart';

/// 同步操作类型
enum SyncOperationType {
  insert,
  update,
  delete,
}

/// 同步操作记录
class SyncOperation {
  final String table;
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  SyncOperation({
    required this.table,
    required this.id,
    required this.type,
    this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'table': table,
      'id': id,
      'type': type.toString().split('.').last,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      table: json['table'],
      id: json['id'],
      type: SyncOperationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => SyncOperationType.update,
      ),
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Supabase 同步管理器
/// 负责本地 SQLite 与 Supabase PostgreSQL 之间的数据同步
class SupabaseSyncManager {
  /// 单例实例
  static final SupabaseSyncManager _instance = SupabaseSyncManager._internal();

  /// 配置实例
  final SupabaseConfig _config = SupabaseConfig();

  /// Supabase 服务
  final SupabaseService _supabase = SupabaseService();

  /// 离线操作队列
  final List<SyncOperation> _pendingOperations = [];

  /// 同步状态流控制器
  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();

  /// 同步进度流控制器
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  /// 是否正在同步
  bool _isSyncing = false;

  /// 订阅列表
  final Map<String, StreamSubscription> _subscriptions = {};

  /// 私有构造函数
  SupabaseSyncManager._internal();

  /// 工厂构造函数
  factory SupabaseSyncManager() => _instance;

  /// 获取同步状态流
  Stream<SyncState> get stateStream => _stateController.stream;

  /// 获取同步进度流
  Stream<double> get progressStream => _progressController.stream;

  /// 获取当前同步状态
  SyncState get currentState => _currentState;
  SyncState _currentState = SyncState.disconnected;

  /// 初始化同步管理器
  Future<void> initialize() async {
    debugPrint('初始化 Supabase 同步管理器...');

    // 加载离线队列
    await _loadPendingOperations();

    // 如果启用了同步，初始化 Supabase
    if (_config.syncEnabled && _config.isConfigured) {
      await _initializeSupabase();
    }

    debugPrint('Supabase 同步管理器初始化完成');
  }

  /// 初始化 Supabase
  Future<void> _initializeSupabase() async {
    try {
      _updateState(SyncState.connecting);

      final success = await _supabase.initialize();

      if (success) {
        _updateState(SyncState.synced);

        // 如果启用了实时同步，启动订阅
        if (_config.realtimeEnabled) {
          await _startRealtimeSubscriptions();
        }

        // 尝试同步离线队列
        await _flushPendingOperations();
      } else {
        _updateState(SyncState.error);
      }
    } catch (e) {
      debugPrint('Supabase 初始化失败: $e');
      _updateState(SyncState.error);
    }
  }

  // ==================== 核心同步方法 ====================

  /// 全量同步（首次同步或手动触发）
  Future<bool> fullSync() async {
    if (_isSyncing) {
      debugPrint('同步已在进行中');
      return false;
    }

    if (!_supabase.isInitialized) {
      debugPrint('Supabase 未初始化');
      return false;
    }

    _isSyncing = true;
    _updateState(SyncState.syncing);
    _updateProgress(0.0);

    try {
      // 1. 同步分类
      _updateProgress(0.1);
      await syncCategories();

      // 2. 同步待办事项
      _updateProgress(0.25);
      await syncTodos();

      // 3. 同步习惯
      _updateProgress(0.4);
      await syncHabits();

      // 4. 同步日记
      _updateProgress(0.55);
      await syncJournals();

      // 5. 同步番茄钟
      _updateProgress(0.7);
      await syncPomodoros();

      // 6. 同步计划
      _updateProgress(0.8);
      await syncPlans();

      // 7. 同步成就
      _updateProgress(0.9);
      await syncAchievements();

      _updateProgress(1.0);
      _updateState(SyncState.synced);
      await _config.setLastSyncAt(DateTime.now());

      debugPrint('全量同步完成');
      return true;
    } catch (e) {
      debugPrint('全量同步失败: $e');
      _updateState(SyncState.error);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// 增量同步（基于时间戳）
  Future<bool> incrementalSync() async {
    if (_isSyncing) return false;
    if (!_supabase.isInitialized) return false;

    _isSyncing = true;
    _updateState(SyncState.syncing);

    try {
      final lastSync = _config.lastSyncAt;

      // 如果从未同步过，执行全量同步
      if (lastSync == null) {
        return await fullSync();
      }

      // 1. 推送本地变更到服务器
      await _pushLocalChanges(lastSync);

      // 2. 拉取服务器变更到本地
      await _pullRemoteChanges(lastSync);

      _updateState(SyncState.synced);
      await _config.setLastSyncAt(DateTime.now());

      debugPrint('增量同步完成');
      return true;
    } catch (e) {
      debugPrint('增量同步失败: $e');
      _updateState(SyncState.error);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// 同步分类
  Future<void> syncCategories() async {
    try {
      final db = await DatabaseService().database;

      // 1. 从服务器拉取最新数据
      final remoteCategories = await _supabase.query('categories');

      // 2. 清空本地数据
      await db.delete('categories');

      // 3. 插入服务器数据
      for (var category in remoteCategories) {
        await db.insert('categories', {
          'id': category['id'],
          'name': category['name'],
          'type': category['type'],
          'icon': category['icon'],
          'color': category['color'],
          'is_expanded': category['is_expanded'] ?? 0,
          'is_question_bank': category['is_question_bank'] ?? 0,
          'created_at': category['created_at'],
          'updated_at': category['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 4. 同步 SharedPreferences 中的分类数据
      await _syncCategoriesToSharedPreferences(remoteCategories);

      debugPrint('分类同步完成，同步了 ${remoteCategories.length} 条记录');
    } catch (e) {
      debugPrint('分类同步失败: $e');
      rethrow;
    }
  }

  /// 同步待办事项
  Future<void> syncTodos() async {
    try {
      // 1. 从 SharedPreferences 读取本地数据
      final prefs = await SharedPreferences.getInstance();
      final localTodosJson = prefs.getString('todo_entries');
      final localTodos = localTodosJson != null
          ? (jsonDecode(localTodosJson) as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      // 2. 从服务器拉取最新数据
      final remoteTodos = await _supabase.query('todos');

      // 3. 合并数据（Last-Write-Wins）
      final mergedTodos = _mergeData(
        localTodos,
        remoteTodos,
        'id',
      );

      // 4. 保存到本地
      await prefs.setString(
        'todo_entries',
        jsonEncode(mergedTodos),
      );

      // 5. 推送到服务器（本地有新数据）
      for (var todo in localTodos) {
        final exists = remoteTodos.any((r) => r['id'] == todo['id']);
        if (!exists) {
          await _supabase.insert('todos', todo);
        }
      }

      debugPrint('待办事项同步完成，同步了 ${mergedTodos.length} 条记录');
    } catch (e) {
      debugPrint('待办事项同步失败: $e');
      rethrow;
    }
  }

  /// 同步习惯
  Future<void> syncHabits() async {
    try {
      // 1. 从 SharedPreferences 读取本地数据
      final prefs = await SharedPreferences.getInstance();
      final localHabitsJson = prefs.getString('habits');
      final localHabits = localHabitsJson != null
          ? (jsonDecode(localHabitsJson) as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      // 2. 从服务器拉取最新数据
      final remoteHabits = await _supabase.query('habits');

      // 3. 合并数据
      final mergedHabits = _mergeData(
        localHabits,
        remoteHabits,
        'id',
      );

      // 4. 保存到本地
      await prefs.setString(
        'habits',
        jsonEncode(mergedHabits),
      );

      // 5. 推送到服务器
      for (var habit in localHabits) {
        final exists = remoteHabits.any((r) => r['id'] == habit['id']);
        if (!exists) {
          await _supabase.insert('habits', habit);
        }
      }

      debugPrint('习惯同步完成，同步了 ${mergedHabits.length} 条记录');
    } catch (e) {
      debugPrint('习惯同步失败: $e');
      rethrow;
    }
  }

  /// 同步日记
  Future<void> syncJournals() async {
    try {
      final db = await DatabaseService().database;
      final userId = await DatabaseService().getCurrentUserId();

      if (userId == null) {
        debugPrint('用户 ID 为空，跳过日记同步');
        return;
      }

      // 1. 从服务器拉取最新数据
      final remoteJournals = await _supabase.query('journals');

      // 2. 更新本地数据库
      for (var journal in remoteJournals) {
        await db.insert('journals', {
          'id': journal['id'],
          'category_id': journal['category_id'],
          'title': journal['title'],
          'content': journal['content'],
          'tags': journal['tags'],
          'date': journal['date'],
          'created_at': journal['created_at'],
          'updated_at': journal['updated_at'],
          'subject': journal['subject'],
          'remarks': journal['remarks'],
          'mood': journal['mood'],
          'user_id': userId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      debugPrint('日记同步完成，同步了 ${remoteJournals.length} 条记录');
    } catch (e) {
      debugPrint('日记同步失败: $e');
      rethrow;
    }
  }

  /// 同步番茄钟
  Future<void> syncPomodoros() async {
    try {
      final db = await DatabaseService().database;

      // 从服务器拉取最新数据
      final remotePomodoros = await _supabase.query('pomodoro_records');

      // 更新本地数据库
      for (var pomodoro in remotePomodoros) {
        await db.insert('pomodoro_records', {
          'id': pomodoro['id'],
          'duration': pomodoro['duration'],
          'start_time': pomodoro['start_time'],
          'end_time': pomodoro['end_time'],
          'tag': pomodoro['tag'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      debugPrint('番茄钟同步完成，同步了 ${remotePomodoros.length} 条记录');
    } catch (e) {
      debugPrint('番茄钟同步失败: $e');
      rethrow;
    }
  }

  /// 同步计划
  Future<void> syncPlans() async {
    try {
      final db = await DatabaseService().database;

      // 从服务器拉取最新数据
      final remotePlans = await _supabase.query('plans');

      // 更新本地数据库
      for (var plan in remotePlans) {
        await db.insert('plans', {
          'id': plan['id'],
          'name': plan['name'],
          'description': plan['description'],
          'start_date': plan['start_date'],
          'end_date': plan['end_date'],
          'is_completed': plan['is_completed'],
          'habit_ids': plan['habit_ids'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      debugPrint('计划同步完成，同步了 ${remotePlans.length} 条记录');
    } catch (e) {
      debugPrint('计划同步失败: $e');
      rethrow;
    }
  }

  /// 同步成就
  Future<void> syncAchievements() async {
    try {
      final db = await DatabaseService().database;

      // 从服务器拉取最新数据
      final remoteAchievements = await _supabase.query('achievements');

      // 更新本地数据库
      for (var achievement in remoteAchievements) {
        await db.insert('achievements', {
          'id': achievement['id'],
          'name': achievement['name'],
          'description': achievement['description'],
          'type': achievement['type'],
          'is_unlocked': achievement['is_unlocked'],
          'unlocked_at': achievement['unlocked_at'],
          'required_progress': achievement['required_progress'],
          'current_progress': achievement['current_progress'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      debugPrint('成就同步完成，同步了 ${remoteAchievements.length} 条记录');
    } catch (e) {
      debugPrint('成就同步失败: $e');
      rethrow;
    }
  }

  // ==================== 离线队列 ====================

  /// 添加离线操作
  Future<void> queueOperation(SyncOperation operation) async {
    _pendingOperations.add(operation);
    await _savePendingOperations();
    debugPrint('离线操作已加入队列: ${operation.type} ${operation.table}');
  }

  /// 刷新离线队列（网络恢复时调用）
  Future<void> _flushPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    debugPrint('开始刷新离线队列，共 ${_pendingOperations.length} 个操作');

    final remaining = <SyncOperation>[];

    for (final operation in _pendingOperations) {
      try {
        switch (operation.type) {
          case SyncOperationType.insert:
            await _supabase.insert(operation.table, operation.data!);
            break;
          case SyncOperationType.update:
            await _supabase.update(
              operation.table,
              operation.id,
              operation.data!,
            );
            break;
          case SyncOperationType.delete:
            await _supabase.delete(operation.table, operation.id);
            break;
        }
        debugPrint('离线操作执行成功: ${operation.type} ${operation.table}');
      } catch (e) {
        debugPrint('离线操作执行失败: $e');
        remaining.add(operation);
      }
    }

    _pendingOperations.clear();
    _pendingOperations.addAll(remaining);
    await _savePendingOperations();

    debugPrint('离线队列刷新完成，剩余 ${remaining.length} 个操作');
  }

  /// 保存离线队列
  Future<void> _savePendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final operationsJson = jsonEncode(
      _pendingOperations.map((op) => op.toJson()).toList(),
    );
    await prefs.setString('sync_pending_operations', operationsJson);
  }

  /// 加载离线队列
  Future<void> _loadPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final operationsJson = prefs.getString('sync_pending_operations');

    if (operationsJson != null) {
      final operationsList = jsonDecode(operationsJson) as List;
      _pendingOperations.clear();
      _pendingOperations.addAll(
        operationsList.map(
          (json) => SyncOperation.fromJson(json as Map<String, dynamic>),
        ),
      );
      debugPrint('加载离线队列: ${_pendingOperations.length} 个操作');
    }
  }

  // ==================== 实时订阅 ====================

  /// 启动实时订阅
  Future<void> _startRealtimeSubscriptions() async {
    if (!_supabase.isInitialized) return;

    debugPrint('启动实时订阅...');

    // 订阅待办事项
    _subscriptions['todos'] = _supabase
        .subscribeToTable('todos')
        .listen(_handleTableChange);

    // 订阅习惯
    _subscriptions['habits'] = _supabase
        .subscribeToTable('habits')
        .listen(_handleTableChange);

    // 订阅日记
    _subscriptions['journals'] = _supabase
        .subscribeToTable('journals')
        .listen(_handleTableChange);

    debugPrint('实时订阅启动完成');
  }

  /// 处理表变更
  void _handleTableChange(List<Map<String, dynamic>> changes) {
    debugPrint('接收到表变更，共 ${changes.length} 条记录');

    // TODO: 实现变更处理逻辑
    // 1. 检测变更类型（INSERT/UPDATE/DELETE）
    // 2. 更新本地 SQLite
    // 3. 通知 BLoC 更新 UI
  }

  /// 停止所有订阅
  Future<void> stopAllSubscriptions() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    debugPrint('所有实时订阅已停止');
  }

  // ==================== 辅助方法 ====================

  /// 推送本地变更到服务器
  Future<void> _pushLocalChanges(DateTime since) async {
    // TODO: 实现本地变更推送逻辑
    // 1. 查询本地 updated_at > since 的数据
    // 2. 推送到服务器
    // 3. 处理冲突
  }

  /// 拉取服务器变更到本地
  Future<void> _pullRemoteChanges(DateTime since) async {
    // TODO: 实现服务器变更拉取逻辑
    // 1. 查询服务器 updated_at > since 的数据
    // 2. 更新本地数据库
    // 3. 处理冲突
  }

  /// 合并数据（Last-Write-Wins 策略）
  List<Map<String, dynamic>> _mergeData(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
    String idField,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    // 添加本地数据
    for (var item in local) {
      merged[item[idField]] = item;
    }

    // 合并服务器数据
    for (var item in remote) {
      final id = item[idField];
      if (merged.containsKey(id)) {
        // 比较更新时间
        final localUpdated = DateTime.parse(merged[id]!['updatedAt'] ??
            merged[id]!['updated_at'] ??
            DateTime.now().toIso8601String());
        final remoteUpdated = DateTime.parse(item['updated_at'] ??
            item['updatedAt'] ??
            DateTime.now().toIso8601String());

        // 使用较新的数据
        if (remoteUpdated.isAfter(localUpdated)) {
          merged[id] = item;
        }
      } else {
        merged[id] = item;
      }
    }

    return merged.values.toList();
  }

  /// 同步分类到 SharedPreferences
  Future<void> _syncCategoriesToSharedPreferences(
    List<Map<String, dynamic>> categories,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = jsonEncode(categories);
    await prefs.setString('categories', categoriesJson);
    debugPrint('分类数据已同步到 SharedPreferences');
  }

  /// 更新同步状态
  void _updateState(SyncState state) {
    _currentState = state;
    _stateController.add(state);
    _config.setSyncStatus(state.name);
    debugPrint('同步状态更新: ${state.displayName}');
  }

  /// 更新同步进度
  void _updateProgress(double progress) {
    _progressController.add(progress);
  }

  /// 清理资源
  Future<void> dispose() async {
    await stopAllSubscriptions();
    await _supabase.dispose();
    await _stateController.close();
    await _progressController.close();
  }
}
