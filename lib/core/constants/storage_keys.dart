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
  static const String themeMode = 'settings_theme_mode';

  /// 自定义存储路径
  static const String storagePath = 'storage_path';

  /// 语言设置
  static const String settingsLanguage = 'settings_language';

  /// 主题模式设置
  static const String settingsThemeMode = 'settings_theme_mode';

  /// 通知开关设置
  static const String settingsNotificationEnabled = 'settings_notification_enabled';

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

  /// 最后同步时间（本地记录）
  static const String lastSyncTime = 'last_sync_time';

  /// 最后登录时间
  static const String lastLoginTime = 'last_login_time';

  /// 注册时间
  static const String registerTime = 'register_time';

  // ==================== 离线队列 ====================

  /// 待同步的离线操作队列
  static const String syncPendingOperations = 'sync_pending_operations';

  // ==================== 安全设置 ====================

  /// 是否启用生物识别
  static const String biometricEnabled = 'security_biometric_enabled';

  /// 是否启用加密
  static const String encryptionEnabled = 'security_encryption_enabled';

  /// 生物识别类型
  static const String securityBiometricType = 'security_biometric_type';

  /// 生物识别是否需要重新认证
  static const String securityBiometricRequireReauth = 'security_biometric_require_reauth';

  /// 生物识别重新认证间隔
  static const String securityBiometricReauthInterval = 'security_biometric_reauth_interval';

  /// 加密算法
  static const String securityEncryptionAlgorithm = 'security_encryption_algorithm';

  /// 加密密钥长度
  static const String securityEncryptionKeyLength = 'security_encryption_key_length';

  /// 是否启用加密密钥自动更新
  static const String securityEncryptionAutoKeyUpdate = 'security_encryption_auto_key_update';

  /// 加密密钥更新间隔
  static const String securityEncryptionKeyUpdateInterval = 'security_encryption_key_update_interval';

  /// 加密密钥最后更新时间
  static const String securityEncryptionLastKeyUpdate = 'security_encryption_last_key_update';

  // ==================== 通知设置 ====================

  /// 是否启用通知
  static const String notificationsEnabled = 'settings_notification_enabled';

  // ==================== 积分 ====================

  /// 每日日记积分上限
  static const String maxDiaryPointsPerDay = 'max_diary_points_per_day';

  /// 每日待办积分上限
  static const String maxTodoPointsPerDay = 'max_todo_points_per_day';

  // ==================== 测试相关 ====================

  /// 测试账户是否已充值
  static const String testAccountRecharged = 'test_account_recharged';

  /// 测试数据是否已添加
  static const String testDataAdded = 'test_data_added';

  // ==================== 清理相关 ====================

  /// 最后清理时间
  static const String lastCleanupTime = 'last_cleanup_time';

  /// 清理天数
  static const String cleanupDays = 'cleanup_days';

  // ==================== 登录相关 ====================

  /// 登录账号历史
  static const String loginAccountHistory = 'login_account_history';

  // ==================== 引导相关 ====================

  /// 是否已看过引导页
  static const String hasSeenOnboarding = 'has_seen_onboarding';
}
