import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'dart:convert';

/// 习惯数据迁移服务
/// 将习惯数据从 SharedPreferences 迁移到 SQLite
class HabitMigrationService {
  static final HabitMigrationService _instance = HabitMigrationService._internal();
  factory HabitMigrationService() => _instance;
  HabitMigrationService._internal();

  final DatabaseService _databaseService = DatabaseService();

  /// 检查是否需要迁移
  Future<bool> needsMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSharedPrefsData = prefs.containsKey('habits');
      
      // 检查 SQLite 是否有数据
      final db = await _databaseService.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM habits');
      final sqliteCount = result.isNotEmpty ? result[0]['count'] as int : 0;
      
      // 如果 SharedPreferences 有数据且 SQLite 没有或数据较少，则需要迁移
      return hasSharedPrefsData && sqliteCount == 0;
    } catch (e) {
      print('检查迁移状态失败: $e');
      return false;
    }
  }

  /// 执行迁移
  Future<MigrationResult> migrate() async {
    try {
      print('开始习惯数据迁移...');
      
      // 1. 从 SharedPreferences 读取数据
      final prefs = await SharedPreferences.getInstance();
      final habitsJson = prefs.getString('habits');
      
      if (habitsJson == null || habitsJson.isEmpty) {
        print('SharedPreferences 中没有习惯数据');
        return MigrationResult(
          success: false,
          message: 'SharedPreferences 中没有习惯数据',
          migratedCount: 0,
        );
      }

      // 2. 解析数据
      final List<dynamic> habitsList = jsonDecode(habitsJson);
      final habits = habitsList
          .map((habitJson) => Habit.fromJson(habitJson as Map<String, dynamic>))
          .toList();

      print('从 SharedPreferences 加载了 ${habits.length} 个习惯');

      // 3. 检查 SQLite 是否已有数据
      final db = await _databaseService.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM habits');
      final sqliteCount = result.isNotEmpty ? result[0]['count'] as int : 0;

      if (sqliteCount > 0) {
        print('SQLite 中已有 $sqliteCount 个习惯，跳过迁移');
        return MigrationResult(
          success: true,
          message: 'SQLite 中已有数据，无需迁移',
          migratedCount: 0,
        );
      }

      // 4. 迁移数据到 SQLite
      int migratedCount = 0;
      int errorCount = 0;

      for (final habit in habits) {
        try {
          await _insertHabitToSqlite(habit);
          migratedCount++;
          print('已迁移习惯: ${habit.name}');
        } catch (e) {
          errorCount++;
          print('迁移习惯失败 ${habit.name}: $e');
        }
      }

      print('迁移完成: 成功 $migratedCount, 失败 $errorCount');

      // 5. 迁移打卡记录
      await _migrateHabitRecords(habits);

      // 6. 清除 SharedPreferences 数据（可选，建议保留作为备份）
      // await prefs.remove('habits');

      return MigrationResult(
        success: true,
        message: '成功迁移 $migratedCount 个习惯',
        migratedCount: migratedCount,
        errorCount: errorCount,
      );
    } catch (e, stackTrace) {
      print('迁移失败: $e\n$stackTrace');
      return MigrationResult(
        success: false,
        message: '迁移失败: $e',
        migratedCount: 0,
      );
    }
  }

  /// 将习惯插入 SQLite
  Future<void> _insertHabitToSqlite(Habit habit) async {
    final db = await _databaseService.database;
    
    // 注意：根据实际数据库表结构调整字段
    await db.insert(
      'habits',
      {
        'id': int.tryParse(habit.id) ?? habit.id.hashCode,
        'name': habit.name,
        'description': habit.notes,
        'color': habit.color.toRadixString(16),
        'icon': habit.icon,
        'target': '${habit.fullStars}',
        'created_at': habit.createdAt.toIso8601String(),
        'updated_at': habit.updatedAt.toIso8601String(),
        'is_reminder_enabled': habit.reminderTime != null ? 1 : 0,
        'reminder_time': habit.reminderTime?.toIso8601String(),
        'frequency': habit.frequency.name,
        'status': 'active',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 迁移打卡记录
  Future<void> _migrateHabitRecords(List<Habit> habits) async {
    final db = await _databaseService.database;
    int migratedRecords = 0;

    for (final habit in habits) {
      for (final record in habit.checkInRecords) {
        try {
          await db.insert(
            'habit_records',
            {
              'habit_id': int.tryParse(habit.id) ?? habit.id.hashCode,
              'check_in_date': record.timestamp.toIso8601String().split('T')[0],
              'check_in_time': record.timestamp.toIso8601String(),
              'note': record.comment,
              'score': record.score,
              'status': 'completed',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          migratedRecords++;
        } catch (e) {
          print('迁移打卡记录失败: $e');
        }
      }
    }

    print('已迁移 $migratedRecords 条打卡记录');
  }

  /// 回滚迁移（从 SQLite 恢复到 SharedPreferences）
  Future<bool> rollback() async {
    try {
      print('开始回滚迁移...');
      
      final db = await _databaseService.database;
      
      // 1. 从 SQLite 读取数据
      final habitsResult = await db.rawQuery('SELECT * FROM habits');
      final recordsResult = await db.rawQuery('SELECT * FROM habit_records');

      if (habitsResult.isEmpty) {
        print('SQLite 中没有习惯数据');
        return false;
      }

      // 2. 转换为 Habit 实体
      final habits = habitsResult.map((row) {
        // 这里需要根据实际的数据库字段映射回 Habit 实体
        // 简化实现
        return Habit(
          id: row['id'].toString(),
          name: row['name'] as String,
          categoryId: '1',
          category: '默认',
          icon: row['icon'] as String? ?? 'fitness_center',
          color: int.tryParse(row['color'] as String? ?? 'FF4CAF50') ?? 0xFF4CAF50,
          createdAt: DateTime.parse(row['created_at'] as String),
          updatedAt: DateTime.parse(row['updated_at'] as String),
          fullStars: int.tryParse(row['target'] as String? ?? '5') ?? 5,
          notes: row['description'] as String? ?? '',
        );
      }).toList();

      // 3. 保存到 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final habitsJson = jsonEncode(habits.map((h) => h.toJson()).toList());
      await prefs.setString('habits', habitsJson);

      print('回滚完成，已恢复 ${habits.length} 个习惯到 SharedPreferences');
      return true;
    } catch (e) {
      print('回滚失败: $e');
      return false;
    }
  }

  /// 获取迁移统计
  Future<MigrationStats> getStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final db = await _databaseService.database;

      // SharedPreferences 数据
      final sharedPrefsHasData = prefs.containsKey('habits');
      int sharedPrefsCount = 0;
      if (sharedPrefsHasData) {
        final habitsJson = prefs.getString('habits');
        if (habitsJson != null) {
          final List<dynamic> list = jsonDecode(habitsJson);
          sharedPrefsCount = list.length;
        }
      }

      // SQLite 数据
      final habitsResult = await db.rawQuery('SELECT COUNT(*) as count FROM habits');
      final sqliteHabitsCount = habitsResult.isNotEmpty ? habitsResult[0]['count'] as int : 0;

      final recordsResult = await db.rawQuery('SELECT COUNT(*) as count FROM habit_records');
      final sqliteRecordsCount = recordsResult.isNotEmpty ? recordsResult[0]['count'] as int : 0;

      return MigrationStats(
        sharedPrefsHasData: sharedPrefsHasData,
        sharedPrefsCount: sharedPrefsCount,
        sqliteHabitsCount: sqliteHabitsCount,
        sqliteRecordsCount: sqliteRecordsCount,
      );
    } catch (e) {
      print('获取迁移统计失败: $e');
      return MigrationStats();
    }
  }
}

/// 迁移结果
class MigrationResult {
  final bool success;
  final String message;
  final int migratedCount;
  final int errorCount;

  const MigrationResult({
    required this.success,
    required this.message,
    this.migratedCount = 0,
    this.errorCount = 0,
  });
}

/// 迁移统计
class MigrationStats {
  final bool sharedPrefsHasData;
  final int sharedPrefsCount;
  final int sqliteHabitsCount;
  final int sqliteRecordsCount;

  const MigrationStats({
    this.sharedPrefsHasData = false,
    this.sharedPrefsCount = 0,
    this.sqliteHabitsCount = 0,
    this.sqliteRecordsCount = 0,
  });
}
