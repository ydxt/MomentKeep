import 'package:flutter/foundation.dart';

/// 应用常量
/// 统一管理应用中的所有常量值，避免魔法数字和字符串
class AppConstants {
  // ==================== 应用信息 ====================
  
  /// 应用名称
  static const String appName = '拾光记';
  
  /// 应用英文名称
  static const String appNameEn = 'Moment Keep';
  
  /// 应用版本
  static const String appVersion = '1.0.0';
  
  /// 数据库版本
  static const int databaseVersion = 17;
  
  /// 同步协议版本
  static const String syncProtocolVersion = '1.0.0';
  
  // ==================== 分页 ====================
  
  /// 默认每页数量
  static const int defaultPageSize = 20;
  
  /// 最大每页数量
  static const int maxPageSize = 100;
  
  // ==================== 超时时间 ====================
  
  /// API 请求超时时间
  static const Duration apiTimeout = Duration(seconds: 30);
  
  /// 同步操作超时时间
  static const Duration syncTimeout = Duration(minutes: 5);
  
  /// 文件上传超时时间
  static const Duration uploadTimeout = Duration(minutes: 10);
  
  // ==================== 限制 ====================
  
  /// 标题最大长度
  static const int maxTitleLength = 100;
  
  /// 内容最大长度
  static const int maxContentLength = 10000;
  
  /// 每个项目最大标签数量
  static const int maxTagsPerItem = 10;
  
  /// 最大重试次数
  static const int maxRetries = 3;
  
  /// 回收站默认保留天数
  static const int defaultRecycleBinRetentionDays = 30;
  
  // ==================== 默认值 ====================
  
  /// 每项任务默认积分
  static const int defaultPointsPerTask = 5;
  
  /// 待办事项默认优先级
  static const String defaultTodoPriority = 'medium';
  
  /// 习惯默认频率
  static const String defaultHabitFrequency = 'daily';
  
  /// 默认习惯类型
  static const String defaultHabitType = 'positive';
  
  // ==================== 时间相关 ====================
  
  /// 每周天数
  static const int daysPerWeek = 7;
  
  /// 每月平均天数
  static const double averageDaysPerMonth = 30.44;
  
  /// 每年月数
  static const int monthsPerYear = 12;
  
  /// 每天小时数
  static const int hoursPerDay = 24;
  
  /// 每小时分钟数
  static const int minutesPerHour = 60;
  
  /// 每天分钟数
  static const int minutesPerDay = 1440;
  
  // ==================== 文件相关 ====================
  
  /// 备份目录名称
  static const String backupDirectoryName = 'moment_keep_backups';
  
  /// 导出目录名称
  static const String exportDirectoryName = 'moment_keep_exports';
  
  /// 头像目录名称
  static const String avatarDirectoryName = 'avatars';
  
  /// 最大图片文件大小 (5MB)
  static const int maxImageFileSize = 5 * 1024 * 1024;
  
  /// 最大音频文件大小 (10MB)
  static const int maxAudioFileSize = 10 * 1024 * 1024;
  
  // ==================== UI 相关 ====================
  
  /// 默认动画持续时间
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  
  /// 快速动画持续时间
  static const Duration fastAnimationDuration = Duration(milliseconds: 200);
  
  /// 慢速动画持续时间
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
  
  /// 自动隐藏延迟时间
  static const Duration autoHideDelay = Duration(seconds: 3);
  
  /// 防抖延迟时间
  static const Duration debounceDuration = Duration(milliseconds: 300);
  
  // ==================== 网络相关 ====================
  
  /// 默认后端 API 地址（开发环境）
  static String get defaultApiBaseUrl {
    if (kDebugMode) {
      return 'http://localhost:6000';
    }
    return 'https://api.example.com'; // 生产环境
  }
  
  /// Supabase 默认 URL（如果未配置）
  static const String defaultSupabaseUrl = '';
  
  /// 连接重试间隔
  static const Duration retryInterval = Duration(seconds: 2);
  
  // ==================== 加密相关 ====================
  
  /// 加密密钥长度
  static const int encryptionKeyLength = 32;
  
  /// 初始化向量长度
  static const int ivLength = 16;
  
  // ==================== 位置相关 ====================
  
  /// 默认地理围栏半径（米）
  static const double defaultGeofenceRadius = 100.0;
  
  /// 位置更新间隔
  static const Duration locationUpdateInterval = Duration(seconds: 5);
  
  // ==================== 番茄钟 ====================
  
  /// 默认番茄钟时长（25分钟）
  static const int defaultPomodoroDuration = 25 * 60;
  
  /// 默认短休息时长（5分钟）
  static const int defaultShortBreakDuration = 5 * 60;
  
  /// 默认长休息时长（15分钟）
  static const int defaultLongBreakDuration = 15 * 60;
  
  /// 长休息间隔
  static const int longBreakInterval = 4;
}
