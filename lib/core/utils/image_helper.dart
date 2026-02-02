import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 图片和文件处理工具类
class ImageHelper {
  /// 私有构造函数，防止实例化
  ImageHelper._();

  /// 获取应用程序文档目录路径
  static Future<String> getApplicationDocumentsDirectoryPath() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    // 从SharedPreferences获取自定义存储路径
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('storage_path');

    if (customPath != null && customPath.isNotEmpty) {
      // 使用自定义存储路径
      return customPath;
    } else {
      // 使用默认路径
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  /// 获取临时目录路径
  static Future<String> getTemporaryDirectoryPath() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  /// 将相对路径转换为绝对路径
  /// [relativePath] 相对路径
  /// [isTemp] 是否为临时文件
  static Future<String> getAbsolutePath(String relativePath,
      {bool isTemp = false}) async {
    if (kIsWeb) {
      return relativePath; // Web平台直接返回路径
    }

    final basePath = isTemp
        ? await getTemporaryDirectoryPath()
        : await getApplicationDocumentsDirectoryPath();

    // 如果已经是绝对路径，直接返回
    if (path.isAbsolute(relativePath)) {
      return relativePath;
    }

    return path.join(basePath, relativePath);
  }

  /// 将绝对路径转换为相对路径
  /// [absolutePath] 绝对路径
  /// [isTemp] 是否为临时文件
  static Future<String> getRelativePath(String absolutePath,
      {bool isTemp = false}) async {
    if (kIsWeb) {
      return absolutePath; // Web平台直接返回路径
    }

    final basePath = isTemp
        ? await getTemporaryDirectoryPath()
        : await getApplicationDocumentsDirectoryPath();

    // 如果已经是相对路径，直接返回
    if (!path.isAbsolute(absolutePath)) {
      return absolutePath;
    }

    return path.relative(absolutePath, from: basePath);
  }

  /// 读取图片文件
  /// [path] 图片路径（相对或绝对）
  /// [isTemp] 是否为临时文件
  static Future<File> getImageFile(String path, {bool isTemp = false}) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    final absolutePath = await getAbsolutePath(path, isTemp: isTemp);
    return File(absolutePath);
  }

  /// 保存图片文件
  /// [file] 图片文件
  /// [fileName] 文件名
  /// [isTemp] 是否保存到临时目录
  static Future<String> saveImageFile(File file, String fileName,
      {bool isTemp = false}) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    final basePath = isTemp
        ? await getTemporaryDirectoryPath()
        : await getApplicationDocumentsDirectoryPath();

    final destinationPath = path.join(basePath, fileName);
    final destinationFile = File(destinationPath);

    // 确保目录存在
    await destinationFile.parent.create(recursive: true);

    // 复制文件到目标位置
    await file.copy(destinationFile.path);

    // 返回相对路径
    return await getRelativePath(destinationFile.path, isTemp: isTemp);
  }

  /// 删除图片文件
  /// [path] 图片路径（相对或绝对）
  /// [isTemp] 是否为临时文件
  static Future<void> deleteImageFile(String path,
      {bool isTemp = false}) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    final absolutePath = await getAbsolutePath(path, isTemp: isTemp);
    final file = File(absolutePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 检查文件是否存在
  /// [path] 文件路径（相对或绝对）
  /// [isTemp] 是否为临时文件
  static Future<bool> fileExists(String path, {bool isTemp = false}) async {
    if (kIsWeb) {
      return false; // Web平台无法检查文件是否存在
    }

    final absolutePath = await getAbsolutePath(path, isTemp: isTemp);
    final file = File(absolutePath);
    return await file.exists();
  }

  /// 获取文件大小
  /// [path] 文件路径（相对或绝对）
  /// [isTemp] 是否为临时文件
  static Future<int> getFileSize(String path, {bool isTemp = false}) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    final absolutePath = await getAbsolutePath(path, isTemp: isTemp);
    final file = File(absolutePath);

    if (await file.exists()) {
      return await file.length();
    }

    return 0;
  }

  /// 获取文件扩展名
  /// [filePath] 文件路径
  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// 判断是否为图片文件
  /// [path] 文件路径
  static bool isImageFile(String path) {
    final extension = getFileExtension(path);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension);
  }

  /// 判断是否为音频文件
  /// [path] 文件路径
  static bool isAudioFile(String path) {
    final extension = getFileExtension(path);
    return ['.mp3', '.wav', '.ogg', '.aac'].contains(extension);
  }
}
