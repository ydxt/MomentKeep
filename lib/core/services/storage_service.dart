import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path_package;
import 'package:shared_preferences/shared_preferences.dart';

/// 存储服务单例类，用于处理图片和语音文件的存储
class StorageService {
  /// 单例实例
  static final StorageService _instance = StorageService._internal();

  /// UUID生成器
  final Uuid _uuid = const Uuid();

  /// 私有构造函数
  StorageService._internal();

  /// 工厂构造函数
  factory StorageService() => _instance;

  /// 存储目录名称
  static const String _storageDirectory = 'MomentKeep';

  /// 获取应用数据目录
  /// [userId] 用户ID，用于创建用户独立目录
  /// [isStore] 是否为星星商店存储，true表示存储在default/store目录下，false表示直接存储在用户目录下
  Future<Directory> _getAppDirectory({required String userId, bool isStore = false}) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 从SharedPreferences获取自定义存储路径
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('storage_path');

      Directory storageDir;

      if (customPath != null && customPath.isNotEmpty) {
        // 使用自定义存储路径
        storageDir = Directory(customPath);
      } else {
        // 使用默认路径
        Directory directory;
        if (Platform.isAndroid || Platform.isIOS) {
          // 移动端使用应用文档目录
          directory = await getApplicationDocumentsDirectory();
        } else if (Platform.isWindows) {
          // Windows使用文档目录
          directory = Directory(path_package.join(
              Platform.environment['USERPROFILE']!, 'Documents'));
        } else if (Platform.isMacOS) {
          // macOS使用文档目录
          directory = Directory(
              path_package.join(Platform.environment['HOME']!, 'Documents'));
        } else if (Platform.isLinux) {
          // Linux使用文档目录
          directory = Directory(
              path_package.join(Platform.environment['HOME']!, 'Documents'));
        } else {
          throw UnsupportedError('Unsupported platform');
        }

        // 创建默认存储目录
        storageDir = Directory(path_package.join(directory.path, _storageDirectory));
      }

      // 确保存储目录存在
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }

      if (isStore) {
        // 创建并返回default/store/用户ID目录
        final defaultDir = Directory(path_package.join(storageDir.path, 'default'));
        if (!await defaultDir.exists()) {
          await defaultDir.create(recursive: true);
        }
        final storeDir = Directory(path_package.join(defaultDir.path, 'store'));
        if (!await storeDir.exists()) {
          await storeDir.create(recursive: true);
        }
        // 为每个用户创建独立目录
        final userDir = Directory(path_package.join(storeDir.path, userId));
        if (!await userDir.exists()) {
          await userDir.create(recursive: true);
        }
        return userDir;
      } else {
        // 为每个用户创建独立目录
        final userDir = Directory(path_package.join(storageDir.path, userId));
        if (!await userDir.exists()) {
          await userDir.create(recursive: true);
        }
        return userDir;
      }
    } catch (e) {
      throw Exception('Failed to get app directory: $e');
    }
  }

  /// 获取应用存储目录的公共方法
  Future<Directory> getAppDirectory({required String userId}) async {
    return await _getAppDirectory(userId: userId);
  }

  /// 存储文件
  /// [xFile] 要存储的文件
  /// [fileType] 文件类型，用于创建子目录（如果未提供，将根据文件扩展名自动确定）
  /// [userId] 用户ID，用于服务器端的用户独立目录
  /// 返回存储后的文件路径
  /// 根据文件扩展名获取文件类型
  String _getFileTypeFromExtension(String filePath) {
    final extension = path_package.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      return 'images';
    } else if (['.mp3', '.wav', '.ogg', '.aac'].contains(extension)) {
      return 'audio';
    } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(extension)) {
      return 'video';
    } else {
      return 'files';
    }
  }

  Future<String> storeFile(XFile xFile, {String? fileType, required String userId, bool isStore = false}) async {
    // 如果未提供fileType，根据文件扩展名自动确定
    final resolvedFileType = fileType ?? _getFileTypeFromExtension(xFile.name);
    
    if (kIsWeb) {
      // Web平台上传到服务器
      try {
        debugPrint('Starting file upload for: ${xFile.name}, type: $resolvedFileType, userId: $userId');
        
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:5000/api/upload'),
        );
        
        // 添加用户ID作为表单字段
        request.fields['user_id'] = userId;
        debugPrint('Upload request created with user_id: $userId');
        
        // 读取文件内容
        final bytes = await xFile.readAsBytes();
        debugPrint('File read successfully, size: ${bytes.length} bytes');
        
        String fileExtension = path_package.extension(xFile.name);
        
        // 确保文件名有扩展名
        if (fileExtension.isEmpty || !fileExtension.startsWith('.')) {
          // 根据文件类型设置默认扩展名
          if (resolvedFileType == 'images') {
            fileExtension = '.png';
          } else if (resolvedFileType == 'audio') {
            fileExtension = '.mp3';
          } else if (resolvedFileType == 'video') {
            fileExtension = '.mp4';
          } else {
            fileExtension = '.bin';
          }
          debugPrint('Using default extension: $fileExtension');
        }
        
        final fileName = '${_uuid.v4()}$fileExtension';
        debugPrint('Generated unique filename: $fileName');
        
        // 添加文件到请求
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));
        debugPrint('File added to request');
        
        // 发送请求
        debugPrint('Sending upload request to: http://localhost:5000/api/upload');
        final response = await request.send();
        debugPrint('Upload request completed with status: ${response.statusCode}');
        
        if (response.statusCode == 201) {
          // 解析响应
          final responseBody = await response.stream.bytesToString();
          debugPrint('Upload response: $responseBody');
          final data = jsonDecode(responseBody);
          final storedFilename = data['filename'] as String;
          debugPrint('File uploaded successfully, stored as: $storedFilename');
          return storedFilename;
        } else {
          final errorResponse = await response.stream.bytesToString();
          debugPrint('Upload failed with status: ${response.statusCode}, response: $errorResponse');
          throw Exception('Failed to upload file: ${response.reasonPhrase}, response: $errorResponse');
        }
      } catch (e) {
        debugPrint('Upload exception: $e');
        throw Exception('Failed to upload file: $e');
      }
    } else {
      // 非Web平台存储到本地
      try {
        // 获取应用存储目录
        final appDir = await _getAppDirectory(userId: userId, isStore: isStore);

        // 创建文件类型子目录
        final typeDir = Directory(path_package.join(appDir.path, resolvedFileType));
        if (!await typeDir.exists()) {
          await typeDir.create(recursive: true);
        }

        // 生成唯一文件名
        final fileExtension = path_package.extension(xFile.path);
        final fileName = '${_uuid.v4()}$fileExtension';

        // 目标文件路径
        final destinationPath = path_package.join(typeDir.path, fileName);

        // 复制文件
        final File sourceFile = File(xFile.path);
        await sourceFile.copy(destinationPath);

        return destinationPath;
      } catch (e) {
        throw Exception('Failed to store file: $e');
      }
    }
  }

  /// 存储图片文件
  /// [xFile] 要存储的图片文件
  /// [userId] 用户ID，用于服务器端的用户独立目录
  /// [isStore] 是否为星星商店存储，true表示存储在store目录下，false表示直接存储在用户目录下
  /// [isComment] 是否为评论图片，true表示存储在comment目录下
  /// 返回存储后的图片路径
  Future<String> storeImage(XFile xFile, {required String userId, bool isStore = false, bool isComment = false}) async {
    final fileType = isComment ? 'comment' : 'images';
    return await storeFile(xFile, fileType: fileType, userId: userId, isStore: isStore);
  }

  /// 存储图片字节数组
  /// [bytes] 图片字节数组
  /// [extension] 图片扩展名
  /// [userId] 用户ID，用于服务器端的用户独立目录
  /// [isStore] 是否为星星商店存储，true表示存储在store目录下，false表示直接存储在用户目录下
  /// 返回存储后的图片路径
  Future<String> storeImageFromBytes(List<int> bytes, {required String userId, required String extension, bool isStore = false}) async {
    try {
      if (kIsWeb) {
        // Web平台上传到服务器
        debugPrint('Starting Base64 image upload, extension: $extension, userId: $userId');
        
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:5000/api/upload'),
        );
        
        // 添加用户ID作为表单字段
        request.fields['user_id'] = userId;
        debugPrint('Upload request created with user_id: $userId');
        
        // 生成唯一文件名
        final fileName = '${_uuid.v4()}.$extension';
        debugPrint('Generated unique filename: $fileName');
        
        // 添加文件到请求
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));
        debugPrint('File added to request');
        
        // 发送请求
        debugPrint('Sending upload request to: http://localhost:5000/api/upload');
        final response = await request.send();
        debugPrint('Upload request completed with status: ${response.statusCode}');
        
        if (response.statusCode == 201) {
          // 解析响应
          final responseBody = await response.stream.bytesToString();
          debugPrint('Upload response: $responseBody');
          final data = jsonDecode(responseBody);
          final storedFilename = data['filename'] as String;
          debugPrint('File uploaded successfully, stored as: $storedFilename');
          return storedFilename;
        } else {
          final errorResponse = await response.stream.bytesToString();
          debugPrint('Upload failed with status: ${response.statusCode}, response: $errorResponse');
          throw Exception('Failed to upload file: ${response.reasonPhrase}, response: $errorResponse');
        }
      } else {
        // 非Web平台存储到本地
        // 获取应用存储目录
        final appDir = await _getAppDirectory(userId: userId, isStore: isStore);

        // 创建图片子目录
        final imagesDir = Directory(path_package.join(appDir.path, 'images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        // 生成唯一文件名
        final fileName = '${_uuid.v4()}.$extension';

        // 目标文件路径
        final destinationPath = path_package.join(imagesDir.path, fileName);

        // 写入文件
        final File file = File(destinationPath);
        await file.writeAsBytes(bytes);

        return destinationPath;
      }
    } catch (e) {
      throw Exception('Failed to store image from bytes: $e');
    }
  }

  /// 存储语音文件
  /// [xFile] 要存储的语音文件
  /// [userId] 用户ID，用于服务器端的用户独立目录
  /// [isStore] 是否为星星商店存储，true表示存储在store目录下，false表示直接存储在用户目录下
  /// 返回存储后的语音路径
  Future<String> storeAudio(XFile xFile, {required String userId, bool isStore = false}) async {
    return await storeFile(xFile, fileType: 'audio', userId: userId, isStore: isStore);
  }

  /// 存储视频文件
  /// [xFile] 要存储的视频文件
  /// [userId] 用户ID，用于服务器端的用户独立目录
  /// [isStore] 是否为星星商店存储，true表示存储在store目录下，false表示直接存储在用户目录下
  /// 返回存储后的视频路径
  Future<String> storeVideo(XFile xFile, {required String userId, bool isStore = false}) async {
    return await storeFile(xFile, fileType: 'video', userId: userId, isStore: isStore);
  }

  /// 删除文件
  /// [filePath] 要删除的文件路径
  Future<void> deleteFile(String filePath) async {
    if (kIsWeb) {
      // Web平台，发送请求到服务器删除文件
      try {
        debugPrint('Starting file delete for: $filePath');
        
        final request = http.Request(
          'DELETE',
          Uri.parse('http://localhost:5000/api/delete_file'),
        );
        
        // 添加文件路径作为查询参数或请求体
        request.body = jsonEncode({'file_path': filePath});
        request.headers['Content-Type'] = 'application/json';
        
        debugPrint('Sending delete request to: http://localhost:5000/api/delete_file');
        final response = await request.send();
        debugPrint('Delete request completed with status: ${response.statusCode}');
        
        if (response.statusCode != 200) {
          final errorResponse = await response.stream.bytesToString();
          debugPrint('Delete failed with status: ${response.statusCode}, response: $errorResponse');
          throw Exception('Failed to delete file: ${response.reasonPhrase}, response: $errorResponse');
        }
        
        debugPrint('File deleted successfully: $filePath');
      } catch (e) {
        debugPrint('Delete exception: $e');
        throw Exception('Failed to delete file: $e');
      }
    } else {
      // 非Web平台，删除本地文件
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        throw Exception('Failed to delete file: $e');
      }
    }
  }

  /// 获取文件列表
  /// [fileType] 文件类型
  /// [userId] 用户ID，用于获取特定用户的文件
  Future<List<File>> getFiles({String fileType = 'images', required String userId}) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 获取应用存储目录
      final appDir = await _getAppDirectory(userId: userId);

      // 文件类型子目录
      final typeDir = Directory(path_package.join(appDir.path, fileType));
      if (!await typeDir.exists()) {
        return [];
      }

      // 获取文件列表
      final files = <File>[];
      await for (final FileSystemEntity entity in typeDir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }

      return files;
    } catch (e) {
      throw Exception('Failed to get files: $e');
    }
  }

  /// 获取图片文件列表
  Future<List<File>> getImages({required String userId}) async {
    return await getFiles(fileType: 'images', userId: userId);
  }

  /// 获取语音文件列表
  Future<List<File>> getAudioFiles({required String userId}) async {
    return await getFiles(fileType: 'audio', userId: userId);
  }

  /// 获取视频文件列表
  Future<List<File>> getVideoFiles({required String userId}) async {
    return await getFiles(fileType: 'video', userId: userId);
  }

  /// 获取文件大小
  /// [filePath] 文件路径
  Future<int> getFileSize(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      throw Exception('Failed to get file size: $e');
    }
  }

  /// 获取文件扩展名
  /// [filePath] 文件路径
  String getFileExtension(String filePath) {
    return path_package.extension(filePath).toLowerCase();
  }

  /// 判断是否为图片文件
  /// [filePath] 文件路径
  bool isImageFile(String filePath) {
    final extension = getFileExtension(filePath);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension);
  }

  /// 判断是否为音频文件
  /// [filePath] 文件路径
  bool isAudioFile(String filePath) {
    final extension = getFileExtension(filePath);
    return ['.mp3', '.wav', '.ogg', '.aac'].contains(extension);
  }
}
