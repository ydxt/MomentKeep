import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/services/storage_service.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart' as entities;
import 'package:moment_keep/domain/entities/pomodoro.dart';
import 'package:moment_keep/domain/entities/plan.dart';
import 'package:moment_keep/domain/entities/achievement.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';

/// 导入导出服务 - 结构化 JSON 数据导入导出
class ImportExportService {
  /// 单例实例
  static final ImportExportService _instance = ImportExportService._internal();

  /// 数据库服务
  final DatabaseService _databaseService = DatabaseService();

  /// 存储服务
  final StorageService _storageService = StorageService();

  /// 私有构造函数
  ImportExportService._internal();

  /// 工厂构造函数
  factory ImportExportService() => _instance;

  /// 导出包版本
  static const String _exportVersion = '1.0.0';

  /// 导出数据结构
  Future<String> exportData({
    bool exportCategories = true,
    bool exportTodos = true,
    bool exportHabits = true,
    bool exportJournals = true,
    bool exportPomodoros = true,
    bool exportPlans = true,
    bool exportAchievements = true,
    bool exportRecycleBin = true,
    bool exportMedia = true,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform does not support file system access');
    }

    try {
      // 创建 ZIP 归档
      final archive = Archive();

      // 创建 manifest
      final manifest = {
        'version': _exportVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0', // TODO: 从 package_info 获取
        'modules': {
          'categories': exportCategories,
          'todos': exportTodos,
          'habits': exportHabits,
          'journals': exportJournals,
          'pomodoros': exportPomodoros,
          'plans': exportPlans,
          'achievements': exportAchievements,
          'recycleBin': exportRecycleBin,
          'media': exportMedia,
        },
      };

      // 添加 manifest.json
      archive.addFile(ArchiveFile(
        'manifest.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
      ));

      // 导出分类
      if (exportCategories) {
        final categories = await _exportCategories();
        archive.addFile(ArchiveFile(
          'categories.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(categories)),
        ));
      }

      // 导出待办事项
      if (exportTodos) {
        final todos = await _exportTodos();
        archive.addFile(ArchiveFile(
          'todos.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(todos)),
        ));
      }

      // 导出习惯
      if (exportHabits) {
        final habits = await _exportHabits();
        archive.addFile(ArchiveFile(
          'habits.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(habits)),
        ));
      }

      // 导出日记
      if (exportJournals) {
        final journals = await _exportJournals();
        archive.addFile(ArchiveFile(
          'journals.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(journals)),
        ));
      }

      // 导出番茄钟
      if (exportPomodoros) {
        final pomodoros = await _exportPomodoros();
        archive.addFile(ArchiveFile(
          'pomodoros.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(pomodoros)),
        ));
      }

      // 导出计划
      if (exportPlans) {
        final plans = await _exportPlans();
        archive.addFile(ArchiveFile(
          'plans.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(plans)),
        ));
      }

      // 导出成就
      if (exportAchievements) {
        final achievements = await _exportAchievements();
        archive.addFile(ArchiveFile(
          'achievements.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(achievements)),
        ));
      }

      // 导出回收站
      if (exportRecycleBin) {
        final recycleBin = await _exportRecycleBin();
        archive.addFile(ArchiveFile(
          'recycle_bin.json',
          0,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(recycleBin)),
        ));
      }

      // 导出媒体文件
      if (exportMedia) {
        await _exportMediaFiles(archive);
      }

      // 创建 ZIP 文件
      final backupDir = await _getExportDirectory();
      final fileName = 'momentkeep_export_${DateTime.now().millisecondsSinceEpoch}.zip';
      final filePath = path_package.join(backupDir.path, fileName);
      final zipFile = File(filePath);

      // 写入 ZIP 数据
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('ZIP 编码失败');
      }
      await zipFile.writeAsBytes(zipBytes);

      return filePath;
    } catch (e) {
      throw Exception('导出数据失败: $e');
    }
  }

  /// 导入数据
  Future<ImportResult> importData(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform does not support file system access');
    }

    try {
      // 读取 ZIP 文件
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('导出文件不存在');
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 解析 manifest
      ManifestData? manifest;
      final filesMap = <String, List<dynamic>>{};
      final mediaFiles = <ArchiveFile>[];

      for (final archiveFile in archive) {
        if (archiveFile.isFile) {
          final fileName = archiveFile.name;

          if (fileName == 'manifest.json') {
            final content = utf8.decode(archiveFile.content as List<int>);
            manifest = ManifestData.fromJson(json.decode(content));
          } else if (fileName.endsWith('.json')) {
            final content = utf8.decode(archiveFile.content as List<int>);
            final data = json.decode(content) as List<dynamic>;
            filesMap[fileName] = data;
          } else if (fileName.startsWith('media/')) {
            mediaFiles.add(archiveFile);
          }
        }
      }

      if (manifest == null) {
        throw Exception('导出文件格式错误：缺少 manifest.json');
      }

      // 验证版本兼容性
      if (manifest.version != _exportVersion) {
        print('警告：导出文件版本 ${manifest.version} 与当前版本 $_exportVersion 不同');
      }

      // 创建临时目录用于解压媒体文件
      final tempDir = await getTemporaryDirectory();
      final mediaDir = Directory(path_package.join(tempDir.path, 'import_media_${DateTime.now().millisecondsSinceEpoch}'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      // 解压媒体文件
      final mediaPathMap = <String, String>{}; // 原路径 -> 新路径
      for (final mediaFile in mediaFiles) {
        final fileName = mediaFile.name;
        final newFilePath = path_package.join(mediaDir.path, fileName.substring(6)); // 去掉 'media/' 前缀
        final newFile = File(newFilePath);

        // 确保目录存在
        await newFile.parent.create(recursive: true);

        await newFile.writeAsBytes(mediaFile.content as List<int>);
        mediaPathMap['media/${fileName.substring(6)}'] = newFilePath;
      }

      // 开始导入
      final result = ImportResult();

      // 1. 导入分类（优先导入，因为其他数据可能引用）
      if (manifest.modules['categories'] == true && filesMap.containsKey('categories.json')) {
        result.categoriesImported = await _importCategories(filesMap['categories.json']!);
      }

      // 2. 导入待办事项
      if (manifest.modules['todos'] == true && filesMap.containsKey('todos.json')) {
        result.todosImported = await _importTodos(filesMap['todos.json']!);
      }

      // 3. 导入习惯
      if (manifest.modules['habits'] == true && filesMap.containsKey('habits.json')) {
        result.habitsImported = await _importHabits(filesMap['habits.json']!);
      }

      // 4. 导入日记
      if (manifest.modules['journals'] == true && filesMap.containsKey('journals.json')) {
        result.journalsImported = await _importJournals(
          filesMap['journals.json']!,
          mediaPathMap,
        );
      }

      // 5. 导入番茄钟
      if (manifest.modules['pomodoros'] == true && filesMap.containsKey('pomodoros.json')) {
        result.pomodorosImported = await _importPomodoros(filesMap['pomodoros.json']!);
      }

      // 6. 导入计划
      if (manifest.modules['plans'] == true && filesMap.containsKey('plans.json')) {
        result.plansImported = await _importPlans(filesMap['plans.json']!);
      }

      // 7. 导入成就
      if (manifest.modules['achievements'] == true && filesMap.containsKey('achievements.json')) {
        result.achievementsImported = await _importAchievements(filesMap['achievements.json']!);
      }

      // 8. 导入回收站
      if (manifest.modules['recycleBin'] == true && filesMap.containsKey('recycle_bin.json')) {
        result.recycleBinImported = await _importRecycleBin(filesMap['recycle_bin.json']!);
      }

      // 清理临时文件
      try {
        if (await mediaDir.exists()) {
          await mediaDir.delete(recursive: true);
        }
      } catch (e) {
        print('清理临时文件失败: $e');
      }

      result.success = true;
      return result;
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: '导入数据失败: $e',
      );
    }
  }

  // ==================== 导出方法 ====================

  /// 导出分类
  Future<List<Map<String, dynamic>>> _exportCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString('categories');
      if (categoriesJson == null) return [];

      final categoriesList = jsonDecode(categoriesJson) as List<dynamic>;
      return categoriesList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('导出分类失败: $e');
      return [];
    }
  }

  /// 导出待办事项
  Future<List<Map<String, dynamic>>> _exportTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todosJson = prefs.getString('todo_entries');
      if (todosJson == null) return [];

      final todosList = jsonDecode(todosJson) as List<dynamic>;
      return todosList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('导出待办事项失败: $e');
      return [];
    }
  }

  /// 导出习惯
  Future<List<Map<String, dynamic>>> _exportHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitsJson = prefs.getString('habits');
      if (habitsJson == null) return [];

      final habitsList = jsonDecode(habitsJson) as List<dynamic>;
      return habitsList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('导出习惯失败: $e');
      return [];
    }
  }

  /// 导出日记
  Future<List<Map<String, dynamic>>> _exportJournals() async {
    try {
      final journals = await _databaseService.getJournals();
      return journals.map((journal) {
        // 数据库返回的已经是解密后的数据，需要转换字段名
        return {
          'id': journal['id'],
          'categoryId': journal['category_id'],
          'title': journal['title'],
          'content': journal['content'], // 已解密的 JSON 字符串
          'tags': journal['tags'],
          'date': journal['date'],
          'createdAt': journal['created_at'],
          'updatedAt': journal['updated_at'],
          'subject': journal['subject'],
          'remarks': journal['remarks'],
          'mood': journal['mood'],
        };
      }).toList();
    } catch (e) {
      print('导出日记失败: $e');
      return [];
    }
  }

  /// 导出番茄钟
  Future<List<Map<String, dynamic>>> _exportPomodoros() async {
    try {
      final db = await _databaseService.database;
      final records = await db.query('pomodoro_records');
      return records.map((record) {
        return Pomodoro(
          id: record['id'].toString(),
          duration: record['duration'] as int,
          startTime: DateTime.parse(record['start_time'] as String),
          endTime: record['end_time'] != null
              ? DateTime.parse(record['end_time'] as String)
              : null,
          tag: record['tag'] as String? ?? '',
        ).toJson();
      }).toList();
    } catch (e) {
      print('导出番茄钟失败: $e');
      return [];
    }
  }

  /// 导出计划
  Future<List<Map<String, dynamic>>> _exportPlans() async {
    try {
      final db = await _databaseService.database;
      final plans = await db.query('plans');
      return plans.map((plan) {
        return Plan(
          id: plan['id'].toString(),
          name: plan['name'] as String,
          description: plan['description'] as String? ?? '',
          startDate: DateTime.parse(plan['start_date'] as String),
          endDate: DateTime.parse(plan['end_date'] as String),
          isCompleted: (plan['is_completed'] as int) == 1,
          habitIds: plan['habit_ids'] != null
              ? List<String>.from(jsonDecode(plan['habit_ids'] as String))
              : [],
        ).toJson();
      }).toList();
    } catch (e) {
      print('导出计划失败: $e');
      return [];
    }
  }

  /// 导出成就
  Future<List<Map<String, dynamic>>> _exportAchievements() async {
    try {
      final db = await _databaseService.database;
      final achievements = await db.query('achievements');
      return achievements.map((achievement) {
        return Achievement(
          id: achievement['id'].toString(),
          name: achievement['name'] as String,
          description: achievement['description'] as String,
          type: AchievementType.values.firstWhere(
            (e) => e.toString().split('.').last == achievement['type'],
            orElse: () => AchievementType.habit,
          ),
          isUnlocked: (achievement['is_unlocked'] as int) == 1,
          unlockedAt: achievement['unlocked_at'] != null
              ? DateTime.parse(achievement['unlocked_at'] as String)
              : null,
          requiredProgress: achievement['required_progress'] as int,
          currentProgress: achievement['current_progress'] as int,
        ).toJson();
      }).toList();
    } catch (e) {
      print('导出成就失败: $e');
      return [];
    }
  }

  /// 导出回收站
  Future<List<Map<String, dynamic>>> _exportRecycleBin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recycleBinJson = prefs.getString('recycle_bin');
      if (recycleBinJson == null) return [];

      final recycleBinList = jsonDecode(recycleBinJson) as List<dynamic>;
      return recycleBinList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('导出回收站失败: $e');
      return [];
    }
  }

  /// 导出媒体文件
  Future<void> _exportMediaFiles(Archive archive) async {
    try {
      // 获取所有图片和音频文件
      final images = await _storageService.getImages(userId: 'export');
      final audioFiles = await _storageService.getAudioFiles(userId: 'export');
      final allFiles = [...images, ...audioFiles];

      for (final file in allFiles) {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = path_package.basename(file.path);
          final fileType = _getFileType(fileName);
          final archivePath = 'media/$fileType/$fileName';

          archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
        }
      }
    } catch (e) {
      print('导出媒体文件失败: $e');
    }
  }

  // ==================== 导入方法 ====================

  /// 导入分类
  Future<int> _importCategories(List<dynamic> categoriesData) async {
    try {
      final categories = categoriesData
          .map((data) => entities.Category.fromJson(data as Map<String, dynamic>))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'categories',
        jsonEncode(categories.map((c) => c.toJson()).toList()),
      );

      return categories.length;
    } catch (e) {
      print('导入分类失败: $e');
      return 0;
    }
  }

  /// 导入待办事项
  Future<int> _importTodos(List<dynamic> todosData) async {
    try {
      final todos = todosData
          .map((data) => Todo.fromJson(data as Map<String, dynamic>))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'todo_entries',
        jsonEncode(todos.map((t) => t.toJson()).toList()),
      );

      return todos.length;
    } catch (e) {
      print('导入待办事项失败: $e');
      return 0;
    }
  }

  /// 导入习惯
  Future<int> _importHabits(List<dynamic> habitsData) async {
    try {
      final habits = habitsData
          .map((data) => Habit.fromJson(data as Map<String, dynamic>))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'habits',
        jsonEncode(habits.map((h) => h.toJson()).toList()),
      );

      return habits.length;
    } catch (e) {
      print('导入习惯失败: $e');
      return 0;
    }
  }

  /// 导入日记
  Future<int> _importJournals(
    List<dynamic> journalsData,
    Map<String, String> mediaPathMap,
  ) async {
    try {
      int importedCount = 0;
      final currentUserId = await _databaseService.getCurrentUserId() ?? 'default_user';

      for (final journalData in journalsData) {
        try {
          final journal = journalData as Map<String, dynamic>;

          // 处理内容中的媒体文件路径
          String contentStr = journal['content'] as String;
          if (contentStr.isNotEmpty) {
            // TODO: 处理媒体文件路径映射
            // 需要根据 mediaPathMap 更新内容中的路径

            // 加密内容
            contentStr = await EncryptionHelper.encrypt(contentStr);
          }

          // 插入数据库
          await _databaseService.database.then((db) async {
            await db.insert('journals', {
              'id': journal['id'],
              'category_id': journal['categoryId'],
              'title': journal['title'],
              'content': contentStr,
              'tags': jsonEncode(journal['tags'] ?? []),
              'date': journal['date'],
              'created_at': journal['createdAt'],
              'updated_at': journal['updatedAt'],
              'subject': journal['subject'],
              'remarks': journal['remarks'],
              'mood': journal['mood'],
              'user_id': currentUserId,
            });
          });

          importedCount++;
        } catch (e) {
          print('导入单条日记失败: $e');
        }
      }

      return importedCount;
    } catch (e) {
      print('导入日记失败: $e');
      return 0;
    }
  }

  /// 导入番茄钟
  Future<int> _importPomodoros(List<dynamic> pomodorosData) async {
    try {
      int importedCount = 0;
      final db = await _databaseService.database;

      for (final pomodoroData in pomodorosData) {
        try {
          final pomodoro = Pomodoro.fromJson(pomodoroData as Map<String, dynamic>);

          await db.insert('pomodoro_records', {
            'id': int.tryParse(pomodoro.id),
            'duration': pomodoro.duration,
            'start_time': pomodoro.startTime.toIso8601String(),
            'end_time': pomodoro.endTime?.toIso8601String(),
            'tag': pomodoro.tag,
          });

          importedCount++;
        } catch (e) {
          print('导入单个番茄钟失败: $e');
        }
      }

      return importedCount;
    } catch (e) {
      print('导入番茄钟失败: $e');
      return 0;
    }
  }

  /// 导入计划
  Future<int> _importPlans(List<dynamic> plansData) async {
    try {
      int importedCount = 0;
      final db = await _databaseService.database;

      for (final planData in plansData) {
        try {
          final plan = Plan.fromJson(planData as Map<String, dynamic>);

          await db.insert('plans', {
            'id': int.tryParse(plan.id),
            'name': plan.name,
            'description': plan.description,
            'start_date': plan.startDate.toIso8601String(),
            'end_date': plan.endDate.toIso8601String(),
            'is_completed': plan.isCompleted ? 1 : 0,
            'habit_ids': jsonEncode(plan.habitIds),
          });

          importedCount++;
        } catch (e) {
          print('导入单个计划失败: $e');
        }
      }

      return importedCount;
    } catch (e) {
      print('导入计划失败: $e');
      return 0;
    }
  }

  /// 导入成就
  Future<int> _importAchievements(List<dynamic> achievementsData) async {
    try {
      int importedCount = 0;
      final db = await _databaseService.database;

      for (final achievementData in achievementsData) {
        try {
          final achievement = Achievement.fromJson(achievementData as Map<String, dynamic>);

          await db.insert('achievements', {
            'id': int.tryParse(achievement.id),
            'name': achievement.name,
            'description': achievement.description,
            'type': achievement.type.toString().split('.').last,
            'is_unlocked': achievement.isUnlocked ? 1 : 0,
            'unlocked_at': achievement.unlockedAt?.toIso8601String(),
            'required_progress': achievement.requiredProgress,
            'current_progress': achievement.currentProgress,
          });

          importedCount++;
        } catch (e) {
          print('导入单个成就失败: $e');
        }
      }

      return importedCount;
    } catch (e) {
      print('导入成就失败: $e');
      return 0;
    }
  }

  /// 导入回收站
  Future<int> _importRecycleBin(List<dynamic> recycleBinData) async {
    try {
      final recycleBinItems = recycleBinData
          .map((data) => RecycleBinItem.fromJson(data as Map<String, dynamic>))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'recycle_bin',
        jsonEncode(recycleBinItems.map((r) => r.toJson()).toList()),
      );

      return recycleBinItems.length;
    } catch (e) {
      print('导入回收站失败: $e');
      return 0;
    }
  }

  // ==================== 辅助方法 ====================

  /// 获取导出目录
  Future<Directory> _getExportDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform does not support file system access');
    }

    Directory directory;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows) {
        directory = Directory('${Platform.environment['USERPROFILE']}\\Documents');
      } else if (Platform.isMacOS) {
        directory = Directory('${Platform.environment['HOME']}/Documents');
      } else if (Platform.isLinux) {
        directory = Directory('${Platform.environment['HOME']}/Documents');
      } else {
        throw UnsupportedError('Unsupported platform');
      }

      final exportDir = Directory(path_package.join(directory.path, 'moment_keep_exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      return exportDir;
    } catch (e) {
      throw Exception('获取导出目录失败: $e');
    }
  }

  /// 获取文件类型
  String _getFileType(String fileName) {
    final extension = path_package.extension(fileName).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'].contains(extension)) {
      return 'images';
    } else if (['.mp3', '.wav', '.ogg', '.aac', '.m4a'].contains(extension)) {
      return 'audio';
    } else if (['.mp4', '.avi', '.mov', '.mkv'].contains(extension)) {
      return 'video';
    } else {
      return 'other';
    }
  }
}

/// Manifest 数据
class ManifestData {
  final String version;
  final String exportDate;
  final String appVersion;
  final Map<String, bool> modules;

  ManifestData({
    required this.version,
    required this.exportDate,
    required this.appVersion,
    required this.modules,
  });

  factory ManifestData.fromJson(Map<String, dynamic> json) {
    return ManifestData(
      version: json['version'] as String,
      exportDate: json['exportDate'] as String,
      appVersion: json['appVersion'] as String,
      modules: Map<String, bool>.from(json['modules'] as Map),
    );
  }
}

/// 导入结果
class ImportResult {
  bool success;
  int categoriesImported;
  int todosImported;
  int habitsImported;
  int journalsImported;
  int pomodorosImported;
  int plansImported;
  int achievementsImported;
  int recycleBinImported;
  String? errorMessage;

  ImportResult({
    this.success = false,
    this.categoriesImported = 0,
    this.todosImported = 0,
    this.habitsImported = 0,
    this.journalsImported = 0,
    this.pomodorosImported = 0,
    this.plansImported = 0,
    this.achievementsImported = 0,
    this.recycleBinImported = 0,
    this.errorMessage,
  });

  int get totalImported =>
      categoriesImported +
      todosImported +
      habitsImported +
      journalsImported +
      pomodorosImported +
      plansImported +
      achievementsImported +
      recycleBinImported;
}
