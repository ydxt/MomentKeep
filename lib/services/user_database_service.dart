import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_package;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite_package;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) 'package:moment_keep/services/empty_sqflite_ffi.dart';

// 定义动态类型别名以适配不同环境
typedef DatabaseType = dynamic;

// 使用简单的日志函数
void _log(String message) {
  if (kDebugMode) {
    print('[UserDatabaseService] $message');
  }
}

/// 用户数据库服务类
/// 负责集中管理所有用户的ID等信息
class UserDatabaseService {
  // 静态单例实例
  static final UserDatabaseService _instance = UserDatabaseService._internal();

  // 数据库实例
  static DatabaseType? _database;

  // 初始化状态标志
  bool _isInitialized = false;

  // 初始化完成的Completer
  Completer<void>? _initializationCompleter;

  // 私有构造函数
  UserDatabaseService._internal();

  // 工厂构造函数返回单例
  factory UserDatabaseService() => _instance;

  /// 数据库名称
  static const String _databaseName = 'moment_keep_users.db';

  /// 数据库版本
  static const int _databaseVersion = 2;

  /// 预初始化数据库服务（轻量级）
  /// 仅进行必要的准备工作，不执行耗时操作
  void preInitialize() {
    // 这里可以做一些轻量级的准备工作
    _initializationCompleter = Completer<void>();
  }

  /// 获取数据库实例（单例模式，保持一个连接）
  Future<DatabaseType> get database async {
    // 如果数据库连接已存在，直接返回
    if (_database != null) {
      return _database!;
    }

    // 标记为已初始化
    if (!_isInitialized &&
        _initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      _isInitialized = true;
      _initializationCompleter!.complete();
    }

    // 初始化数据库连接
    _database = await _initDatabase();
    return _database!;
  }

  /// 等待数据库完全初始化完成
  Future<void> waitForInitialization() async {
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      await _initializationCompleter!.future;
    }
  }

  /// 初始化数据库
  Future<DatabaseType> _initDatabase() async {
    // 处理不同环境下的数据库初始化
    try {
      if (kIsWeb) {
        // Web环境使用模拟数据库
        _log('Web环境: 使用模拟内存数据库');
        final mockDb = _createMockDatabase();
        // 手动调用onCreate初始化表结构
        await _onCreate(mockDb, _databaseVersion);
        return mockDb;
      }
      
      final directory = await _getDefaultDirectory();
      if (directory == null) {
        throw Exception('Unable to access default directory');
      }

      final path = path_package.join(directory.path, _databaseName);

      // 桌面平台处理 (Windows, Linux, macOS)
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _log('桌面环境: 使用FFi数据库 at $path');
        // 初始化FFI数据库工厂
        try {
          // 初始化sqflite_ffi
          sqfliteFfiInit();
        } catch (e) {
          _log('FFi初始化错误: $e');
          // 继续执行，让openDatabase失败并使用模拟实现
        }
      } else {
        _log('移动环境: 使用文件数据库 at $path');
      }

      // 使用适当的数据库工厂打开数据库，直接使用databaseFactoryFfi而不是设置全局工厂
      return await databaseFactoryFfi.openDatabase(
        path,
        options: sqflite_package.OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } catch (e) {
      _log('数据库初始化错误: $e');
      // 任何环境下如果初始化失败，返回一个空的MockDatabase实例
      _log('尝试使用备用模拟数据库实现');
      return _createMockDatabase();
    }
  }

  /// 获取默认目录（default目录）
  Future<Directory?> _getDefaultDirectory() async {
    try {
      // 从SharedPreferences获取自定义存储路径
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('storage_path');

      Directory storageDir;

      if (customPath != null && customPath.isNotEmpty) {
        // 使用自定义存储路径下的default目录
        storageDir = Directory('$customPath/default');
      } else {
        // 使用默认路径下的default目录
        Directory directory;
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          // 移动端使用应用文档目录
          directory = await getApplicationDocumentsDirectory();
        } else if (defaultTargetPlatform == TargetPlatform.windows) {
          // Windows使用文档目录
          directory = Directory(path_package.join(
              Platform.environment['USERPROFILE']!, 'Documents'));
        } else if (defaultTargetPlatform == TargetPlatform.macOS) {
          // macOS使用文档目录
          directory = Directory(
              path_package.join(Platform.environment['HOME']!, 'Documents'));
        } else if (defaultTargetPlatform == TargetPlatform.linux) {
          // Linux使用文档目录
          directory = Directory(
              path_package.join(Platform.environment['HOME']!, 'Documents'));
        } else {
          throw UnsupportedError('Unsupported platform');
        }

        // 创建默认存储目录
        storageDir = Directory(path_package.join(directory.path, 'MomentKeep', 'default'));
      }

      // 确保存储目录存在
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }

      return storageDir;
    } catch (e) {
      _log('Error getting default directory: $e');
      return null;
    }
  }

  /// 创建数据库表结构
  Future<void> _onCreate(dynamic db, int version) async {
    _log('Creating user database tables, version: $version');

    // 创建用户主表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        user_type TINYINT NOT NULL,
        status TINYINT NOT NULL DEFAULT 0,
        create_time DATETIME NOT NULL,
        update_time DATETIME NOT NULL,
        last_login_time DATETIME,
        login_ip VARCHAR(50),
        delete_flag TINYINT NOT NULL DEFAULT 0
      );
    ''');
    _log('Created users table');

    // 创建买家扩展表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS buyer_extensions (
        user_id TEXT PRIMARY KEY,
        nickname VARCHAR(20) NOT NULL,
        avatar VARCHAR(255),
        gender TINYINT DEFAULT 0,
        birthday DATE,
        phone VARCHAR(20),
        email VARCHAR(100),
        password_hash VARCHAR(128),
        secret_question VARCHAR(255),
        default_address_id VARCHAR(12),
        member_level TINYINT DEFAULT 0,
        points REAL DEFAULT 0,
        id_card_encrypt VARCHAR(128),
        real_name VARCHAR(50),
        privacy_setting JSON,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      );
    ''');
    _log('Created buyer_extensions table');

    // 创建商家扩展表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS seller_extensions (
        user_id TEXT PRIMARY KEY,
        business_name VARCHAR(100) NOT NULL,
        business_license VARCHAR(255) NOT NULL,
        credit_code VARCHAR(50),
        contact_name VARCHAR(50) NOT NULL,
        contact_phone VARCHAR(20) NOT NULL,
        phone VARCHAR(20),
        email VARCHAR(100),
        password_hash VARCHAR(128),
        secret_question VARCHAR(255),
        shop_id VARCHAR(12),
        settlement_account JSON,
        qualification_status TINYINT DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      );
    ''');
    _log('Created seller_extensions table');

    // 创建管理员扩展表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS admin_extensions (
        user_id TEXT PRIMARY KEY,
        real_name VARCHAR(50) NOT NULL,
        job_number VARCHAR(20) NOT NULL,
        dept VARCHAR(50) NOT NULL,
        enterprise_email VARCHAR(100) NOT NULL,
        password_hash VARCHAR(128),
        secret_question VARCHAR(255),
        role_id VARCHAR(10),
        permission_ids VARCHAR(255),
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      );
    ''');
    _log('Created admin_extensions table');

    // 创建索引
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_buyer_phone ON buyer_extensions(phone);');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_buyer_email ON buyer_extensions(email);');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_seller_business_name ON seller_extensions(business_name);');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_job_number ON admin_extensions(job_number);');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_email ON admin_extensions(enterprise_email);');

    _log('User database tables created successfully');
  }

  /// 数据库升级处理
  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    _log('Upgrading user database from version $oldVersion to $newVersion');
    
    // 处理从版本1升级到版本2 - 添加real_name列到buyer_extensions表
    if (oldVersion < 2) {
      try {
        // 为buyer_extensions表添加real_name列
        await db.execute(
            'ALTER TABLE buyer_extensions ADD COLUMN real_name VARCHAR(50);');
        _log('Added real_name column to buyer_extensions table');
      } catch (e) {
        _log('Error during database upgrade: $e');
        // 允许部分失败，继续尝试后续升级
      }
    }
  }

  /// 模拟数据库实现（Web环境使用）
  dynamic _createMockDatabase() {
    return _MockDatabaseForWeb();
  }

  /// 插入新用户
  Future<int> insertUser(Map<String, dynamic> userData, Map<String, dynamic>? extensionData) async {
    final db = await database;
    int result = 0;

    // 开始事务
    await db.transaction((txn) async {
      // 插入用户主表
      result = await txn.insert('users', userData);

      // 根据用户类型插入扩展表
      final userType = userData['user_type'];
      final userId = userData['user_id'];

      if (extensionData != null) {
        extensionData['user_id'] = userId;

        if (userType == 0) {
          // 买家
          await txn.insert('buyer_extensions', extensionData);
        } else if (userType == 1) {
          // 商家
          await txn.insert('seller_extensions', extensionData);
        } else if (userType == 2) {
          // 管理员
          await txn.insert('admin_extensions', extensionData);
        }
      }
    });

    return result;
  }

  /// 根据用户ID获取用户信息
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final db = await database;
    final userResult = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (userResult.isEmpty) {
      return null;
    }

    // 创建一个新的Map对象，而不是直接使用数据库返回的只读对象
    final userData = Map<String, dynamic>.from(userResult.first);
    final userType = userData['user_type'];
    Map<String, dynamic>? extensionData;

    // 获取扩展信息
    if (userType == 0) {
      // 买家
      final buyerResult = await db.query(
        'buyer_extensions',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (buyerResult.isNotEmpty) {
        extensionData = Map<String, dynamic>.from(buyerResult.first);
      }
    } else if (userType == 1) {
      // 商家
      final sellerResult = await db.query(
        'seller_extensions',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (sellerResult.isNotEmpty) {
        extensionData = Map<String, dynamic>.from(sellerResult.first);
      }
    } else if (userType == 2) {
      // 管理员
      final adminResult = await db.query(
        'admin_extensions',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (adminResult.isNotEmpty) {
        extensionData = Map<String, dynamic>.from(adminResult.first);
      }
    }

    if (extensionData != null) {
      userData.addAll(extensionData);
    }

    return userData;
  }

  /// 更新用户信息
  Future<int> updateUser(String userId, Map<String, dynamic> userData, Map<String, dynamic>? extensionData) async {
    final db = await database;
    int result = 0;

    // 不使用事务，直接更新
    // 更新用户主表（仅当有数据时）
    if (userData.isNotEmpty) {
      result = await db.update(
        'users',
        userData,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }

    // 如果提供了扩展数据，更新扩展表
    if (extensionData != null && extensionData.isNotEmpty) {
      // 获取用户类型
      final userResult = await db.query(
        'users',
        columns: ['user_type'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (userResult.isNotEmpty) {
        final userType = userResult.first['user_type'];

        if (userType == 0) {
          // 买家
          await db.update(
            'buyer_extensions',
            extensionData,
            where: 'user_id = ?',
            whereArgs: [userId],
          );
        } else if (userType == 1) {
          // 商家
          await db.update(
            'seller_extensions',
            extensionData,
            where: 'user_id = ?',
            whereArgs: [userId],
          );
        } else if (userType == 2) {
          // 管理员
          await db.update(
            'admin_extensions',
            extensionData,
            where: 'user_id = ?',
            whereArgs: [userId],
          );
        }
      }
    }

    return result;
  }

  /// 删除用户（逻辑删除）
  Future<int> deleteUser(String userId) async {
    final db = await database;
    return await db.update(
      'users',
      {'delete_flag': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// 获取所有用户列表
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users', where: 'delete_flag = 0');
  }
  
  /// 根据邮箱查找用户
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    
    // 首先查找买家扩展表
    final buyerResult = await db.query(
      'buyer_extensions',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    
    if (buyerResult.isNotEmpty) {
      final buyerData = Map<String, dynamic>.from(buyerResult.first);
      final userId = buyerData['user_id'];
      
      // 获取用户主表信息
      final userResult = await db.query(
        'users',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (userResult.isNotEmpty) {
        final userData = Map<String, dynamic>.from(userResult.first);
        userData.addAll(buyerData);
        return userData;
      }
    }
    
    // 然后查找商家扩展表
    final sellerResult = await db.query(
      'seller_extensions',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    
    if (sellerResult.isNotEmpty) {
      final sellerData = Map<String, dynamic>.from(sellerResult.first);
      final userId = sellerData['user_id'];
      
      // 获取用户主表信息
      final userResult = await db.query(
        'users',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (userResult.isNotEmpty) {
        final userData = Map<String, dynamic>.from(userResult.first);
        userData.addAll(sellerData);
        return userData;
      }
    }
    
    // 最后查找管理员扩展表
    final adminResult = await db.query(
      'admin_extensions',
      where: 'enterprise_email = ?',
      whereArgs: [email],
      limit: 1,
    );
    
    if (adminResult.isNotEmpty) {
      final adminData = Map<String, dynamic>.from(adminResult.first);
      final userId = adminData['user_id'];
      
      // 获取用户主表信息
      final userResult = await db.query(
        'users',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (userResult.isNotEmpty) {
        final userData = Map<String, dynamic>.from(userResult.first);
        userData.addAll(adminData);
        return userData;
      }
    }
    
    return null;
  }
}

/// Web环境下的模拟数据库实现
class _MockDatabaseForWeb {
  // 存储表数据，格式：{tableName: {rowId: rowData}}
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};
  // 自增ID计数器
  final Map<String, int> _autoIncrementIds = {};

  Future<void> execute(String sql) async {
    // 简单的SQL解析，仅处理CREATE TABLE语句
    if (sql.trim().toUpperCase().startsWith('CREATE TABLE')) {
      final tableName = 
          RegExp(r'CREATE TABLE\s+([a-zA-Z_]+)\s*\(').firstMatch(sql)?.group(1);
      if (tableName != null) {
        _tables[tableName] = {};
        _autoIncrementIds[tableName] = 1;
      }
    }
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    // 简单的查询实现
    return [];
  }

  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack}) async {
    if (!_tables.containsKey(table)) {
      _tables[table] = {};
      _autoIncrementIds[table] = 1;
    }

    final id = values.containsKey('user_id') 
        ? values['user_id'].toString()
        : _autoIncrementIds[table]!.toString();
    _tables[table]![id] = values;
    _autoIncrementIds[table] = _autoIncrementIds[table]! + 1;
    return 1;
  }

  Future<List<Map<String, dynamic>>> query(String table, {
    String? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (!_tables.containsKey(table)) {
      return [];
    }

    var rows = _tables[table]!.values.toList();

    // 简单的where条件过滤
    if (where != null && whereArgs != null && where.contains('?')) {
      rows = rows.where((row) {
        if (where.contains('=') && whereArgs.length == 1) {
          final fieldName = where.split('=')[0].trim();
          return row[fieldName] == whereArgs[0];
        }
        return true;
      }).toList();
    }

    return rows;
  }

  Future<int> update(String table, Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (!_tables.containsKey(table)) {
      return 0;
    }

    int count = 0;

    _tables[table]!.forEach((key, row) {
      bool shouldUpdate = false;

      if (where != null && whereArgs != null && where.contains('?')) {
        if (where.contains('=') && whereArgs.length == 1) {
          final fieldName = where.split('=')[0].trim();
          if (row[fieldName] == whereArgs[0]) {
            shouldUpdate = true;
          }
        }
      } else {
        shouldUpdate = true;
      }

      if (shouldUpdate) {
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow.addAll(values);
        _tables[table]![key] = updatedRow;
        count++;
      }
    });

    return count;
  }

  Future<int> delete(String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (!_tables.containsKey(table)) {
      return 0;
    }

    int count = 0;
    final keysToDelete = <String>[];

    _tables[table]!.forEach((key, row) {
      bool shouldDelete = false;

      if (where != null && whereArgs != null && where.contains('?')) {
        if (where.contains('=') && whereArgs.length == 1) {
          final fieldName = where.split('=')[0].trim();
          if (row[fieldName] == whereArgs[0]) {
            shouldDelete = true;
          }
        }
      } else {
        shouldDelete = true;
      }

      if (shouldDelete) {
        keysToDelete.add(key);
        count++;
      }
    });

    for (final key in keysToDelete) {
      _tables[table]!.remove(key);
    }

    return count;
  }

  Future<int> close() async {
    return 0;
  }

  dynamic transaction(Future<void> Function(dynamic) action) async {
    await action(this);
  }
}
