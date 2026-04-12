/// SharedPreferences 存储键名常量
/// 用于统一管理所有本地存储的键名，避免魔法字符串
class StorageKeys {
  // ==================== 用户相关 ====================
  
  /// 用户 ID
  static const String userId = 'user_id';
  
  /// 用户邮箱
  static const String userEmail = 'user_email';
  
  /// 用户名
  static const String userUsername = 'user_username';
  
  /// 用户头像
  static const String userAvatar = 'user_avatar';
  
  // ==================== 待办事项 ====================
  
  /// 待办事项列表
  static const String todoEntries = 'todo_entries';
  
  /// 每项待办完成获得的积分
  static const String pointsPerTodo = 'points_per_todo';
  
  // ==================== 习惯 ====================
  
  /// 习惯列表
  static const String habits = 'habits';
  
  // ==================== 分类 ====================
  
  /// 分类列表
  static const String categories = 'categories';
  
  // ==================== 日记 ====================
  
  /// 每篇日记获得的积分
  static const String pointsPerDiary = 'points_per_diary';
  
  // ==================== 回收站 ====================
  
  /// 回收站项目
  static const String recycleBin = 'recycle_bin';
  
  /// 回收站保留天数
  static const String recycleBinRetentionDays = 'recycle_bin_retention_days';
  
  // ==================== 应用设置 ====================
  
  /// 主题模式
  static const String themeMode = 'theme_mode';
  
  /// 自定义存储路径
  static const String storagePath = 'storage_path';
  
  // ==================== Supabase 同步 ====================
  
  /// Supabase 项目 URL
  static const String supabaseUrl = 'supabase_url';
  
  /// Supabase Anon Key
  static const String supabaseAnonKey = 'supabase_anon_key';
  
  /// 是否启用同步
  static const String syncEnabled = 'sync_enabled';
  
  /// 是否启用实时同步
  static const String realtimeEnabled = 'realtime_enabled';
  
  /// 最后同步时间
  static const String lastSyncAt = 'last_sync_at';
  
  /// 同步状态
  static const String syncStatus = 'sync_status';
  
  /// 同步冲突解决策略
  static const String syncConflictStrategy = 'sync_conflict_strategy';
  
  // ==================== 离线队列 ====================
  
  /// 待同步的离线操作队列
  static const String syncPendingOperations = 'sync_pending_operations';
  
  // ==================== 安全设置 ====================
  
  /// 是否启用生物识别
  static const String biometricEnabled = 'biometric_enabled';
  
  /// 是否启用加密
  static const String encryptionEnabled = 'encryption_enabled';
  
  // ==================== 通知设置 ====================
  
  /// 是否启用通知
  static const String notificationsEnabled = 'notifications_enabled';
  
  /// 通知时间
  static const String notificationTime = 'notification_time';
  
  // ==================== 积分 ====================
  
  /// 用户总积分
  static const String userPoints = 'user_points';
  
  /// 积分历史记录
  static const String pointsHistory = 'points_history';
}
