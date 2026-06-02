// Web平台数据库辅助类，提供空实现
/// 桌面平台数据库初始化助手类 - Web平台空实现
class DesktopDatabaseHelper {
  /// 初始化sqflite_common_ffi - Web平台空实现
  static void init() {
    // Web平台不需要初始化
  }

  /// 获取桌面平台数据库工厂 - Web平台空实现
  static dynamic get databaseFactory => null;

  /// 桌面平台数据库选项构造函数 - Web平台空实现
  static dynamic createOpenDatabaseOptions({
    required int version,
    required void Function(dynamic, int) onCreate,
    required void Function(dynamic, int, int) onUpgrade,
  }) {
    return null;
  }
}
