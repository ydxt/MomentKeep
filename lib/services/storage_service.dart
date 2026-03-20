import 'dart:io';
import 'dart:typed_data';
import 'package:moment_keep/services/storage_path_service.dart';

/// 存储类型枚举
enum StorageType {
  /// 本地存储
  local,
  /// Cloud存储（模拟服务器存储）
  cloud,
  /// 默认数据存储
  defaultData,
  /// 用户个人存储
  user,
  /// 商品文件存储
  product,
  /// 系统文件存储
  system,
  /// 日志存储
  log,
}

/// 存储服务
/// 负责文件的存储和读取操作
class StorageService {
  /// 保存文件
  /// [type] 存储类型
  /// [filename] 文件名
  /// [data] 文件数据
  /// [userId] 用户ID（当type为StorageType.user时需要）
  /// [subType] 子类型（当type为StorageType.user时，可指定images/audio/video/files）
  static Future<bool> saveFile(
    StorageType type,
    String filename,
    Uint8List data,
    {String? userId,
    String? subType,
  }) async {
    try {
      String filePath = _getFilePath(type, filename, userId: userId, subType: subType);
      File file = File(filePath);
      
      // 确保目录存在
      await file.parent.create(recursive: true);
      
      // 写入文件
      await file.writeAsBytes(data);
      return true;
    } catch (e) {
      print('保存文件失败: $e');
      return false;
    }
  }

  /// 读取文件
  /// [type] 存储类型
  /// [filename] 文件名
  /// [userId] 用户ID（当type为StorageType.user时需要）
  /// [subType] 子类型（当type为StorageType.user时，可指定images/audio/video/files）
  static Future<Uint8List?> readFile(
    StorageType type,
    String filename,
    {String? userId,
    String? subType,
  }) async {
    try {
      String filePath = _getFilePath(type, filename, userId: userId, subType: subType);
      File file = File(filePath);
      
      if (!file.existsSync()) {
        return null;
      }
      
      return await file.readAsBytes();
    } catch (e) {
      print('读取文件失败: $e');
      return null;
    }
  }

  /// 删除文件
  /// [type] 存储类型
  /// [filename] 文件名
  /// [userId] 用户ID（当type为StorageType.user时需要）
  /// [subType] 子类型（当type为StorageType.user时，可指定images/audio/video/files）
  static Future<bool> deleteFile(
    StorageType type,
    String filename,
    {String? userId,
    String? subType,
  }) async {
    try {
      String filePath = _getFilePath(type, filename, userId: userId, subType: subType);
      File file = File(filePath);
      
      if (file.existsSync()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      print('删除文件失败: $e');
      return false;
    }
  }

  /// 检查文件是否存在
  /// [type] 存储类型
  /// [filename] 文件名
  /// [userId] 用户ID（当type为StorageType.user时需要）
  /// [subType] 子类型（当type为StorageType.user时，可指定images/audio/video/files）
  static bool fileExists(
    StorageType type,
    String filename,
    {String? userId,
    String? subType,
  }) {
    try {
      String filePath = _getFilePath(type, filename, userId: userId, subType: subType);
      File file = File(filePath);
      return file.existsSync();
    } catch (e) {
      print('检查文件存在失败: $e');
      return false;
    }
  }

  /// 获取文件路径
  /// [type] 存储类型
  /// [filename] 文件名
  /// [userId] 用户ID（当type为StorageType.user时需要）
  /// [subType] 子类型（当type为StorageType.user时，可指定images/audio/video/files）
  static String _getFilePath(
    StorageType type,
    String filename,
    {String? userId,
    String? subType,
  }) {
    String basePath;
    
    switch (type) {
      case StorageType.local:
        basePath = StoragePathService.getLocalDirectory();
        break;
      case StorageType.cloud:
        basePath = StoragePathService.getCloudDirectory();
        break;
      case StorageType.defaultData:
        basePath = StoragePathService.getDefaultDirectory();
        break;
      case StorageType.user:
        if (userId == null) {
          throw Exception('StorageType.user requires userId');
        }
        if (subType != null) {
          switch (subType.toLowerCase()) {
            case 'images':
              basePath = StoragePathService.getUserImagesDirectory(userId);
              break;
            case 'audio':
              basePath = StoragePathService.getUserAudioDirectory(userId);
              break;
            case 'video':
              basePath = StoragePathService.getUserVideoDirectory(userId);
              break;
            case 'files':
              basePath = StoragePathService.getUserOtherFilesDirectory(userId);
              break;
            default:
              basePath = StoragePathService.getUserFilesDirectory(userId);
          }
        } else {
          basePath = StoragePathService.getUserFilesDirectory(userId);
        }
        break;
      case StorageType.product:
        basePath = StoragePathService.getProductsDirectory();
        break;
      case StorageType.system:
        basePath = StoragePathService.getSystemDirectory();
        break;
      case StorageType.log:
        basePath = StoragePathService.getLogsDirectory();
        break;
    }
    
    return '$basePath/$filename';
  }

  /// 获取文件列表
  /// [type] 存储类型
  /// [userId] 用户ID（当type为StorageType.user时需要）
  /// [subType] 子类型（当type为StorageType.user时，可指定images/audio/video/files）
  static List<String> getFileList(
    StorageType type,
    {String? userId,
    String? subType,
  }) {
    try {
      String basePath;
      
      switch (type) {
        case StorageType.local:
          basePath = StoragePathService.getLocalDirectory();
          break;
        case StorageType.cloud:
          basePath = StoragePathService.getCloudDirectory();
          break;
        case StorageType.defaultData:
          basePath = StoragePathService.getDefaultDirectory();
          break;
        case StorageType.user:
          if (userId == null) {
            throw Exception('StorageType.user requires userId');
          }
          if (subType != null) {
            switch (subType.toLowerCase()) {
              case 'images':
                basePath = StoragePathService.getUserImagesDirectory(userId);
                break;
              case 'audio':
                basePath = StoragePathService.getUserAudioDirectory(userId);
                break;
              case 'video':
                basePath = StoragePathService.getUserVideoDirectory(userId);
                break;
              case 'files':
                basePath = StoragePathService.getUserOtherFilesDirectory(userId);
                break;
              default:
                basePath = StoragePathService.getUserFilesDirectory(userId);
            }
          } else {
            basePath = StoragePathService.getUserFilesDirectory(userId);
          }
          break;
        case StorageType.product:
          basePath = StoragePathService.getProductsDirectory();
          break;
        case StorageType.system:
          basePath = StoragePathService.getSystemDirectory();
          break;
        case StorageType.log:
          basePath = StoragePathService.getLogsDirectory();
          break;
      }
      
      Directory directory = Directory(basePath);
      if (!directory.existsSync()) {
        return [];
      }
      
      List<FileSystemEntity> entities = directory.listSync();
      List<String> files = [];
      
      for (var entity in entities) {
        if (entity is File) {
          files.add(entity.path.split('/').last);
        }
      }
      
      return files;
    } catch (e) {
      print('获取文件列表失败: $e');
      return [];
    }
  }

  /// 获取文件大小
  /// [type] 存储类型
  /// [filename] 文件名
  /// [userId] 用户ID（当type为StorageType.user时需要）
  /// [subType] 子类型（当type为StorageType.user时，可指定images/audio/video/files）
  static int getFileSize(
    StorageType type,
    String filename,
    {String? userId,
    String? subType,
  }) {
    try {
      String filePath = _getFilePath(type, filename, userId: userId, subType: subType);
      File file = File(filePath);
      
      if (!file.existsSync()) {
        return 0;
      }
      
      return file.lengthSync();
    } catch (e) {
      print('获取文件大小失败: $e');
      return 0;
    }
  }
}
