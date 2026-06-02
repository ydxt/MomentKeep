import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
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

class ImportExportService {
  static final ImportExportService _instance = ImportExportService._internal();

  final DatabaseService _databaseService = DatabaseService();

  final StorageService _storageService = StorageService();

  ImportExportService._internal();

  factory ImportExportService() => _instance;

  static const String _exportVersion = '1.0.0';

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
    String format = 'zip',
    DateTime? todoStartDate,
    DateTime? todoEndDate,
    DateTime? habitStartDate,
    DateTime? habitEndDate,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform does not support file system access');
    }

    try {
      switch (format) {
        case 'excel':
          return await _exportAsExcel(
            exportCategories: exportCategories,
            exportTodos: exportTodos,
            exportHabits: exportHabits,
            exportJournals: exportJournals,
            exportPomodoros: exportPomodoros,
            exportPlans: exportPlans,
            exportAchievements: exportAchievements,
            exportRecycleBin: exportRecycleBin,
            todoStartDate: todoStartDate,
            todoEndDate: todoEndDate,
            habitStartDate: habitStartDate,
            habitEndDate: habitEndDate,
          );
        case 'json':
          return await _exportAsJson(
            exportCategories: exportCategories,
            exportTodos: exportTodos,
            exportHabits: exportHabits,
            exportJournals: exportJournals,
            exportPomodoros: exportPomodoros,
            exportPlans: exportPlans,
            exportAchievements: exportAchievements,
            exportRecycleBin: exportRecycleBin,
            todoStartDate: todoStartDate,
            todoEndDate: todoEndDate,
            habitStartDate: habitStartDate,
            habitEndDate: habitEndDate,
          );
        case 'zip':
        default:
          return await _exportAsZip(
            exportCategories: exportCategories,
            exportTodos: exportTodos,
            exportHabits: exportHabits,
            exportJournals: exportJournals,
            exportPomodoros: exportPomodoros,
            exportPlans: exportPlans,
            exportAchievements: exportAchievements,
            exportRecycleBin: exportRecycleBin,
            exportMedia: exportMedia,
            todoStartDate: todoStartDate,
            todoEndDate: todoEndDate,
            habitStartDate: habitStartDate,
            habitEndDate: habitEndDate,
          );
      }
    } catch (e) {
      throw Exception('导出数据失败: $e');
    }
  }

  Future<String> _exportAsZip({
    bool exportCategories = true,
    bool exportTodos = true,
    bool exportHabits = true,
    bool exportJournals = true,
    bool exportPomodoros = true,
    bool exportPlans = true,
    bool exportAchievements = true,
    bool exportRecycleBin = true,
    bool exportMedia = true,
    DateTime? todoStartDate,
    DateTime? todoEndDate,
    DateTime? habitStartDate,
    DateTime? habitEndDate,
  }) async {
    final archive = Archive();

    final manifest = {
      'version': _exportVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
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

    archive.addFile(ArchiveFile(
      'manifest.json',
      0,
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
    ));

    if (exportCategories) {
      final categories = await _exportCategories();
      archive.addFile(ArchiveFile(
        'categories.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(categories)),
      ));
    }

    if (exportTodos) {
      final todos = await _exportTodos(
        startDate: todoStartDate,
        endDate: todoEndDate,
      );
      archive.addFile(ArchiveFile(
        'todos.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(todos)),
      ));
    }

    if (exportHabits) {
      final habits = await _exportHabits(
        startDate: habitStartDate,
        endDate: habitEndDate,
      );
      archive.addFile(ArchiveFile(
        'habits.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(habits)),
      ));
    }

    if (exportJournals) {
      final journals = await _exportJournals();
      archive.addFile(ArchiveFile(
        'journals.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(journals)),
      ));
    }

    if (exportPomodoros) {
      final pomodoros = await _exportPomodoros();
      archive.addFile(ArchiveFile(
        'pomodoros.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(pomodoros)),
      ));
    }

    if (exportPlans) {
      final plans = await _exportPlans();
      archive.addFile(ArchiveFile(
        'plans.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(plans)),
      ));
    }

    if (exportAchievements) {
      final achievements = await _exportAchievements();
      archive.addFile(ArchiveFile(
        'achievements.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(achievements)),
      ));
    }

    if (exportRecycleBin) {
      final recycleBin = await _exportRecycleBin();
      archive.addFile(ArchiveFile(
        'recycle_bin.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(recycleBin)),
      ));
    }

    if (exportMedia) {
      await _exportMediaFiles(archive);
    }

    final backupDir = await _getExportDirectory();
    final fileName = 'momentkeep_export_${DateTime.now().millisecondsSinceEpoch}.zip';
    final filePath = path_package.join(backupDir.path, fileName);
    final zipFile = File(filePath);

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('ZIP 编码失败');
    }
    await zipFile.writeAsBytes(zipBytes);

    return filePath;
  }

  Future<String> _exportAsExcel({
    bool exportCategories = true,
    bool exportTodos = true,
    bool exportHabits = true,
    bool exportJournals = true,
    bool exportPomodoros = true,
    bool exportPlans = true,
    bool exportAchievements = true,
    bool exportRecycleBin = true,
    DateTime? todoStartDate,
    DateTime? todoEndDate,
    DateTime? habitStartDate,
    DateTime? habitEndDate,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    if (exportCategories) {
      final sheet = excel['分类'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('名称'), TextCellValue('类型'), TextCellValue('图标'), TextCellValue('颜色')]);
      final categories = await _exportCategories();
      for (final cat in categories) {
        sheet.appendRow([
          TextCellValue(cat['id']?.toString() ?? ''),
          TextCellValue(cat['name']?.toString() ?? ''),
          TextCellValue(cat['type']?.toString() ?? ''),
          TextCellValue(cat['icon']?.toString() ?? ''),
          TextCellValue(cat['color']?.toString() ?? ''),
        ]);
      }
    }

    if (exportTodos) {
      final sheet = excel['待办事项'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('标题'), TextCellValue('分类ID'), TextCellValue('优先级'), TextCellValue('是否完成'), TextCellValue('创建时间'), TextCellValue('结束时间'), TextCellValue('标签')]);
      final todos = await _exportTodos(
        startDate: todoStartDate,
        endDate: todoEndDate,
      );
      for (final todo in todos) {
        String? endDateStr;
        if (todo['date'] != null) {
          try {
            endDateStr = dateFormat.format(DateTime.parse(todo['date'].toString()));
          } catch (_) {
            endDateStr = todo['date']?.toString() ?? '';
          }
        }
        String createdAtStr = '';
        try {
          createdAtStr = dateFormat.format(DateTime.parse(todo['createdAt'].toString()));
        } catch (_) {
          createdAtStr = todo['createdAt']?.toString() ?? '';
        }
        sheet.appendRow([
          TextCellValue(todo['id']?.toString() ?? ''),
          TextCellValue(todo['title']?.toString() ?? ''),
          TextCellValue(todo['categoryId']?.toString() ?? ''),
          TextCellValue(todo['priority']?.toString() ?? ''),
          TextCellValue(todo['isCompleted'] == true ? '是' : '否'),
          TextCellValue(createdAtStr),
          TextCellValue(endDateStr ?? ''),
          TextCellValue((todo['tags'] is List) ? (todo['tags'] as List).join(', ') : ''),
        ]);
      }
    }

    if (exportHabits) {
      final sheet = excel['习惯追踪'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('名称'), TextCellValue('图标'), TextCellValue('计分模式'), TextCellValue('频率'), TextCellValue('目标天数'), TextCellValue('创建时间')]);
      final habits = await _exportHabits(
        startDate: habitStartDate,
        endDate: habitEndDate,
      );
      for (final habit in habits) {
        String createdAtStr = '';
        try {
          createdAtStr = dateFormat.format(DateTime.parse(habit['createdAt'].toString()));
        } catch (_) {
          createdAtStr = habit['createdAt']?.toString() ?? '';
        }
        sheet.appendRow([
          TextCellValue(habit['id']?.toString() ?? ''),
          TextCellValue(habit['name']?.toString() ?? ''),
          TextCellValue(habit['icon']?.toString() ?? ''),
          TextCellValue(habit['scoringMode']?.toString() ?? ''),
          TextCellValue(habit['frequency']?.toString() ?? ''),
          TextCellValue(habit['targetDays']?.toString() ?? ''),
          TextCellValue(createdAtStr),
        ]);
      }

      final checkInSheet = excel['打卡记录'];
      checkInSheet.appendRow([TextCellValue('习惯ID'), TextCellValue('习惯名称'), TextCellValue('评分'), TextCellValue('打卡时间'), TextCellValue('是否补卡'), TextCellValue('补卡时间'), TextCellValue('是否负向打卡')]);
      for (final habit in habits) {
        final checkInRecords = habit['checkInRecords'];
        if (checkInRecords is List) {
          for (final record in checkInRecords) {
            if (record is Map<String, dynamic>) {
              String timestampStr = '';
              try {
                timestampStr = dateFormat.format(DateTime.parse(record['timestamp'].toString()));
              } catch (_) {
                timestampStr = record['timestamp']?.toString() ?? '';
              }
              final isMakeup = record['checkedInAt'] != null;
              String checkedInAtStr = '';
              if (isMakeup) {
                try {
                  checkedInAtStr = dateFormat.format(DateTime.parse(record['checkedInAt'].toString()));
                } catch (_) {
                  checkedInAtStr = record['checkedInAt']?.toString() ?? '';
                }
              }
              checkInSheet.appendRow([
                TextCellValue(habit['id']?.toString() ?? ''),
                TextCellValue(habit['name']?.toString() ?? ''),
                TextCellValue(record['score']?.toString() ?? ''),
                TextCellValue(timestampStr),
                TextCellValue(isMakeup ? '是' : '否'),
                TextCellValue(checkedInAtStr),
                TextCellValue(record['isNegative'] == true ? '是' : '否'),
              ]);
            }
          }
        }
      }
    }

    if (exportJournals) {
      final sheet = excel['日记'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('标题'), TextCellValue('分类ID'), TextCellValue('日期'), TextCellValue('标签'), TextCellValue('创建时间')]);
      final journals = await _exportJournals();
      for (final journal in journals) {
        String dateStr = '';
        try {
          dateStr = dateFormat.format(DateTime.parse(journal['date'].toString()));
        } catch (_) {
          dateStr = journal['date']?.toString() ?? '';
        }
        String createdAtStr = '';
        try {
          createdAtStr = dateFormat.format(DateTime.parse(journal['createdAt'].toString()));
        } catch (_) {
          createdAtStr = journal['createdAt']?.toString() ?? '';
        }
        sheet.appendRow([
          TextCellValue(journal['id']?.toString() ?? ''),
          TextCellValue(journal['title']?.toString() ?? ''),
          TextCellValue(journal['categoryId']?.toString() ?? ''),
          TextCellValue(dateStr),
          TextCellValue((journal['tags'] is List) ? (journal['tags'] as List).join(', ') : ''),
          TextCellValue(createdAtStr),
        ]);
      }
    }

    if (exportPomodoros) {
      final sheet = excel['番茄钟'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('时长(分钟)'), TextCellValue('开始时间'), TextCellValue('结束时间'), TextCellValue('标签')]);
      final pomodoros = await _exportPomodoros();
      for (final pomodoro in pomodoros) {
        String startTimeStr = '';
        try {
          final startTime = pomodoro['start_time'] ?? pomodoro['startTime'];
          if (startTime is int) {
            startTimeStr = dateFormat.format(DateTime.fromMillisecondsSinceEpoch(startTime));
          } else {
            startTimeStr = dateFormat.format(DateTime.parse(startTime.toString()));
          }
        } catch (_) {
          startTimeStr = (pomodoro['start_time'] ?? pomodoro['startTime'] ?? '').toString();
        }
        String endTimeStr = '';
        try {
          final endTime = pomodoro['end_time'] ?? pomodoro['endTime'];
          if (endTime != null) {
            if (endTime is int) {
              endTimeStr = dateFormat.format(DateTime.fromMillisecondsSinceEpoch(endTime));
            } else {
              endTimeStr = dateFormat.format(DateTime.parse(endTime.toString()));
            }
          }
        } catch (_) {
          endTimeStr = (pomodoro['end_time'] ?? pomodoro['endTime'] ?? '').toString();
        }
        final durationMinutes = pomodoro['duration_minutes'] ?? pomodoro['duration'] ?? 0;
        sheet.appendRow([
          TextCellValue((pomodoro['pomodoro_id'] ?? pomodoro['id'] ?? '').toString()),
          TextCellValue(durationMinutes.toString()),
          TextCellValue(startTimeStr),
          TextCellValue(endTimeStr),
          TextCellValue(pomodoro['tag']?.toString() ?? ''),
        ]);
      }
    }

    if (exportPlans) {
      final sheet = excel['计划'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('名称'), TextCellValue('描述'), TextCellValue('开始日期'), TextCellValue('结束日期'), TextCellValue('是否完成')]);
      final plans = await _exportPlans();
      for (final plan in plans) {
        String startDateStr = '';
        try {
          startDateStr = dateFormat.format(DateTime.parse(plan['startDate'].toString()));
        } catch (_) {
          startDateStr = plan['startDate']?.toString() ?? '';
        }
        String endDateStr = '';
        try {
          endDateStr = dateFormat.format(DateTime.parse(plan['endDate'].toString()));
        } catch (_) {
          endDateStr = plan['endDate']?.toString() ?? '';
        }
        sheet.appendRow([
          TextCellValue(plan['id']?.toString() ?? ''),
          TextCellValue(plan['name']?.toString() ?? ''),
          TextCellValue(plan['description']?.toString() ?? ''),
          TextCellValue(startDateStr),
          TextCellValue(endDateStr),
          TextCellValue(plan['isCompleted'] == true ? '是' : '否'),
        ]);
      }
    }

    if (exportAchievements) {
      final sheet = excel['成就'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('名称'), TextCellValue('描述'), TextCellValue('类型'), TextCellValue('是否解锁'), TextCellValue('所需进度'), TextCellValue('当前进度')]);
      final achievements = await _exportAchievements();
      for (final achievement in achievements) {
        sheet.appendRow([
          TextCellValue(achievement['id']?.toString() ?? ''),
          TextCellValue(achievement['name']?.toString() ?? ''),
          TextCellValue(achievement['description']?.toString() ?? ''),
          TextCellValue(achievement['type']?.toString() ?? ''),
          TextCellValue(achievement['isUnlocked'] == true ? '是' : '否'),
          TextCellValue(achievement['requiredProgress']?.toString() ?? ''),
          TextCellValue(achievement['currentProgress']?.toString() ?? ''),
        ]);
      }
    }

    if (exportRecycleBin) {
      final sheet = excel['回收站'];
      sheet.appendRow([TextCellValue('ID'), TextCellValue('原始类型'), TextCellValue('名称'), TextCellValue('删除时间')]);
      final recycleBin = await _exportRecycleBin();
      for (final item in recycleBin) {
        String deletedAtStr = '';
        try {
          deletedAtStr = dateFormat.format(DateTime.parse(item['deletedAt'].toString()));
        } catch (_) {
          deletedAtStr = item['deletedAt']?.toString() ?? '';
        }
        sheet.appendRow([
          TextCellValue(item['id']?.toString() ?? ''),
          TextCellValue(item['type']?.toString() ?? ''),
          TextCellValue(item['name']?.toString() ?? ''),
          TextCellValue(deletedAtStr),
        ]);
      }
    }

    final backupDir = await _getExportDirectory();
    final fileName = 'momentkeep_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = path_package.join(backupDir.path, fileName);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Excel 编码失败');
    }
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  Future<String> _exportAsJson({
    bool exportCategories = true,
    bool exportTodos = true,
    bool exportHabits = true,
    bool exportJournals = true,
    bool exportPomodoros = true,
    bool exportPlans = true,
    bool exportAchievements = true,
    bool exportRecycleBin = true,
    DateTime? todoStartDate,
    DateTime? todoEndDate,
    DateTime? habitStartDate,
    DateTime? habitEndDate,
  }) async {
    final archive = Archive();

    if (exportCategories) {
      final categories = await _exportCategories();
      archive.addFile(ArchiveFile(
        'categories.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(categories)),
      ));
    }

    if (exportTodos) {
      final todos = await _exportTodos(
        startDate: todoStartDate,
        endDate: todoEndDate,
      );
      archive.addFile(ArchiveFile(
        'todos.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(todos)),
      ));
    }

    if (exportHabits) {
      final habits = await _exportHabits(
        startDate: habitStartDate,
        endDate: habitEndDate,
      );
      archive.addFile(ArchiveFile(
        'habits.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(habits)),
      ));
    }

    if (exportJournals) {
      final journals = await _exportJournals();
      archive.addFile(ArchiveFile(
        'journals.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(journals)),
      ));
    }

    if (exportPomodoros) {
      final pomodoros = await _exportPomodoros();
      archive.addFile(ArchiveFile(
        'pomodoros.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(pomodoros)),
      ));
    }

    if (exportPlans) {
      final plans = await _exportPlans();
      archive.addFile(ArchiveFile(
        'plans.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(plans)),
      ));
    }

    if (exportAchievements) {
      final achievements = await _exportAchievements();
      archive.addFile(ArchiveFile(
        'achievements.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(achievements)),
      ));
    }

    if (exportRecycleBin) {
      final recycleBin = await _exportRecycleBin();
      archive.addFile(ArchiveFile(
        'recycle_bin.json',
        0,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(recycleBin)),
      ));
    }

    final backupDir = await _getExportDirectory();
    final fileName = 'momentkeep_export_${DateTime.now().millisecondsSinceEpoch}.zip';
    final filePath = path_package.join(backupDir.path, fileName);
    final zipFile = File(filePath);

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('ZIP 编码失败');
    }
    await zipFile.writeAsBytes(zipBytes);

    return filePath;
  }

  Future<ImportResult> importData(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform does not support file system access');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('导出文件不存在');
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

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

      if (manifest.version != _exportVersion) {
        print('警告：导出文件版本 ${manifest.version} 与当前版本 $_exportVersion 不同');
      }

      final tempDir = await getTemporaryDirectory();
      final mediaDir = Directory(path_package.join(tempDir.path, 'import_media_${DateTime.now().millisecondsSinceEpoch}'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final mediaPathMap = <String, String>{};
      for (final mediaFile in mediaFiles) {
        final fileName = mediaFile.name;
        final newFilePath = path_package.join(mediaDir.path, fileName.substring(6));
        final newFile = File(newFilePath);

        await newFile.parent.create(recursive: true);

        await newFile.writeAsBytes(mediaFile.content as List<int>);
        mediaPathMap['media/${fileName.substring(6)}'] = newFilePath;
      }

      final result = ImportResult();

      if (manifest.modules['categories'] == true && filesMap.containsKey('categories.json')) {
        result.categoriesImported = await _importCategories(filesMap['categories.json']!);
      }

      if (manifest.modules['todos'] == true && filesMap.containsKey('todos.json')) {
        result.todosImported = await _importTodos(filesMap['todos.json']!);
      }

      if (manifest.modules['habits'] == true && filesMap.containsKey('habits.json')) {
        result.habitsImported = await _importHabits(filesMap['habits.json']!);
      }

      if (manifest.modules['journals'] == true && filesMap.containsKey('journals.json')) {
        result.journalsImported = await _importJournals(
          filesMap['journals.json']!,
          mediaPathMap,
        );
      }

      if (manifest.modules['pomodoros'] == true && filesMap.containsKey('pomodoros.json')) {
        result.pomodorosImported = await _importPomodoros(filesMap['pomodoros.json']!);
      }

      if (manifest.modules['plans'] == true && filesMap.containsKey('plans.json')) {
        result.plansImported = await _importPlans(filesMap['plans.json']!);
      }

      if (manifest.modules['achievements'] == true && filesMap.containsKey('achievements.json')) {
        result.achievementsImported = await _importAchievements(filesMap['achievements.json']!);
      }

      if (manifest.modules['recycleBin'] == true && filesMap.containsKey('recycle_bin.json')) {
        result.recycleBinImported = await _importRecycleBin(filesMap['recycle_bin.json']!);
      }

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

  Future<List<Map<String, dynamic>>> _exportCategories() async {
    try {
      final db = DatabaseService();
      final userId = await db.getCurrentUserId() ?? 'default_user';
      final rows = await db.getCategories(userId);
      if (rows.isEmpty) return [];
      return rows.map((row) {
        final data = <String, dynamic>{};
        if (row['data'] != null) {
          try {
            data.addAll(jsonDecode(row['data'] as String) as Map<String, dynamic>);
          } catch (_) {}
        }
        data['id'] = row['id'].toString();
        data['name'] = row['name'];
        data['type'] = row['type'];
        data['icon'] = row['icon'] ?? '';
        data['color'] = row['color'] ?? 0;
        return data;
      }).toList();
    } catch (e) {
      print('导出分类失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportTodos({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = DatabaseService();
      final todos = await db.getTodos();
      var todosMap = todos.map((t) => t.toJson()).toList();

      if (startDate != null || endDate != null) {
        todosMap = todosMap.where((todo) {
          try {
            final createdAt = DateTime.parse(todo['createdAt'].toString());
            if (startDate != null && createdAt.isBefore(startDate)) return false;
            if (endDate != null && createdAt.isAfter(endDate)) return false;
            return true;
          } catch (_) {
            return true;
          }
        }).toList();
      }

      return todosMap;
    } catch (e) {
      print('导出待办事项失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportHabits({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = DatabaseService();
      final habits = await db.getAllHabits();
      if (habits.isEmpty) return [];

      var habitsMap = habits.map((h) => h.toJson()).toList();

      if (startDate != null || endDate != null) {
        habitsMap = habitsMap.map((habit) {
          final checkInRecords = habit['checkInRecords'];
          if (checkInRecords is List) {
            final filteredRecords = checkInRecords.where((record) {
              if (record is Map<String, dynamic>) {
                try {
                  final timestamp = DateTime.parse(record['timestamp'].toString());
                  if (startDate != null && timestamp.isBefore(startDate)) return false;
                  if (endDate != null && timestamp.isAfter(endDate)) return false;
                  return true;
                } catch (_) {
                  return true;
                }
              }
              return true;
            }).toList();
            return Map<String, dynamic>.from(habit)..['checkInRecords'] = filteredRecords;
          }
          return habit;
        }).toList();
      }

      return habitsMap;
    } catch (e) {
      print('导出习惯失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _exportJournals() async {
    try {
      final journals = await _databaseService.getJournals();
      return journals.map((journal) {
        return {
          'id': journal['id'],
          'categoryId': journal['category_id'],
          'title': journal['title'],
          'content': journal['content'],
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

  Future<List<Map<String, dynamic>>> _exportRecycleBin() async {
    try {
      final db = DatabaseService();
      final userId = await db.getCurrentUserId() ?? 'default_user';
      final rows = await db.getRecycleBinItems(userId);
      if (rows.isEmpty) return [];
      return rows.map((row) {
        final data = <String, dynamic>{};
        if (row['data'] != null) {
          try {
            data.addAll(jsonDecode(row['data'] as String) as Map<String, dynamic>);
          } catch (_) {}
        }
        data['id'] = row['id'].toString();
        data['type'] = row['type'];
        data['name'] = row['name'];
        if (row['deleted_at'] != null) data['deletedAt'] = row['deleted_at'];
        if (row['expires_at'] != null) data['expiresAt'] = row['expires_at'];
        return data;
      }).toList();
    } catch (e) {
      print('导出回收站失败: $e');
      return [];
    }
  }

  Future<void> _exportMediaFiles(Archive archive) async {
    try {
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

  Future<int> _importCategories(List<dynamic> categoriesData) async {
    try {
      final db = DatabaseService();
      final userId = await db.getCurrentUserId() ?? 'default_user';
      int importedCount = 0;
      for (final data in categoriesData) {
        try {
          final cat = entities.Category.fromJson(data as Map<String, dynamic>);
          final dataJson = jsonEncode({
            'isExpanded': cat.isExpanded,
            'isQuestionBank': cat.isQuestionBank,
          });
          await db.insertCategory(userId, {
            'name': cat.name,
            'icon': cat.icon,
            'color': cat.color,
            'type': cat.type.toString().split('.').last,
            'sort_order': importedCount,
            'data': dataJson,
          });
          importedCount++;
        } catch (_) {}
      }
      return importedCount;
    } catch (e) {
      print('导入分类失败: $e');
      return 0;
    }
  }

  Future<int> _importTodos(List<dynamic> todosData) async {
    try {
      final db = DatabaseService();
      int importedCount = 0;
      for (final todoJson in todosData) {
        try {
          final todo = Todo.fromJson(todoJson as Map<String, dynamic>);
          await db.insertTodo(todo);
          importedCount++;
        } catch (e) {
          print('导入单条待办事项失败: $e');
        }
      }
      return importedCount;
    } catch (e) {
      print('导入待办事项失败: $e');
      return 0;
    }
  }

  Future<int> _importHabits(List<dynamic> habitsData) async {
    try {
      final db = DatabaseService();
      int importedCount = 0;
      for (final data in habitsData) {
        try {
          final habit = Habit.fromJson(data as Map<String, dynamic>);
          await db.insertHabit(habit);
          importedCount++;
        } catch (_) {}
      }
      return importedCount;
    } catch (e) {
      print('导入习惯失败: $e');
      return 0;
    }
  }

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

          String contentStr = journal['content'] as String;
          if (contentStr.isNotEmpty) {
            contentStr = await EncryptionHelper.encrypt(contentStr);
          }

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

  Future<int> _importRecycleBin(List<dynamic> recycleBinData) async {
    try {
      final db = DatabaseService();
      final userId = await db.getCurrentUserId() ?? 'default_user';
      int importedCount = 0;
      for (final data in recycleBinData) {
        try {
          final item = RecycleBinItem.fromJson(data as Map<String, dynamic>);
          await db.insertRecycleBinItem(
            userId,
            item.type,
            jsonEncode(item.data),
            item.deletedAt.toIso8601String(),
          );
          importedCount++;
        } catch (_) {}
      }
      return importedCount;
    } catch (e) {
      print('导入回收站失败: $e');
      return 0;
    }
  }

  // ==================== 辅助方法 ====================

  Future<Directory> _getExportDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform does not support file system access');
    }

    Directory directory;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows) {
        directory = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
      } else if (Platform.isMacOS) {
        directory = Directory('${Platform.environment['HOME']}/Downloads');
      } else if (Platform.isLinux) {
        directory = Directory('${Platform.environment['HOME']}/Downloads');
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
