import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/services/storage_service.dart';

/// 数据备份与恢复服务
class BackupService {
  /// 单例实例
  static final BackupService _instance = BackupService._internal();

  /// 数据库服务
  final DatabaseService _databaseService = DatabaseService();

  /// 存储服务
  final StorageService _storageService = StorageService();

  /// 私有构造函数
  BackupService._internal();

  /// 工厂构造函数
  factory BackupService() => _instance;

  /// 备份目录名称
  static const String _backupDirectory = 'moment_keep_backups';

  /// 获取备份目录
  Future<Directory> _getBackupDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    Directory directory;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端使用应用文档目录
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows) {
        // Windows使用文档目录
        directory =
            Directory('${Platform.environment['USERPROFILE']}Documents');
      } else if (Platform.isMacOS) {
        // macOS使用文档目录
        directory = Directory('${Platform.environment['HOME']}/Documents');
      } else if (Platform.isLinux) {
        // Linux使用文档目录
        directory = Directory('${Platform.environment['HOME']}/Documents');
      } else {
        throw UnsupportedError('Unsupported platform');
      }

      // 创建备份目录
      final backupDir =
          Directory(path_package.join(directory.path, _backupDirectory));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      return backupDir;
    } catch (e) {
      throw Exception('Failed to get backup directory: $e');
    }
  }

  /// 导出数据库为JSON文件
  Future<String> exportDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 获取数据库统计信息
      final stats = await _databaseService.getDatabaseStats();

      // 导出所有表数据
      final db = await _databaseService.database;
      final tables = [
        'habits',
        'habit_records',
        'tags',
        'habit_tags',
        'plans',
        'plan_habits',
        'pomodoro_records',
        'achievements',
        'users',
        'journals',
      ];

      final databaseData = <String, dynamic>{
        'version': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'stats': stats,
        'data': <String, List<Map<String, dynamic>>>{},
      };

      for (final table in tables) {
        try {
          final data = await db.query(table);
          databaseData['data'][table] = data;
        } catch (e) {
          print('Failed to export table $table: $e');
          databaseData['data'][table] = [];
        }
      }

      // 创建JSON文件
      final backupDir = await _getBackupDirectory();
      final fileName =
          'database_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = path_package.join(backupDir.path, fileName);
      final file = File(filePath);

      // 写入JSON数据
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(databaseData),
        mode: FileMode.write,
      );

      return filePath;
    } catch (e) {
      throw Exception('Failed to export database: $e');
    }
  }

  /// 导出所有文件为ZIP
  Future<String> exportFiles() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 获取所有图片和音频文件
      final images = await _storageService.getImages(userId: 'backup');
      final audioFiles = await _storageService.getAudioFiles(userId: 'backup');
      final allFiles = [...images, ...audioFiles];

      if (allFiles.isEmpty) {
        throw Exception('No files to export');
      }

      // 创建ZIP归档
      final archive = Archive();

      // 添加文件到归档
      for (final file in allFiles) {
        final bytes = await file.readAsBytes();
        final fileName = path_package.basename(file.path);
        final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
        archive.addFile(archiveFile);
      }

      // 创建ZIP文件
      final backupDir = await _getBackupDirectory();
      final fileName =
          'files_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final filePath = path_package.join(backupDir.path, fileName);
      final zipFile = File(filePath);

      // 写入ZIP数据
      final zipBytes = ZipEncoder().encode(archive);
      await zipFile.writeAsBytes(zipBytes);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export files: $e');
    }
  }

  /// 导出完整备份（数据库+文件）
  Future<String> exportFullBackup() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 导出数据库
      final databasePath = await exportDatabase();

      // 创建ZIP归档
      final archive = Archive();

      // 添加数据库备份到归档
      final databaseFile = File(databasePath);
      final databaseBytes = await databaseFile.readAsBytes();
      final databaseArchiveFile = ArchiveFile(
        path_package.basename(databasePath),
        databaseBytes.length,
        databaseBytes,
      );
      archive.addFile(databaseArchiveFile);

      // 添加所有图片和音频文件到归档
      final images = await _storageService.getImages(userId: 'backup');
      final audioFiles = await _storageService.getAudioFiles(userId: 'backup');
      final allFiles = [...images, ...audioFiles];

      for (final file in allFiles) {
        final bytes = await file.readAsBytes();
        final fileName = path_package.basename(file.path);
        final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
        archive.addFile(archiveFile);
      }

      // 创建完整备份ZIP文件
      final backupDir = await _getBackupDirectory();
      final fileName =
          'full_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final filePath = path_package.join(backupDir.path, fileName);
      final zipFile = File(filePath);

      // 写入ZIP数据
      final zipBytes = ZipEncoder().encode(archive);
      await zipFile.writeAsBytes(zipBytes);

      // 删除临时数据库备份文件
      await databaseFile.delete();

      return filePath;
    } catch (e) {
      throw Exception('Failed to create full backup: $e');
    }
  }

  /// 导入数据库备份
  Future<void> importDatabase(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 读取JSON文件
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file does not exist');
      }

      final jsonString = await file.readAsString();
      final databaseData = json.decode(jsonString) as Map<String, dynamic>;

      // 获取数据库实例
      final db = await _databaseService.database;

      // 开始事务
      await db.transaction((txn) async {
        // 获取所有表
        final tables = databaseData['data'] as Map<String, dynamic>;

        for (final entry in tables.entries) {
          final table = entry.key;
          final data = entry.value as List<dynamic>;

          // 清空表
          await txn.delete(table);

          // 插入数据
          for (final row in data) {
            final rowData = row as Map<String, dynamic>;
            await txn.insert(table, rowData);
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to import database: $e');
    }
  }

  /// 导入文件备份
  Future<void> importFiles(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 读取ZIP文件
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file does not exist');
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 解压文件
      for (final archiveFile in archive) {
        if (archiveFile.isFile) {
          final fileName = archiveFile.name;
          final fileBytes = archiveFile.content as List<int>;

          // 确定文件类型
          final extension = path_package.extension(fileName).toLowerCase();
          final fileType = _getFileType(extension);

          // 创建临时文件
          final tempDir = await getTemporaryDirectory();
          final tempFilePath = path_package.join(tempDir.path, fileName);
          final tempFile = File(tempFilePath);
          await tempFile.writeAsBytes(fileBytes);

          // 获取当前用户ID
          final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
          // 使用存储服务保存文件
          await _storageService.storeFile(
            XFile(tempFilePath),
            fileType: fileType,
            userId: userId,
          );

          // 删除临时文件
          await tempFile.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to import files: $e');
    }
  }

  /// 导入完整备份
  Future<void> importFullBackup(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      // 读取ZIP文件
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file does not exist');
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 创建临时目录
      final tempDir = await getTemporaryDirectory();

      // 解压文件
      String? databaseFilePath;
      final filePaths = <String>[];

      for (final archiveFile in archive) {
        if (archiveFile.isFile) {
          final fileName = archiveFile.name;
          final fileBytes = archiveFile.content as List<int>;
          final tempFilePath = path_package.join(tempDir.path, fileName);
          final tempFile = File(tempFilePath);

          await tempFile.writeAsBytes(fileBytes);

          if (fileName.endsWith('.json')) {
            // 数据库备份文件
            databaseFilePath = tempFilePath;
          } else {
            // 其他文件
            filePaths.add(tempFilePath);
          }
        }
      }

      // 导入数据库
      if (databaseFilePath != null) {
        await importDatabase(databaseFilePath);
        await File(databaseFilePath).delete();
      }

      // 导入文件
      for (final filePath in filePaths) {
        final fileName = path_package.basename(filePath);
        final extension = path_package.extension(fileName).toLowerCase();
        final fileType = _getFileType(extension);

        // 获取当前用户ID
        final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
        await _storageService.storeFile(
          XFile(filePath),
          fileType: fileType,
          userId: userId,
        );

        await File(filePath).delete();
      }
    } catch (e) {
      throw Exception('Failed to import full backup: $e');
    }
  }

  /// 获取文件类型
  String _getFileType(String extension) {
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      return 'images';
    } else if (['.mp3', '.wav', '.ogg', '.aac'].contains(extension)) {
      return 'audio';
    } else {
      return 'other';
    }
  }

  /// 获取备份文件列表
  Future<List<File>> getBackupFiles() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) {
        return [];
      }

      final files = <File>[];
      await for (final entity in backupDir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.json') || entity.path.endsWith('.zip'))) {
          files.add(entity);
        }
      }

      // 按修改时间排序，最新的在前面
      files
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } catch (e) {
      throw Exception('Failed to get backup files: $e');
    }
  }

  /// 删除备份文件
  Future<void> deleteBackup(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web platform does not support file system access');
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete backup: $e');
    }
  }
}
