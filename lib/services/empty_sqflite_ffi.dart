// Web平台空实现，避免编译错误

// 空实现sqflite_ffi包的类和函数
void sqfliteFfiInit() {
  // Web平台不需要初始化
}

dynamic get databaseFactoryFfi => null;

class OpenDatabaseOptions {
  final int version;
  final void Function(dynamic, int) onCreate;
  final void Function(dynamic, int, int) onUpgrade;
  
  const OpenDatabaseOptions({
    required this.version,
    required this.onCreate,
    required this.onUpgrade,
  });
}
