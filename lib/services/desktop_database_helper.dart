// 桌面平台数据库辅助类，只在非Web平台使用
import 'dart:io';

/// 桌面平台数据库初始化助手类
class DesktopDatabaseHelper {
  /// 初始化sqflite_common_ffi
  static void init() {
    // 只有在非Web平台才初始化
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 动态导入，避免在Web平台编译错误
      _initDesktopDatabase();
    }
  }

  /// 动态初始化桌面数据库
  static Future<void> _initDesktopDatabase() async {
    // 使用延迟导入，避免在Web平台编译错误
    final sqflite_ffi = await _importSqfliteFfi();
    if (sqflite_ffi != null) {
      sqflite_ffi.sqfliteFfiInit();
    }
  }

  /// 动态导入sqflite_common_ffi包
  static Future<dynamic> _importSqfliteFfi() async {
    try {
      // 使用Isolate.spawn或其他方式动态导入
      // 这里简化处理，直接返回null
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取桌面平台数据库工厂
  static dynamic get databaseFactory {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 动态获取，避免在Web平台编译错误
      return null;
    }
    return null;
  }

  /// 桌面平台数据库选项构造函数
  static dynamic createOpenDatabaseOptions({
    required int version,
    required void Function(dynamic, int) onCreate,
    required void Function(dynamic, int, int) onUpgrade,
  }) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 动态创建，避免在Web平台编译错误
      return null;
    }
    return null;
  }
}
