import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // 导入完整的foundation，用于kDebugMode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
// 导入以获取TargetPlatform
import 'package:sqflite/sqflite.dart' as sqflite_package;
import 'package:path/path.dart' as path_package;
import 'package:path_provider/path_provider.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/core/services/storage_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/cart_database_service.dart';
import 'package:moment_keep/presentation/pages/merchant_order_management_page.dart';

// 仅在非Web平台导入sqflite_common_ffi
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    if (dart.library.html) 'package:moment_keep/services/empty_sqflite_ffi.dart';

// 定义动态类型别名以适配不同环境
typedef DatabaseType = dynamic;

// 使用简单的日志函数
void _log(String message) {
  if (kDebugMode) {
    print('[DatabaseService] $message');
  }
}

/// 网络服务类，用于与后端API通信
class _NetworkService {
  static const String baseUrl = 'http://localhost:6000/api';
  static final _client = http.Client();

  /// 发送GET请求
  static Future<http.Response> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final uri =
        Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);
    return await _client.get(uri, headers: _getHeaders());
  }

  /// 发送POST请求
  static Future<http.Response> post(String endpoint,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    return await _client.post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  /// 发送PUT请求
  static Future<http.Response> put(String endpoint,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    return await _client.put(
      uri,
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  /// 发送DELETE请求
  static Future<http.Response> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    return await _client.delete(uri, headers: _getHeaders());
  }

  /// 获取请求头
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // 这里可以添加认证信息，比如JWT token
    };
  }
}

/// Web环境下的模拟数据库实现
class _MockDatabaseForWeb {
  // 存储表数据，格式：{tableName: {rowId: rowData}}
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};
  // 自增ID计数器
  final Map<String, int> _autoIncrementIds = {};
  // 是否使用网络服务
  final bool useNetworkService = true;

  Future<void> execute(String sql) async {
    // 简单的SQL解析，仅处理CREATE TABLE语句
    if (sql.trim().toUpperCase().startsWith('CREATE TABLE')) {
      final tableName =
          RegExp(r'CREATE TABLE\s+(\w+)\s*\(').firstMatch(sql)?.group(1);
      if (tableName != null) {
        _tables[tableName] = {};
        _autoIncrementIds[tableName] = 1;
      }
    }
  }

  // 注意：这里的实现需要同时支持带参数和不带参数的调用方式
  // 当被调用为rawQuery(sql)或rawQuery(sql, args)时都能正常工作
  // 我们将使用可选参数的方式实现
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object?>? arguments]) async {
    if (useNetworkService) {
      // 简单的SQL解析，提取表名
      String? tableName;
      if (sql.toUpperCase().contains('FROM')) {
        final fromMatch = RegExp(r'FROM\s+(\w+)').firstMatch(sql.toUpperCase());
        if (fromMatch != null) {
          tableName = fromMatch.group(1);
        }
      }

      // 处理日记查询
      if (tableName == 'journals') {
        // 从本地存储获取用户ID（实际应用中应该从认证信息中获取）
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? 'default_user';

        final response = await _NetworkService.get('journals',
            queryParams: {'user_id': userId});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          return data.cast<Map<String, dynamic>>();
        }
      }

      // 处理分类查询
      if (tableName == 'categories') {
        // 从本地存储获取用户ID
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? 'default_user';

        String? typeFilter;
        if (sql.toUpperCase().contains('WHERE') &&
            arguments != null &&
            arguments.isNotEmpty) {
          final whereMatch =
              RegExp(r'WHERE\s+type\s*=\s*\?').firstMatch(sql.toUpperCase());
          if (whereMatch != null) {
            typeFilter = arguments[0] as String;
          }
        }

        final response = await _NetworkService.get('categories', queryParams: {
          'user_id': userId,
          if (typeFilter != null) 'type': typeFilter,
        });
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          return data.cast<Map<String, dynamic>>();
        }
      }
    }

    // 网络服务不可用或不支持的查询，使用本地模拟实现
    if (sql.contains('sqlite_master') && sql.contains('table')) {
      // 处理表存在检查的查询
      final tableName = RegExp(r"name=\'([^\']+)\'").firstMatch(sql)?.group(1);
      if (tableName != null && _tables.containsKey(tableName)) {
        return [
          {'name': tableName}
        ];
      }
    }

    // 处理参数化查询
    if (arguments != null && sql.contains('?')) {
      // 尝试提取表名
      String? tableName;
      if (sql.toUpperCase().contains('FROM')) {
        final fromMatch = RegExp(r'FROM\s+(\w+)').firstMatch(sql.toUpperCase());
        if (fromMatch != null) {
          tableName = fromMatch.group(1);
        }
      }

      // 如果能确定表名，并且表存在，执行简单的查询逻辑
      if (tableName != null && _tables.containsKey(tableName)) {
        final rows = _tables[tableName]!.values.toList();

        // 简单的WHERE条件处理（仅处理单一条件的情况）
        if (sql.toUpperCase().contains('WHERE') && arguments.isNotEmpty) {
          final whereMatch =
              RegExp(r'WHERE\s+(\w+)\s*=\s*\?').firstMatch(sql.toUpperCase());
          if (whereMatch != null) {
            final fieldName = whereMatch.group(1);
            final filteredRows =
                rows.where((row) => row[fieldName] == arguments[0]).toList();

            // 处理COUNT查询
            if (sql.toUpperCase().contains('COUNT')) {
              return [
                {'count': filteredRows.length}
              ];
            }

            return filteredRows;
          }
        }

        // 处理COUNT查询
        if (sql.toUpperCase().contains('COUNT')) {
          return [
            {'count': rows.length}
          ];
        }

        return rows;
      }
    }

    return [];
  }

  Future<int> close() async {
    return 0;
  }

  /// 实现batch方法以支持批量操作
  _MockBatch batch() {
    return _MockBatch(this);
  }

  /// 实现insert方法
  Future<int> insert(String table, Map<String, dynamic> values,
      {String? nullColumnHack}) async {
    if (useNetworkService) {
      // 处理日记插入
      if (table == 'journals') {
        // 从本地存储获取用户ID
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? 'default_user';

        // 构建请求体
        final body = Map<String, dynamic>.from(values);
        body['user_id'] = userId;

        // 发送POST请求
        final response = await _NetworkService.post('journals', body: body);
        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return 1; // 返回插入的行数
        }
      }

      // 处理分类插入
      if (table == 'categories') {
        // 从本地存储获取用户ID
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? 'default_user';

        // 构建请求体
        final body = Map<String, dynamic>.from(values);
        body['user_id'] = userId;

        // 发送POST请求
        final response = await _NetworkService.post('categories', body: body);
        if (response.statusCode == 201) {
          return 1; // 返回插入的行数
        }
      }
    }

    // 网络服务不可用或不支持的插入，使用本地模拟实现
    // 确保表存在
    if (!_tables.containsKey(table)) {
      _tables[table] = {};
      _autoIncrementIds[table] = 1;
    }

    // 获取自增ID
    final id = _autoIncrementIds[table]!;
    _autoIncrementIds[table] = id + 1;

    // 创建新行数据，复制传入的值并添加id
    final newRow = Map<String, dynamic>.from(values);
    newRow['id'] = id;

    // 存储数据
    _tables[table]![id.toString()] = newRow;

    return id;
  }

  /// 实现query方法
  Future<List<Map<String, dynamic>>> query(String table,
      {String? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
    if (useNetworkService) {
      // 处理日记查询
      if (table == 'journals') {
        // 从本地存储获取用户ID
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? 'default_user';

        final response = await _NetworkService.get('journals',
            queryParams: {'user_id': userId});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          return data.cast<Map<String, dynamic>>();
        }
      }
    }

    // 网络服务不可用或不支持的查询，使用本地模拟实现
    // 确保表存在
    if (!_tables.containsKey(table)) {
      return [];
    }

    // 获取所有行
    var rows = _tables[table]!.values.toList();

    // 简单的where条件过滤
    if (where != null && whereArgs != null && where.contains('?')) {
      rows = rows.where((row) {
        // 简单实现等于条件过滤，实际应用中需要更复杂的解析
        if (where.contains('=') && whereArgs.length == 1) {
          final fieldName = where.split('=')[0].trim();
          return row[fieldName] == whereArgs[0];
        }
        return true;
      }).toList();
    }

    // 排序
    if (orderBy != null) {
      rows.sort((a, b) {
        final field = orderBy.split(' ')[0];
        final isDesc = orderBy.toUpperCase().contains('DESC');

        if (a[field] == null || b[field] == null) {
          return 0;
        }

        final result = a[field].compareTo(b[field]);
        return isDesc ? -result : result;
      });
    }

    return rows;
  }

  /// 实现update方法
  Future<int> update(String table, Map<String, dynamic> values,
      {String? where, List<Object?>? whereArgs}) async {
    if (useNetworkService) {
      // 处理日记更新
      if (table == 'journals') {
        // 提取ID
        if (where != null && whereArgs != null && where.contains('?')) {
          final whereMatch =
              RegExp(r'WHERE\s+id\s*=\s*\?').firstMatch(where.toUpperCase());
          if (whereMatch != null && whereArgs.isNotEmpty) {
            final id = whereArgs[0];

            // 发送PUT请求
            final response =
                await _NetworkService.put('journals/$id', body: values);
            if (response.statusCode == 200) {
              return 1; // 返回更新的行数
            }
          }
        }
      }
    }

    // 网络服务不可用或不支持的更新，使用本地模拟实现
    // 确保表存在
    if (!_tables.containsKey(table)) {
      return 0;
    }

    int count = 0;

    // 更新匹配的行
    _tables[table]!.forEach((key, row) {
      bool shouldUpdate = false;

      // 简单的where条件匹配
      if (where != null && whereArgs != null && where.contains('?')) {
        if (where.contains('=') && whereArgs.length == 1) {
          final fieldName = where.split('=')[0].trim();
          if (row[fieldName] == whereArgs[0]) {
            shouldUpdate = true;
          }
        }
      } else {
        // 如果没有where条件，更新所有行
        shouldUpdate = true;
      }

      if (shouldUpdate) {
        // 更新行数据
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow.addAll(values);
        _tables[table]![key] = updatedRow;
        count++;
      }
    });

    return count;
  }

  /// 实现delete方法
  Future<int> delete(String table,
      {String? where, List<Object?>? whereArgs}) async {
    if (useNetworkService) {
      // 处理日记删除
      if (table == 'journals') {
        // 提取ID，支持带有user_id条件的where子句
        if (where != null && whereArgs != null && where.contains('?')) {
          // 使用更灵活的正则表达式，提取第一个问号对应的值作为ID
          final id = whereArgs[0];

          // 发送DELETE请求
          final response = await _NetworkService.delete('journals/$id');
          if (response.statusCode == 200) {
            return 1; // 返回删除的行数
          }
        }
      }
    }

    // 网络服务不可用或不支持的删除，使用本地模拟实现
    // 确保表存在
    if (!_tables.containsKey(table)) {
      return 0;
    }

    int count = 0;
    final keysToDelete = <String>[];

    // 找出要删除的行
    _tables[table]!.forEach((key, row) {
      bool shouldDelete = false;

      // 简单的where条件匹配
      if (where != null && whereArgs != null && where.contains('?')) {
        if (where.contains('=') && whereArgs.length == 1) {
          final fieldName = where.split('=')[0].trim();
          if (row[fieldName] == whereArgs[0]) {
            shouldDelete = true;
          }
        }
      } else {
        // 如果没有where条件，删除所有行
        shouldDelete = true;
      }

      if (shouldDelete) {
        keysToDelete.add(key);
        count++;
      }
    });

    // 执行删除
    for (final key in keysToDelete) {
      _tables[table]!.remove(key);
    }

    return count;
  }
}

/// 模拟批量操作类
class _MockBatch {
  final _MockDatabaseForWeb _db;
  final List<_BatchOperation> _operations = [];

  _MockBatch(this._db);

  /// 添加插入操作到批处理
  void insert(String table, Map<String, dynamic> values,
      {String? nullColumnHack}) {
    _operations.add(_BatchOperation('insert', table, values));
  }

  /// 执行所有批处理操作
  Future<List<Object?>> commit() async {
    final results = <Object?>[];

    for (final operation in _operations) {
      if (operation.type == 'insert') {
        // 确保表存在
        if (!_db._tables.containsKey(operation.table)) {
          _db._tables[operation.table] = {};
        }

        // 简单处理插入操作，使用当前时间戳作为ID
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        _db._tables[operation.table]![id] = operation.values;
        results.add(1); // 返回插入成功
      }
    }

    return results;
  }
}

/// 表示批处理中的单个操作
class _BatchOperation {
  final String type;
  final String table;
  final Map<String, dynamic> values;

  _BatchOperation(this.type, this.table, this.values);
}

/// 创建模拟数据库实例
dynamic _createMockDatabase() {
  return _MockDatabaseForWeb();
}

// 获取文档目录的函数，适配Web环境
Future<dynamic> _getDocumentsDirectory({bool includeUserDir = true}) async {
  if (kIsWeb) {
    return null; // Web环境返回null
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

      // 创建软件数据目录，与ProductDatabaseService保持一致
      storageDir =
          Directory(path_package.join(directory.path, 'MomentKeep'));
    }

    // 确保存储目录存在
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }

    // 如果需要包含用户目录，则为当前用户创建独立目录
    if (includeUserDir) {
      final currentUserId =
          await DatabaseService().getCurrentUserId() ?? 'default';
      final userDir =
          Directory(path_package.join(storageDir.path, currentUserId));
      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
      }
      return userDir;
    }

    return storageDir;
  } catch (e) {
    _log('Error getting documents directory: $e');
    // 出错时使用默认路径
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (fallbackError) {
      _log('Error getting fallback documents directory: $fallbackError');
      return null;
    }
  }
}

/// 数据库服务类
/// 负责数据库的初始化、连接和表结构管理
class DatabaseService {
  // 静态单例实例
  static final DatabaseService _instance = DatabaseService._internal();

  // 数据库实例
  static DatabaseType? _database;

  // Web平台的模拟数据库
  _MockDatabaseForWeb? _mockDatabase;

  // 初始化状态标志
  bool _isInitialized = false;

  // 初始化完成的Completer
  Completer<void>? _initializationCompleter;

  // 私有构造函数
  DatabaseService._internal();

  // 工厂构造函数返回单例
  factory DatabaseService() => _instance;

  /// 数据库名称
  static const String _databaseName = 'moment_keep.db';

  /// 数据库版本
  static const int _databaseVersion = 17;

  /// 预初始化数据库服务（轻量级）
  /// 仅进行必要的准备工作，不执行耗时操作
  void preInitialize() {
    // 这里可以做一些轻量级的准备工作
    _initializationCompleter = Completer<void>();
  }

  /// 获取数据库实例（单例模式，确保所有部分共享同一个连接）
  Future<DatabaseType> get database async {
    // 如果数据库已打开且连接正常，直接返回
    if (_database != null) {
      return _database!;
    }

    // 如果在Web平台，使用模拟数据库
    if (kIsWeb) {
      _mockDatabase = _MockDatabaseForWeb();
      _isInitialized = true;
      if (_initializationCompleter != null &&
          !_initializationCompleter!.isCompleted) {
        _initializationCompleter!.complete();
      }
      return _mockDatabase!;
    }

    // 初始化数据库实例
    _database = await _initDatabase();

    // 检查并创建缺失的表
    await _ensureTablesExist(_database!);

    // 标记为已初始化
    if (!_isInitialized &&
        _initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      _isInitialized = true;
      _initializationCompleter!.complete();
    }

    return _database!;
  }

  /// 检查并创建缺失的表
  Future<void> _ensureTablesExist(dynamic db) async {
    _log('Checking and creating missing tables...');

    // 检查reviews表是否存在
    final reviewsTableResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='reviews'");
    if (reviewsTableResult.isEmpty) {
      // 创建reviews表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reviews (
          id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          product_image TEXT NOT NULL,
          variant TEXT,
          rating INTEGER NOT NULL,
          content TEXT NOT NULL,
          images TEXT,
          created_at INTEGER NOT NULL,
          appended_at INTEGER,
          appended_content TEXT,
          appended_images TEXT,
          seller_reply TEXT,
          seller_reply_at INTEGER,
          status TEXT NOT NULL,
          FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
        );
      ''');
      _log('Created missing reviews table');

      // 添加reviews表索引
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reviews_order_id ON reviews (order_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reviews_product_id ON reviews (product_id)');
      _log('Created indexes for reviews table');
    }
    
    // 检查coupons表是否存在
    final couponsTableResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='coupons'");
    if (couponsTableResult.isEmpty) {
      // 创建coupons表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS coupons (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          amount INTEGER NOT NULL DEFAULT 0,
          condition INTEGER NOT NULL DEFAULT 0,
          validity TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT '可用',
          type TEXT NOT NULL,
          discount REAL DEFAULT 1.0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          from_user_id TEXT,
          from_user_name TEXT,
          reason TEXT,
          related_id TEXT,
          used_at INTEGER,
          used_order_id TEXT
        );
      ''');
      _log('Created missing coupons table');
    } else {
      // 检查表结构是否需要更新
      try {
        // 检查used_at列是否存在
        final columnsResult = await db.rawQuery("PRAGMA table_info(coupons)");
        final hasUsedAtColumn = columnsResult.any((column) => column['name'] == 'used_at');
        if (!hasUsedAtColumn) {
          // 添加used_at列
          await db.execute('ALTER TABLE coupons ADD COLUMN used_at INTEGER');
          _log('Added used_at column to coupons table');
        }
        
        // 检查used_order_id列是否存在
        final hasUsedOrderIdColumn = columnsResult.any((column) => column['name'] == 'used_order_id');
        if (!hasUsedOrderIdColumn) {
          // 添加used_order_id列
          await db.execute('ALTER TABLE coupons ADD COLUMN used_order_id TEXT');
          _log('Added used_order_id column to coupons table');
        }
      } catch (e) {
        _log('Error updating coupons table: $e');
      }
    }
    
    // 检查red_packets表是否存在
    final redPacketsTableResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='red_packets'");
    if (redPacketsTableResult.isEmpty) {
      // 创建red_packets表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS red_packets (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          amount INTEGER NOT NULL,
          validity TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT '可用',
          type TEXT NOT NULL DEFAULT '现金红包',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          from_user_id TEXT,
          from_user_name TEXT,
          reason TEXT,
          related_id TEXT,
          used_at INTEGER,
          used_order_id TEXT
        );
      ''');
      _log('Created missing red_packets table');
    } else {
      // 检查表结构是否需要更新
      try {
        // 检查used_at列是否存在
        final columnsResult = await db.rawQuery("PRAGMA table_info(red_packets)");
        final hasUsedAtColumn = columnsResult.any((column) => column['name'] == 'used_at');
        if (!hasUsedAtColumn) {
          // 添加used_at列
          await db.execute('ALTER TABLE red_packets ADD COLUMN used_at INTEGER');
          _log('Added used_at column to red_packets table');
        }
        
        // 检查used_order_id列是否存在
        final hasUsedOrderIdColumn = columnsResult.any((column) => column['name'] == 'used_order_id');
        if (!hasUsedOrderIdColumn) {
          // 添加used_order_id列
          await db.execute('ALTER TABLE red_packets ADD COLUMN used_order_id TEXT');
          _log('Added used_order_id column to red_packets table');
        }
      } catch (e) {
        _log('Error updating red_packets table: $e');
      }
    }
    
    // 检查shopping_cards表是否存在
    final shoppingCardsTableResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='shopping_cards'");
    if (shoppingCardsTableResult.isEmpty) {
      // 创建shopping_cards表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shopping_cards (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          amount INTEGER NOT NULL,
          validity TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT '可用',
          type TEXT NOT NULL DEFAULT '电子卡',
          from_user_id TEXT,
          from_user_name TEXT,
          reason TEXT,
          related_id TEXT,
          used_at INTEGER,
          used_order_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      _log('Created missing shopping_cards table');
    } else {
      // 检查表结构是否需要更新
      try {
        // 检查used_at列是否存在
        final columnsResult = await db.rawQuery("PRAGMA table_info(shopping_cards)");
        final hasUsedAtColumn = columnsResult.any((column) => column['name'] == 'used_at');
        if (!hasUsedAtColumn) {
          // 添加used_at列
          await db.execute('ALTER TABLE shopping_cards ADD COLUMN used_at INTEGER');
          _log('Added used_at column to shopping_cards table');
        }
        
        // 检查used_order_id列是否存在
        final hasUsedOrderIdColumn = columnsResult.any((column) => column['name'] == 'used_order_id');
        if (!hasUsedOrderIdColumn) {
          // 添加used_order_id列
          await db.execute('ALTER TABLE shopping_cards ADD COLUMN used_order_id TEXT');
          _log('Added used_order_id column to shopping_cards table');
        }
      } catch (e) {
        _log('Error updating shopping_cards table: $e');
      }
    }
    
    // 检查pomodoro_records表是否存在
    final pomodoroRecordsTableResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='pomodoro_records'");
    if (pomodoroRecordsTableResult.isEmpty) {
      // 创建pomodoro_records表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pomodoro_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pomodoro_id TEXT NOT NULL,
          todo_id INTEGER,
          habit_id INTEGER,
          user_id TEXT,
          start_time INTEGER NOT NULL,
          end_time INTEGER,
          duration_minutes INTEGER NOT NULL DEFAULT 25,
          is_completed INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          state TEXT,
          FOREIGN KEY (todo_id) REFERENCES todos(id) ON DELETE SET NULL,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE SET NULL
        );
      ''');
      _log('Created missing pomodoro_records table');
      
      // 添加索引
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pomodoro_records_completed ON pomodoro_records (is_completed)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pomodoro_records_pomodoro_id ON pomodoro_records (pomodoro_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pomodoro_records_user_id ON pomodoro_records (user_id)');
      _log('Created indexes for pomodoro_records table');
    }
  }

  /// 等待数据库完全初始化完成
  Future<void> waitForInitialization() async {
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      await _initializationCompleter!.future;
    }
  }

  /// 初始化数据库（重写为轻量级版本）
  /// 确保数据库已创建并连接
  Future<void> initialize() async {
    // 只进行预初始化，不执行完整的数据库加载
    preInitialize();
    // 初始化加密助手
    await EncryptionHelper.initialize();
    // 不等待完整数据库加载，允许异步进行
  }

  /// 完全初始化数据库（用于需要完整数据库时）
  Future<void> fullyInitialize() async {
    // 确保数据库已经初始化并获取实例
    await database;
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

      // 获取存储目录（包含用户目录）
      final userDir = await _getDocumentsDirectory(includeUserDir: true);
      if (userDir == null) {
        throw Exception('Unable to access storage directory');
      }

      // 使用用户目录存储该用户的数据
      final path = path_package.join(userDir.path, _databaseName);
      _log('使用用户目录: $path');

      // 桌面平台处理 (Windows, Linux, macOS)
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _log('桌面环境: 使用FFi数据库 at $path');
        // 初始化FFI数据库工厂
        try {
          // 初始化sqflite_ffi
          sqfliteFfiInit();
          // 直接使用databaseFactoryFfi而不是设置全局工厂
          return await databaseFactoryFfi.openDatabase(
            path,
            options: sqflite_package.OpenDatabaseOptions(
              version: _databaseVersion,
              onCreate: _onCreate,
              onUpgrade: _onUpgrade,
              // 使用单例模式（默认），确保所有部分共享同一个连接
              singleInstance: true,
            ),
          );
        } catch (e) {
          _log('FFi初始化错误: $e');
          // 继续执行，让openDatabase失败并使用模拟实现
        }
      } else {
        _log('移动环境: 使用文件数据库 at $path');
      }

      // 使用默认数据库工厂打开数据库
      return await sqflite_package.openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      _log('数据库初始化错误: $e');
      // 任何环境下如果初始化失败，返回一个空的MockDatabase实例
      _log('尝试使用备用模拟数据库实现');
      return _createMockDatabase();
    }
  }

  /// 创建数据库表结构 - 统一处理不同平台的数据库类型
  Future<void> _onCreate(dynamic db, int version) async {
    _log('Creating database tables, version: $version');

    // 用户管理功能已移至moment_keep_users.db数据库
    // 此处不再创建users表和id_management表

    // 创建习惯表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        target TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_time TEXT,
        frequency TEXT NOT NULL DEFAULT 'daily',
        status TEXT NOT NULL DEFAULT 'active',
        user_id TEXT
      )
    ''');
    _log('Created habits table');

    // 创建标签表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT
      );
    ''');
    _log('Created tags table');

    // 创建习惯-标签关联表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,
        UNIQUE(habit_id, tag_id)
      );
    ''');
    _log('Created habit_tags table');

    // 创建打卡记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        check_in_date TEXT NOT NULL,
        check_in_time TEXT NOT NULL,
        note TEXT,
        score INTEGER DEFAULT 100,
        status TEXT NOT NULL DEFAULT 'completed',
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');
    _log('Created habit_records table');

    // 创建计划表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        max_score INTEGER DEFAULT 100,
        start_date TEXT NOT NULL,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT
      )
    ''');
    _log('Created plans table');

    // 创建计划与习惯关联表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        habit_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE,
        UNIQUE (plan_id, habit_id)
      )
    ''');
    _log('Created plan_habits table');

    // 仅在版本大于等于3时创建新表（新安装的应用）
    if (version >= 3) {
      await _createNewTables(db);
    }

    // 创建索引以提高查询性能
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_habit_records_habit_id ON habit_records (habit_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_habit_records_date ON habit_records (check_in_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_plan_habits_plan_id ON plan_habits (plan_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_plan_habits_habit_id ON plan_habits (habit_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_habits_status ON habits (status)');
    // 标签相关索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tags_name ON tags (name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_habit_tags_habit_id ON habit_tags (habit_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_habit_tags_tag_id ON habit_tags (tag_id)');

    // 创建账单表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bills (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        income INTEGER NOT NULL DEFAULT 0,
        expense INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created bills table');

    // 创建账单明细表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_items (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        bill_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        related_id TEXT,
        FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE
      );
    ''');
    
    // 创建优惠券表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS coupons (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        condition INTEGER NOT NULL DEFAULT 0,
        validity TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '可用',
        type TEXT NOT NULL,
        discount REAL DEFAULT 1.0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        used_at INTEGER,
        used_order_id TEXT
      );
    ''');
    
    // 创建红包表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS red_packets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        validity TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '可用',
        type TEXT NOT NULL DEFAULT '现金红包',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        used_at INTEGER,
        used_order_id TEXT
      );
    ''');
    
    // 创建购物卡表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_cards (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        validity TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '可用',
        type TEXT NOT NULL DEFAULT '电子卡',
        used_date TEXT,
        used_at INTEGER,
        used_order_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    
    // 创建评论表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reviews (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        product_image TEXT NOT NULL,
        variant TEXT,
        rating INTEGER NOT NULL,
        content TEXT NOT NULL,
        images TEXT,
        created_at INTEGER NOT NULL,
        appended_at INTEGER,
        appended_content TEXT,
        appended_images TEXT,
        seller_reply TEXT,
        seller_reply_at INTEGER,
        status TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      );
    ''');
    _log('Created bill_items, coupons, red_packets, shopping_cards and reviews tables');

    // 添加账单相关索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bills_user_id ON bills (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_user_id ON bill_items (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_bill_id ON bill_items (bill_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_type ON bill_items (type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_transaction_type ON bill_items (transaction_type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_created_at ON bill_items (created_at)');
    
    // 添加优惠券、红包和购物卡相关索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_coupons_user_id ON coupons (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_coupons_status ON coupons (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_red_packets_user_id ON red_packets (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_red_packets_status ON red_packets (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shopping_cards_user_id ON shopping_cards (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shopping_cards_status ON shopping_cards (status)');
    _log('Added indexes for bill, coupons, red_packets and shopping_cards tables');

    // 更新数据库版本
    _log('数据库表结构创建完成，版本: $version');
  }

  /// 创建新版本中添加的表和索引
  Future<void> _createNewTables(dynamic db) async {
    try {
      // 创建番茄钟记录表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pomodoro_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pomodoro_id TEXT NOT NULL,
          todo_id INTEGER,
          habit_id INTEGER,
          user_id TEXT,
          start_time INTEGER NOT NULL,
          end_time INTEGER,
          duration_minutes INTEGER NOT NULL DEFAULT 25,
          is_completed INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          state TEXT,
          FOREIGN KEY (todo_id) REFERENCES todos(id) ON DELETE SET NULL,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE SET NULL
        );
      ''');
      _log('Created pomodoro_records table');

      // 创建成就表
      await db.execute('''
      CREATE TABLE IF NOT EXISTS achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        target_value INTEGER DEFAULT 0,
        is_unlocked INTEGER DEFAULT 0,
        unlocked_at TEXT,
        user_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
      _log('Created achievements table');

      // 创建日记表
      await db.execute('''
      CREATE TABLE IF NOT EXISTS journals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        title TEXT,
        content TEXT NOT NULL,
        tags TEXT,
        date TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'normal',
        attachments TEXT,
        mistake_meta TEXT,
        user_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
      _log('Created journals table');

      // 创建待办事项表
      await db.execute('''
      CREATE TABLE IF NOT EXISTS todos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'medium',
        user_id TEXT
      )
    ''');
      _log('Created todos table');

      // 添加索引
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pomodoro_records_completed ON pomodoro_records (is_completed)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pomodoro_records_created_at ON pomodoro_records (created_at)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_achievements_unlocked ON achievements (is_unlocked)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_achievements_type ON achievements (type)');
      // 添加用户ID索引，提高查询性能
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pomodoro_records_user_id ON pomodoro_records (user_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_achievements_user_id ON achievements (user_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journals_user_id ON journals (user_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_todos_user_id ON todos (user_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_plans_user_id ON plans (user_id)');
      _log('Added indexes for new tables');
    } catch (e) {
      _log('Error creating new tables: $e');
    }
  }

  /// 数据库升级处理 - 统一处理不同平台的数据库类型
  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    // 这里可以处理数据库升级逻辑
    // 例如添加新表、修改表结构等
    _log('Upgrading database from version $oldVersion to $newVersion');

    // 处理从版本1升级到版本2
    if (oldVersion < 2) {
      try {
        // 为habit_records表添加score字段
        await db.execute(
            'ALTER TABLE habit_records ADD COLUMN score INTEGER DEFAULT 100');
        _log('Added score column to habit_records table');

        // 为plans表添加max_score字段
        await db.execute(
            'ALTER TABLE plans ADD COLUMN max_score INTEGER DEFAULT 100');
        _log('Added max_score column to plans table');
      } catch (e) {
        _log('Error during database upgrade: $e');
        // 如果出现错误，可以选择回滚或使用其他策略
        // rethrow; // 允许部分失败，继续尝试后续升级
      }
    }

    // 处理从版本2升级到版本3 - 添加新表
    if (oldVersion < 3) {
      await _createNewTables(db);
    }

    // 处理从版本3升级到版本4 - 修复缺失字段
    if (oldVersion < 4) {
      try {
        // 检查achievements表是否存在target_value字段
        // 注意：SQLite没有直接的IF NOT EXISTS for columns，所以我们尝试添加，如果失败则忽略
        try {
          await db.execute(
              'ALTER TABLE achievements ADD COLUMN target_value INTEGER DEFAULT 0');
          _log('Added target_value column to achievements table');
        } catch (e) {
          _log('target_value column might already exist or table missing: $e');
        }

        // 检查pomodoro_records表是否存在todo_id字段
        try {
          await db.execute(
              'ALTER TABLE pomodoro_records ADD COLUMN todo_id INTEGER');
          _log('Added todo_id column to pomodoro_records table');
        } catch (e) {
          _log('todo_id column might already exist or table missing: $e');
        }
      } catch (e) {
        _log('Error during database upgrade to v4: $e');
      }
    }

    // 商品相关表的升级逻辑已移至product_database_service.dart
    // 从版本14到16的商品表升级逻辑不再需要，因为商品数据现在存储在独立的商品数据库中

    // 处理从版本16升级到版本17 - 为users表添加新字段的逻辑已移至user_database_service.dart
    // 此处不再处理users表的升级

    // 处理从版本4升级到版本5 - 添加标签相关表
    if (oldVersion < 5) {
      try {
        // 创建标签表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            user_id TEXT,
            -- FOREIGN KEY constraint removed, users table now in separate database
          );
        ''');
        _log('Created tags table during upgrade');

        // 创建习惯-标签关联表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS habit_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            habit_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,
            UNIQUE(habit_id, tag_id)
          );
        ''');
        _log('Created habit_tags table during upgrade');

        // 添加索引
        await db
            .execute('CREATE INDEX IF NOT EXISTS idx_tags_name ON tags (name)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_habit_tags_habit_id ON habit_tags (habit_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_habit_tags_tag_id ON habit_tags (tag_id)');
        _log('Added indexes for tags tables during upgrade');
      } catch (e) {
        _log('Error during database upgrade to v5: $e');
      }
    }

    // 处理从版本5升级到版本6 - 为journals表添加category_id和title列
    if (oldVersion < 6) {
      try {
        // 为journals表添加category_id列
        try {
          await db
              .execute('ALTER TABLE journals ADD COLUMN category_id INTEGER');
          _log('Added category_id column to journals table');
        } catch (e) {
          _log('category_id column might already exist or table missing: $e');
        }

        // 为journals表添加title列
        try {
          await db.execute('ALTER TABLE journals ADD COLUMN title TEXT');
          _log('Added title column to journals table');
        } catch (e) {
          _log('title column might already exist or table missing: $e');
        }
      } catch (e) {
        _log('Error during database upgrade to v6: $e');
      }
    }

    // 处理从版本6升级到版本7 - 为所有表添加user_id字段
    if (oldVersion < 7) {
      try {
        // 为plans表添加user_id列
        try {
          await db.execute('ALTER TABLE plans ADD COLUMN user_id TEXT');
          _log('Added user_id column to plans table');
        } catch (e) {
          _log(
              'user_id column might already exist or table missing for plans: $e');
        }

        // 为pomodoro_records表添加user_id列
        try {
          await db
              .execute('ALTER TABLE pomodoro_records ADD COLUMN user_id TEXT');
          _log('Added user_id column to pomodoro_records table');
        } catch (e) {
          _log(
              'user_id column might already exist or table missing for pomodoro_records: $e');
        }

        // 为achievements表添加user_id列
        try {
          await db.execute('ALTER TABLE achievements ADD COLUMN user_id TEXT');
          _log('Added user_id column to achievements table');
        } catch (e) {
          _log(
              'user_id column might already exist or table missing for achievements: $e');
        }

        // 为journals表添加user_id列
        try {
          await db.execute('ALTER TABLE journals ADD COLUMN user_id TEXT');
          _log('Added user_id column to journals table');
        } catch (e) {
          _log(
              'user_id column might already exist or table missing for journals: $e');
        }

        // 为todos表添加user_id列
        try {
          await db.execute('ALTER TABLE todos ADD COLUMN user_id TEXT');
          _log('Added user_id column to todos table');
        } catch (e) {
          _log(
              'user_id column might already exist or table missing for todos: $e');
        }

        // 为tags表添加user_id列（在版本5的升级中创建的tags表没有user_id字段）
        try {
          await db.execute('ALTER TABLE tags ADD COLUMN user_id TEXT');
          _log('Added user_id column to tags table');
        } catch (e) {
          _log(
              'user_id column might already exist or table missing for tags: $e');
        }
      } catch (e) {
        _log('Error during database upgrade to v7: $e');
      }
    }

    // 处理从版本7升级到版本8 - 为用户表添加is_admin字段的逻辑已移至user_database_service.dart
    // 此处不再处理users表的升级

    // 星星商店相关表的创建逻辑已移至product_database_service.dart
    // 从版本8到9的星星商店表创建逻辑不再需要，因为商品数据现在存储在独立的商品数据库中

    // 星星商店商品表的回收站功能升级逻辑已移至product_database_service.dart
    // 从版本9到10的星星商店表升级逻辑不再需要，因为商品数据现在存储在独立的商品数据库中

    // 订单、退积分申请和退积分设置表的创建逻辑已移至product_database_service.dart
    // 从版本10到11的商品相关表创建逻辑不再需要，因为商品数据现在存储在独立的商品数据库中
    _log('跳过版本10到11的商品相关表升级，这些表现在存储在独立的商品数据库中');

    // 处理从版本11升级到版本12 - 添加账单和账单明细表
    if (oldVersion < 12) {
      try {
        // 创建账单表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bills (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            balance INTEGER NOT NULL DEFAULT 0,
            income INTEGER NOT NULL DEFAULT 0,
            expense INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
        _log('Created bills table during upgrade');

        // 创建账单明细表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bill_items (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            bill_id TEXT NOT NULL,
            amount INTEGER NOT NULL,
            type TEXT NOT NULL,
            transaction_type TEXT NOT NULL,
            description TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            related_id TEXT,
            FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE
          );
        ''');
        _log('Created bill_items table during upgrade');

        // 添加账单相关索引
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_bills_user_id ON bills (user_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_bill_items_user_id ON bill_items (user_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_bill_items_bill_id ON bill_items (bill_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_bill_items_type ON bill_items (type)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_bill_items_transaction_type ON bill_items (transaction_type)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_bill_items_created_at ON bill_items (created_at)');
        _log('Added indexes for bill tables during upgrade');
      } catch (e) {
        _log('Error during database upgrade to v12: $e');
      }
    }

    // 处理从版本12升级到版本13 - 为star_products表添加缺失的列
    if (oldVersion < 13) {
      try {
        // 为star_products表添加缺失的列
        // 添加product_code列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN product_code TEXT');
          _log('Added product_code column to star_products table');
        } catch (e) {
          _log('product_code column might already exist: $e');
        }

        // 添加cost_price列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN cost_price INTEGER NOT NULL DEFAULT 0');
          _log('Added cost_price column to star_products table');
        } catch (e) {
          _log('cost_price column might already exist: $e');
        }

        // 添加brand列
        try {
          await db.execute('ALTER TABLE star_products ADD COLUMN brand TEXT');
          _log('Added brand column to star_products table');
        } catch (e) {
          _log('brand column might already exist: $e');
        }

        // 添加tags列
        try {
          await db.execute('ALTER TABLE star_products ADD COLUMN tags TEXT');
          _log('Added tags column to star_products table');
        } catch (e) {
          _log('tags column might already exist: $e');
        }

        // 添加status列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN status TEXT NOT NULL DEFAULT "draft"');
          _log('Added status column to star_products table');
        } catch (e) {
          _log('status column might already exist: $e');
        }

        // 添加shipping_template_id列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN shipping_template_id INTEGER');
          _log('Added shipping_template_id column to star_products table');
        } catch (e) {
          _log('shipping_template_id column might already exist: $e');
        }

        // 添加is_pre_sale列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN is_pre_sale INTEGER NOT NULL DEFAULT 0');
          _log('Added is_pre_sale column to star_products table');
        } catch (e) {
          _log('is_pre_sale column might already exist: $e');
        }

        // 添加pre_sale_end_time列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN pre_sale_end_time INTEGER');
          _log('Added pre_sale_end_time column to star_products table');
        } catch (e) {
          _log('pre_sale_end_time column might already exist: $e');
        }

        // 添加release_time列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN release_time INTEGER');
          _log('Added release_time column to star_products table');
        } catch (e) {
          _log('release_time column might already exist: $e');
        }

        // 添加scheduled_release_time列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN scheduled_release_time INTEGER');
          _log('Added scheduled_release_time column to star_products table');
        } catch (e) {
          _log('scheduled_release_time column might already exist: $e');
        }

        // 添加sales_7_days列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN sales_7_days INTEGER NOT NULL DEFAULT 0');
          _log('Added sales_7_days column to star_products table');
        } catch (e) {
          _log('sales_7_days column might already exist: $e');
        }

        // 添加total_sales列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN total_sales INTEGER NOT NULL DEFAULT 0');
          _log('Added total_sales column to star_products table');
        } catch (e) {
          _log('total_sales column might already exist: $e');
        }

        // 添加visitors列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN visitors INTEGER NOT NULL DEFAULT 0');
          _log('Added visitors column to star_products table');
        } catch (e) {
          _log('visitors column might already exist: $e');
        }

        // 添加conversion_rate列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN conversion_rate REAL NOT NULL DEFAULT 0.0');
          _log('Added conversion_rate column to star_products table');
        } catch (e) {
          _log('conversion_rate column might already exist: $e');
        }

        // 添加category_path列
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN category_path TEXT');
          _log('Added category_path column to star_products table');
        } catch (e) {
          _log('category_path column might already exist: $e');
        }

        _log(
            'Successfully upgraded star_products table to include all missing columns');
      } catch (e) {
        _log('Error during database upgrade to v13: $e');
      }
    }

    // 处理从版本13升级到版本14 - 确保category_path列存在
    if (oldVersion < 14) {
      try {
        // 确保category_path列存在
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN category_path TEXT');
          _log(
              'Added category_path column to star_products table during upgrade to v14');
        } catch (e) {
          _log('category_path column might already exist or error adding: $e');
        }

        _log('Successfully upgraded database to v14');
      } catch (e) {
        _log('Error during database upgrade to v14: $e');
      }
    }

    // 处理从版本14升级到版本15 - 添加支付方式相关字段
    if (oldVersion < 15) {
      try {
        // 添加支付方式相关字段
        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN support_points_payment INTEGER NOT NULL DEFAULT 1');
          _log('Added support_points_payment column to star_products table');
        } catch (e) {
          _log('support_points_payment column might already exist: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN support_cash_payment INTEGER NOT NULL DEFAULT 1');
          _log('Added support_cash_payment column to star_products table');
        } catch (e) {
          _log('support_cash_payment column might already exist: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN support_hybrid_payment INTEGER NOT NULL DEFAULT 1');
          _log('Added support_hybrid_payment column to star_products table');
        } catch (e) {
          _log('support_hybrid_payment column might already exist: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN hybrid_price INTEGER DEFAULT 0');
          _log('Added hybrid_price column to star_products table');
        } catch (e) {
          _log('hybrid_price column might already exist: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_products ADD COLUMN hybrid_points INTEGER DEFAULT 0');
          _log('Added hybrid_points column to star_products table');
        } catch (e) {
          _log('hybrid_points column might already exist: $e');
        }

        // 为star_product_skus表添加支付方式相关字段
        try {
          await db.execute(
              'ALTER TABLE star_product_skus ADD COLUMN support_points_payment INTEGER NOT NULL DEFAULT 1');
          _log(
              'Added support_points_payment column to star_product_skus table');
        } catch (e) {
          _log(
              'support_points_payment column might already exist in star_product_skus: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_product_skus ADD COLUMN support_cash_payment INTEGER NOT NULL DEFAULT 1');
          _log('Added support_cash_payment column to star_product_skus table');
        } catch (e) {
          _log(
              'support_cash_payment column might already exist in star_product_skus: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_product_skus ADD COLUMN support_hybrid_payment INTEGER NOT NULL DEFAULT 1');
          _log(
              'Added support_hybrid_payment column to star_product_skus table');
        } catch (e) {
          _log(
              'support_hybrid_payment column might already exist in star_product_skus: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_product_skus ADD COLUMN hybrid_price INTEGER DEFAULT 0');
          _log('Added hybrid_price column to star_product_skus table');
        } catch (e) {
          _log(
              'hybrid_price column might already exist in star_product_skus: $e');
        }

        try {
          await db.execute(
              'ALTER TABLE star_product_skus ADD COLUMN hybrid_points INTEGER DEFAULT 0');
          _log('Added hybrid_points column to star_product_skus table');
        } catch (e) {
          _log(
              'hybrid_points column might already exist in star_product_skus: $e');
        }

        _log(
            'Successfully upgraded database to v15 with payment method columns');
      } catch (e) {
        _log('Error during database upgrade to v15: $e');
      }
    }

    // 处理从版本15升级到版本16 - 添加reviews表（如果不存在）
    if (oldVersion < 16) {
      try {
        // 检查reviews表是否存在
        final tablesResult = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='reviews'");
        if (tablesResult.isEmpty) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS reviews (
              id TEXT PRIMARY KEY,
              order_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              product_name TEXT NOT NULL,
              product_image TEXT NOT NULL,
              variant TEXT,
              rating INTEGER NOT NULL,
              content TEXT NOT NULL,
              images TEXT,
              created_at INTEGER NOT NULL,
              appended_at INTEGER,
              appended_content TEXT,
              appended_images TEXT,
              seller_reply TEXT,
              seller_reply_at INTEGER,
              status TEXT NOT NULL,
              FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
            );
          ''');
          _log('Created reviews table during upgrade to v16');
        }
      } catch (e) {
        _log('Error creating reviews table during upgrade to v16: $e');
      }
    }

    // 兼容处理：对于所有版本，确保reviews表存在
    // 这是为了处理数据库版本 >= 16 但 reviews 表缺失的情况
    try {
      final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='reviews'");
      if (tablesResult.isEmpty) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reviews (
            id TEXT PRIMARY KEY,
            order_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            product_name TEXT NOT NULL,
            product_image TEXT NOT NULL,
            variant TEXT,
            rating INTEGER NOT NULL,
            content TEXT NOT NULL,
            images TEXT,
            created_at INTEGER NOT NULL,
            appended_at INTEGER,
            appended_content TEXT,
            appended_images TEXT,
            seller_reply TEXT,
            seller_reply_at INTEGER,
            status TEXT NOT NULL,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
          );
        ''');
        _log('Created reviews table (compat check)');
      }
    } catch (e) {
      _log('Error creating reviews table (compat check): $e');
    }
  }

  /// 关闭数据库连接
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// 删除数据库（用于开发和测试）
  Future<void> deleteDatabase() async {
    try {
      await closeDatabase();

      if (!kIsWeb) {
        // 非Web环境使用sqflite删除数据库
        final directory = await _getDocumentsDirectory();
        if (directory != null) {
          final path = path_package.join(directory.path, _databaseName);
          await sqflite_package.deleteDatabase(path);
        }
      } else {
        // Web环境重置数据库实例
        _database = null;
        // 重新初始化一个空的数据库
        _database = await _initDatabase();
        _log('Web环境: 数据库已重置');
      }
    } catch (e) {
      _log('删除数据库失败: $e');
    }
  }

  /// 清空所有数据（保留表结构）
  /// 用于重置应用数据，解决数据冲突问题
  Future<void> clearAllData() async {
    try {
      final db = await database;

      _log('开始清空所有数据...');

      // 定义需要清空的表（按依赖顺序，先删除子表）
      final tablesToClear = [
        'habit_records', // 打卡记录
        'habit_tags', // 习惯-标签关联
        'plan_habits', // 计划-习惯关联
        'pomodoro_records', // 番茄钟记录
        'habits', // 习惯
        'tags', // 标签
        'plans', // 计划
        'achievements', // 成就
        'users', // 用户（如果需要保留用户数据，可以注释掉这一行）
      ];

      // 逐个清空表
      for (final table in tablesToClear) {
        try {
          await db.delete(table);
          _log('已清空表: $table');
        } catch (e) {
          _log('清空表 $table 失败: $e');
          // 继续清空其他表
        }
      }

      // Web环境需要重置自增ID
      if (kIsWeb && _mockDatabase != null) {
        for (final table in tablesToClear) {
          _mockDatabase!._autoIncrementIds[table] = 1;
        }
      }

      _log('所有数据已清空');
    } catch (e) {
      _log('清空数据失败: $e');
      rethrow;
    }
  }

  /// 清空特定表的数据
  Future<void> clearTable(String tableName) async {
    try {
      final db = await database;
      await db.delete(tableName);

      // Web环境重置自增ID
      if (kIsWeb && _mockDatabase != null) {
        _mockDatabase!._autoIncrementIds[tableName] = 1;
      }

      _log('已清空表: $tableName');
    } catch (e) {
      _log('清空表 $tableName 失败: $e');
      rethrow;
    }
  }

  /// 获取数据库统计信息
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final db = await database;
      final stats = <String, int>{};

      final tables = [
        'habits',
        'habit_records',
        'tags',
        'habit_tags',
        'plans',
        'plan_habits',
        'pomodoro_records',
        'achievements',
        // 'users' 表已移至moment_keep_users.db数据库
      ];

      for (final table in tables) {
        try {
          final result =
              await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          final count = _firstIntValue(result);
          stats[table] = count;
        } catch (e) {
          _log('获取表 $table 统计失败: $e');
          stats[table] = 0;
        }
      }

      return stats;
    } catch (e) {
      _log('获取数据库统计失败: $e');
      return {};
    }
  }

  /// 获取当前用户ID
  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  /// 订单相关操作

  /// 插入订单
  Future<int> insertOrder(Map<String, dynamic> order) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.insertOrder(order);
  }

  /// 获取用户所有订单
  Future<List<Map<String, dynamic>>> getOrdersByUserId(String userId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.getOrdersByUserId(userId);
  }

  /// 获取所有订单（管理员使用）
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.getAllOrders();
  }

  /// 根据订单ID获取退款请求
  Future<List<Map<String, dynamic>>> getRefundRequestsByOrderId(
      String orderId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.getRefundRequestsByOrderId(orderId);
  }

  /// 根据条件查询订单（用于筛选和搜索）
  Future<List<Map<String, dynamic>>> getOrdersByCondition({
    required String userId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? orderType,
    double? minAmount,
    double? maxAmount,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供根据条件查询订单的方法，
    // 所以先获取所有订单，然后在内存中过滤
    final allOrders = await productDb.getAllOrders();

    // 应用过滤条件
    final filteredOrders = allOrders.where((order) {
      // 用户ID匹配
      if (order['user_id'] != userId) return false;

      // 状态匹配
      if (status != null && status.isNotEmpty && order['status'] != status)
        return false;

      // 日期范围匹配
      final orderCreatedAt =
          DateTime.fromMillisecondsSinceEpoch(order['created_at'] as int);
      if (startDate != null && orderCreatedAt.isBefore(startDate)) return false;
      if (endDate != null && orderCreatedAt.isAfter(endDate)) return false;

      // 其他条件可以根据需要添加
      return true;
    }).toList();

    // 排序
    filteredOrders.sort(
        (a, b) => (b['created_at'] as int).compareTo(a['created_at'] as int));

    // 分页
    final startIndex = offset;
    final endIndex = offset + limit > filteredOrders.length
        ? filteredOrders.length
        : offset + limit;
    return filteredOrders.sublist(startIndex, endIndex);
  }

  /// 获取订单详情
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    final allOrders = await productDb.getAllOrders();
    for (final order in allOrders) {
      if (order['id'] == orderId) {
        return order;
      }
    }
    return null;
  }

  /// 更新订单状态
  Future<int> updateOrderStatus(String orderId, String status) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 直接更新订单状态，不获取所有订单
    return await productDb.updateOrder(orderId, {'status': status});
  }

  /// 更新订单信息
  Future<int> updateOrder(
      String orderId, Map<String, dynamic> orderData) async {
    // 委托给ProductDatabaseService处理
    debugPrint('DatabaseService: 开始更新订单 $orderId');
    debugPrint('DatabaseService: 更新数据: $orderData');
    final productDb = ProductDatabaseService();
    final result = await productDb.updateOrder(orderId, orderData);
    debugPrint('DatabaseService: 更新订单 $orderId 结果: $result');
    return result;
  }

  /// 删除单个订单
  Future<int> deleteOrder(String orderId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.deleteOrder(orderId);
  }

  /// 根据订单ID获取商家订单
  Future<MerchantOrder?> getMerchantOrderById(String orderId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    final orderMap = await productDb.getOrderById(orderId);
    if (orderMap != null) {
      // 将Map转换为MerchantOrder对象
      return MerchantOrder.fromMap(orderMap);
    }
    return null;
  }

  /// 添加操作记录
  Future<int> addOperationLog(String orderId, String operator, String action,
      String? description) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.addOperationLog(
        orderId, operator, action, description);
  }

  /// 根据订单ID获取操作记录
  Future<List<Map<String, dynamic>>> getOperationLogsByOrderId(
      String orderId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.getOperationLogsByOrderId(orderId);
  }

  /// 批量删除订单
  Future<int> deleteOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return 0;

    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    int deletedCount = 0;

    for (final orderId in orderIds) {
      final result = await productDb.deleteOrder(orderId);
      if (result > 0) deletedCount++;
    }

    return deletedCount;
  }

  /// 购物车相关操作
  /// 添加商品到购物车
  Future<int> addToCart(StarProduct product, int quantity) async {
    final cartDb = CartDatabaseService();
    final userId = await getCurrentUserId() ?? 'default_user';
    return await cartDb.addToCart(product, quantity, userId);
  }

  /// 获取用户购物车商品
  Future<List<CartItem>> getCartItems(String userId) async {
    final cartDb = CartDatabaseService();
    final items = await cartDb.getCartItems(userId);
    // 转换数据格式
    return items
        .map((item) => CartItem(
              id: item['id'] as int,
              productId: item['product_id'] as int,
              product: item['product'] as StarProduct,
              quantity: item['quantity'] as int,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .toList();
  }

  /// 更新购物车商品数量
  Future<int> updateCartItemQuantity(int itemId, int quantity) async {
    final cartDb = CartDatabaseService();
    return await cartDb.updateCartItemQuantity(itemId, quantity);
  }

  /// 删除购物车商品
  Future<int> removeFromCart(int itemId) async {
    final cartDb = CartDatabaseService();
    return await cartDb.removeFromCart(itemId);
  }

  /// 清空购物车
  Future<int> clearCart() async {
    final cartDb = CartDatabaseService();
    final userId = await getCurrentUserId() ?? 'default_user';
    return await cartDb.clearCart(userId);
  }

  /// 获取购物车商品总数
  Future<int> getCartItemCount() async {
    final cartDb = CartDatabaseService();
    final userId = await getCurrentUserId() ?? 'default_user';
    return await cartDb.getCartItemCount(userId);
  }

  /// 退积分申请相关操作

  /// 插入退积分申请
  Future<int> insertRefundRequest(Map<String, dynamic> request) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供插入退积分申请的方法，
    // 可以考虑在ProductDatabaseService中添加该方法
    return 0;
  }

  /// 获取用户的退积分申请
  Future<List<Map<String, dynamic>>> getRefundRequestsByUserId(
      String userId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供获取退积分申请的方法，
    // 可以考虑在ProductDatabaseService中添加该方法
    return [];
  }

  /// 获取所有退积分申请（管理员使用）
  Future<List<Map<String, dynamic>>> getAllRefundRequests() async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供获取所有退积分申请的方法，
    // 可以考虑在ProductDatabaseService中添加该方法
    return [];
  }

  /// 获取退积分申请详情
  Future<Map<String, dynamic>?> getRefundRequestById(int requestId) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供获取退积分申请详情的方法，
    // 可以考虑在ProductDatabaseService中添加该方法
    return null;
  }

  /// 更新退积分申请状态
  Future<int> updateRefundRequestStatus(
      int requestId, String status, String? approvedBy) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供更新退积分申请状态的方法，
    // 可以考虑在ProductDatabaseService中添加该方法
    return 0;
  }

  /// 退积分设置相关操作

  /// 获取退积分设置
  Future<Map<String, dynamic>?> getRefundSettings() async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供获取退积分设置的方法，
    // 可以考虑在ProductDatabaseService中添加该方法
    return null;
  }

  /// 更新退积分设置
  Future<int> updateRefundSettings(Map<String, dynamic> settings) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供更新退积分设置的方法，
    // 可以考虑在ProductDatabaseService中添加该方法
    return 0;
  }

  /// 辅助方法：从查询结果中提取第一个整数值
  int _firstIntValue(List<Map<String, dynamic>> result) {
    if (result.isEmpty) return 0;
    final value = result.first.values.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// 检查当前用户是否为管理员
  Future<bool> _isCurrentUserAdmin() async {
    final currentUser = await getCurrentUserId();
    if (currentUser == null) {
      return false;
    }

    // 使用UserDatabaseService检查用户是否为管理员
    final user = await UserDatabaseService().getUserById(currentUser);
    // 管理员用户类型为2
    return user != null && user['user_type'] == 2;
  }

  /// 检查表是否存在
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
    return result.isNotEmpty;
  }

  /// 获取数据库路径
  Future<String> getDatabasePath() async {
    if (kIsWeb) {
      return 'mock_database'; // Web环境返回模拟路径
    }

    final directory = await _getDocumentsDirectory();
    if (directory == null) {
      throw Exception('Unable to access documents directory');
    }

    return path_package.join(directory.path, _databaseName);
  }

  /// 插入日记（自动加密内容）
  Future<int> insertJournal(Map<String, dynamic> journal) async {
    final db = await database;
    final userId = await getCurrentUserId();

    if (userId == null) {
      throw Exception('User not logged in');
    }

    // 加密日记内容
    final content = journal['content'] as String;
    final encryptedContent = await EncryptionHelper.encrypt(content);

    // 将tags转换为JSON字符串
    final tagsJson = jsonEncode(journal['tags'] ?? []);

    // 创建符合数据库字段名的日记对象
    final dbJournal = {
      'category_id': int.tryParse(journal['categoryId'] ?? '0') ?? 0,
      'title': journal['title'] ?? '',
      'content': encryptedContent,
      'tags': tagsJson,
      'date': journal['date'] ?? DateTime.now().toIso8601String(),
      'user_id': userId,
      'created_at': journal['createdAt'] ?? DateTime.now().toIso8601String(),
      'updated_at': journal['updatedAt'] ?? DateTime.now().toIso8601String(),
      // 默认值
      'type': 'normal',
      'attachments': jsonEncode([]),
      'mistake_meta': null,
    };

    // 插入数据库
    final insertedId = await db.insert('journals', dbJournal);
    debugPrint('日记插入成功，ID: $insertedId');
    return insertedId;
  }

  /// 查询所有日记（自动解密内容）
  Future<List<Map<String, dynamic>>> getJournals({String? targetUserId}) async {
    final db = await database;
    final userId = await getCurrentUserId();

    if (userId == null) {
      return [];
    }

    final isAdmin = await _isCurrentUserAdmin();
    String? whereClause;
    List<Object?> whereArgs = [];

    // 如果是管理员，可以指定targetUserId获取特定用户的日记，或者获取所有用户的日记
    if (isAdmin) {
      if (targetUserId != null) {
        whereClause = 'user_id = ?';
        whereArgs = [targetUserId];
      }
      // 否则获取所有日记，不添加where条件
    } else {
      // 非管理员只能获取自己的日记
      whereClause = 'user_id = ?';
      whereArgs = [userId];
    }

    // 从数据库获取日记
    final journalList = await db.query('journals',
        where: whereClause, whereArgs: whereArgs, orderBy: 'date DESC');

    // 创建可变副本，避免修改只读Map
    final journals = <Map<String, dynamic>>[];

    // 解密每个日记的内容并转换字段名
    for (final journal in journalList) {
      try {
        // 解密内容
        final encryptedContent = journal['content'] as String;
        final decryptedContent =
            await EncryptionHelper.decrypt(encryptedContent);

        // 转换字段名：从下划线命名法转换为驼峰命名法
        final decryptedJournal = {
          'id': journal['id']?.toString() ?? '',
          'categoryId': journal['category_id']?.toString() ?? '',
          'title': journal['title'] ?? '',
          'content': decryptedContent,
          'tags': jsonDecode(journal['tags'] ?? '[]'),
          'date': journal['date'] ?? '',
          'createdAt': journal['created_at'] ?? '',
          'updatedAt': journal['updated_at'] ?? '',
          'subject': journal['subject'],
          'remarks': journal['remarks'],
        };

        journals.add(decryptedJournal);
      } catch (e) {
        debugPrint('处理日记失败: $e');
        // 如果处理失败，跳过该日记
        continue;
      }
    }

    return journals;
  }

  /// 根据ID查询日记（自动解密内容）
  Future<Map<String, dynamic>?> getJournalById(int id) async {
    final db = await database;
    final userId = await getCurrentUserId();

    if (userId == null) {
      return null;
    }

    final isAdmin = await _isCurrentUserAdmin();
    String whereClause;
    List<Object?> whereArgs;

    if (isAdmin) {
      // 管理员可以获取任意日记
      whereClause = 'id = ?';
      whereArgs = [id];
    } else {
      // 非管理员只能获取自己的日记
      whereClause = 'id = ? AND user_id = ?';
      whereArgs = [id, userId];
    }

    // 从数据库获取日记
    final journals = await db.query(
      'journals',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (journals.isEmpty) {
      return null;
    }

    try {
      // 解密日记内容
      final encryptedContent = journals.first['content'] as String;
      final decryptedContent = await EncryptionHelper.decrypt(encryptedContent);

      // 转换字段名：从下划线命名法转换为驼峰命名法
      final decryptedJournal = {
        'id': journals.first['id']?.toString() ?? '',
        'categoryId': journals.first['category_id']?.toString() ?? '',
        'title': journals.first['title'] ?? '',
        'content': decryptedContent,
        'tags': jsonDecode(journals.first['tags'] ?? '[]'),
        'date': journals.first['date'] ?? '',
        'createdAt': journals.first['created_at'] ?? '',
        'updatedAt': journals.first['updated_at'] ?? '',
        'subject': journals.first['subject'],
        'remarks': journals.first['remarks'],
      };

      return decryptedJournal;
    } catch (e) {
      debugPrint('处理日记失败: $e');
      return null;
    }
  }

  /// 更新日记（自动加密内容）
  Future<int> updateJournal(int id, Map<String, dynamic> journal) async {
    final db = await database;
    final userId = await getCurrentUserId();

    if (userId == null) {
      return 0;
    }

    final isAdmin = await _isCurrentUserAdmin();
    String whereClause;
    List<Object?> whereArgs;

    if (isAdmin) {
      // 管理员可以更新任意日记
      whereClause = 'id = ?';
      whereArgs = [id];
    } else {
      // 非管理员只能更新自己的日记
      whereClause = 'id = ? AND user_id = ?';
      whereArgs = [id, userId];
    }

    // 创建符合数据库字段名的更新对象
    final updateData = <String, dynamic>{};

    // 处理每个字段的映射
    if (journal.containsKey('categoryId')) {
      updateData['category_id'] =
          int.tryParse(journal['categoryId'] ?? '0') ?? 0;
    }

    if (journal.containsKey('title')) {
      updateData['title'] = journal['title'];
    }

    if (journal.containsKey('content')) {
      // 加密日记内容
      final content = journal['content'] as String;
      final encryptedContent = await EncryptionHelper.encrypt(content);
      updateData['content'] = encryptedContent;
    }

    if (journal.containsKey('tags')) {
      // 将tags转换为JSON字符串
      updateData['tags'] = jsonEncode(journal['tags'] ?? []);
    }

    if (journal.containsKey('date')) {
      updateData['date'] = journal['date'];
    }

    if (journal.containsKey('createdAt')) {
      updateData['created_at'] = journal['createdAt'];
    }

    if (journal.containsKey('updatedAt')) {
      updateData['updated_at'] = journal['updatedAt'];
    }

    // 更新数据库
    final updatedCount = await db.update(
      'journals',
      updateData,
      where: whereClause,
      whereArgs: whereArgs,
    );

    debugPrint('日记更新成功，影响行数: $updatedCount');
    return updatedCount;
  }

  /// 删除日记（临时删除，用于添加到回收站）
  Future<int> deleteJournal(dynamic id) async {
    final db = await database;
    final userId = await getCurrentUserId();

    if (userId == null) {
      return 0;
    }

    // 将id转换为int类型
    final int journalId = id is String ? int.tryParse(id) ?? 0 : id as int;
    if (journalId == 0) {
      return 0;
    }

    final isAdmin = await _isCurrentUserAdmin();
    String whereClause;
    List<Object?> whereArgs;

    if (isAdmin) {
      // 管理员可以删除任意日记
      whereClause = 'id = ?';
      whereArgs = [journalId];
    } else {
      // 非管理员只能删除自己的日记
      whereClause = 'id = ? AND user_id = ?';
      whereArgs = [journalId, userId];
    }

    // 从数据库删除日记（仅删除记录，不删除媒体文件）
    return await db.delete(
      'journals',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// 永久删除日记（从回收站删除时调用，会删除相关媒体文件）
  Future<void> permanentDeleteJournal(Journal journal) async {
    await _permanentDeleteContentBlocks(journal.content);
  }

  /// 永久删除习惯（从回收站删除时调用，会删除相关媒体文件）
  Future<void> permanentDeleteHabit(Habit habit) async {
    await _permanentDeleteContentBlocks(habit.content);
  }

  /// 永久删除待办事项（从回收站删除时调用，会删除相关媒体文件）
  Future<void> permanentDeleteTodo(Todo todo) async {
    await _permanentDeleteContentBlocks(todo.content);
  }

  /// 永久删除内容块中的媒体文件
  Future<void> _permanentDeleteContentBlocks(
      List<ContentBlock> contentBlocks) async {
    // 提取所有内容块中的文件路径
    final filePaths = <String>{};

    // 遍历所有内容块
    for (final block in contentBlocks) {
      if (block.type == ContentBlockType.text &&
          block.attributes['type'] == 'quill') {
        try {
          final decoded = jsonDecode(block.data) as List;
          final doc = flutter_quill.Document.fromJson(decoded);
          final delta = doc.toDelta();

          // 提取嵌入的文件路径
          for (final op in delta.toList()) {
            if (op.data is Map) {
              final data = op.data as Map;

              // 提取图片路径
              if (data.containsKey('image')) {
                filePaths.add(data['image'] as String);
              }

              // 提取自定义嵌入的文件路径
              if (data.containsKey('custom')) {
                final customData = data['custom'];
                Map<String, dynamic> embedData;

                if (customData is String) {
                  embedData = jsonDecode(customData);
                } else if (customData is Map) {
                  embedData = Map<String, dynamic>.from(customData);
                } else {
                  continue;
                }

                // 处理不同类型的嵌入
                if (embedData.containsKey('video')) {
                  final videoInfo = embedData['video'];
                  String? videoPath;

                  if (videoInfo is String) {
                    // 如果是字符串，尝试解析为JSON
                    try {
                      final videoJson =
                          jsonDecode(videoInfo) as Map<String, dynamic>;
                      videoPath = videoJson['path'] as String?;
                    } catch (e) {
                      // 如果解析失败，直接使用字符串作为路径
                      videoPath = videoInfo;
                    }
                  } else if (videoInfo is Map &&
                      videoInfo.containsKey('path')) {
                    videoPath = videoInfo['path'] as String?;
                  }

                  if (videoPath != null) {
                    filePaths.add(videoPath);
                  }
                } else if (embedData.containsKey('audio')) {
                  final audioInfo = embedData['audio'];
                  String? audioPath;

                  if (audioInfo is String) {
                    // 如果是字符串，尝试解析为JSON
                    try {
                      final audioJson =
                          jsonDecode(audioInfo) as Map<String, dynamic>;
                      audioPath = audioJson['path'] as String?;
                    } catch (e) {
                      // 如果解析失败，直接使用字符串作为路径
                      audioPath = audioInfo;
                    }
                  } else if (audioInfo is Map &&
                      audioInfo.containsKey('path')) {
                    audioPath = audioInfo['path'] as String?;
                  }

                  if (audioPath != null) {
                    filePaths.add(audioPath);
                  }
                } else if (embedData.containsKey('file')) {
                  final fileInfo = embedData['file'];
                  String? filePath;

                  if (fileInfo is String) {
                    // 如果是字符串，尝试解析为JSON
                    try {
                      final fileJson =
                          jsonDecode(fileInfo) as Map<String, dynamic>;
                      filePath = fileJson['path'] as String?;
                    } catch (e) {
                      // 如果解析失败，直接使用字符串作为路径
                      filePath = fileInfo;
                    }
                  } else if (fileInfo is Map && fileInfo.containsKey('path')) {
                    filePath = fileInfo['path'] as String?;
                  }

                  if (filePath != null) {
                    filePaths.add(filePath);
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing content block: $e');
        }
      }
    }

    // 使用StorageService删除所有相关文件
    final storageService = StorageService();
    for (final filePath in filePaths) {
      try {
        await storageService.deleteFile(filePath);
      } catch (e) {
        // 忽略文件删除错误
      }
    }
  }

  /// 获取所有用户（管理员权限）
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    // 获取当前用户
    final currentUser = await getCurrentUserId();
    if (currentUser == null) {
      return [];
    }

    // 检查当前用户是否为管理员
    final isAdmin = await _isCurrentUserAdmin();
    if (!isAdmin) {
      return [];
    }

    // 使用UserDatabaseService获取所有用户
    return await UserDatabaseService().getAllUsers();
  }

  /// 删除用户（管理员权限）
  Future<int> deleteUser(String userId) async {
    // 获取当前用户
    final currentUser = await getCurrentUserId();
    if (currentUser == null) {
      return 0;
    }

    // 检查当前用户是否为管理员
    final isAdmin = await _isCurrentUserAdmin();
    if (!isAdmin) {
      return 0;
    }

    // 不允许删除自己
    if (userId == currentUser) {
      return 0;
    }

    // 使用UserDatabaseService删除用户
    return await UserDatabaseService().deleteUser(userId);
  }

  /// 更新用户信息（管理员权限）
  Future<int> updateUser(String userId, Map<String, dynamic> userData) async {
    // 获取当前用户
    final currentUser = await getCurrentUserId();
    if (currentUser == null) {
      return 0;
    }

    // 检查当前用户是否为管理员
    final isAdmin = await _isCurrentUserAdmin();
    if (!isAdmin) {
      return 0;
    }

    // 使用UserDatabaseService更新用户信息
    return await UserDatabaseService().updateUser(userId, userData, null);
  }

  /// 设置用户管理员权限（管理员权限）
  Future<int> setUserAdminStatus(String userId, bool isAdmin) async {
    // 获取当前用户
    final currentUser = await getCurrentUserId();
    if (currentUser == null) {
      return 0;
    }

    // 检查当前用户是否为管理员
    final currentIsAdmin = await _isCurrentUserAdmin();
    if (!currentIsAdmin) {
      return 0;
    }

    // 使用UserDatabaseService更新用户类型
    // 管理员用户类型为2，普通用户类型为0
    final userData = {'user_type': isAdmin ? 2 : 0};
    return await UserDatabaseService().updateUser(userId, userData, null);
  }

  /// 获取用户积分
  Future<double> getUserPoints(String userId) async {
    try {
      final userData = await UserDatabaseService().getUserById(userId);
      if (userData != null) {
        if (userData['points'] is int) {
          return (userData['points'] as int).toDouble();
        } else if (userData['points'] is double) {
          return userData['points'] as double;
        }
        return 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('获取用户积分失败: $e');
      return 0.0;
    }
  }

  /// 添加评价
  Future<void> addReview(Map<String, dynamic> reviewData) async {
    try {
      final db = await database;
      final String reviewId =
          reviewData['id'] ?? 'review_${DateTime.now().millisecondsSinceEpoch}';

      await db.insert(
        'reviews',
        {
          'id': reviewId,
          'order_id': reviewData['orderId'],
          'product_id': reviewData['productId'],
          'product_name': reviewData['productName'],
          'product_image': reviewData['productImage'],
          'variant': reviewData['variant'] ?? '',
          'rating': reviewData['rating'],
          'content': reviewData['content'],
          'images': reviewData['images'] != null
              ? json.encode(reviewData['images'])
              : null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'status': reviewData['status'] ?? 'completed',
        },
        conflictAlgorithm: sqflite_package.ConflictAlgorithm.replace,
      );
      _log('Added review: $reviewId');
    } catch (e) {
      debugPrint('添加评价失败: $e');
    }
  }

  /// 获取订单的评价
  Future<List<Map<String, dynamic>>> getReviewsByOrderId(String orderId) async {
    try {
      // 模拟数据库查询，返回模拟数据
      // 这里我们直接返回空列表，实际应用中应该从数据库查询
      return [];
    } catch (e) {
      debugPrint('获取订单评价失败: $e');
      return [];
    }
  }

  /// 获取商品的评价
  Future<List<Map<String, dynamic>>> getReviewsByProductId(
      String productId) async {
    try {
      // 模拟数据库查询，返回模拟数据
      // 这里我们直接返回空列表，实际应用中应该从数据库查询
      return [];
    } catch (e) {
      debugPrint('获取商品评价失败: $e');
      return [];
    }
  }

  /// 更新评价
  Future<void> updateReview(
      String reviewId, Map<String, dynamic> updates) async {
    try {
      final db = await _database;

      // 处理JSON字段
      if (updates.containsKey('images')) {
        updates['images'] = json.encode(updates['images']);
      }
      if (updates.containsKey('appended_images')) {
        updates['appended_images'] = json.encode(updates['appended_images']);
      }

      await db.update(
        'reviews',
        updates,
        where: 'id = ?',
        whereArgs: [reviewId],
      );
      _log('Updated review: $reviewId');
    } catch (e) {
      debugPrint('更新评价失败: $e');
    }
  }

  /// 更新用户积分并创建账单记录
  Future<void> updateUserPoints(String userId, double points,
      {String? description, String? transactionType, String? relatedId}) async {
    try {
      final userData = await UserDatabaseService().getUserById(userId);
      if (userData != null) {
        dynamic currentPointsValue = userData['points'] ?? 0;
        double currentPoints;
        if (currentPointsValue is int) {
          currentPoints = currentPointsValue.toDouble();
        } else if (currentPointsValue is double) {
          currentPoints = currentPointsValue;
        } else {
          currentPoints = 0.0;
        }
        final newPoints = currentPoints + points;

        // 更新用户积分
        await UserDatabaseService().updateUser(
          userId,
          {},
          {'points': newPoints},
        );

        // 创建账单记录
        if (points != 0) {
          // 获取当前账单（如果没有会自动创建）
          var currentBill = await getCurrentBill(userId);
          // 更新账单余额
          final newBalance = newPoints.round();
          final newIncome =
              points > 0 ? currentBill.income + points.round() : currentBill.income;
          final newExpense = points < 0
              ? currentBill.expense + (-points).round()
              : currentBill.expense;
          await updateBillBalance(
            currentBill.id,
            newBalance,
            newIncome,
            newExpense,
          );

          // 添加账单明细
          final isIncome = points > 0;
          final defaultTransactionType = isIncome ? 'reward' : 'expense';
          final defaultDescription = isIncome ? '获得积分' : '消费积分';

          await addBillItem(
            userId,
            currentBill.id,
            points.abs().round(), // 账单记录使用整数
            isIncome ? 'income' : 'expense',
            transactionType ?? defaultTransactionType,
            description ?? defaultDescription,
            relatedId: relatedId,
          );
        }
      }
    } catch (e) {
      debugPrint('更新用户积分失败: $e');
      rethrow;
    }
  }

  /// 根据邮箱为用户充值积分
  Future<void> rechargePointsByEmail(String email, double points) async {
    try {
      final userDatabaseService = UserDatabaseService();
      final user = await userDatabaseService.getUserByEmail(email);
      if (user != null) {
        final userId = user['user_id'];
        await updateUserPoints(userId, points);
      }
    } catch (e) {
      debugPrint('根据邮箱充值积分失败: $e');
      rethrow;
    }
  }

  // -------------------- 优惠券、红包和购物卡相关方法 --------------------
  
  /// 获取用户的优惠券列表
  Future<List<Map<String, dynamic>>> getUserCoupons(String userId) async {
    final db = await database;
    return await db.query(
      'coupons',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }
  
  /// 获取用户的红包列表
  Future<List<Map<String, dynamic>>> getUserRedPackets(String userId) async {
    final db = await database;
    return await db.query(
      'red_packets',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }
  
  /// 获取用户的购物卡列表
  Future<List<Map<String, dynamic>>> getUserShoppingCards(String userId) async {
    final db = await database;
    return await db.query(
      'shopping_cards',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }
  
  /// 获取用户的可用优惠券数量
  Future<int> getUserCouponCount(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM coupons WHERE user_id = ? AND status = ? AND (validity = '永久' OR validity >= ?)",
      [userId, '可用', now],
    );
    return result.isNotEmpty ? int.tryParse(result[0]['count'].toString()) ?? 0 : 0;
  }
  
  /// 获取用户的可用红包数量
  Future<int> getUserRedPacketCount(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM red_packets WHERE user_id = ? AND status = ? AND (validity = '永久' OR validity >= ?)",
      [userId, '可用', now],
    );
    return result.isNotEmpty ? int.tryParse(result[0]['count'].toString()) ?? 0 : 0;
  }
  
  /// 获取用户的可用购物卡数量
  Future<int> getUserShoppingCardCount(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM shopping_cards WHERE user_id = ? AND status = ? AND (validity = '永久' OR validity >= ?)",
      [userId, '可用', now],
    );
    return result.isNotEmpty ? int.tryParse(result[0]['count'].toString()) ?? 0 : 0;
  }
  
  // -------------------- 星星商店相关方法 --------------------

  // MARK: - StarCategory CRUD Operations

  /// 获取所有星星商店分类
  Future<List<StarCategory>> getAllStarCategories() async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    final results = await productDb.getAllCategories();
    return results
        .map<StarCategory>((map) => StarCategory.fromMap(map))
        .toList();
  }

  /// 插入星星商店分类
  Future<int> insertStarCategory(StarCategory category) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.insertCategory(category.toMap());
  }

  /// 更新星星商店分类
  Future<int> updateStarCategory(StarCategory category) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.updateCategory(category.id!, category.toMap());
  }

  /// 删除星星商店分类
  Future<int> deleteStarCategory(int id) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.deleteCategory(id);
  }

  // MARK: - StarProduct CRUD Operations

  /// 获取所有未删除的星星商店商品
  /// 获取所有未删除的星星商店商品，包括SKU和规格
  Future<List<StarProduct>> getAllStarProducts() async {
    try {
      // 委托给ProductDatabaseService处理
      final productDb = ProductDatabaseService();
      final productsResults = await productDb.getAllProducts();

      final List<StarProduct> products = [];
      for (final productMap in productsResults) {
        // 直接使用从数据库映射创建的product对象，它包含所有字段
        final product = StarProduct.fromMap(productMap);
        products.add(product);
      }

      debugPrint('加载商品成功，共 ${products.length} 个商品');
      return products;
    } catch (e) {
      debugPrint('获取商品列表失败: $e');
      return [];
    }
  }

  /// 根据分类ID获取未删除的星星商店商品，包括SKU和规格
  Future<List<StarProduct>> getStarProductsByCategoryId(int categoryId) async {
    try {
      // 委托给ProductDatabaseService处理
      final productDb = ProductDatabaseService();
      // 目前ProductDatabaseService没有直接提供根据分类ID获取商品的方法，
      // 所以先获取所有商品，然后在内存中过滤
      final allProductsResults = await productDb.getAllProducts();
      final productsResults = allProductsResults
          .where((productMap) => productMap['category_id'] == categoryId)
          .toList();

      final List<StarProduct> products = [];
      for (final productMap in productsResults) {
        // 直接使用从数据库映射创建的product对象，它包含所有字段
        final product = StarProduct.fromMap(productMap);
        products.add(product);
      }

      return products;
    } catch (e) {
      debugPrint('根据分类ID获取商品失败: $e');
      return [];
    }
  }

  /// 获取所有已删除的星星商店商品（回收站商品），包括SKU和规格
  Future<List<StarProduct>> getDeletedStarProducts() async {
    try {
      // 委托给ProductDatabaseService处理
      final productDb = ProductDatabaseService();
      final allProductsResults = await productDb.getAllProducts();
      final productsResults = allProductsResults
          .where((productMap) => productMap['is_deleted'] == 1)
          .toList();

      final List<StarProduct> products = [];
      for (final productMap in productsResults) {
        // 直接使用从数据库映射创建的product对象，它包含所有字段
        final product = StarProduct.fromMap(productMap);
        products.add(product);
      }

      return products;
    } catch (e) {
      debugPrint('获取已删除商品失败: $e');
      return [];
    }
  }

  /// 插入星星商店商品，包括SKU和规格
  Future<int> insertStarProduct(StarProduct product) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.insertProduct(product.toMap());
  }

  /// 更新星星商店商品，包括SKU和规格
  Future<int> updateStarProduct(StarProduct product) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.updateProduct(product.id!, product.toMap());
  }

  /// 软删除星星商店商品（标记为已删除，移至回收站），包括SKU和规格
  Future<int> deleteStarProduct(int id) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.deleteProduct(id);
  }

  /// 恢复星星商店商品（从回收站恢复）
  Future<int> restoreStarProduct(int id) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    return await productDb.updateProduct(id, {
      'is_deleted': 0,
      'deleted_at': null,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 彻底删除星星商店商品（从数据库中删除），包括SKU和规格
  /// 注意：相关的SKU和规格会通过外键约束自动删除
  Future<int> permanentlyDeleteStarProduct(int id) async {
    // 委托给ProductDatabaseService处理
    final productDb = ProductDatabaseService();
    // 目前ProductDatabaseService没有直接提供彻底删除商品的方法，
    // 所以先获取商品信息，然后使用deleteProduct方法进行软删除
    // 如果需要彻底删除，可以在ProductDatabaseService中添加相应方法
    return await productDb.deleteProduct(id);
  }

  // 账单相关操作方法

  /// 获取当前用户的账单
  Future<Bill> getCurrentBill(String userId) async {
    final db = await database;
    final maps = await db.query('bills',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
        limit: 1);

    // 获取当前用户的积分
    final userData = await UserDatabaseService().getUserById(userId);
    final currentPoints = userData?['points'] ?? 0;

    if (maps.isNotEmpty) {
      final bill = Bill.fromMap(maps.first);

      // 检查账单余额是否与用户当前积分一致，如果不一致，就更新账单余额
      if (bill.balance != currentPoints) {
        // 计算收入和支出的差值
        final diff = currentPoints - bill.balance;
        final newIncome = diff > 0 ? bill.income + diff : bill.income;
        final newExpense = diff < 0 ? bill.expense + (-diff) : bill.expense;

        await updateBillBalance(
          bill.id,
          currentPoints,
          newIncome as int,
          newExpense as int,
        );

        // 返回更新后的账单
        return Bill(
          id: bill.id,
          userId: bill.userId,
          balance: currentPoints,
          income: newIncome as int,
          expense: newExpense as int,
          createdAt: bill.createdAt,
          updatedAt: DateTime.now(),
        );
      }

      return bill;
    }

    // 如果没有找到账单，自动创建一个初始账单
    return await createBill(userId, initialBalance: currentPoints);
  }

  /// 创建新账单
  Future<Bill> createBill(String userId, {int initialBalance = 0}) async {
    final db = await database;
    final now = DateTime.now();
    final bill = Bill(
      id: 'bill_${now.millisecondsSinceEpoch}',
      userId: userId,
      balance: initialBalance,
      income: 0,
      expense: 0,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('bills', bill.toMap());
    return bill;
  }

  /// 更新账单余额
  Future<void> updateBillBalance(
      String billId, int balance, int income, int expense) async {
    final db = await database;
    await db.update(
        'bills',
        {
          'balance': balance,
          'income': income,
          'expense': expense,
          'updated_at': DateTime.now().millisecondsSinceEpoch
        },
        where: 'id = ?',
        whereArgs: [billId]);
  }

  /// 添加账单明细
  Future<BillItem> addBillItem(String userId, String billId, int amount,
      String type, String transactionType, String description,
      {String? relatedId}) async {
    final db = await database;
    final now = DateTime.now();
    final billItem = BillItem(
      id: 'bill_item_${now.millisecondsSinceEpoch}',
      userId: userId,
      billId: billId,
      amount: amount,
      type: type,
      transactionType: transactionType,
      description: description,
      createdAt: now,
      updatedAt: now,
      relatedId: relatedId,
    );

    await db.insert('bill_items', billItem.toMap());
    return billItem;
  }

  /// 获取账单明细列表
  Future<List<BillItem>> getBillItems(String userId,
      {DateTime? startDate,
      DateTime? endDate,
      String? type,
      String? transactionType}) async {
    final db = await database;

    List<String> whereConditions = ['user_id = ?'];
    List<Object?> whereArgs = [userId];

    // 添加日期条件
    if (startDate != null) {
      whereConditions.add('created_at >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereConditions.add('created_at <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    // 添加类型条件
    if (type != null) {
      whereConditions.add('type = ?');
      whereArgs.add(type);
    }
    if (transactionType != null) {
      whereConditions.add('transaction_type = ?');
      whereArgs.add(transactionType);
    }

    final results = await db.query('bill_items',
        where: whereConditions.join(' AND '),
        whereArgs: whereArgs,
        orderBy: 'created_at DESC');

    return results.map<BillItem>((map) => BillItem.fromMap(map)).toList();
  }

  /// 获取账单统计信息
  Future<Map<String, dynamic>> getBillStatistics(String userId,
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    List<String> whereConditions = ['user_id = ?'];
    List<Object?> whereArgs = [userId];

    // 添加日期条件
    if (startDate != null) {
      whereConditions.add('created_at >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereConditions.add('created_at <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    // 获取收入总和
    final incomeResult = await db.rawQuery(
        'SELECT SUM(amount) as total_income FROM bill_items WHERE type = ? AND ' +
            whereConditions.join(' AND '),
        ['income', ...whereArgs]);

    // 获取支出总和
    final expenseResult = await db.rawQuery(
        'SELECT SUM(amount) as total_expense FROM bill_items WHERE type = ? AND ' +
            whereConditions.join(' AND '),
        ['expense', ...whereArgs]);

    // 获取当前余额
    final currentBill = await getCurrentBill(userId);

    return {
      'total_income': incomeResult.first['total_income'] ?? 0,
      'total_expense': expenseResult.first['total_expense'] ?? 0,
      'balance': currentBill.balance
    };
  }
}
