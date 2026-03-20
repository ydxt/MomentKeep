import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 存储路径服务
/// 负责管理应用的存储路径和目录结构
class StoragePathService {
  static Directory? _appSupportDir;
  static Directory? _cloudDir;
  static Directory? _localDir;
  static bool _isTestMode = false;
  static bool _isInitialized = false;

  /// 确保服务已初始化
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// 设置测试模式
  /// 在测试环境中使用模拟路径
  static void setTestMode() {
    _isTestMode = true;
  }

  /// 初始化存储路径
  /// 必须在应用启动时调用
  static Future<void> initialize() async {
    if (_isTestMode) {
      // 测试模式：使用临时目录
      _appSupportDir = Directory.systemTemp.createTempSync('MomentKeepTest');
    } else if (Platform.isWindows) {
      // Windows平台：使用文档目录下的MomentKeep子目录
      final docsDir = await getApplicationDocumentsDirectory();
      _appSupportDir = Directory('${docsDir.path}/MomentKeep');
      if (!_appSupportDir!.existsSync()) {
        _appSupportDir!.createSync(recursive: true);
      }
    } else {
      // 其他平台：使用应用支持目录
      _appSupportDir = await getApplicationSupportDirectory();
    }
    
    // 创建cloud目录（模拟服务器存储）
    _cloudDir = Directory('${_appSupportDir!.path}/cloud');
    if (!_cloudDir!.existsSync()) {
      _cloudDir!.createSync(recursive: true);
    }

    // 创建本地目录
    _localDir = Directory('${_appSupportDir!.path}/local');
    if (!_localDir!.existsSync()) {
      _localDir!.createSync(recursive: true);
    }

    // 创建所有必要的子目录
    _createSubDirectories();
    
    _isInitialized = true;
  }

  /// 创建所有必要的子目录
  static void _createSubDirectories() {
    // Cloud目录子目录
    Directory('${_cloudDir!.path}/database').createSync(recursive: true);
    Directory('${_cloudDir!.path}/files/products').createSync(recursive: true);
    Directory('${_cloudDir!.path}/files/users').createSync(recursive: true);
    Directory('${_cloudDir!.path}/files/system').createSync(recursive: true);
    Directory('${_cloudDir!.path}/files/system/password_resets').createSync(recursive: true);
    Directory('${_cloudDir!.path}/logs').createSync(recursive: true);

    // 本地目录子目录
    Directory('${_localDir!.path}/default/database').createSync(recursive: true);
    Directory('${_localDir!.path}/default/store').createSync(recursive: true);
    Directory('${_localDir!.path}/local_database').createSync(recursive: true);
  }

  /// 获取应用支持目录路径
  static Future<String> getAppSupportDirectory() async {
    await _ensureInitialized();
    return _appSupportDir!.path;
  }

  /// 获取Cloud目录路径（模拟服务器存储）
  static Future<String> getCloudDirectory() async {
    await _ensureInitialized();
    return _cloudDir!.path;
  }

  /// 获取本地目录路径
  static Future<String> getLocalDirectory() async {
    await _ensureInitialized();
    return _localDir!.path;
  }

  /// 获取服务器数据库目录路径
  static Future<String> getServerDatabaseDirectory() async {
    await _ensureInitialized();
    return '${_cloudDir!.path}/database';
  }

  /// 获取本地数据库目录路径
  static Future<String> getLocalDatabaseDirectory() async {
    await _ensureInitialized();
    return '${_localDir!.path}/local_database';
  }

  /// 获取默认数据目录路径
  static Future<String> getDefaultDirectory() async {
    await _ensureInitialized();
    return '${_localDir!.path}/default';
  }

  /// 获取默认数据库目录路径
  static Future<String> getDefaultDatabaseDirectory() async {
    await _ensureInitialized();
    return '${_localDir!.path}/default/database';
  }

  /// 获取默认商店数据目录路径
  static Future<String> getDefaultStoreDirectory() async {
    await _ensureInitialized();
    return '${_localDir!.path}/default/store';
  }

  /// 获取商品文件存储目录路径
  static Future<String> getProductsDirectory() async {
    await _ensureInitialized();
    return '${_cloudDir!.path}/files/products';
  }

  /// 获取用户文件存储目录路径
  static Future<String> getUsersDirectory() async {
    await _ensureInitialized();
    return '${_cloudDir!.path}/files/users';
  }

  /// 获取系统文件存储目录路径
  static Future<String> getSystemDirectory() async {
    await _ensureInitialized();
    return '${_cloudDir!.path}/files/system';
  }

  /// 获取日志目录路径
  static Future<String> getLogsDirectory() async {
    await _ensureInitialized();
    return '${_cloudDir!.path}/logs';
  }

  /// 获取用户个人文件目录路径
  /// [userId] 用户ID
  static Future<String> getUserFilesDirectory(String userId) async {
    await _ensureInitialized();
    Directory userDir = Directory('${_localDir!.path}/$userId');
    if (!userDir.existsSync()) {
      userDir.createSync(recursive: true);
      // 创建用户子目录
      Directory('${userDir.path}/images').createSync(recursive: true);
      Directory('${userDir.path}/audio').createSync(recursive: true);
      Directory('${userDir.path}/video').createSync(recursive: true);
      Directory('${userDir.path}/files').createSync(recursive: true);
    }
    return userDir.path;
  }

  /// 获取用户图片目录路径
  /// [userId] 用户ID
  static Future<String> getUserImagesDirectory(String userId) async {
    String userDir = await getUserFilesDirectory(userId);
    return '${userDir}/images';
  }

  /// 获取用户音频目录路径
  /// [userId] 用户ID
  static Future<String> getUserAudioDirectory(String userId) async {
    String userDir = await getUserFilesDirectory(userId);
    return '${userDir}/audio';
  }

  /// 获取用户视频目录路径
  /// [userId] 用户ID
  static Future<String> getUserVideoDirectory(String userId) async {
    String userDir = await getUserFilesDirectory(userId);
    return '${userDir}/video';
  }

  /// 获取用户其他文件目录路径
  /// [userId] 用户ID
  static Future<String> getUserOtherFilesDirectory(String userId) async {
    String userDir = await getUserFilesDirectory(userId);
    return '${userDir}/files';
  }

  /// 获取密码重置令牌存储目录路径
  static Future<String> getPasswordResetsDirectory() async {
    await _ensureInitialized();
    return '${_cloudDir!.path}/files/system/password_resets';
  }
}
