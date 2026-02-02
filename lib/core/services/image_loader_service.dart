
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 图片加载服务，根据不同平台提供不同的图片加载策略
class ImageLoaderService {
  /// 有效的透明1x1像素PNG数据
  static final Uint8List _transparentImage = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ]);

  /// 静态方法，根据图片URL获取对应的ImageProvider
  /// 
  /// [imageUrl] 图片URL或本地文件路径
  /// 
  /// 平台策略：
  /// - Web: 始终使用NetworkImage从网络加载
  /// - Windows: 使用FileImage从本地文件系统加载，无效路径时返回安全的占位图
  /// - Mobile: 优先使用NetworkImage从网络加载，网络不可用时使用本地缓存
  static ImageProvider getImageProvider(String imageUrl) {
    // 检查图片URL是否为空
    if (imageUrl.isEmpty) {
      // 返回一个有效的透明占位图
      return MemoryImage(_transparentImage);
    }
    
    // 检查是否为网络URL
    final isNetwork = isNetworkUrl(imageUrl);
    
    if (kIsWeb) {
      // Web平台：从网络加载图片
      return NetworkImage(imageUrl);
    } else if (Platform.isWindows) {
      // Windows平台：从本地文件系统加载图片
      try {
        // 检查是否为本地文件路径
        if (!isNetwork) {
          final file = File(imageUrl);
          if (file.existsSync()) {
            return FileImage(file);
          } else {
            // 文件不存在，返回有效的透明占位图
            debugPrint('Local image file not found: $imageUrl');
            return MemoryImage(_transparentImage);
          }
        } else {
          // 网络URL，使用NetworkImage
          return NetworkImage(imageUrl);
        }
      } catch (e) {
        // 处理异常，返回有效的透明占位图
        debugPrint('Error loading image on Windows: $e');
        return MemoryImage(_transparentImage);
      }
    } else {
      // 移动平台：根据URL类型选择加载方式
      if (isNetwork) {
        return NetworkImage(imageUrl);
      } else {
        // 本地文件路径
        try {
          final file = File(imageUrl);
          if (file.existsSync()) {
            return FileImage(file);
          } else {
            // 文件不存在，返回有效的透明占位图
            debugPrint('Local image file not found on mobile: $imageUrl');
            return MemoryImage(_transparentImage);
          }
        } catch (e) {
          // 处理异常，返回有效的透明占位图
          debugPrint('Error loading image on mobile: $e');
          return MemoryImage(_transparentImage);
        }
      }
    }
  }

  /// 检查图片URL是否为网络URL
  static bool isNetworkUrl(String imageUrl) {
    // 检查是否以http://或https://开头
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return true;
    }
    
    // 检查是否为本地文件路径
    // Windows本地路径通常以盘符开头，如C:、D:等，可能使用正斜杠或反斜杠
    if (RegExp(r'^[A-Za-z]:[/\\]').hasMatch(imageUrl)) {
      return false;
    }
    
    // 检查是否为file://开头的本地文件URL
    if (imageUrl.startsWith('file://')) {
      return false;
    }
    
    // 检查是否为以/开头的绝对路径
    if (imageUrl.startsWith('/')) {
      return false;
    }
    
    // 其他情况视为网络URL
    return true;
  }

  /// 获取图片缓存路径（仅在非Web平台可用）
  static String? getImageCachePath() {
    if (kIsWeb) {
      return null;
    }

    // 根据平台返回默认缓存路径
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Android/data/com.example.moment_keep/cache/images';
    } else if (Platform.isIOS) {
      return null; // iOS使用NSCache，不需要手动管理路径
    } else if (Platform.isWindows) {
      return '${Platform.environment['USERPROFILE']}/AppData/Local/moment_keep/cache/images';
    } else if (Platform.isMacOS) {
      return '${Platform.environment['HOME']}/Library/Caches/moment_keep/images';
    } else if (Platform.isLinux) {
      return '${Platform.environment['HOME']}/.cache/moment_keep/images';
    }

    return null;
  }
}
