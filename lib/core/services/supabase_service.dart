import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moment_keep/core/config/supabase_config.dart';

/// Supabase 服务封装
class SupabaseService {
  /// 单例实例
  static final SupabaseService _instance = SupabaseService._internal();

  /// 配置实例
  final SupabaseConfig _config = SupabaseConfig();

  /// Supabase 客户端
  SupabaseClient? _client;

  /// 初始化状态
  bool _isInitialized = false;

  /// 私有构造函数
  SupabaseService._internal();

  /// 工厂构造函数
  factory SupabaseService() => _instance;

  /// 获取 SupabaseClient 实例
  SupabaseClient? get client {
    if (!_isInitialized || _client == null) {
      return null;
    }
    return _client;
  }

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化 Supabase
  /// 在应用启动时调用，或配置更新后调用
  Future<bool> initialize() async {
    try {
      // 检查配置
      if (!_config.isConfigured) {
        debugPrint('Supabase 配置不完整，跳过初始化');
        return false;
      }

      // 如果已经初始化，先清理
      if (_client != null) {
        await dispose();
      }

      // 初始化 Supabase
      await Supabase.initialize(
        url: _config.supabaseUrl,
        anonKey: _config.supabaseAnonKey,
        debug: false, // 生产环境关闭调试日志
      );

      _client = Supabase.instance.client;
      _isInitialized = true;

      debugPrint('Supabase 初始化成功');
      return true;
    } catch (e) {
      debugPrint('Supabase 初始化失败: $e');
      _isInitialized = false;
      _client = null;
      return false;
    }
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized || _client == null) {
        await initialize();
      }

      if (_client == null) {
        return false;
      }

      // 尝试查询当前用户，测试连接
      final user = _client!.auth.currentUser;
      debugPrint('Supabase 连接测试成功，当前用户: ${user?.id ?? "未登录"}');
      return true;
    } catch (e) {
      debugPrint('Supabase 连接测试失败: $e');
      return false;
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    if (_client != null) {
      // 移除所有实时订阅
      await _client!.removeAllChannels();
      _client = null;
    }
    _isInitialized = false;
  }

  // ==================== 数据库操作 ====================

  /// 查询数据
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
    int? offset,
  }) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      PostgrestQueryBuilder<dynamic, dynamic> builder = _client!.from(table).select(select ?? '*');

      // 应用过滤器
      dynamic query = builder;
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // 排序
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // 分页
      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 10) - 1);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Supabase 查询失败 ($table): $e');
      rethrow;
    }
  }

  /// 插入数据
  Future<String> insert(String table, Map<String, dynamic> data) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      final response = await _client!.from(table).insert(data).select();
      
      if (response.isNotEmpty) {
        return response.first['id'] as String;
      }
      
      throw Exception('插入失败：无返回数据');
    } catch (e) {
      debugPrint('Supabase 插入失败 ($table): $e');
      rethrow;
    }
  }

  /// 更新数据
  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      await _client!
          .from(table)
          .update(data)
          .eq('id', id);
    } catch (e) {
      debugPrint('Supabase 更新失败 ($table): $e');
      rethrow;
    }
  }

  /// 删除数据
  Future<void> delete(String table, String id) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      await _client!
          .from(table)
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Supabase 删除失败 ($table): $e');
      rethrow;
    }
  }

  /// 批量插入
  Future<void> insertBatch(String table, List<Map<String, dynamic>> dataList) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      // 分批插入，每批最多 100 条
      const batchSize = 100;
      for (int i = 0; i < dataList.length; i += batchSize) {
        final batch = dataList.sublist(
          i,
          (i + batchSize < dataList.length) ? i + batchSize : dataList.length,
        );
        await _client!.from(table).insert(batch);
      }
    } catch (e) {
      debugPrint('Supabase 批量插入失败 ($table): $e');
      rethrow;
    }
  }

  /// 增量查询（获取指定时间后的变更）
  Future<List<Map<String, dynamic>>> querySince(
    String table,
    DateTime since, {
    String? orderBy,
  }) async {
    return query(
      table,
      filters: {
        'updated_at': since.toIso8601String(),
      },
      orderBy: orderBy ?? 'updated_at',
      ascending: true,
    );
  }

  // ==================== 实时订阅 ====================

  /// 订阅表变更
  Stream<List<Map<String, dynamic>>> subscribeToTable(
    String table, {
    String? schema,
  }) {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    final stream = _client!
        .from(table)
        .stream(primaryKey: ['id'])
        .order('updated_at');

    return stream.map((changes) {
      return List<Map<String, dynamic>>.from(changes);
    });
  }

  /// 订阅单条记录变更
  Stream<Map<String, dynamic>?> subscribeToRecord(
    String table,
    String id,
  ) {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    final stream = _client!
        .from(table)
        .stream(primaryKey: ['id'])
        .eq('id', id);

    return stream.map((changes) {
      if (changes.isNotEmpty) {
        return Map<String, dynamic>.from(changes.first);
      }
      return null;
    });
  }

  /// 移除所有订阅
  Future<void> removeAllSubscriptions() async {
    if (_client != null) {
      await _client!.removeAllChannels();
    }
  }

  // ==================== 文件存储 ====================

  /// 上传文件
  Future<String> uploadFile(
    String bucket,
    String path,
    List<int> data,
  ) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      await _client!.storage.from(bucket).uploadBinary(
            path,
            data,
          );

      // 获取公共 URL
      final url = _client!.storage.from(bucket).getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Supabase 文件上传失败: $e');
      rethrow;
    }
  }

  /// 下载文件
  Future<List<int>> downloadFile(String bucket, String path) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      final data = await _client!.storage.from(bucket).download(path);
      return data;
    } catch (e) {
      debugPrint('Supabase 文件下载失败: $e');
      rethrow;
    }
  }

  /// 删除文件
  Future<void> deleteFile(String bucket, String path) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    try {
      await _client!.storage.from(bucket).remove([path]);
    } catch (e) {
      debugPrint('Supabase 文件删除失败: $e');
      rethrow;
    }
  }

  // ==================== 认证 ====================

  /// 获取当前用户
  User? get currentUser {
    if (_client == null) return null;
    return _client!.auth.currentUser;
  }

  /// 监听认证状态变化
  Stream<AuthState> get authStateChanges {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }
    return _client!.auth.onAuthStateChange;
  }

  /// 邮箱登录
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    return await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// 注册
  Future<AuthResponse> signUp(String email, String password) async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    return await _client!.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// 登出
  Future<void> signOut() async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    await _client!.auth.signOut();
  }

  /// 刷新会话
  Future<void> refreshSession() async {
    if (_client == null) {
      throw Exception('Supabase 未初始化');
    }

    await _client!.auth.refreshSession();
  }
}
