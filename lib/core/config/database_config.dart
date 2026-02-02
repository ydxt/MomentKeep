import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// SQLite数据库配置类
class DatabaseConfig {
  /// 数据库版本
  static const int databaseVersion = 1;

  /// 数据库名称
  static const String databaseName = 'moment_keep.db';

  /// 初始化数据库
  static Future<Database> initialize() async {
    // 在Web平台上，返回一个模拟的Database对象
    if (kIsWeb) {
      // 这里我们返回一个空的Database对象，因为在Web平台上我们不会使用这个文件
      throw Exception(
          'DatabaseConfig is not supported on Web platform. Use DatabaseService instead.');
    }

    // 初始化数据库工厂（用于Windows/Linux/macOS）
    if (!kIsWeb) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 获取数据库路径
    String databasePath;

    // 从SharedPreferences获取自定义存储路径
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('storage_path');

    if (customPath != null && customPath.isNotEmpty) {
      // 使用自定义存储路径
      databasePath = customPath;
    } else {
      // 使用默认路径
      databasePath = await getDatabasesPath();
    }

    final path = join(databasePath, databaseName);

    // 确保目录存在
    final dir = Directory(databasePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 打开或创建数据库
    final database = await openDatabase(
      path,
      version: databaseVersion,
      onCreate: (db, version) async {
        // 创建所有表
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 数据库升级逻辑
        await _upgradeDatabase(db, oldVersion, newVersion);
      },
    );

    return database;
  }

  /// 创建所有表
  static Future<void> _createTables(Database db) async {
    // 创建用户设置表
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 创建待办事项表
    await db.execute('''
      CREATE TABLE todos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        priority INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        deadline DATETIME,
        tags TEXT
      )
    ''');

    // 创建习惯表
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        frequency INTEGER NOT NULL,
        target_value INTEGER NOT NULL,
        unit TEXT NOT NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL
      )
    ''');

    // 创建习惯记录表
    await db.execute('''
      CREATE TABLE habit_records (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        date TEXT NOT NULL,
        value INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    // 创建番茄钟记录表
    await db.execute('''
      CREATE TABLE pomodoro_sessions (
        id TEXT PRIMARY KEY,
        duration INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL
      )
    ''');

    // 创建智能日记表
    await db.execute('''
      CREATE TABLE diary_entries (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        mood INTEGER NOT NULL,
        tags TEXT,
        images TEXT,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL
      )
    ''');

    // 创建成就表
    await db.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        is_unlocked INTEGER NOT NULL DEFAULT 0,
        unlocked_at DATETIME,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL
      )
    ''');
  }

  /// 数据库升级逻辑
  static Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    // 这里将在后续数据库版本升级时添加升级逻辑
    // 例如：添加新表、修改表结构等
  }

  /// 关闭数据库
  static Future<void> close(Database db) async {
    await db.close();
  }

  /// 清除所有数据
  static Future<void> clearAll() async {
    // 在Web平台上，跳过数据库操作
    if (kIsWeb) {
      return;
    }

    final db = await initialize();
    await db.execute('DELETE FROM user_settings');
    await db.execute('DELETE FROM todos');
    await db.execute('DELETE FROM habits');
    await db.execute('DELETE FROM habit_records');
    await db.execute('DELETE FROM pomodoro_sessions');
    await db.execute('DELETE FROM diary_entries');
    await db.execute('DELETE FROM achievements');
    await close(db);
  }
}
