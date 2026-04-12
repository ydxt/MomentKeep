import 'package:shared_preferences/shared_preferences.dart';

/// Supabase 同步配置管理
class SupabaseConfig {
  /// 单例实例
  static final SupabaseConfig _instance = SupabaseConfig._internal();

  /// SharedPreferences 实例
  SharedPreferences? _prefs;

  /// 配置键名
  static const String _supabaseUrlKey = 'supabase_url';
  static const String _supabaseAnonKey = 'supabase_anon_key';
  static const String _syncEnabledKey = 'sync_enabled';
  static const String _realtimeEnabledKey = 'realtime_enabled';
  static const String _lastSyncAtKey = 'last_sync_at';
  static const String _syncStatusKey = 'sync_status';

  /// 私有构造函数
  SupabaseConfig._internal();

  /// 工厂构造函数
  factory SupabaseConfig() => _instance;

  /// 初始化配置（应用启动时调用）
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Supabase 项目 URL
  String get supabaseUrl => _prefs?.getString(_supabaseUrlKey) ?? '';

  Future<void> setSupabaseUrl(String url) async {
    await _prefs?.setString(_supabaseUrlKey, url);
  }

  /// Supabase Anon Key
  String get supabaseAnonKey => _prefs?.getString(_supabaseAnonKey) ?? '';

  Future<void> setSupabaseAnonKey(String key) async {
    await _prefs?.setString(_supabaseAnonKey, key);
  }

  /// 是否启用同步
  bool get syncEnabled => _prefs?.getBool(_syncEnabledKey) ?? false;

  Future<void> setSyncEnabled(bool enabled) async {
    await _prefs?.setBool(_syncEnabledKey, enabled);
  }

  /// 是否启用实时同步
  bool get realtimeEnabled => _prefs?.getBool(_realtimeEnabledKey) ?? false;

  Future<void> setRealtimeEnabled(bool enabled) async {
    await _prefs?.setBool(_realtimeEnabledKey, enabled);
  }

  /// 最后同步时间
  DateTime? get lastSyncAt {
    final timestamp = _prefs?.getInt(_lastSyncAtKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  Future<void> setLastSyncAt(DateTime? dateTime) async {
    if (dateTime != null) {
      await _prefs?.setInt(_lastSyncAtKey, dateTime.millisecondsSinceEpoch);
    } else {
      await _prefs?.remove(_lastSyncAtKey);
    }
  }

  /// 同步状态
  String get syncStatus => _prefs?.getString(_syncStatusKey) ?? 'disconnected';

  Future<void> setSyncStatus(String status) async {
    await _prefs?.setString(_syncStatusKey, status);
  }

  /// 检查配置是否完整
  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// 清除所有配置
  Future<void> clearAll() async {
    await _prefs?.remove(_supabaseUrlKey);
    await _prefs?.remove(_supabaseAnonKey);
    await _prefs?.remove(_syncEnabledKey);
    await _prefs?.remove(_realtimeEnabledKey);
    await _prefs?.remove(_lastSyncAtKey);
    await _prefs?.remove(_syncStatusKey);
  }

  /// 获取配置摘要（用于调试）
  Map<String, dynamic> getDebugInfo() {
    return {
      'supabaseUrl': supabaseUrl.isEmpty ? '未配置' : '已配置',
      'supabaseAnonKey': supabaseAnonKey.isEmpty ? '未配置' : '已配置',
      'syncEnabled': syncEnabled,
      'realtimeEnabled': realtimeEnabled,
      'lastSyncAt': lastSyncAt?.toString() ?? '从未同步',
      'syncStatus': syncStatus,
      'isConfigured': isConfigured,
    };
  }
}

/// 同步状态枚举
enum SyncState {
  disconnected, // 未连接
  connecting,   // 连接中
  syncing,      // 同步中
  synced,       // 已同步
  error,        // 错误
  offline,      // 离线
}

/// 同步状态扩展
extension SyncStateExtension on SyncState {
  String get displayName {
    switch (this) {
      case SyncState.disconnected:
        return '未连接';
      case SyncState.connecting:
        return '连接中';
      case SyncState.syncing:
        return '同步中';
      case SyncState.synced:
        return '已同步';
      case SyncState.error:
        return '同步错误';
      case SyncState.offline:
        return '离线';
    }
  }
}
