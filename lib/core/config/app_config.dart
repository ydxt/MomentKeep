// 应用程序配置类
class AppConfig {
  /// 应用名称
  static const String appName = '每日打卡';

  /// 应用版本
  static const String appVersion = '1.0.0';

  /// 应用包名
  static const String packageName = 'com.example.moment_keep';

  /// 数据库名称
  static const String databaseName = 'moment_keep.db';

  /// 数据库版本
  static const int databaseVersion = 1;

  /// 支持的平台
  static const List<String> supportedPlatforms = [
    'android',
    'ios',
    'windows',
    'macos',
    'linux',
    'web',
  ];
}
