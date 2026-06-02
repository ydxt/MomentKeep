import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_package;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';
import 'package:sqflite/sqflite.dart' as sqflite_package;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    if (dart.library.html) 'package:moment_keep/services/empty_sqflite_ffi.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/storage_path_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

// 定义动态类型别名以适配不同环境
typedef DatabaseType = dynamic;

// 使用简单的日志函数
void _log(String message) {
  if (kDebugMode) {
    print('[ProductDatabaseService] $message');
  }
}

/// 商品数据库服务类
/// 负责集中管理所有商品相关数据
class ProductDatabaseService {
  // 静态单例实例
  static final ProductDatabaseService _instance =
      ProductDatabaseService._internal();

  // 数据库实例
  static DatabaseType? _database;

  // 初始化状态标志

  // 初始化完成的Completer
  Completer<void>? _initializationCompleter;

  // 私有构造函数
  ProductDatabaseService._internal();

  // 工厂构造函数返回单例
  factory ProductDatabaseService() => _instance;

  /// 数据库名称 - 专门用于商品和订单数据
  static const String _databaseName = 'moment_keep_products.db';

  /// 数据库版本
  static const int _databaseVersion = 20;

  /// 打印数据库版本信息
  void _logDatabaseInfo() {
    _log('Database Version: $_databaseVersion');
  }

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

    // 记录数据库版本
    _log('Database Version: $_databaseVersion');

    // 初始化数据库
    _database = await _initDatabase();
    // 检查并创建缺失的表
    await _ensureTablesExist(_database!);
    return _database!;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Directory?> getDefaultDirectory() async {
    return await _getDefaultDirectory();
  }

  /// 检查并创建缺失的表
  Future<void> _ensureTablesExist(DatabaseType db) async {
    _log('Checking and creating missing tables...');

    // 检查cleanup_logs表是否存在
    final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='cleanup_logs'");
    if (tablesResult.isEmpty) {
      // 创建cleanup_logs表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cleanup_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cleanup_time INTEGER NOT NULL,
          total_products INTEGER NOT NULL,
          success_count INTEGER NOT NULL,
          failed_count INTEGER NOT NULL,
          details TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      _log('Created missing cleanup_logs table');

      // 创建索引
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_cleanup_time ON cleanup_logs (cleanup_time)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_created_at ON cleanup_logs (created_at)');
      _log('Created indexes for cleanup_logs table');
    }

    final favoriteTablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='favorite_products'");
    if (favoriteTablesResult.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS favorite_products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          product_id INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          UNIQUE(user_id, product_id)
        );
      ''');
      _log('Created missing favorite_products table');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_favorite_products_user_id ON favorite_products (user_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_favorite_products_product_id ON favorite_products (product_id)');
      _log('Created indexes for favorite_products table');
    }

    final cartTablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='cart_items'");
    if (cartTablesResult.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cart_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          product_data TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          user_id TEXT NOT NULL
        );
      ''');
      _log('Created missing cart_items table');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items (user_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON cart_items (product_id)');
      _log('Created indexes for cart_items table');
    }

    await _migrateFromCartDb(db);

    // 检查orders表的columns并添加缺失的列
    try {
      // 检查orders表是否有quantity列
      final quantityColumnResult =
          await db.rawQuery("PRAGMA table_info(orders)");
      bool hasQuantityColumn = false;
      bool hasUpdatedAtColumn = false;
      // 售后相关字段检查
      bool hasAfterSalesTypeColumn = false;
      bool hasAfterSalesReasonColumn = false;
      bool hasAfterSalesDescriptionColumn = false;
      bool hasAfterSalesImagesColumn = false;
      bool hasAfterSalesCreateTimeColumn = false;
      bool hasAfterSalesStatusColumn = false;
      bool hasLogisticsInfoColumn = false;
      bool hasDeliveryAddressColumn = false;
      bool hasBuyerNoteColumn = false;
      bool hasBuyerNameColumn = false;
      bool hasBuyerPhoneColumn = false;

      for (var column in quantityColumnResult) {
        if (column['name'] == 'quantity') {
          hasQuantityColumn = true;
        }
        if (column['name'] == 'updated_at') {
          hasUpdatedAtColumn = true;
        }
        // 检查售后相关字段
        if (column['name'] == 'after_sales_type') {
          hasAfterSalesTypeColumn = true;
        }
        if (column['name'] == 'after_sales_reason') {
          hasAfterSalesReasonColumn = true;
        }
        if (column['name'] == 'after_sales_description') {
          hasAfterSalesDescriptionColumn = true;
        }
        if (column['name'] == 'after_sales_images') {
          hasAfterSalesImagesColumn = true;
        }
        if (column['name'] == 'after_sales_create_time') {
          hasAfterSalesCreateTimeColumn = true;
        }
        if (column['name'] == 'after_sales_status') {
          hasAfterSalesStatusColumn = true;
        }
        // 检查物流相关字段
        if (column['name'] == 'logistics_info') {
          hasLogisticsInfoColumn = true;
        }
        // 检查买家相关字段
        if (column['name'] == 'delivery_address') {
          hasDeliveryAddressColumn = true;
        }
        if (column['name'] == 'buyer_note') {
          hasBuyerNoteColumn = true;
        }
        if (column['name'] == 'buyer_name') {
          hasBuyerNameColumn = true;
        }
        if (column['name'] == 'buyer_phone') {
          hasBuyerPhoneColumn = true;
        }
      }

      if (!hasQuantityColumn) {
        // 添加quantity列
        await db.execute(
            'ALTER TABLE orders ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1');
        _log('Added missing quantity column to orders table');
      }

      if (!hasUpdatedAtColumn) {
        // 添加updated_at列
        await db.execute(
            'ALTER TABLE orders ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
        _log('Added missing updated_at column to orders table');
      }

      // 添加售后相关字段
      if (!hasAfterSalesTypeColumn) {
        await db.execute('ALTER TABLE orders ADD COLUMN after_sales_type TEXT');
        _log('Added missing after_sales_type column to orders table');
      }

      if (!hasAfterSalesReasonColumn) {
        await db
            .execute('ALTER TABLE orders ADD COLUMN after_sales_reason TEXT');
        _log('Added missing after_sales_reason column to orders table');
      }

      if (!hasAfterSalesDescriptionColumn) {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN after_sales_description TEXT');
        _log('Added missing after_sales_description column to orders table');
      }

      if (!hasAfterSalesImagesColumn) {
        await db
            .execute('ALTER TABLE orders ADD COLUMN after_sales_images TEXT');
        _log('Added missing after_sales_images column to orders table');
      }

      if (!hasAfterSalesCreateTimeColumn) {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN after_sales_create_time INTEGER');
        _log('Added missing after_sales_create_time column to orders table');
      }

      if (!hasAfterSalesStatusColumn) {
        await db
            .execute('ALTER TABLE orders ADD COLUMN after_sales_status TEXT');
        _log('Added missing after_sales_status column to orders table');
      }

      // 检查并添加物流相关字段
      if (!hasLogisticsInfoColumn) {
        await db.execute('ALTER TABLE orders ADD COLUMN logistics_info TEXT');
        _log('Added missing logistics_info column to orders table');
      }

      // 检查并添加买家相关字段
      if (!hasDeliveryAddressColumn) {
        await db.execute('ALTER TABLE orders ADD COLUMN delivery_address TEXT');
        _log('Added missing delivery_address column to orders table');
      }

      if (!hasBuyerNoteColumn) {
        await db.execute('ALTER TABLE orders ADD COLUMN buyer_note TEXT');
        _log('Added missing buyer_note column to orders table');
      }

      if (!hasBuyerNameColumn) {
        await db.execute('ALTER TABLE orders ADD COLUMN buyer_name TEXT');
        _log('Added missing buyer_name column to orders table');
      }

      if (!hasBuyerPhoneColumn) {
        await db.execute('ALTER TABLE orders ADD COLUMN buyer_phone TEXT');
        _log('Added missing buyer_phone column to orders table');
      }
    } catch (e) {
      _log('Error checking/adding columns to orders table: $e');
    }

    // 检查并添加star_products表的支付方式相关列
    try {
      final starProductsColumns =
          await db.rawQuery("PRAGMA table_info(star_products)");
      final columnsMap = <String, bool>{};
      for (var column in starProductsColumns) {
        columnsMap[column['name'] as String] = true;
      }

      // 检查并添加支付方式列
      final List<String> paymentColumns = [
        'support_points_payment INTEGER NOT NULL DEFAULT 1',
        'support_cash_payment INTEGER NOT NULL DEFAULT 1',
        'support_hybrid_payment INTEGER NOT NULL DEFAULT 1',
        'hybrid_price INTEGER DEFAULT 0',
        'hybrid_points INTEGER DEFAULT 0'
      ];

      for (var columnDef in paymentColumns) {
        final columnName = columnDef.split(' ')[0];
        if (!columnsMap.containsKey(columnName)) {
          await db.execute('ALTER TABLE star_products ADD COLUMN $columnDef');
          _log('Added missing $columnName column to star_products table');
        }
      }
    } catch (e) {
      _log(
          'Error checking or adding payment columns to star_products table: $e');
    }

    // 检查并添加star_product_skus表的支付方式相关列
    try {
      final starProductSkusColumns =
          await db.rawQuery("PRAGMA table_info(star_product_skus)");
      final columnsMap = <String, bool>{};
      for (var column in starProductSkusColumns) {
        columnsMap[column['name'] as String] = true;
      }

      // 检查并添加支付方式列
      final List<String> paymentColumns = [
        'support_points_payment INTEGER NOT NULL DEFAULT 1',
        'support_cash_payment INTEGER NOT NULL DEFAULT 1',
        'support_hybrid_payment INTEGER NOT NULL DEFAULT 1',
        'hybrid_price INTEGER DEFAULT 0',
        'hybrid_points INTEGER DEFAULT 0'
      ];

      for (var columnDef in paymentColumns) {
        final columnName = columnDef.split(' ')[0];
        if (!columnsMap.containsKey(columnName)) {
          await db
              .execute('ALTER TABLE star_product_skus ADD COLUMN $columnDef');
          _log('Added missing $columnName column to star_product_skus table');
        }
      }
    } catch (e) {
      _log(
          'Error checking or adding payment columns to star_product_skus table: $e');
    }

    // 检查并添加star_products表的merchant_id列
    try {
      final starProductsColumns =
          await db.rawQuery("PRAGMA table_info(star_products)");
      final columnsMap = <String, bool>{};
      for (var column in starProductsColumns) {
        columnsMap[column['name'] as String] = true;
      }

      if (!columnsMap.containsKey('merchant_id')) {
        await db.execute(
            'ALTER TABLE star_products ADD COLUMN merchant_id INTEGER REFERENCES merchants(id) ON DELETE SET NULL');
        _log('Added missing merchant_id column to star_products table');
      }
    } catch (e) {
      _log(
          'Error checking or adding merchant_id column to star_products table: $e');
    }

    // 检查并添加orders表的merchant_id列
    try {
      final ordersColumns =
          await db.rawQuery("PRAGMA table_info(orders)");
      final columnsMap = <String, bool>{};
      for (var column in ordersColumns) {
        columnsMap[column['name'] as String] = true;
      }

      if (!columnsMap.containsKey('merchant_id')) {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN merchant_id INTEGER REFERENCES merchants(id) ON DELETE SET NULL');
        _log('Added missing merchant_id column to orders table');
      }
    } catch (e) {
      _log(
          'Error checking or adding merchant_id column to orders table: $e');
    }

    try {
      final orderColumnsMap = <String, String>{};
      final orderColumns = await db.rawQuery('PRAGMA table_info(orders)');
      for (final col in orderColumns) {
        orderColumnsMap[col['name'] as String] = col['type'] as String;
      }
      if (!orderColumnsMap.containsKey('fund_status')) {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN fund_status TEXT NOT NULL DEFAULT \'escrow\'');
        _log('Added missing fund_status column to orders table');
      }
    } catch (e) {
      debugPrint(
          'Error checking or adding fund_status column to orders table: $e');
    }

    try {
      await db.rawUpdate(
          "UPDATE orders SET fund_status = 'escrow' WHERE fund_status IS NULL OR fund_status = ''");
      _log('Fixed NULL/empty fund_status for existing orders');
      await db.rawUpdate(
          "UPDATE orders SET fund_status = 'released' WHERE status IN ('已完成', '待评价', '已评价') AND fund_status = 'escrow'");
      await db.rawUpdate(
          "UPDATE orders SET fund_status = 'refunded' WHERE status IN ('已退款', '已取消') AND fund_status = 'escrow'");
      _log('Migrated existing orders fund_status values');
    } catch (e) {
      debugPrint('Error migrating orders fund_status: $e');
    }

    // 先检查 payment_records 表是否存在，不存在则创建
    final paymentRecordsTableResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='payment_records'");
    if (paymentRecordsTableResult.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payment_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id TEXT NOT NULL,
          merchant_id INTEGER,
          user_id TEXT NOT NULL,
          payment_no TEXT NOT NULL,
          amount INTEGER NOT NULL,
          points_used INTEGER NOT NULL DEFAULT 0,
          cash_amount INTEGER NOT NULL DEFAULT 0,
          payment_method TEXT NOT NULL,
          third_party_payment_id TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          paid_at INTEGER,
          refunded_at INTEGER,
          failure_reason TEXT,
          fund_status TEXT DEFAULT 'escrow',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL
        );
      ''');
      _log('Created missing payment_records table');
      try {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_payment_records_order_id ON payment_records (order_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_payment_records_user_id ON payment_records (user_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_payment_records_merchant_id ON payment_records (merchant_id)');
        _log('Created indexes for payment_records table');
      } catch (e) {
        _log('Error creating payment_records indexes: $e');
      }
    } else {
      try {
        final paymentColumnsMap = <String, String>{};
        final paymentColumns = await db.rawQuery('PRAGMA table_info(payment_records)');
        for (final col in paymentColumns) {
          paymentColumnsMap[col['name'] as String] = col['type'] as String;
        }
        if (!paymentColumnsMap.containsKey('merchant_id')) {
          await db.execute(
              'ALTER TABLE payment_records ADD COLUMN merchant_id INTEGER REFERENCES merchants(id) ON DELETE SET NULL');
          _log('Added missing merchant_id column to payment_records table');
        }
        if (!paymentColumnsMap.containsKey('fund_status')) {
          await db.execute('ALTER TABLE payment_records ADD COLUMN fund_status TEXT DEFAULT \'escrow\'');
          _log('Added missing fund_status column to payment_records table');
        }
        if (!paymentColumnsMap.containsKey('refunded_at')) {
          await db.execute('ALTER TABLE payment_records ADD COLUMN refunded_at INTEGER');
          _log('Added missing refunded_at column to payment_records table');
        }
      } catch (e) {
        _log('Error checking or adding columns to payment_records table: $e');
      }
    }

    final returnLogisticsTableResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='return_logistics'");
    if (returnLogisticsTableResult.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS return_logistics (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id TEXT NOT NULL,
          tracking_number TEXT,
          logistics_company_id INTEGER,
          status TEXT NOT NULL DEFAULT 'pending_ship',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (logistics_company_id) REFERENCES logistics_companies(id) ON DELETE SET NULL
        );
      ''');
      _log('Created missing return_logistics table');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_return_logistics_order_id ON return_logistics (order_id)');
    }

    try {
      final orderColumns = await db.rawQuery('PRAGMA table_info(orders)');
      final orderColNames = orderColumns.map((c) => c['name'] as String).toSet();
      if (!orderColNames.contains('logistics_company_id')) {
        await db.execute('ALTER TABLE orders ADD COLUMN logistics_company_id INTEGER');
        _log('Added logistics_company_id column to orders table');
      }
    } catch (e) {
      _log('Error adding logistics_company_id to orders: $e');
    }
  }

  Future<void> _migrateFromCartDb(DatabaseType db) async {
    try {
      final serverDir = await _getServerDirectory();
      if (serverDir == null) return;

      final cartDbPath = path_package.join(serverDir.path, 'cart.db');
      final cartDbFile = File(cartDbPath);
      if (!await cartDbFile.exists()) return;

      _log('Found old cart.db, starting migration...');

      final cartDb = await databaseFactoryFfi.openDatabase(
        cartDbPath,
        options: sqflite_package.OpenDatabaseOptions(
          version: 1,
          readOnly: true,
        ),
      );

      final cartItems = await cartDb.query('cart_items');
      await cartDb.close();

      if (cartItems.isNotEmpty) {
        for (final item in cartItems) {
          final existing = await db.query(
            'cart_items',
            where: 'product_id = ? AND user_id = ?',
            whereArgs: [item['product_id'], item['user_id']],
          );
          if (existing.isEmpty) {
            await db.insert('cart_items', {
              'product_id': item['product_id'],
              'product_data': item['product_data'],
              'quantity': item['quantity'],
              'created_at': item['created_at'],
              'updated_at': item['updated_at'],
              'user_id': item['user_id'],
            });
          }
        }
        _log('Migrated ${cartItems.length} cart items from cart.db');
      }

      await cartDbFile.delete();
      _log('Deleted old cart.db after migration');
    } catch (e) {
      _log('Error migrating from cart.db: $e');
    }
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

      // 直接从SharedPreferences获取当前用户ID，避免循环依赖
      final prefs = await SharedPreferences.getInstance();

      // 所有用户都使用cloud目录下的数据库文件
      // 使用服务器目录确保数据存放在cloud/database目录
      final directory = await _getServerDirectory();
      if (directory == null) {
        throw Exception('Unable to access server directory');
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
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: sqflite_package.OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          // 使用单例模式（默认），确保所有部分共享同一个连接，解决状态更新同步问题
          singleInstance: true,
        ),
      );

      // 检查并创建所有缺失的表
      await _checkAndCreateMissingTables(db);

      return db;
    } catch (e) {
      _log('数据库初始化错误: $e');
      // 确保抛出异常，而不是返回模拟数据库实例，这样调用者可以知道初始化失败
      throw Exception('Failed to initialize database: $e');
    }
  }

  Future<Directory?> _getDefaultDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString(StorageKeys.storagePath);

      Directory storageDir;
      Directory baseDir;

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        baseDir = await getApplicationDocumentsDirectory();
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        baseDir = Directory(path_package.join(
            Platform.environment['USERPROFILE']!, 'Documents'));
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        baseDir = Directory(
            path_package.join(Platform.environment['HOME']!, 'Documents'));
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        baseDir = Directory(
            path_package.join(Platform.environment['HOME']!, 'Documents'));
      } else {
        throw UnsupportedError('Unsupported platform');
      }

      if (customPath != null && customPath.isNotEmpty) {
        storageDir = Directory(customPath);
      } else {
        storageDir =
            Directory(path_package.join(baseDir.path, 'MomentKeep'));
      }

      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }

      final cloudDir =
          Directory(path_package.join(storageDir.path, 'cloud', 'database'));
      if (!await cloudDir.exists()) {
        await cloudDir.create(recursive: true);
      }

      await _migrateDefaultToCloudDir(storageDir, cloudDir);

      return cloudDir;
    } catch (e) {
      _log('Error getting default directory: $e');
      return null;
    }
  }

  Future<void> _migrateDefaultToCloudDir(Directory storageDir, Directory cloudDir) async {
    try {
      final defaultDir = Directory(path_package.join(storageDir.path, 'default'));
      if (!await defaultDir.exists()) return;

      final oldDbFile = File(path_package.join(defaultDir.path, _databaseName));
      if (!await oldDbFile.exists()) return;

      final newDbFile = File(path_package.join(cloudDir.path, _databaseName));
      if (await newDbFile.exists()) return;

      _log('Migrating database from default/ to cloud/database/...');
      await newDbFile.writeAsBytes(await oldDbFile.readAsBytes());
      await oldDbFile.delete();
      _log('Database migration completed');
    } catch (e) {
      _log('Error migrating database from default/ to cloud/database/: $e');
    }
  }

  /// 获取服务器目录（cloud/database/目录）
  /// 用于存放商品数据库等核心业务数据
  Future<Directory?> _getServerDirectory() async {
    try {
      // 从SharedPreferences获取自定义存储路径
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString(StorageKeys.storagePath);

      Directory serverDir;

      if (customPath != null && customPath.isNotEmpty) {
        // 使用自定义存储路径下的cloud/database目录
        serverDir = Directory('$customPath/cloud/database');
      } else {
        // 使用StoragePathService获取服务器数据库目录
        final serverDatabasePath = await StoragePathService.getServerDatabaseDirectory();
        serverDir = Directory(serverDatabasePath);
      }

      // 确保存储目录存在
      if (!await serverDir.exists()) {
        await serverDir.create(recursive: true);
        _log('创建服务器目录: ${serverDir.path}');
      }

      _log('使用服务器目录: ${serverDir.path}');
      return serverDir;
    } catch (e) {
      _log('Error getting server directory: $e');
      return null;
    }
  }

  /// 创建数据库表结构
  Future<void> _onCreate(dynamic db, int version) async {
    _log('Creating product database tables, version: $version');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS merchants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        logo TEXT,
        description TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        rating REAL NOT NULL DEFAULT 0.0,
        total_sales INTEGER NOT NULL DEFAULT 0,
        approved_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created merchants table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS star_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created star_categories table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS star_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        image TEXT NOT NULL,
        product_code TEXT,
        points INTEGER NOT NULL,
        cost_price INTEGER NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        merchant_id INTEGER,
        brand TEXT,
        tags TEXT,
        category_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT "draft",
        shipping_template_id INTEGER,
        is_pre_sale INTEGER NOT NULL DEFAULT 0,
        pre_sale_end_time INTEGER,
        release_time INTEGER,
        scheduled_release_time INTEGER,
        sales_7_days INTEGER NOT NULL DEFAULT 0,
        total_sales INTEGER NOT NULL DEFAULT 0,
        visitors INTEGER NOT NULL DEFAULT 0,
        conversion_rate REAL NOT NULL DEFAULT 0.0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        main_images TEXT,
        video TEXT,
        video_cover TEXT,
        video_description TEXT,
        detail_images TEXT,
        detail TEXT,
        weight TEXT,
        volume TEXT,
        original_price INTEGER DEFAULT 0,
        price INTEGER DEFAULT 0,
        member_price INTEGER DEFAULT 0,
        shipping_time TEXT,
        shipping_address TEXT,
        return_policy TEXT,
        sort_weight INTEGER DEFAULT 0,
        is_limited_purchase INTEGER DEFAULT 0,
        limit_quantity INTEGER DEFAULT 1,
        internal_note TEXT,
        seo_title TEXT,
        seo_keywords TEXT,
        support_points_payment INTEGER NOT NULL DEFAULT 1,
        support_cash_payment INTEGER NOT NULL DEFAULT 1,
        support_hybrid_payment INTEGER NOT NULL DEFAULT 1,
        hybrid_price INTEGER DEFAULT 0,
        hybrid_points INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES star_categories(id) ON DELETE CASCADE,
        FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL
      );
    ''');
    _log('Created star_products table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS star_product_skus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        sku_code TEXT NOT NULL,
        spec_values TEXT NOT NULL,
        price INTEGER NOT NULL,
        points INTEGER NOT NULL DEFAULT 0,
        cost_price INTEGER NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL,
        image TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        support_points_payment INTEGER NOT NULL DEFAULT 1,
        support_cash_payment INTEGER NOT NULL DEFAULT 1,
        support_hybrid_payment INTEGER NOT NULL DEFAULT 1,
        hybrid_price INTEGER DEFAULT 0,
        hybrid_points INTEGER DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created star_product_skus table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS star_product_specs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        spec_values TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created star_product_specs table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        merchant_id INTEGER,
        product_name TEXT NOT NULL,
        product_image TEXT NOT NULL,
        points INTEGER NOT NULL,
        product_price INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        points_used INTEGER NOT NULL DEFAULT 0,
        cash_amount REAL NOT NULL DEFAULT 0,
        original_points INTEGER NOT NULL DEFAULT 0,
        original_cash INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        variant TEXT,
        status TEXT NOT NULL,
        is_electronic INTEGER NOT NULL DEFAULT 0,
        delivery_address TEXT,
        buyer_note TEXT,
        buyer_name TEXT,
        buyer_phone TEXT,
        fund_status TEXT NOT NULL DEFAULT 'escrow',
        logistics_company_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE,
        FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL
      );
    ''');
    _log('Created orders table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reviews (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
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
        is_anonymous INTEGER NOT NULL DEFAULT 1,
        user_id TEXT,
        user_name TEXT,
        user_avatar TEXT,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created reviews table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS refund_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        points INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        reason TEXT,
        created_at INTEGER NOT NULL,
        approved_at INTEGER,
        approved_by TEXT,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      );
    ''');
    _log('Created refund_requests table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS refund_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        days INTEGER NOT NULL DEFAULT 0,
        hours INTEGER NOT NULL DEFAULT 0,
        minutes INTEGER NOT NULL DEFAULT 0,
        seconds INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created refund_settings table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cleanup_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cleanup_time INTEGER NOT NULL,
        total_products INTEGER NOT NULL,
        success_count INTEGER NOT NULL,
        failed_count INTEGER NOT NULL,
        details TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    _log('Created cleanup_logs table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS operation_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        operator TEXT NOT NULL,
        action TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id)
      );
    ''');
    _log('Created operation_logs table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        type TEXT NOT NULL,
        value INTEGER,
        min_amount INTEGER,
        max_discount INTEGER,
        total_count INTEGER NOT NULL,
        used_count INTEGER NOT NULL DEFAULT 0,
        start_time INTEGER,
        end_time INTEGER,
        valid_days INTEGER,
        category_ids TEXT,
        product_ids TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        reward_type TEXT NOT NULL DEFAULT 'cash'
      );
    ''');
    _log('Created coupons table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        coupon_id INTEGER NOT NULL,
        order_id TEXT,
        used_at INTEGER,
        created_at INTEGER NOT NULL,
        expires_at INTEGER,
        status TEXT NOT NULL DEFAULT 'unused',
        FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE
      );
    ''');
    _log('Created user_coupons table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS red_packets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        total_count INTEGER NOT NULL,
        received_count INTEGER NOT NULL DEFAULT 0,
        min_amount INTEGER,
        max_amount INTEGER,
        start_time INTEGER,
        end_time INTEGER,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        reward_type TEXT NOT NULL DEFAULT 'cash'
      );
    ''');
    _log('Created red_packets table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS red_packet_claims (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        red_packet_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        claimed_at INTEGER NOT NULL,
        FOREIGN KEY (red_packet_id) REFERENCES red_packets(id) ON DELETE CASCADE
      );
    ''');
    _log('Created red_packet_claims table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_no TEXT NOT NULL,
        name TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        balance INTEGER NOT NULL,
        password TEXT,
        valid_from INTEGER,
        valid_to INTEGER,
        status TEXT NOT NULL DEFAULT 'inactive',
        activated_at INTEGER,
        user_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created shopping_cards table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_card_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shopping_card_id INTEGER NOT NULL,
        order_id TEXT,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        balance_before INTEGER NOT NULL,
        balance_after INTEGER NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (shopping_card_id) REFERENCES shopping_cards(id) ON DELETE CASCADE
      );
    ''');
    _log('Created shopping_card_transactions table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS addresses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        province TEXT NOT NULL,
        city TEXT NOT NULL,
        district TEXT NOT NULL,
        detail TEXT NOT NULL,
        postal_code TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        tag TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created addresses table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS member_levels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        min_points INTEGER NOT NULL,
        discount REAL NOT NULL DEFAULT 1.0,
        points_bonus INTEGER NOT NULL DEFAULT 0,
        icon TEXT,
        privileges TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created member_levels table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS logistics_companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        website TEXT,
        phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Created logistics_companies table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS logistics_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        logistics_company_id INTEGER,
        tracking_number TEXT,
        status TEXT NOT NULL,
        description TEXT NOT NULL,
        location TEXT,
        track_time INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (logistics_company_id) REFERENCES logistics_companies(id) ON DELETE SET NULL
      );
    ''');
    _log('Created logistics_tracks table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        merchant_id INTEGER,
        user_id TEXT NOT NULL,
        payment_no TEXT NOT NULL,
        amount REAL NOT NULL,
        points_used INTEGER NOT NULL DEFAULT 0,
        cash_amount INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        third_party_payment_id TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        paid_at INTEGER,
        refunded_at INTEGER,
        failure_reason TEXT,
        fund_status TEXT DEFAULT 'escrow',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL
      );
    ''');
    _log('Created payment_records table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        sku_id INTEGER,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        stock_before INTEGER NOT NULL,
        stock_after INTEGER NOT NULL,
        related_id TEXT,
        remark TEXT,
        operator_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created stock_records table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS promotions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'full_reduction',
        threshold_amount INTEGER NOT NULL DEFAULT 0,
        discount_value REAL NOT NULL DEFAULT 0,
        start_time TEXT,
        end_time TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created promotions table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS return_logistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        tracking_number TEXT,
        logistics_company_id INTEGER,
        status TEXT NOT NULL DEFAULT 'pending_ship',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (logistics_company_id) REFERENCES logistics_companies(id) ON DELETE SET NULL
      );
    ''');
    _log('Created return_logistics table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS card_secrets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        card_secret TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'unused',
        expires_at INTEGER,
        created_at INTEGER NOT NULL,
        used_at INTEGER
      );
    ''');
    _log('Created card_secrets table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL,
        order_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        invoice_type TEXT NOT NULL DEFAULT '个人',
        title TEXT NOT NULL,
        tax_id TEXT,
        email TEXT,
        status TEXT NOT NULL DEFAULT '待开具',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        issued_at INTEGER,
        mailed_at INTEGER
      );
    ''');
    _log('Created invoices table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS real_name_auth (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        real_name TEXT NOT NULL,
        id_card TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        reject_reason TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        verified_at INTEGER
      );
    ''');
    _log('Created real_name_auth table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS browsing_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        product_image TEXT NOT NULL,
        product_price INTEGER NOT NULL,
        product_points INTEGER NOT NULL,
        visited_at INTEGER NOT NULL
      );
    ''');
    _log('Created browsing_history table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        question TEXT NOT NULL,
        answer TEXT,
        answered_by TEXT,
        answered_at INTEGER,
        is_answered INTEGER NOT NULL DEFAULT 0,
        like_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created product_questions table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(user_id, product_id)
      );
    ''');
    _log('Created favorite_products table');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_data TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        user_id TEXT NOT NULL
      );
    ''');
    _log('Created cart_items table');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_star_categories_name ON star_categories (name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_star_products_category_id ON star_products (category_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_star_products_is_active ON star_products (is_active)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_product_id ON orders (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_refund_requests_order_id ON refund_requests (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_refund_requests_user_id ON refund_requests (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_refund_requests_status ON refund_requests (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_cleanup_time ON cleanup_logs (cleanup_time)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_created_at ON cleanup_logs (created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_operation_logs_order_id ON operation_logs (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at ON operation_logs (created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_browsing_history_user_id ON browsing_history (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_browsing_history_visited_at ON browsing_history (visited_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_questions_product_id ON product_questions (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_questions_created_at ON product_questions (created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_questions_is_answered ON product_questions (is_answered)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons (code)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_coupons_user_id ON user_coupons (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_coupons_coupon_id ON user_coupons (coupon_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_coupons_status ON user_coupons (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_red_packet_claims_red_packet_id ON red_packet_claims (red_packet_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_red_packet_claims_user_id ON red_packet_claims (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shopping_cards_card_no ON shopping_cards (card_no)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shopping_cards_user_id ON shopping_cards (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shopping_card_transactions_shopping_card_id ON shopping_card_transactions (shopping_card_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_shopping_card_transactions_order_id ON shopping_card_transactions (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_addresses_is_default ON addresses (is_default)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_member_levels_min_points ON member_levels (min_points)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_logistics_companies_code ON logistics_companies (code)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_logistics_tracks_order_id ON logistics_tracks (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_logistics_tracks_tracking_number ON logistics_tracks (tracking_number)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_records_order_id ON payment_records (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_records_user_id ON payment_records (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_records_payment_no ON payment_records (payment_no)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_records_product_id ON stock_records (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_records_sku_id ON stock_records (sku_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_merchants_user_id ON merchants (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_merchants_status ON merchants (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_favorite_products_user_id ON favorite_products (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_favorite_products_product_id ON favorite_products (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON cart_items (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_promotions_product_id ON promotions (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_promotions_is_active ON promotions (is_active)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_return_logistics_order_id ON return_logistics (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_card_secrets_order_id ON card_secrets (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_card_secrets_user_id ON card_secrets (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_card_secrets_product_id ON card_secrets (product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_card_secrets_status ON card_secrets (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON invoices (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_order_id ON invoices (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_real_name_auth_user_id ON real_name_auth (user_id)');

    await db.insert('refund_settings', {
      'days': 7,
      'hours': 0,
      'minutes': 0,
      'seconds': 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });
    _log('Inserted default refund settings');
  }

  /// 数据库升级处理
  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    _log('Upgrading product database from version $oldVersion to $newVersion');
    await _onCreate(db, newVersion);
  }

  /// 检查并创建所有缺失的表
  Future<void> _checkAndCreateMissingTables(dynamic db) async {
    _log('Checking and creating missing tables...');

    // 为orders表添加variant字段（如果不存在）
    try {
      await db.execute('ALTER TABLE orders ADD COLUMN variant TEXT');
      _log('Added variant column to orders table');
    } catch (e) {
      // _log('variant column might already exist in orders table: $e');
    }

    // 为orders表添加original_points字段（如果不存在）
    try {
      await db.execute('ALTER TABLE orders ADD COLUMN original_points INTEGER NOT NULL DEFAULT 0');
      _log('Added original_points column to orders table');
    } catch (e) {
      _log('original_points column might already exist in orders table: $e');
    }

    // 为orders表添加original_cash字段（如果不存在）
    try {
      await db.execute('ALTER TABLE orders ADD COLUMN original_cash INTEGER NOT NULL DEFAULT 0');
      _log('Added original_cash column to orders table');
    } catch (e) {
      _log('original_cash column might already exist in orders table: $e');
    }

    // 创建评论表（如果不存在）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reviews (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
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
        is_anonymous INTEGER NOT NULL DEFAULT 1,
        user_id TEXT,
        user_name TEXT,
        user_avatar TEXT,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Ensured reviews table exists');

    // 创建退积分设置表（如果不存在）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS refund_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        days INTEGER NOT NULL DEFAULT 0,
        hours INTEGER NOT NULL DEFAULT 0,
        minutes INTEGER NOT NULL DEFAULT 0,
        seconds INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');
    _log('Ensured refund_settings table exists');

    // 创建退积分申请表（如果不存在）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS refund_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        points INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        reason TEXT,
        created_at INTEGER NOT NULL,
        approved_at INTEGER,
        approved_by TEXT,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      );
    ''');
    _log('Ensured refund_requests table exists');

    // 创建清理日志表（如果不存在）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cleanup_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cleanup_time INTEGER NOT NULL,
        total_products INTEGER NOT NULL,
        success_count INTEGER NOT NULL,
        failed_count INTEGER NOT NULL,
        details TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    _log('Ensured cleanup_logs table exists');

    // 检查并插入默认退积分设置（如果不存在）
    final refundSettings = await db.query('refund_settings');
    if (refundSettings.isEmpty) {
      await db.insert('refund_settings', {
        'days': 7,
        'hours': 0,
        'minutes': 0,
        'seconds': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      });
      _log('Inserted default refund settings');
    }

    // 创建索引（如果不存在）
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_cleanup_time ON cleanup_logs (cleanup_time)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_created_at ON cleanup_logs (created_at)');
    _log('Ensured indexes exist');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_data TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        user_id TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items (user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON cart_items (product_id)');
    _log('Ensured cart_items table exists');

    try {
      await db.rawUpdate(
          "UPDATE orders SET total_amount = cash_amount WHERE total_amount != cash_amount");
      _log('Fixed orders total_amount to cash_amount only');
    } catch (e) {
      _log('Failed to fix orders total_amount: $e');
    }

    try {
      await db.rawUpdate(
          "UPDATE payment_records SET amount = cash_amount WHERE amount != cash_amount");
      _log('Fixed payment_records amount to cash_amount only');
    } catch (e) {
      _log('Failed to fix payment_records amount: $e');
    }

    try {
      await db.execute('ALTER TABLE payment_records ADD COLUMN merchant_id INTEGER REFERENCES merchants(id) ON DELETE SET NULL');
      _log('Added missing merchant_id column to payment_records table');
    } catch (e) {
      _log('merchant_id column might already exist in payment_records: $e');
    }

    try {
      await db.execute(
          "ALTER TABLE coupons ADD COLUMN reward_type TEXT NOT NULL DEFAULT 'cash'");
      _log('Added reward_type column to coupons table');
    } catch (e) {
      _log('reward_type column might already exist in coupons: $e');
    }
    try {
      await db.execute(
          "ALTER TABLE red_packets ADD COLUMN reward_type TEXT NOT NULL DEFAULT 'cash'");
      _log('Added reward_type column to red_packets table');
    } catch (e) {
      _log('reward_type column might already exist in red_packets: $e');
    }

    await db.rawUpdate(
        "UPDATE coupons SET reward_type = 'cash' WHERE reward_type IS NULL OR reward_type = ''");
    await db.rawUpdate(
        "UPDATE red_packets SET reward_type = 'points' WHERE type IN ('星星红包', '积分红包') AND (reward_type IS NULL OR reward_type = '' OR reward_type = 'cash')");
    await db.rawUpdate(
        "UPDATE red_packets SET reward_type = 'cash' WHERE reward_type IS NULL OR reward_type = ''");
    _log('Migrated reward_type for existing coupons and red_packets');

    _log('All missing tables checked and created successfully');
  }

  /// 模拟数据库实现（Web环境使用）
  dynamic _createMockDatabase() {
    return _MockDatabaseForWeb();
  }

  /// 获取所有商品分类
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('star_categories',
        orderBy: 'sort_order ASC, created_at DESC');
  }

  /// 根据ID获取商品分类
  Future<Map<String, dynamic>?> getCategoryById(int categoryId) async {
    final db = await database;
    final result = await db.query(
      'star_categories',
      where: 'id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// 插入商品分类
  Future<int> insertCategory(Map<String, dynamic> categoryData) async {
    final db = await database;
    return await db.insert('star_categories', categoryData);
  }

  /// 更新商品分类
  Future<int> updateCategory(
      int categoryId, Map<String, dynamic> categoryData) async {
    final db = await database;
    return await db.update(
      'star_categories',
      categoryData,
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  /// 删除商品分类
  Future<int> deleteCategory(int categoryId) async {
    final db = await database;
    return await db.delete(
      'star_categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  /// 获取所有商品
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('star_products',
        where: 'is_deleted = 0', orderBy: 'created_at DESC');
  }

  /// 根据商家ID获取商品
  Future<List<Map<String, dynamic>>> getProductsByMerchantId(int merchantId) async {
    final db = await database;
    return await db.query('star_products',
        where: 'merchant_id = ? AND is_deleted = 0',
        whereArgs: [merchantId],
        orderBy: 'created_at DESC');
  }

  /// 获取所有已上架的商品（用户端浏览）
  Future<List<Map<String, dynamic>>> getActiveProducts() async {
    final db = await database;
    return await db.query('star_products',
        where: 'status = ? AND is_deleted = 0 AND is_active = 1',
        whereArgs: ['active'],
        orderBy: 'created_at DESC');
  }

  /// 根据ID获取商品
  Future<Map<String, dynamic>?> getProductById(int productId) async {
    final db = await database;
    final result = await db.query(
      'star_products',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [productId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// 插入商品
  Future<int> insertProduct(Map<String, dynamic> productData) async {
    final db = await database;
    return await db.insert('star_products', productData);
  }

  /// 更新商品
  Future<int> updateProduct(
      int productId, Map<String, dynamic> productData) async {
    final db = await database;
    return await db.update(
      'star_products',
      productData,
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// 删除商品（逻辑删除）
  Future<int> deleteProduct(int productId) async {
    final db = await database;
    return await db.update(
      'star_products',
      {'is_deleted': 1, 'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// 获取商品SKU
  Future<List<Map<String, dynamic>>> getProductSkus(int productId) async {
    final db = await database;
    return await db.query(
      'star_product_skus',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  /// 插入商品SKU
  Future<int> insertProductSku(Map<String, dynamic> skuData) async {
    final db = await database;
    return await db.insert('star_product_skus', skuData);
  }

  /// 更新商品SKU
  Future<int> updateProductSku(int skuId, Map<String, dynamic> skuData) async {
    final db = await database;
    return await db.update(
      'star_product_skus',
      skuData,
      where: 'id = ?',
      whereArgs: [skuId],
    );
  }

  /// 删除商品SKU
  Future<int> deleteProductSku(int skuId) async {
    final db = await database;
    return await db.delete(
      'star_product_skus',
      where: 'id = ?',
      whereArgs: [skuId],
    );
  }

  /// 更新商品SKU库存
  Future<int> updateProductSkuStock(int skuId, int newStock) async {
    final db = await database;
    return await db.update(
      'star_product_skus',
      {'stock': newStock, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [skuId],
    );
  }

  /// 更新商品SKU库存（别名方法，兼容其他调用）
  Future<int> updateSkuStock(int skuId, int newStock) async {
    return await updateProductSkuStock(skuId, newStock);
  }

  /// 更新商品库存
  Future<int> updateProductStock(int productId, int newStock) async {
    final db = await database;
    return await db.update(
      'star_products',
      {'stock': newStock, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ==================== 智能推荐相关方法 ====================

  /// 获取猜你喜欢商品（基于用户浏览历史和购买记录）
  Future<List<Map<String, dynamic>>> getRecommendedProducts({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final db = await database;
      
      // 获取用户浏览过的商品分类
      final viewedCategories = await db.rawQuery('''
        SELECT DISTINCT sp.category_id 
        FROM browsing_history bh
        JOIN star_products sp ON bh.product_id = sp.id
        WHERE bh.user_id = ? AND sp.is_deleted = 0
        ORDER BY bh.created_at DESC
        LIMIT 5
      ''', [userId]);

      if (viewedCategories.isNotEmpty) {
        final categoryIds = viewedCategories.map((row) => row['category_id']).toList();
        final placeholders = List.filled(categoryIds.length, '?').join(',');
        
        // 推荐同类别的高销量商品
        final recommendedProducts = await db.rawQuery('''
          SELECT * FROM star_products 
          WHERE category_id IN ($placeholders) 
            AND is_deleted = 0 
            AND is_active = 1 
            AND status = 'active'
            AND id NOT IN (
              SELECT product_id FROM browsing_history WHERE user_id = ?
            )
          ORDER BY total_sales DESC, visitors DESC
          LIMIT ?
        ''', [...categoryIds, userId, limit]);

        return recommendedProducts;
      }

      // 如果没有浏览历史，返回热门商品
      return await getHotProducts(limit: limit);
    } catch (e) {
      debugPrint('获取推荐商品失败: $e');
      return await getHotProducts(limit: limit);
    }
  }

  /// 获取相似商品（基于当前商品的分类和标签）
  Future<List<Map<String, dynamic>>> getSimilarProducts({
    required int productId,
    int limit = 6,
  }) async {
    try {
      final db = await database;
      
      // 获取当前商品信息
      final currentProduct = await getProductById(productId);
      if (currentProduct == null) {
        return [];
      }

      final categoryId = currentProduct['category_id'];
      final tags = currentProduct['tags'] as String?;

      if (tags != null && tags.isNotEmpty) {
        // 基于标签相似度推荐
        final tagList = tags.split(',');
        final similarByTags = <Map<String, dynamic>>[];
        
        for (final tag in tagList) {
          final products = await db.rawQuery('''
            SELECT * FROM star_products 
            WHERE tags LIKE ? 
              AND is_deleted = 0 
              AND is_active = 1 
              AND status = 'active'
              AND id != ?
            ORDER BY total_sales DESC
            LIMIT ?
          ''', ['%$tag%', productId, limit - similarByTags.length]);
          
          similarByTags.addAll(products);
          if (similarByTags.length >= limit) break;
        }

        if (similarByTags.isNotEmpty) {
          // 去重
          final seenIds = <int>{};
          final uniqueProducts = <Map<String, dynamic>>[];
          for (final product in similarByTags) {
            final id = product['id'] as int;
            if (!seenIds.contains(id)) {
              seenIds.add(id);
              uniqueProducts.add(product);
            }
          }
          return uniqueProducts.take(limit).toList();
        }
      }

      // 如果没有标签，返回同分类商品
      return await db.rawQuery('''
        SELECT * FROM star_products 
        WHERE category_id = ? 
          AND is_deleted = 0 
          AND is_active = 1 
          AND status = 'active'
          AND id != ?
        ORDER BY total_sales DESC, created_at DESC
        LIMIT ?
      ''', [categoryId, productId, limit]);
    } catch (e) {
      debugPrint('获取相似商品失败: $e');
      return [];
    }
  }

  /// 获取搭配购商品（基于历史订单的关联购买）
  Future<List<Map<String, dynamic>>> getBundleProducts({
    required int productId,
    int limit = 4,
  }) async {
    try {
      final db = await database;
      
      // 查询包含该商品的所有订单
      final orders = await db.rawQuery('''
        SELECT DISTINCT o.id as order_id 
        FROM orders o
        JOIN json_each(o.items) as je ON 1=1
        WHERE json_extract(je.value, '\$.product_id') = ?
          AND o.status IN ('交易完成', '已签收')
        LIMIT 50
      ''', [productId]);

      if (orders.isEmpty) {
        // 如果没有订单数据，返回同分类热门商品
        return await getHotProductsByCategory(productId, limit: limit);
      }

      final orderIds = orders.map((o) => o['order_id']).toList();
      final placeholders = List.filled(orderIds.length, '?').join(',');

      // 统计这些订单中其他商品的购买频次
      final bundleProducts = await db.rawQuery('''
        SELECT sp.*, COUNT(*) as frequency
        FROM star_products sp
        JOIN orders o ON 1=1
        JOIN json_each(o.items) as je ON 1=1
        WHERE o.id IN ($placeholders)
          AND json_extract(je.value, '\$.product_id') = sp.id
          AND sp.id != ?
          AND sp.is_deleted = 0
          AND sp.is_active = 1
          AND sp.status = 'active'
        GROUP BY sp.id
        ORDER BY frequency DESC, sp.total_sales DESC
        LIMIT ?
      ''', [...orderIds, productId, limit]);

      return bundleProducts;
    } catch (e) {
      debugPrint('获取搭配商品失败: $e');
      return await getHotProductsByCategory(productId, limit: limit);
    }
  }

  /// 根据分类获取热门商品
  Future<List<Map<String, dynamic>>> getHotProductsByCategory(
    int productId, {
    int limit = 4,
  }) async {
    try {
      final db = await database;
      final product = await getProductById(productId);
      
      if (product == null) {
        return await getHotProducts(limit: limit);
      }

      return await db.rawQuery('''
        SELECT * FROM star_products 
        WHERE category_id = ? 
          AND is_deleted = 0 
          AND is_active = 1 
          AND status = 'active'
          AND id != ?
        ORDER BY total_sales DESC, visitors DESC
        LIMIT ?
      ''', [product['category_id'], productId, limit]);
    } catch (e) {
      debugPrint('获取分类热门商品失败: $e');
      return await getHotProducts(limit: limit);
    }
  }

  /// 获取热门商品（全局）
  Future<List<Map<String, dynamic>>> getHotProducts({int limit = 10}) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT * FROM star_products 
        WHERE is_deleted = 0 
          AND is_active = 1 
          AND status = 'active'
        ORDER BY total_sales DESC, conversion_rate DESC
        LIMIT ?
      ''', [limit]);
    } catch (e) {
      debugPrint('获取热门商品失败: $e');
      return [];
    }
  }

  /// 获取新品上市商品
  Future<List<Map<String, dynamic>>> getNewProducts({int limit = 10}) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT * FROM star_products 
        WHERE is_deleted = 0 
          AND is_active = 1 
          AND status = 'active'
        ORDER BY created_at DESC
        LIMIT ?
      ''', [limit]);
    } catch (e) {
      debugPrint('获取新品失败: $e');
      return [];
    }
  }

  /// 获取榜单商品（支持多种排序）
  Future<List<Map<String, dynamic>>> getRankingProducts({
    String sortBy = 'sales', // sales, visitors, conversion_rate
    int limit = 10,
    int? categoryId,
  }) async {
    try {
      final db = await database;
      
      String orderByClause;
      switch (sortBy) {
        case 'sales':
          orderByClause = 'total_sales DESC';
          break;
        case 'visitors':
          orderByClause = 'visitors DESC';
          break;
        case 'conversion_rate':
          orderByClause = 'conversion_rate DESC';
          break;
        default:
          orderByClause = 'total_sales DESC';
      }

      String whereClause = 'is_deleted = 0 AND is_active = 1 AND status = ?';
      List<dynamic> whereArgs = ['active'];

      if (categoryId != null) {
        whereClause += ' AND category_id = ?';
        whereArgs.add(categoryId);
      }

      final result = await db.rawQuery('''
        SELECT * FROM star_products 
        WHERE $whereClause
        ORDER BY $orderByClause
        LIMIT ?
      ''', [...whereArgs, limit]);

      return result;
    } catch (e) {
      debugPrint('获取榜单商品失败: $e');
      return [];
    }
  }

  /// 更新商品浏览量
  Future<void> incrementProductViews(int productId) async {
    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE star_products 
        SET visitors = visitors + 1, updated_at = ?
        WHERE id = ? AND is_deleted = 0
      ''', [DateTime.now().millisecondsSinceEpoch, productId]);
    } catch (e) {
      debugPrint('更新商品浏览量失败: $e');
    }
  }

  /// 更新商品转化率（下单次数/浏览量）
  Future<void> updateProductConversionRate(int productId) async {
    try {
      final db = await database;
      
      // 获取商品浏览量
      final product = await getProductById(productId);
      if (product == null) return;

      final visitors = product['visitors'] as int? ?? 0;
      if (visitors == 0) return;

      // 统计该商品的订单数量
      final orderCount = await db.rawQuery('''
        SELECT COUNT(DISTINCT o.id) as count
        FROM orders o
        JOIN json_each(o.items) as je ON 1=1
        WHERE json_extract(je.value, '\$.product_id') = ?
          AND o.status NOT IN ('已取消', '待付款')
      ''', [productId]);

      final orders = (orderCount.first['count'] as int?) ?? 0;
      final conversionRate = orders / visitors;

      await db.rawUpdate('''
        UPDATE star_products 
        SET conversion_rate = ?, updated_at = ?
        WHERE id = ? AND is_deleted = 0
      ''', [conversionRate, DateTime.now().millisecondsSinceEpoch, productId]);
    } catch (e) {
      debugPrint('更新商品转化率失败: $e');
    }
  }

  /// 记录浏览历史并更新商品浏览量
  Future<void> recordProductView({
    required String userId,
    required int productId,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 插入浏览历史
      await db.insert('browsing_history', {
        'user_id': userId,
        'product_id': productId,
        'created_at': now,
      });

      // 更新商品浏览量
      await incrementProductViews(productId);
    } catch (e) {
      debugPrint('记录浏览历史失败: $e');
    }
  }

  // ==================== 订单库存管理 ====================

  /// 恢复订单库存
  ///
  /// 封装库存恢复逻辑，供所有取消订单/拒单入口调用。
  /// [orderId] 订单ID
  /// [reason] 恢复原因（如"取消订单"、"拒单"等）
  Future<void> restoreOrderStock(String orderId, String reason) async {
    try {
      final orderData = await getOrderById(orderId);
      if (orderData == null) {
        _log('restoreOrderStock: 订单不存在 orderId=$orderId');
        return;
      }

      final String? status = orderData['status'] as String?;
      if (status == '待付款') {
        _log('restoreOrderStock: 订单未付款，无需恢复库存 orderId=$orderId');
        return;
      }

      final int productId = orderData['product_id'] as int;
      final int quantity = (orderData['quantity'] as int?) ?? 1;
      final dynamic skuIdRaw = orderData['sku_id'];
      final int? skuId = (skuIdRaw is int && skuIdRaw > 0) ? skuIdRaw : null;

      final productData = await getProductById(productId);
      if (productData == null) {
        _log('restoreOrderStock: 商品不存在 productId=$productId');
        return;
      }
      final int currentProductStock = productData['stock'] as int;

      int? currentSkuStock;
      if (skuId != null) {
        final db = await database;
        final skuResult = await db.query(
          'star_product_skus',
          where: 'id = ?',
          whereArgs: [skuId],
          limit: 1,
        );
        if (skuResult.isNotEmpty) {
          currentSkuStock = skuResult.first['stock'] as int;
        }
      }

      if (skuId != null && currentSkuStock != null) {
        await updateSkuStock(skuId, currentSkuStock + quantity);
        await insertStockRecord(StockRecord(
          productId: productId,
          skuId: skuId,
          type: 'return',
          quantity: quantity,
          stockBefore: currentSkuStock,
          stockAfter: currentSkuStock + quantity,
          relatedId: orderId,
          remark: reason,
          operatorId: 'system',
          createdAt: DateTime.now(),
        ));
      }

      await updateProductStock(productId, currentProductStock + quantity);
      await insertStockRecord(StockRecord(
        productId: productId,
        skuId: skuId,
        type: 'return',
        quantity: quantity,
        stockBefore: currentProductStock,
        stockAfter: currentProductStock + quantity,
        relatedId: orderId,
        remark: reason,
        operatorId: 'system',
        createdAt: DateTime.now(),
      ));

      _log('restoreOrderStock: 库存恢复成功 orderId=$orderId, productId=$productId, skuId=$skuId, quantity=$quantity, reason=$reason');
    } catch (e) {
      _log('restoreOrderStock: 库存恢复异常 orderId=$orderId, error=$e');
    }
  }

  /// 获取商品规格
  Future<List<Map<String, dynamic>>> getProductSpecs(int productId) async {
    final db = await database;
    return await db.query(
      'star_product_specs',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  /// 插入商品规格
  Future<int> insertProductSpec(Map<String, dynamic> specData) async {
    final db = await database;
    return await db.insert('star_product_specs', specData);
  }

  /// 更新商品规格
  Future<int> updateProductSpec(
      int specId, Map<String, dynamic> specData) async {
    final db = await database;
    return await db.update(
      'star_product_specs',
      specData,
      where: 'id = ?',
      whereArgs: [specId],
    );
  }

  /// 删除商品规格
  Future<int> deleteProductSpec(int specId) async {
    final db = await database;
    return await db.delete(
      'star_product_specs',
      where: 'id = ?',
      whereArgs: [specId],
    );
  }

  /// 根据商品ID删除所有规格
  Future<int> deleteProductSpecsByProductId(int productId) async {
    final db = await database;
    return await db.delete(
      'star_product_specs',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  /// 根据商品ID删除所有SKU
  Future<int> deleteProductSkusByProductId(int productId) async {
    final db = await database;
    return await db.delete(
      'star_product_skus',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  /// 根据分类ID删除所有商品（逻辑删除）
  Future<void> deleteProductsByCategoryId(int categoryId) async {
    final db = await database;
    await db.update(
      'star_products',
      {'is_deleted': 1, 'deleted_at': DateTime.now().millisecondsSinceEpoch, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'category_id = ? AND is_deleted = 0',
      whereArgs: [categoryId],
    );
  }

  /// 获取所有订单
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final db = await database;
    debugPrint('开始查询所有订单...');
    // 使用单例连接，不再需要 PRAGMA 重载
    final orders = await db.query('orders', orderBy: 'created_at DESC');

    debugPrint('查询到 ${orders.length} 个订单');
    // 打印第一个订单的状态，用于调试
    if (orders.isNotEmpty) {
      debugPrint('第一个订单的状态: ${orders[0]['status']}');
      debugPrint('第一个订单的ID: ${orders[0]['id']}');
    }

    // 为每个订单添加售后记录，与getOrdersByUserId保持一致
    final ordersWithAfterSales = <Map<String, dynamic>>[];
    for (final order in orders) {
      final orderId = order['id'] as String;
      // 获取所有相关的售后记录
      final refundRequests = await db.query('refund_requests',
          where: 'order_id = ?',
          whereArgs: [orderId],
          orderBy: 'created_at DESC');

      // 将售后记录转换为列表格式，存储到订单中
      final afterSalesRecords = <Map<String, dynamic>>[];
      for (final refund in refundRequests) {
        afterSalesRecords.add({
          'id': '${orderId}_${refund['id']}',
          'after_sales_type':
              refund['reason']?.contains('维修') == true ? 'repair' : 'refund',
          'after_sales_reason': refund['reason'] as String?,
          'after_sales_description': refund['reason'] as String?,
          'after_sales_images': [],
          'after_sales_create_time': refund['created_at'] as int,
          'after_sales_status': refund['status'] as String,
          'after_sales_result': refund['approved_at'] != null ? '已处理' : '待处理',
          'after_sales_handle_time': refund['approved_at'] as int?,
        });
      }

      // 如果订单表中已有售后信息，也添加到售后记录列表
      if (order['after_sales_type'] != null ||
          order['after_sales_reason'] != null ||
          order['after_sales_description'] != null ||
          order['after_sales_images'] != null ||
          order['after_sales_create_time'] != null ||
          order['after_sales_status'] != null) {
        // 处理售后图片，确保它是有效的JSON格式
        List<String> imagesList = [];
        if (order['after_sales_images'] != null) {
          final afterSalesImages = order['after_sales_images'] as String?;
          if (afterSalesImages != null &&
              afterSalesImages.isNotEmpty &&
              afterSalesImages != '[]') {
            try {
              // 检查是否是直接的文件路径格式，如[C:\path\to\file.png]或直接的文件路径
              if (afterSalesImages.startsWith('[') &&
                  afterSalesImages.endsWith(']')) {
                // 去除前后的[]
                String cleanedStr =
                    afterSalesImages.substring(1, afterSalesImages.length - 1);

                // 检查是否包含逗号
                if (cleanedStr.contains(',')) {
                  // 多个文件路径，按逗号分割
                  List<String> imagesPaths = cleanedStr.split(',');
                  // 清理每个图片URL
                  imagesList = imagesPaths.map((img) {
                    // 去除前后的空格
                    String cleanedImg = img.trim();
                    // 去除可能存在的引号
                    if ((cleanedImg.startsWith('"') &&
                            cleanedImg.endsWith('"')) ||
                        (cleanedImg.startsWith("'") &&
                            cleanedImg.endsWith("'"))) {
                      cleanedImg =
                          cleanedImg.substring(1, cleanedImg.length - 1);
                    }
                    return cleanedImg;
                  }).toList();
                } else {
                  // 单个文件路径
                  String cleanedImg = cleanedStr.trim();
                  // 去除可能存在的引号
                  if ((cleanedImg.startsWith('"') &&
                          cleanedImg.endsWith('"')) ||
                      (cleanedImg.startsWith("'") &&
                          cleanedImg.endsWith("'"))) {
                    cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
                  }
                  imagesList = [cleanedImg];
                }
              } else if (afterSalesImages.contains('\\') ||
                  afterSalesImages.startsWith('http')) {
                // 直接的文件路径或URL，没有[]包裹
                imagesList = [afterSalesImages];
              } else {
                // 尝试JSON解析
                imagesList = List<String>.from(json.decode(afterSalesImages));
              }
            } catch (e) {
              // 如果所有解析都失败，检查是否是有效的文件路径
              String cleanedImg = afterSalesImages.trim();
              // 去除可能存在的引号
              if ((cleanedImg.startsWith('"') && cleanedImg.endsWith('"')) ||
                  (cleanedImg.startsWith("'") && cleanedImg.endsWith("'"))) {
                cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
              }
              // 检查是否是有效的文件路径或URL
              if (cleanedImg.contains('\\') || cleanedImg.startsWith('http')) {
                imagesList = [cleanedImg];
              } else {
                // 其他情况，使用空列表
                imagesList = [];
              }
            }
          }
        }

        afterSalesRecords.add({
          'id': '${orderId}_0',
          'after_sales_type': order['after_sales_type'] as String? ?? 'refund',
          'after_sales_reason': order['after_sales_reason'] as String?,
          'after_sales_description':
              order['after_sales_description'] as String?,
          'after_sales_images': imagesList,
          'after_sales_create_time': order['after_sales_create_time'] as int? ??
              DateTime.now().millisecondsSinceEpoch,
          'after_sales_status':
              order['after_sales_status'] as String? ?? 'pending',
          'after_sales_result':
              order['after_sales_status'] == 'completed' ? '已处理' : '待处理',
          'after_sales_handle_time': null,
        });
      }

      // 将售后记录添加到订单中
      final orderWithAfterSales = Map<String, dynamic>.from(order);
      if (afterSalesRecords.isNotEmpty) {
        // 按创建时间降序排序，确保最新的记录在前面
        afterSalesRecords.sort((a, b) => (b['after_sales_create_time'] as int)
            .compareTo(a['after_sales_create_time'] as int));
        // 去重，确保每个记录ID唯一
        final uniqueRecords = <Map<String, dynamic>>[];
        final seenIds = <String>{};
        for (final record in afterSalesRecords) {
          final id = record['id'] as String;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueRecords.add(record);
          }
        }
        orderWithAfterSales['after_sales_records'] = json.encode(uniqueRecords);
      }

      ordersWithAfterSales.add(orderWithAfterSales);
    }

    // 移除显式关闭连接

    return ordersWithAfterSales;
  }

  /// 根据订单ID获取单个订单
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    final db = await database;
    // 使用单例连接，不再需要 PRAGMA 重载
    final orders = await db.query('orders',
        where: 'id = ?', whereArgs: [orderId], limit: 1);

    Map<String, dynamic>? result = null;

    if (orders.isNotEmpty) {
      final order = orders.first;
      final orderId = order['id'] as String;

      // 获取所有相关的售后记录
      final refundRequests = await db.query('refund_requests',
          where: 'order_id = ?',
          whereArgs: [orderId],
          orderBy: 'created_at DESC');

      // 将售后记录转换为列表格式，存储到订单中
      final afterSalesRecords = <Map<String, dynamic>>[];
      for (final refund in refundRequests) {
        afterSalesRecords.add({
          'id': '${orderId}_${refund['id']}',
          'after_sales_type':
              refund['reason']?.contains('维修') == true ? 'repair' : 'refund',
          'after_sales_reason': refund['reason'] as String?,
          'after_sales_description': refund['reason'] as String?,
          'after_sales_images': [],
          'after_sales_create_time': refund['created_at'] as int,
          'after_sales_status': refund['status'] as String,
          'after_sales_result': refund['approved_at'] != null ? '已处理' : '待处理',
          'after_sales_handle_time': refund['approved_at'] as int?,
        });
      }

      // 如果订单表中已有售后信息，也添加到售后记录列表
      if (order['after_sales_type'] != null ||
          order['after_sales_reason'] != null ||
          order['after_sales_description'] != null ||
          order['after_sales_images'] != null ||
          order['after_sales_create_time'] != null ||
          order['after_sales_status'] != null) {
        // 处理售后图片，确保它是有效的JSON格式
        List<String> imagesList = [];
        if (order['after_sales_images'] != null) {
          final afterSalesImages = order['after_sales_images'] as String?;
          if (afterSalesImages != null &&
              afterSalesImages.isNotEmpty &&
              afterSalesImages != '[]') {
            try {
              // 检查是否是直接的文件路径格式，如[C:\path\to\file.png]或直接的文件路径
              if (afterSalesImages.startsWith('[') &&
                  afterSalesImages.endsWith(']')) {
                // 去除前后的[]
                String cleanedStr =
                    afterSalesImages.substring(1, afterSalesImages.length - 1);

                // 检查是否包含逗号
                if (cleanedStr.contains(',')) {
                  // 多个文件路径，按逗号分割
                  List<String> imagesPaths = cleanedStr.split(',');
                  // 清理每个图片URL
                  imagesList = imagesPaths.map((img) {
                    // 去除前后的空格
                    String cleanedImg = img.trim();
                    // 去除可能存在的引号
                    if ((cleanedImg.startsWith('"') &&
                            cleanedImg.endsWith('"')) ||
                        (cleanedImg.startsWith("'") &&
                            cleanedImg.endsWith("'"))) {
                      cleanedImg =
                          cleanedImg.substring(1, cleanedImg.length - 1);
                    }
                    return cleanedImg;
                  }).toList();
                } else {
                  // 单个文件路径
                  String cleanedImg = cleanedStr.trim();
                  // 去除可能存在的引号
                  if ((cleanedImg.startsWith('"') &&
                          cleanedImg.endsWith('"')) ||
                      (cleanedImg.startsWith("'") &&
                          cleanedImg.endsWith("'"))) {
                    cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
                  }
                  imagesList = [cleanedImg];
                }
              } else if (afterSalesImages.contains('\\') ||
                  afterSalesImages.startsWith('http')) {
                // 直接的文件路径或URL，没有[]包裹
                imagesList = [afterSalesImages];
              } else {
                // 尝试JSON解析
                imagesList = List<String>.from(json.decode(afterSalesImages));
              }
            } catch (e) {
              // 如果所有解析都失败，检查是否是有效的文件路径
              String cleanedImg = afterSalesImages.trim();
              // 去除可能存在的引号
              if ((cleanedImg.startsWith('"') && cleanedImg.endsWith('"')) ||
                  (cleanedImg.startsWith("'") && cleanedImg.endsWith("'"))) {
                cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
              }
              // 检查是否是有效的文件路径或URL
              if (cleanedImg.contains('\\') || cleanedImg.startsWith('http')) {
                imagesList = [cleanedImg];
              } else {
                // 其他情况，使用空列表
                imagesList = [];
              }
            }
          }
        }

        afterSalesRecords.add({
          'id': '${orderId}_0',
          'after_sales_type': order['after_sales_type'] as String? ?? 'refund',
          'after_sales_reason': order['after_sales_reason'] as String?,
          'after_sales_description':
              order['after_sales_description'] as String?,
          'after_sales_images': imagesList,
          'after_sales_create_time': order['after_sales_create_time'] as int? ??
              DateTime.now().millisecondsSinceEpoch,
          'after_sales_status':
              order['after_sales_status'] as String? ?? 'pending',
          'after_sales_result':
              order['after_sales_status'] == 'completed' ? '已处理' : '待处理',
          'after_sales_handle_time': null,
        });
      }

      // 将售后记录添加到订单中
      final orderWithAfterSales = Map<String, dynamic>.from(order);
      if (afterSalesRecords.isNotEmpty) {
        // 按创建时间降序排序，确保最新的记录在前面
        afterSalesRecords.sort((a, b) => (b['after_sales_create_time'] as int)
            .compareTo(a['after_sales_create_time'] as int));
        // 去重，确保每个记录ID唯一
        final uniqueRecords = <Map<String, dynamic>>[];
        final seenIds = <String>{};
        for (final record in afterSalesRecords) {
          final id = record['id'] as String;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueRecords.add(record);
          }
        }
        orderWithAfterSales['after_sales_records'] = json.encode(uniqueRecords);
      }

      result = orderWithAfterSales;
    }

    // 移除显式关闭连接

    return result;
  }

  /// 根据用户ID获取订单
  Future<List<Map<String, dynamic>>> getOrdersByUserId(String userId) async {
    final db = await database;
    // 使用单例连接，不再需要 PRAGMA 重载
    final orders = await db.query('orders',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');

    // 为每个订单添加售后记录
    final ordersWithAfterSales = <Map<String, dynamic>>[];
    for (final order in orders) {
      final orderId = order['id'] as String;
      // 获取所有相关的售后记录
      final refundRequests = await db.query('refund_requests',
          where: 'order_id = ?',
          whereArgs: [orderId],
          orderBy: 'created_at DESC');

      // 将售后记录转换为列表格式，存储到订单中
      final afterSalesRecords = <Map<String, dynamic>>[];
      for (final refund in refundRequests) {
        afterSalesRecords.add({
          'id': '${orderId}_${refund['id']}',
          'after_sales_type':
              refund['reason']?.contains('维修') == true ? 'repair' : 'refund',
          'after_sales_reason': refund['reason'] as String?,
          'after_sales_description': refund['reason'] as String?,
          'after_sales_images': [],
          'after_sales_create_time': refund['created_at'] as int,
          'after_sales_status': refund['status'] as String,
          'after_sales_result': refund['approved_at'] != null ? '已处理' : '待处理',
          'after_sales_handle_time': refund['approved_at'] as int?,
        });
      }

      // 如果订单表中已有售后信息，也添加到售后记录列表
      if (order['after_sales_type'] != null ||
          order['after_sales_reason'] != null ||
          order['after_sales_description'] != null ||
          order['after_sales_images'] != null ||
          order['after_sales_create_time'] != null ||
          order['after_sales_status'] != null) {
        // 处理售后图片，确保它是有效的JSON格式
        List<String> imagesList = [];
        if (order['after_sales_images'] != null) {
          final afterSalesImages = order['after_sales_images'] as String?;
          if (afterSalesImages != null &&
              afterSalesImages.isNotEmpty &&
              afterSalesImages != '[]') {
            try {
              // 检查是否是直接的文件路径格式，如[C:\path\to\file.png]或直接的文件路径
              if (afterSalesImages.startsWith('[') &&
                  afterSalesImages.endsWith(']')) {
                // 去除前后的[]
                String cleanedStr =
                    afterSalesImages.substring(1, afterSalesImages.length - 1);

                // 检查是否包含逗号
                if (cleanedStr.contains(',')) {
                  // 多个文件路径，按逗号分割
                  List<String> imagesPaths = cleanedStr.split(',');
                  // 清理每个图片URL
                  imagesList = imagesPaths.map((img) {
                    // 去除前后的空格
                    String cleanedImg = img.trim();
                    // 去除可能存在的引号
                    if ((cleanedImg.startsWith('"') &&
                            cleanedImg.endsWith('"')) ||
                        (cleanedImg.startsWith("'") &&
                            cleanedImg.endsWith("'"))) {
                      cleanedImg =
                          cleanedImg.substring(1, cleanedImg.length - 1);
                    }
                    return cleanedImg;
                  }).toList();
                } else {
                  // 单个文件路径
                  String cleanedImg = cleanedStr.trim();
                  // 去除可能存在的引号
                  if ((cleanedImg.startsWith('"') &&
                          cleanedImg.endsWith('"')) ||
                      (cleanedImg.startsWith("'") &&
                          cleanedImg.endsWith("'"))) {
                    cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
                  }
                  imagesList = [cleanedImg];
                }
              } else if (afterSalesImages.contains('\\') ||
                  afterSalesImages.startsWith('http')) {
                // 直接的文件路径或URL，没有[]包裹
                imagesList = [afterSalesImages];
              } else {
                // 尝试JSON解析
                imagesList = List<String>.from(json.decode(afterSalesImages));
              }
            } catch (e) {
              // 如果所有解析都失败，检查是否是有效的文件路径
              String cleanedImg = afterSalesImages.trim();
              // 去除可能存在的引号
              if ((cleanedImg.startsWith('"') && cleanedImg.endsWith('"')) ||
                  (cleanedImg.startsWith("'") && cleanedImg.endsWith("'"))) {
                cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
              }
              // 检查是否是有效的文件路径或URL
              if (cleanedImg.contains('\\') || cleanedImg.startsWith('http')) {
                imagesList = [cleanedImg];
              } else {
                // 其他情况，使用空列表
                imagesList = [];
              }
            }
          }
        }

        afterSalesRecords.add({
          'id': '${orderId}_0',
          'after_sales_type': order['after_sales_type'] as String? ?? 'refund',
          'after_sales_reason': order['after_sales_reason'] as String?,
          'after_sales_description':
              order['after_sales_description'] as String?,
          'after_sales_images': imagesList,
          'after_sales_create_time': order['after_sales_create_time'] as int? ??
              DateTime.now().millisecondsSinceEpoch,
          'after_sales_status':
              order['after_sales_status'] as String? ?? 'pending',
          'after_sales_result':
              order['after_sales_status'] == 'completed' ? '已处理' : '待处理',
          'after_sales_handle_time': null,
        });
      }

      // 将售后记录添加到订单中
      final orderWithAfterSales = Map<String, dynamic>.from(order);
      if (afterSalesRecords.isNotEmpty) {
        // 按创建时间降序排序，确保最新的记录在前面
        afterSalesRecords.sort((a, b) => (b['after_sales_create_time'] as int)
            .compareTo(a['after_sales_create_time'] as int));
        // 去重，确保每个记录ID唯一
        final uniqueRecords = <Map<String, dynamic>>[];
        final seenIds = <String>{};
        for (final record in afterSalesRecords) {
          final id = record['id'] as String;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueRecords.add(record);
          }
        }
        orderWithAfterSales['after_sales_records'] = json.encode(uniqueRecords);
      }

      ordersWithAfterSales.add(orderWithAfterSales);
    }

    return ordersWithAfterSales;
  }

  Future<List<Map<String, dynamic>>> getOrdersByProductIdAndUserId(
      int productId, String userId) async {
    final db = await database;
    return await db.query('orders',
        where: 'product_id = ? AND user_id = ?',
        whereArgs: [productId, userId],
        orderBy: 'created_at DESC');
  }

  /// 根据订单ID获取退款请求
  Future<List<Map<String, dynamic>>> getRefundRequestsByOrderId(
      String orderId) async {
    final db = await database;
    return await db.query('refund_requests',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at DESC');
  }

  /// 插入订单
  Future<int> insertOrder(Map<String, dynamic> orderData) async {
    final db = await database;
    return await db.insert('orders', orderData);
  }

  /// 更新订单状态
  Future<int> updateOrderStatus(String orderId, String status) async {
    final updateData = {'status': status};
    return await updateOrder(orderId, updateData);
  }

  /// 更新订单
  Future<int> updateOrder(
      String orderId, Map<String, dynamic> orderData) async {
    // 打印数据库路径，确认数据写入位置
    final directory = await _getDefaultDirectory();
    final dbPath = path_package.join(directory!.path, _databaseName);
    _log('开始更新订单，数据库路径: $dbPath');

    // 创建一个新的数据库连接，确保不使用缓存连接
    final db = await database;

    // 过滤掉不存在的列，只保留订单表中实际存在的列
    final validColumns = <String>{
      'id',
      'user_id',
      'product_id',
      'product_name',
      'product_image',
      'points',
      'status',
      'is_electronic',
      'created_at',
      'quantity',
      'updated_at',
      'product_price',
      'total_amount',
      'points_used',
      'cash_amount',
      'payment_method',
      'variant',
      'delivery_address',
      'buyer_note',
      'buyer_name',
      'buyer_phone',
      'after_sales_type',
      'after_sales_reason',
      'after_sales_description',
      'after_sales_images',
      'after_sales_create_time',
      'after_sales_status',
      'logistics_info',
      'logistics_company_id',
      'fund_status',
      'merchant_id'
    };

    // 只保留validColumns中的字段，并添加updated_at字段
    final filteredOrderData = Map<String, dynamic>.fromEntries(
        orderData.entries.where((entry) => validColumns.contains(entry.key)));

    // 显式更新updated_at字段，确保订单被标记为已更新
    filteredOrderData['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    _log('更新订单 $orderId，更新数据: $filteredOrderData');

    // 执行更新操作
    int result = await db.update(
      'orders',
      filteredOrderData,
      where: 'id = ?',
      whereArgs: [orderId],
    );

    _log('更新订单结果: $result，订单ID: $orderId');

    // 验证更新是否成功，手动查询订单状态
    final updatedOrder = await db.query('orders',
        where: 'id = ?', whereArgs: [orderId], limit: 1);

    if (updatedOrder.isNotEmpty) {
      _log(
          '验证更新结果: 订单 ${updatedOrder[0]['id']} 的状态为 ${updatedOrder[0]['status']}');
    }

    return result;
  }

  /// 删除订单
  Future<int> deleteOrder(String orderId) async {
    final db = await database;
    return await db.delete(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// 添加操作记录
  Future<int> addOperationLog(String orderId, String operator, String action,
      String? description) async {
    final db = await database;
    return await db.insert('operation_logs', {
      'order_id': orderId,
      'operator': operator,
      'action': action,
      'description': description,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 根据订单ID获取操作记录
  Future<List<Map<String, dynamic>>> getOperationLogsByOrderId(
      String orderId) async {
    final db = await database;
    return await db.query(
      'operation_logs',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at ASC',
    );
  }

  /// 同意维修申请
  Future<int> approveRepair(
      String orderId, String operator, String description) async {
    final db = await database;

    // 开启事务
    return await db.transaction((txn) async {
      // 更新订单状态为维修中
      final updatedCount = await txn.update(
        'orders',
        {
          'after_sales_status': 'approved',
          'status': '维修中',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 添加操作记录
      await txn.insert('operation_logs', {
        'order_id': orderId,
        'operator': operator,
        'action': '同意维修',
        'description': description,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      return updatedCount;
    });
  }

  /// 维修完成
  Future<int> completeRepair(
      String orderId, String operator, String description) async {
    final db = await database;

    // 开启事务
    return await db.transaction((txn) async {
      // 更新订单状态为已完成
      final updatedCount = await txn.update(
        'orders',
        {
          'after_sales_status': 'completed',
          'status': '已完成',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 添加操作记录
      await txn.insert('operation_logs', {
        'order_id': orderId,
        'operator': operator,
        'action': '维修完成',
        'description': description,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      return updatedCount;
    });
  }

  /// 同意退款申请 - 先退还积分，再更新订单状态，确保用户一定能收到退款
  Future<int> approveRefund(String orderId, String operator, String description) async {
    final db = await database;

    final orderResult = await db.query(
      'orders',
      columns: [
        'user_id',
        'payment_method',
        'points_used',
        'cash_amount',
        'total_amount',
        'product_name',
        'fund_status',
        'merchant_id'
      ],
      where: 'id = ?',
      whereArgs: [orderId],
    );

    if (orderResult.isEmpty) {
      throw Exception('订单不存在');
    }

    final orderData = orderResult.first;
    final userId = orderData['user_id'] as String? ?? '';
    final paymentMethod = orderData['payment_method'] as String? ?? '';
    final pointsUsed = orderData['points_used'] as int? ?? 0;
    final cashAmount = orderData['cash_amount'] as double? ?? 0.0;
    final productName = orderData['product_name'] as String? ?? '';
    final fundStatus = orderData['fund_status'] as String? ?? 'escrow';
    final merchantId = orderData['merchant_id'] as int?;

    if (fundStatus == 'refunded') {
      return 0;
    }

    // 第一步：如果资金已释放给商家，先从商家扣回
    if (fundStatus == 'released' && merchantId != null) {
      final merchant = await getMerchantById(merchantId);
      if (merchant != null && pointsUsed > 0) {
        final refundPointsUsed = (orderData['points_used'] as num?)?.toDouble() ?? 0;
        final refundCashAmount = (orderData['cash_amount'] as num?)?.toDouble() ?? 0;
        final refundAmount = refundPointsUsed + refundCashAmount;
        await DatabaseService().updateUserPoints(
          merchant.userId,
          -refundAmount,
          description: '退款扣回 - $productName',
          transactionType: 'merchant_refund',
          relatedId: orderId,
        );
        // 为商家创建退款扣减的支付记录，确保商家交易记录中显示积分退还项
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final refundPaymentRecord = PaymentRecord(
          orderId: '${orderId}_refund',
          userId: merchant.userId,
          merchantId: merchantId,
          paymentNo: 'REFUND${nowMs}',
          amount: -refundAmount.round(),
          pointsUsed: -refundPointsUsed.round(),
          cashAmount: -refundCashAmount.round(),
          paymentMethod: paymentMethod.isNotEmpty ? paymentMethod : 'hybrid',
          status: 'refunded',
          refundedAt: DateTime.now(),
          fundStatus: 'refunded',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await insertPaymentRecord(refundPaymentRecord);
      }
    }

    // 第二步：退还积分给用户（必须在更新订单状态之前，确保用户一定能收到退款）
    if (pointsUsed > 0 && userId.isNotEmpty) {
      await DatabaseService().updateUserPoints(
        userId,
        pointsUsed.toDouble(),
        description: '退款 - $productName',
        transactionType: 'refund',
        relatedId: orderId,
      );
    }

    // 现金退款处理 - 这里可以添加现金退款的逻辑，比如调用支付平台API
    // if (cashAmount > 0) {
    //   // 调用支付平台API退款
    //   // await paymentService.refund(orderId, cashAmount);
    // }

    // 第三步：所有退款操作成功后，再更新订单状态为已退款
    final updatedCount = await db.update(
      'orders',
      {
        'after_sales_status': 'approved',
        'status': '已退款',
        'fund_status': 'refunded',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );

    await updatePaymentRecordFundStatus(orderId, 'refunded');

    // 第四步：添加操作记录
    await db.insert('operation_logs', {
      'order_id': orderId,
      'operator': operator,
      'action': '同意退款',
      'description': description,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    return updatedCount;
  }

  /// 拒绝维修申请
  Future<int> rejectRepair(
      String orderId, String operator, String description) async {
    final db = await database;

    // 开启事务
    return await db.transaction((txn) async {
      // 更新订单状态为已拒绝
      final updatedCount = await txn.update(
        'orders',
        {
          'after_sales_status': 'rejected',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 添加操作记录
      await txn.insert('operation_logs', {
        'order_id': orderId,
        'operator': operator,
        'action': '拒绝维修',
        'description': description,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      return updatedCount;
    });
  }

  /// 拒绝退款申请
  Future<int> rejectRefund(
      String orderId, String operator, String description) async {
    final db = await database;

    // 开启事务
    return await db.transaction((txn) async {
      // 更新订单状态为已拒绝
      final updatedCount = await txn.update(
        'orders',
        {
          'after_sales_status': 'rejected',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 添加操作记录
      await txn.insert('operation_logs', {
        'order_id': orderId,
        'operator': operator,
        'action': '拒绝退款',
        'description': description,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      return updatedCount;
    });
  }

  /// 彻底删除星星商店商品（从数据库中删除），包括SKU和规格
  /// 注意：相关的SKU和规格会通过外键约束自动删除
  Future<int> permanentlyDeleteProduct(int productId) async {
    final db = await database;

    // 开启事务
    return await db.transaction((txn) async {
      // 删除商品SKU
      await txn.delete('star_product_skus',
          where: 'product_id = ?', whereArgs: [productId]);

      // 删除商品规格
      await txn.delete('star_product_specs',
          where: 'product_id = ?', whereArgs: [productId]);

      // 彻底删除商品
      return await txn
          .delete('star_products', where: 'id = ?', whereArgs: [productId]);
    });
  }

  /// 添加清理日志
  Future<int> insertCleanupLog(Map<String, dynamic> logData) async {
    final db = await database;
    return await db.insert('cleanup_logs', logData);
  }

  /// 获取清理日志列表
  Future<List<Map<String, dynamic>>> getCleanupLogs(
      {int limit = 100, int offset = 0}) async {
    final db = await database;
    return await db.query(
      'cleanup_logs',
      orderBy: 'cleanup_time DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 添加评论
  Future<int> addReview(Map<String, dynamic> reviewData) async {
    final db = await database;
    final String reviewId =
        reviewData['id'] ?? 'review_${DateTime.now().millisecondsSinceEpoch}';

    return await db.insert(
      'reviews',
      {
        'id': reviewId,
        'order_id': reviewData['order_id'],
        'product_id': reviewData['product_id'],
        'product_name': reviewData['product_name'],
        'product_image': reviewData['product_image'],
        'variant': reviewData['variant'] ?? '',
        'rating': reviewData['rating'],
        'content': reviewData['content'],
        'images': reviewData['images'],
        'created_at':
            reviewData['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        'appended_at': reviewData['appended_at'],
        'appended_content': reviewData['appended_content'],
        'appended_images': reviewData['appended_images'],
        'seller_reply': reviewData['seller_reply'],
        'seller_reply_at': reviewData['seller_reply_at'],
        'status': reviewData['status'] ?? 'completed',
        'is_anonymous': reviewData['is_anonymous'] ?? 1, // 添加匿名状态字段
        'user_id': reviewData['user_id'], // 添加用户ID字段
        'user_name': reviewData['user_name'], // 添加用户名字段
        'user_avatar': reviewData['user_avatar'], // 添加用户头像字段
      },
      conflictAlgorithm: sqflite_package.ConflictAlgorithm.replace,
    );
  }

  /// 获取订单的评论
  Future<List<Map<String, dynamic>>> getReviewsByOrderId(String orderId) async {
    final db = await database;
    return await db.query(
      'reviews',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  /// 获取商品的评论
  Future<List<Map<String, dynamic>>> getReviewsByProductId(
      int productId) async {
    final db = await database;
    return await db.query(
      'reviews',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  /// 更新评论
  Future<int> updateReview(
      String reviewId, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'reviews',
      updates,
      where: 'id = ?',
      whereArgs: [reviewId],
    );
  }

  /// 删除评论
  Future<int> deleteReview(String reviewId) async {
    final db = await database;
    return await db.delete(
      'reviews',
      where: 'id = ?',
      whereArgs: [reviewId],
    );
  }

  /// 获取所有评论
  Future<List<Map<String, dynamic>>> getAllReviews() async {
    final db = await database;
    return await db.query(
      'reviews',
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateReviewStatus(String reviewId, String status) async {
    final db = await database;
    return await db.update(
      'reviews',
      {'status': status},
      where: 'id = ?',
      whereArgs: [reviewId],
    );
  }

  Future<int> updateReviewReply(String reviewId, String reply) async {
    final db = await database;
    return await db.update(
      'reviews',
      {
        'seller_reply': reply,
        'seller_reply_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [reviewId],
    );
  }

  // ==========================================
  // 优惠券相关操作
  // ==========================================

  /// 添加优惠券
  Future<int> insertCoupon(Coupon coupon) async {
    final db = await database;
    return await db.insert('coupons', coupon.toMap()..remove('id'));
  }

  /// 获取所有优惠券
  Future<List<Coupon>> getAllCoupons({bool? isActive}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'coupons',
      where: isActive != null ? 'is_active = ?' : null,
      whereArgs: isActive != null ? [isActive ? 1 : 0] : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Coupon.fromMap(map)).toList();
  }

  /// 根据ID获取优惠券
  Future<Coupon?> getCouponById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'coupons',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Coupon.fromMap(maps.first);
  }

  /// 根据编码获取优惠券
  Future<Coupon?> getCouponByCode(String code) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'coupons',
      where: 'code = ?',
      whereArgs: [code],
    );
    if (maps.isEmpty) return null;
    return Coupon.fromMap(maps.first);
  }

  /// 更新优惠券
  Future<int> updateCoupon(int id, Coupon coupon) async {
    final db = await database;
    return await db.update(
      'coupons',
      coupon.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除优惠券
  Future<int> deleteCoupon(int id) async {
    final db = await database;
    return await db.delete(
      'coupons',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新优惠券已使用数量
  Future<int> incrementCouponUsedCount(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE coupons SET used_count = used_count + 1, updated_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  // ==========================================
  // 用户优惠券相关操作
  // ==========================================

  /// 领取优惠券
  Future<int> insertUserCoupon(UserCoupon userCoupon) async {
    final db = await database;
    return await db.insert('user_coupons', userCoupon.toMap()..remove('id'));
  }

  /// 获取用户的所有优惠券
  Future<List<Map<String, dynamic>>> getUserCoupons(String userId, {String? status}) async {
    final db = await database;
    return await db.query(
      'user_coupons',
      where: status != null ? 'user_id = ? AND status = ?' : 'user_id = ?',
      whereArgs: status != null ? [userId, status] : [userId],
      orderBy: 'created_at DESC',
    );
  }

  /// 获取用户可用的优惠券（未使用且未过期）
  Future<List<Map<String, dynamic>>> getUserAvailableCoupons(String userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.query(
      'user_coupons',
      where: 'user_id = ? AND status = ? AND (expires_at IS NULL OR expires_at > ?)',
      whereArgs: [userId, 'unused', now],
      orderBy: 'created_at DESC',
    );
  }

  /// 使用优惠券
  Future<int> useUserCoupon(int id, String orderId) async {
    final db = await database;
    return await db.update(
      'user_coupons',
      {
        'status': 'used',
        'order_id': orderId,
        'used_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除用户优惠券
  Future<int> deleteUserCoupon(int id) async {
    final db = await database;
    return await db.delete(
      'user_coupons',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有用户优惠券（管理端）
  Future<List<UserCoupon>> getAllUserCoupons({String? status}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_coupons',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => UserCoupon.fromMap(map)).toList();
  }

  // ==========================================
  // 红包相关操作
  // ==========================================

  /// 添加红包
  Future<int> insertRedPacket(RedPacket redPacket) async {
    final db = await database;
    return await db.insert('red_packets', redPacket.toMap()..remove('id'));
  }

  /// 获取所有红包
  Future<List<RedPacket>> getAllRedPackets({bool? isActive}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'red_packets',
      where: isActive != null ? 'is_active = ?' : null,
      whereArgs: isActive != null ? [isActive ? 1 : 0] : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => RedPacket.fromMap(map)).toList();
  }

  /// 根据ID获取红包
  Future<RedPacket?> getRedPacketById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'red_packets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return RedPacket.fromMap(maps.first);
  }

  /// 更新红包
  Future<int> updateRedPacket(int id, RedPacket redPacket) async {
    final db = await database;
    return await db.update(
      'red_packets',
      redPacket.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除红包
  Future<int> deleteRedPacket(int id) async {
    final db = await database;
    return await db.delete(
      'red_packets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新红包领取数量
  Future<int> incrementRedPacketReceivedCount(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE red_packets SET received_count = received_count + 1, updated_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  /// 领取红包记录
  Future<int> insertRedPacketClaim(RedPacketClaim claim) async {
    final db = await database;
    return await db.insert('red_packet_claims', claim.toMap()..remove('id'));
  }

  /// 获取红包的领取记录
  Future<List<RedPacketClaim>> getRedPacketClaims(int redPacketId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'red_packet_claims',
      where: 'red_packet_id = ?',
      whereArgs: [redPacketId],
      orderBy: 'claimed_at DESC',
    );
    return maps.map((map) => RedPacketClaim.fromMap(map)).toList();
  }

  /// 获取用户领取的红包
  Future<List<RedPacketClaim>> getUserRedPacketClaims(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'red_packet_claims',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'claimed_at DESC',
    );
    return maps.map((map) => RedPacketClaim.fromMap(map)).toList();
  }

  Future<List<RedPacketClaim>> getAllRedPacketClaims() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'red_packet_claims',
      orderBy: 'claimed_at DESC',
    );
    return maps.map((map) => RedPacketClaim.fromMap(map)).toList();
  }

  // ==========================================
  // 购物卡相关操作
  // ==========================================

  /// 添加购物卡
  Future<int> insertShoppingCard(ShoppingCard card) async {
    final db = await database;
    return await db.insert('shopping_cards', card.toMap()..remove('id'));
  }

  /// 获取所有购物卡
  Future<List<ShoppingCard>> getAllShoppingCards({String? status, String? userId}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (status != null && userId != null) {
      where = 'status = ? AND user_id = ?';
      whereArgs = [status, userId];
    } else if (status != null) {
      where = 'status = ?';
      whereArgs = [status];
    } else if (userId != null) {
      where = 'user_id = ?';
      whereArgs = [userId];
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_cards',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ShoppingCard.fromMap(map)).toList();
  }

  /// 根据卡号获取购物卡
  Future<ShoppingCard?> getShoppingCardByNo(String cardNo) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_cards',
      where: 'card_no = ?',
      whereArgs: [cardNo],
    );
    if (maps.isEmpty) return null;
    return ShoppingCard.fromMap(maps.first);
  }

  /// 根据ID获取购物卡
  Future<ShoppingCard?> getShoppingCardById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_cards',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ShoppingCard.fromMap(maps.first);
  }

  /// 激活购物卡
  Future<int> activateShoppingCard(int id, String userId) async {
    final db = await database;
    return await db.update(
      'shopping_cards',
      {
        'status': 'active',
        'user_id': userId,
        'activated_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新购物卡余额
  Future<int> updateShoppingCardBalance(int id, int newBalance) async {
    final db = await database;
    return await db.update(
      'shopping_cards',
      {
        'balance': newBalance,
        'status': newBalance <= 0 ? 'used' : 'active',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除购物卡
  Future<int> deleteShoppingCard(int id) async {
    final db = await database;
    return await db.delete(
      'shopping_cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 添加购物卡交易记录
  Future<int> insertShoppingCardTransaction(ShoppingCardTransaction transaction) async {
    final db = await database;
    return await db.insert('shopping_card_transactions', transaction.toMap()..remove('id'));
  }

  /// 获取购物卡的交易记录
  Future<List<ShoppingCardTransaction>> getShoppingCardTransactions(int cardId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shopping_card_transactions',
      where: 'shopping_card_id = ?',
      whereArgs: [cardId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ShoppingCardTransaction.fromMap(map)).toList();
  }

  // ==========================================
  // 地址相关操作
  // ==========================================

  /// 添加地址
  Future<int> insertAddress(Address address) async {
    final db = await database;
    if (address.isDefault) {
      await db.update(
        'addresses',
        {'is_default': 0},
        where: 'user_id = ? AND is_default = 1',
        whereArgs: [address.userId],
      );
    }
    return await db.insert('addresses', address.toMap()..remove('id'));
  }

  /// 获取用户的所有地址
  Future<List<Address>> getUserAddresses(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'addresses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'is_default DESC, created_at DESC',
    );
    return maps.map((map) => Address.fromMap(map)).toList();
  }

  /// 获取用户默认地址
  Future<Address?> getUserDefaultAddress(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'addresses',
      where: 'user_id = ? AND is_default = 1',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return null;
    return Address.fromMap(maps.first);
  }

  /// 根据ID获取地址
  Future<Address?> getAddressById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'addresses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Address.fromMap(maps.first);
  }

  /// 更新地址
  Future<int> updateAddress(int id, Address address) async {
    final db = await database;
    if (address.isDefault) {
      await db.update(
        'addresses',
        {'is_default': 0},
        where: 'user_id = ? AND is_default = 1 AND id != ?',
        whereArgs: [address.userId, id],
      );
    }
    return await db.update(
      'addresses',
      address.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 设为默认地址
  Future<int> setDefaultAddress(int id, String userId) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.update(
        'addresses',
        {'is_default': 0},
        where: 'user_id = ? AND is_default = 1',
        whereArgs: [userId],
      );
      return await txn.update(
        'addresses',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// 删除地址
  Future<int> deleteAddress(int id) async {
    final db = await database;
    return await db.delete(
      'addresses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // 会员等级相关操作
  // ==========================================

  /// 添加会员等级
  Future<int> insertMemberLevel(MemberLevel level) async {
    final db = await database;
    return await db.insert('member_levels', level.toMap()..remove('id'));
  }

  /// 获取所有会员等级
  Future<List<MemberLevel>> getAllMemberLevels() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'member_levels',
      orderBy: 'sort_order ASC, min_points ASC',
    );
    return maps.map((map) => MemberLevel.fromMap(map)).toList();
  }

  /// 根据ID获取会员等级
  Future<MemberLevel?> getMemberLevelById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'member_levels',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return MemberLevel.fromMap(maps.first);
  }

  /// 根据积分获取会员等级
  Future<MemberLevel?> getMemberLevelByPoints(int points) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'member_levels',
      where: 'min_points <= ?',
      whereArgs: [points],
      orderBy: 'min_points DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MemberLevel.fromMap(maps.first);
  }

  /// 更新会员等级
  Future<int> updateMemberLevel(int id, MemberLevel level) async {
    final db = await database;
    return await db.update(
      'member_levels',
      level.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除会员等级
  Future<int> deleteMemberLevel(int id) async {
    final db = await database;
    return await db.delete(
      'member_levels',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除个人数据表（user_coupons, red_packet_claims, addresses, member_levels）
  /// 在数据迁移到 moment_keep.db 后调用
  Future<void> dropPersonalTables() async {
    try {
      final db = await database;
      final personalTables = ['user_coupons', 'red_packet_claims', 'addresses', 'member_levels'];
      for (final tableName in personalTables) {
        try {
          final tableExists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
          if (tableExists.isNotEmpty) {
            await db.execute('DROP TABLE IF EXISTS $tableName');
            _log('Dropped $tableName table from products.db');
          }
        } catch (e) {
          _log('Error dropping $tableName table from products.db: $e');
        }
      }
    } catch (e) {
      _log('Error during dropPersonalTables: $e');
    }
  }

  // ==========================================
  // 物流公司相关操作
  // ==========================================

  /// 添加物流公司
  Future<int> insertLogisticsCompany(LogisticsCompany company) async {
    final db = await database;
    return await db.insert('logistics_companies', company.toMap()..remove('id'));
  }

  /// 获取所有物流公司
  Future<List<LogisticsCompany>> getAllLogisticsCompanies({bool? isActive}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logistics_companies',
      where: isActive != null ? 'is_active = ?' : null,
      whereArgs: isActive != null ? [isActive ? 1 : 0] : null,
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map((map) => LogisticsCompany.fromMap(map)).toList();
  }

  /// 根据ID获取物流公司
  Future<LogisticsCompany?> getLogisticsCompanyById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logistics_companies',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return LogisticsCompany.fromMap(maps.first);
  }

  /// 根据编码获取物流公司
  Future<LogisticsCompany?> getLogisticsCompanyByCode(String code) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logistics_companies',
      where: 'code = ?',
      whereArgs: [code],
    );
    if (maps.isEmpty) return null;
    return LogisticsCompany.fromMap(maps.first);
  }

  /// 更新物流公司
  Future<int> updateLogisticsCompany(int id, LogisticsCompany company) async {
    final db = await database;
    return await db.update(
      'logistics_companies',
      company.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除物流公司
  Future<int> deleteLogisticsCompany(int id) async {
    final db = await database;
    return await db.delete(
      'logistics_companies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // 物流跟踪相关操作
  // ==========================================

  /// 添加物流跟踪记录
  Future<int> insertLogisticsTrack(LogisticsTrack track) async {
    final db = await database;
    return await db.insert('logistics_tracks', track.toMap()..remove('id'));
  }

  /// 获取订单的物流跟踪记录
  Future<List<LogisticsTrack>> getLogisticsTracksByOrderId(String orderId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logistics_tracks',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'track_time DESC',
    );
    return maps.map((map) => LogisticsTrack.fromMap(map)).toList();
  }

  /// 根据快递单号获取物流跟踪记录
  Future<List<LogisticsTrack>> getLogisticsTracksByTrackingNumber(String trackingNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logistics_tracks',
      where: 'tracking_number = ?',
      whereArgs: [trackingNumber],
      orderBy: 'track_time DESC',
    );
    return maps.map((map) => LogisticsTrack.fromMap(map)).toList();
  }

  /// 更新物流跟踪状态
  Future<int> updateLogisticsTrackStatus(int id, String status, String description, {String? location}) async {
    final db = await database;
    return await db.update(
      'logistics_tracks',
      {
        'status': status,
        'description': description,
        'location': location,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除物流跟踪记录
  Future<int> deleteLogisticsTrack(int id) async {
    final db = await database;
    return await db.delete(
      'logistics_tracks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取最近的物流跟踪记录（按运单号分组，每个运单号取最新一条）
  Future<List<LogisticsTrack>> getRecentLogisticsTracks({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logistics_tracks',
      orderBy: 'track_time DESC',
      limit: limit,
    );
    return maps.map((map) => LogisticsTrack.fromMap(map)).toList();
  }

  // ==========================================
  // 退货物流相关操作
  // ==========================================

  /// 插入退货物流记录
  Future<int> insertReturnLogistics(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('return_logistics', data);
  }

  /// 根据订单ID获取退货物流记录
  Future<List<Map<String, dynamic>>> getReturnLogisticsByOrderId(String orderId) async {
    final db = await database;
    return await db.query(
      'return_logistics',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at DESC',
    );
  }

  /// 更新退货物流状态
  Future<int> updateReturnLogisticsStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'return_logistics',
      {'status': status, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // 支付记录相关操作
  // ==========================================

  /// 添加支付记录
  Future<int> insertPaymentRecord(PaymentRecord record) async {
    final db = await database;
    final map = record.toMap()..remove('id');
    if (record.merchantId == null) {
      final orderMaps = await db.query(
        'orders',
        columns: ['merchant_id'],
        where: 'id = ?',
        whereArgs: [record.orderId],
      );
      if (orderMaps.isNotEmpty && orderMaps.first['merchant_id'] != null) {
        map['merchant_id'] = orderMaps.first['merchant_id'];
      }
    }
    if (record.fundStatus != null && !map.containsKey('fund_status')) {
      map['fund_status'] = record.fundStatus;
    }

    _log('insertPaymentRecord: orderId=${record.orderId}, '
        'paymentNo=${record.paymentNo}, amount=${record.amount}, '
        'method=${record.paymentMethod}, merchantId=${map['merchant_id']}, '
        'fundStatus=${map['fund_status']}');

    try {
      final result = await db.insert('payment_records', map);
      _log('insertPaymentRecord succeeded, rowId=$result');
      return result;
    } catch (e) {
      _log('insertPaymentRecord FAILED: $e');
      _log('Attempting table recovery...');

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS payment_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id TEXT NOT NULL,
            merchant_id INTEGER,
            user_id TEXT NOT NULL,
            payment_no TEXT NOT NULL,
            amount INTEGER NOT NULL,
            points_used INTEGER NOT NULL DEFAULT 0,
            cash_amount INTEGER NOT NULL DEFAULT 0,
            payment_method TEXT NOT NULL,
            third_party_payment_id TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            paid_at INTEGER,
            refunded_at INTEGER,
            failure_reason TEXT,
            fund_status TEXT DEFAULT 'escrow',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL
          );
        ''');
        _log('Recreated payment_records table');

        final retryResult = await db.insert('payment_records', map);
        _log('insertPaymentRecord retry succeeded, rowId=$retryResult');
        return retryResult;
      } catch (retryError) {
        _log('insertPaymentRecord retry also FAILED: $retryError');
        rethrow;
      }
    }
  }

  /// 更新支付记录的资金状态，同时同步 status 和退款时间
  Future<void> updatePaymentRecordFundStatus(String orderId, String fundStatus) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final updateData = <String, dynamic>{
        'fund_status': fundStatus,
        'updated_at': now,
      };
      // 当资金状态变为 refunded 时，同步更新 status 和 refunded_at
      if (fundStatus == 'refunded') {
        updateData['status'] = 'refunded';
        updateData['refunded_at'] = now;
      }
      await db.update(
        'payment_records',
        updateData,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      _log('Updated payment_records fund_status=$fundStatus, status=${updateData['status'] ?? '(unchanged)'} for order $orderId');
    } catch (e) {
      _log('Error updating payment_records fund_status: $e');
    }
  }

  /// 获取订单的支付记录
  Future<PaymentRecord?> getPaymentRecordByOrderId(String orderId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_records',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    if (maps.isEmpty) return null;
    return PaymentRecord.fromMap(maps.first);
  }

  /// 根据支付流水号获取支付记录
  Future<PaymentRecord?> getPaymentRecordByPaymentNo(String paymentNo) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_records',
      where: 'payment_no = ?',
      whereArgs: [paymentNo],
    );
    if (maps.isEmpty) return null;
    return PaymentRecord.fromMap(maps.first);
  }

  /// 获取所有支付记录
  Future<List<PaymentRecord>> getAllPaymentRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_records',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => PaymentRecord.fromMap(map)).toList();
  }

  /// 获取用户的所有支付记录
  Future<List<PaymentRecord>> getUserPaymentRecords(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => PaymentRecord.fromMap(map)).toList();
  }

  /// 更新支付记录状态
  Future<int> updatePaymentRecordStatus(int id, String status, {String? thirdPartyPaymentId, String? failureReason}) async {
    final db = await database;
    return await db.update(
      'payment_records',
      {
        'status': status,
        'third_party_payment_id': thirdPartyPaymentId,
        'failure_reason': failureReason,
        'paid_at': status == 'success' ? DateTime.now().millisecondsSinceEpoch : null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除支付记录
  Future<int> deletePaymentRecord(int id) async {
    final db = await database;
    return await db.delete(
      'payment_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getOrdersByDateRange(
      DateTime startDate, DateTime endDate, {int? merchantId}) async {
    final db = await database;
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;
    if (merchantId != null) {
      return await db.query('orders',
          where: 'created_at >= ? AND created_at <= ? AND merchant_id = ?',
          whereArgs: [startMs, endMs, merchantId],
          orderBy: 'created_at DESC');
    }
    return await db.query('orders',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [startMs, endMs],
        orderBy: 'created_at DESC');
  }

  Future<List<PaymentRecord>> getPaymentRecordsByDateRange(
      DateTime startDate, DateTime endDate, {int? merchantId}) async {
    final db = await database;
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;
    List<Map<String, dynamic>> maps;
    if (merchantId != null) {
      maps = await db.query(
        'payment_records',
        where: 'created_at >= ? AND created_at <= ? AND merchant_id = ?',
        whereArgs: [startMs, endMs, merchantId],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        'payment_records',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [startMs, endMs],
        orderBy: 'created_at DESC',
      );
    }
    return maps.map((map) => PaymentRecord.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getProductSalesRanking(
      {int limit = 10, int? merchantId}) async {
    final db = await database;
    List<Map<String, dynamic>> results;
    if (merchantId != null) {
      results = await db.rawQuery('''
        SELECT 
          o.product_id,
          o.product_name,
          SUM(o.quantity) as total_sales,
          SUM(o.total_amount) as total_revenue
        FROM orders o
        WHERE o.status NOT IN ('refunded', 'cancelled') AND o.merchant_id = ?
        GROUP BY o.product_id, o.product_name
        ORDER BY total_revenue DESC
        LIMIT ?
      ''', [merchantId, limit]);
    } else {
      results = await db.rawQuery('''
        SELECT 
          o.product_id,
          o.product_name,
          SUM(o.quantity) as total_sales,
          SUM(o.total_amount) as total_revenue
        FROM orders o
        WHERE o.status NOT IN ('refunded', 'cancelled')
        GROUP BY o.product_id, o.product_name
        ORDER BY total_revenue DESC
        LIMIT ?
      ''', [limit]);
    }
    return results;
  }

  // ==========================================
  // 库存记录相关操作
  // ==========================================

  /// 添加库存变动记录
  Future<int> insertStockRecord(StockRecord record) async {
    final db = await database;
    return await db.insert('stock_records', record.toMap()..remove('id'));
  }

  /// 获取商品的库存变动记录
  Future<List<StockRecord>> getStockRecordsByProductId(int productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_records',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => StockRecord.fromMap(map)).toList();
  }

  /// 获取所有库存变动记录
  Future<List<StockRecord>> getAllStockRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_records',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => StockRecord.fromMap(map)).toList();
  }

  /// 获取SKU的库存变动记录
  Future<List<StockRecord>> getStockRecordsBySkuId(int skuId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_records',
      where: 'sku_id = ?',
      whereArgs: [skuId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => StockRecord.fromMap(map)).toList();
  }

  /// 删除库存记录
  Future<int> deleteStockRecord(int id) async {
    final db = await database;
    return await db.delete(
      'stock_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // 商家相关操作
  // ==========================================

  /// 添加商家
  Future<int> insertMerchant(Merchant merchant) async {
    final db = await database;
    return await db.insert('merchants', merchant.toMap()..remove('id'));
  }

  /// 获取所有商家
  Future<List<Merchant>> getAllMerchants({String? status}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'merchants',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Merchant.fromMap(map)).toList();
  }

  /// 根据用户ID获取商家
  Future<Merchant?> getMerchantByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'merchants',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return null;
    return Merchant.fromMap(maps.first);
  }

  /// 根据ID获取商家
  Future<Merchant?> getMerchantById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'merchants',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Merchant.fromMap(maps.first);
  }

  /// 更新商家信息
  Future<int> updateMerchant(int id, Merchant merchant) async {
    final db = await database;
    return await db.update(
      'merchants',
      merchant.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新商家状态
  Future<int> updateMerchantStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'merchants',
      {
        'status': status,
        'approved_at': status == 'active' ? DateTime.now().millisecondsSinceEpoch : null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新商家评分和销量
  Future<int> updateMerchantStats(int id, double rating, int totalSales) async {
    final db = await database;
    return await db.update(
      'merchants',
      {
        'rating': rating,
        'total_sales': totalSales,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除商家
  Future<int> deleteMerchant(int id) async {
    final db = await database;
    return await db.delete(
      'merchants',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<StarProduct>> getFavoriteProducts(String userId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT sp.* FROM star_products sp
      INNER JOIN favorite_products fp ON sp.id = fp.product_id
      WHERE fp.user_id = ? AND sp.is_deleted = 0
      ORDER BY fp.created_at DESC
    ''', [userId]);

    return results.map((map) {
      final productMap = Map<String, dynamic>.from(map);
      if (productMap.containsKey('main_images') && productMap['main_images'] is String) {
        final mainImagesStr = productMap['main_images'] as String;
        productMap['main_images'] = mainImagesStr;
      }
      if (productMap.containsKey('tags') && productMap['tags'] is String) {
        final tagsStr = productMap['tags'] as String;
        productMap['tags'] = tagsStr;
      }
      if (productMap.containsKey('detail_images') && productMap['detail_images'] is String) {
        final detailImagesStr = productMap['detail_images'] as String;
        productMap['detail_images'] = detailImagesStr;
      }
      return StarProduct.fromMap(productMap);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getFavoriteProductsWithTime(String userId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT sp.*, fp.created_at as favorited_at FROM star_products sp
      INNER JOIN favorite_products fp ON sp.id = fp.product_id
      WHERE fp.user_id = ? AND sp.is_deleted = 0
      ORDER BY fp.created_at DESC
    ''', [userId]);

    return results;
  }

  Future<int> addFavoriteProduct(String userId, int productId) async {
    final db = await database;
    return await db.insert('favorite_products', {
      'user_id': userId,
      'product_id': productId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> removeFavoriteProduct(String userId, int productId) async {
    final db = await database;
    return await db.delete(
      'favorite_products',
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
    );
  }

  Future<bool> isFavoriteProduct(String userId, int productId) async {
    final db = await database;
    final results = await db.query(
      'favorite_products',
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
    );
    return results.isNotEmpty;
  }

  Future<int> addToCart(StarProduct product, int quantity, String userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final existingItems = await db.query(
      'cart_items',
      where: 'product_id = ? AND user_id = ?',
      whereArgs: [product.id, userId],
    );

    if (existingItems.isNotEmpty) {
      final existingItem = existingItems.first;
      final newQuantity = (existingItem['quantity'] as int) + quantity;
      return await db.update(
        'cart_items',
        {
          'quantity': newQuantity,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existingItem['id']],
      );
    } else {
      return await db.insert(
        'cart_items',
        {
          'product_id': product.id,
          'product_data': json.encode(product.toMap()),
          'quantity': quantity,
          'created_at': now,
          'updated_at': now,
          'user_id': userId,
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCartItems(String userId) async {
    final db = await database;
    final items = await db.query(
      'cart_items',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return items.map<Map<String, dynamic>>((item) {
      final productJson = item['product_data'] as String;
      final productMap = json.decode(productJson) as Map<String, dynamic>;
      final product = StarProduct.fromMap(productMap);
      return {
        'id': item['id'] as int,
        'product_id': item['product_id'] as int,
        'product': product,
        'quantity': item['quantity'] as int,
      };
    }).toList();
  }

  Future<int> updateCartItemQuantity(int itemId, int quantity) async {
    final db = await database;
    return await db.update(
      'cart_items',
      {
        'quantity': quantity,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<int> removeFromCart(int itemId) async {
    final db = await database;
    return await db.delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<int> clearCart(String userId) async {
    final db = await database;
    return await db.delete(
      'cart_items',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> getCartItemCount(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantity) as total FROM cart_items WHERE user_id = ?',
      [userId],
    );
    if (result.isEmpty || result.first['total'] == null) {
      return 0;
    }
    return result.first['total'] as int;
  }

  Future<int> insertPromotion(Map<String, dynamic> promotion) async {
    final db = await database;
    return await db.insert('promotions', promotion);
  }

  Future<List<Map<String, dynamic>>> getPromotionsByProductId(int productId) async {
    final db = await database;
    return await db.query(
      'promotions',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getActivePromotions() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      'promotions',
      where: 'is_active = 1 AND (start_time IS NULL OR start_time <= ?) AND (end_time IS NULL OR end_time >= ?)',
      whereArgs: [now, now],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updatePromotion(int id, Map<String, dynamic> promotion) async {
    final db = await database;
    return await db.update(
      'promotions',
      promotion,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePromotion(int id) async {
    final db = await database;
    return await db.delete(
      'promotions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deactivateExpiredPromotions() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'promotions',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'is_active = 1 AND end_time IS NOT NULL AND end_time < ?',
      whereArgs: [now],
    );
  }

  Future<List<Map<String, dynamic>>> getActivePromotionsByProductId(int productId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      'promotions',
      where: 'product_id = ? AND is_active = 1 AND (start_time IS NULL OR start_time <= ?) AND (end_time IS NULL OR end_time >= ?)',
      whereArgs: [productId, now, now],
      orderBy: 'created_at DESC',
    );
  }

  /// 插入卡密数据
  ///
  /// 参数:
  ///   data - 包含卡密信息的Map，需包含 order_id, user_id, product_id, product_name, card_secret 等字段
  ///
  /// 返回:
  ///   插入成功的记录ID
  Future<int> insertCardSecret(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('card_secrets', {
      ...data,
      'created_at': data['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 根据用户ID获取所有卡密
  ///
  /// 参数:
  ///   userId - 用户唯一标识
  ///
  /// 返回:
  ///   该用户的所有卡密记录列表，按创建时间降序排列
  Future<List<Map<String, dynamic>>> getCardSecretsByUserId(String userId) async {
    final db = await database;
    return await db.query(
      'card_secrets',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  /// 根据订单ID获取卡密
  ///
  /// 参数:
  ///   orderId - 订单唯一标识
  ///
  /// 返回:
  ///   该订单关联的所有卡密记录列表
  Future<List<Map<String, dynamic>>> getCardSecretsByOrderId(String orderId) async {
    final db = await database;
    return await db.query(
      'card_secrets',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at DESC',
    );
  }

  /// 更新卡密状态
  ///
  /// 参数:
  ///   id - 卡密记录ID
  ///   status - 新状态值 ('unused', 'used', 'expired')
  ///
  /// 返回:
  ///   受影响的行数
  Future<int> updateCardSecretStatus(int id, String status) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'status': status,
    };
    if (status == 'used') {
      updateData['used_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    return await db.update(
      'card_secrets',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertBrowsingHistory(Map<String, dynamic> data) async {
    final db = await database;
    final userId = data['user_id'] as String;
    final productId = data['product_id'] as int;

    final existing = await db.query(
      'browsing_history',
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'browsing_history',
        {'visited_at': data['visited_at']},
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
      );
    }

    return await db.insert('browsing_history', data);
  }

  Future<List<Map<String, dynamic>>> getBrowsingHistoryByUserId(
    String userId, {
    int limit = 50,
  }) async {
    final db = await database;
    return await db.query(
      'browsing_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'visited_at DESC',
      limit: limit,
    );
  }

  Future<int> deleteBrowsingHistory(int id) async {
    final db = await database;
    return await db.delete(
      'browsing_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearBrowsingHistory(String userId) async {
    final db = await database;
    return await db.delete(
      'browsing_history',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ==================== 商品问答相关方法 ====================

  /// 获取商品的所有问题
  Future<List<Map<String, dynamic>>> getProductQuestions({
    required int productId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT * FROM product_questions
        WHERE product_id = ?
        ORDER BY is_answered DESC, created_at DESC
        LIMIT ? OFFSET ?
      ''', [productId, limit, offset]);
    } catch (e) {
      debugPrint('获取商品问题失败: $e');
      return [];
    }
  }

  /// 获取问题的详细信息
  Future<Map<String, dynamic>?> getQuestionById(int questionId) async {
    try {
      final db = await database;
      final result = await db.query(
        'product_questions',
        where: 'id = ?',
        whereArgs: [questionId],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('获取问题详情失败: $e');
      return null;
    }
  }

  /// 添加新问题
  Future<int> insertQuestion({
    required int productId,
    required String userId,
    required String userName,
    required String question,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      return await db.insert('product_questions', {
        'product_id': productId,
        'user_id': userId,
        'user_name': userName,
        'question': question,
        'is_answered': 0,
        'like_count': 0,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      debugPrint('添加问题失败: $e');
      rethrow;
    }
  }

  /// 回答问题
  Future<bool> answerQuestion({
    required int questionId,
    required String answer,
    required String answeredBy,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = await db.update(
        'product_questions',
        {
          'answer': answer,
          'answered_by': answeredBy,
          'answered_at': now,
          'is_answered': 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [questionId],
      );
      return result > 0;
    } catch (e) {
      debugPrint('回答问题失败: $e');
      return false;
    }
  }

  /// 更新回答
  Future<bool> updateAnswer({
    required int questionId,
    required String answer,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = await db.update(
        'product_questions',
        {
          'answer': answer,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [questionId],
      );
      return result > 0;
    } catch (e) {
      debugPrint('更新回答失败: $e');
      return false;
    }
  }

  /// 删除问题
  Future<bool> deleteQuestion(int questionId) async {
    try {
      final db = await database;
      final result = await db.delete(
        'product_questions',
        where: 'id = ?',
        whereArgs: [questionId],
      );
      return result > 0;
    } catch (e) {
      debugPrint('删除问题失败: $e');
      return false;
    }
  }

  /// 点赞问题
  Future<bool> likeQuestion(int questionId) async {
    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE product_questions
        SET like_count = like_count + 1, updated_at = ?
        WHERE id = ?
      ''', [DateTime.now().millisecondsSinceEpoch, questionId]);
      return true;
    } catch (e) {
      debugPrint('点赞问题失败: $e');
      return false;
    }
  }

  /// 取消点赞
  Future<bool> unlikeQuestion(int questionId) async {
    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE product_questions
        SET like_count = MAX(like_count - 1, 0), updated_at = ?
        WHERE id = ?
      ''', [DateTime.now().millisecondsSinceEpoch, questionId]);
      return true;
    } catch (e) {
      debugPrint('取消点赞失败: $e');
      return false;
    }
  }

  /// 获取用户的问题列表
  Future<List<Map<String, dynamic>>> getUserQuestions({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT pq.*, sp.name as product_name, sp.image as product_image
        FROM product_questions pq
        LEFT JOIN star_products sp ON pq.product_id = sp.id
        WHERE pq.user_id = ?
        ORDER BY pq.created_at DESC
        LIMIT ?
      ''', [userId, limit]);
    } catch (e) {
      debugPrint('获取用户问题列表失败: $e');
      return [];
    }
  }

  /// 获取未回答的问题数量（商家用）
  Future<int> getUnansweredQuestionsCount(int productId) async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM product_questions
        WHERE product_id = ? AND is_answered = 0
      ''', [productId]);
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('获取未回答问题数量失败: $e');
      return 0;
    }
  }

  Future<int> insertInvoice(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('invoices', {
      ...data,
      'created_at': data['created_at'] ?? now,
      'updated_at': data['updated_at'] ?? now,
    });
  }

  Future<List<Map<String, dynamic>>> getInvoicesByUserId(String userId) async {
    final db = await database;
    return await db.query(
      'invoices',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final db = await database;
    return await db.query('invoices', orderBy: 'created_at DESC');
  }

  Future<int> updateInvoiceStatus(int id, String status) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (status == '已开具') {
      updateData['issued_at'] = DateTime.now().millisecondsSinceEpoch;
    } else if (status == '已邮寄') {
      updateData['mailed_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    return await db.update(
      'invoices',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getInvoicableOrders(String userId) async {
    final db = await database;
    final orders = await db.query(
      'orders',
      where: 'user_id = ? AND status IN (?, ?, ?)',
      whereArgs: [userId, '已签收', '交易完成', '已付款'],
      orderBy: 'created_at DESC',
    );
    final invoicedOrderIds = (await db.query(
      'invoices',
      columns: ['order_id'],
      where: 'user_id = ? AND status != ?',
      whereArgs: [userId, '已取消'],
    )).map((i) => i['order_id'] as String).toSet();
    return orders.where((o) => !invoicedOrderIds.contains(o['id'] as String)).toList();
  }

  Future<int> insertRealNameAuth(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('real_name_auth', {
      ...data,
      'created_at': data['created_at'] ?? now,
      'updated_at': data['updated_at'] ?? now,
    });
  }

  Future<Map<String, dynamic>?> getRealNameAuthByUserId(String userId) async {
    final db = await database;
    final results = await db.query(
      'real_name_auth',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateRealNameAuthStatus(int id, String status, {String? rejectReason}) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (status == 'verified') {
      updateData['verified_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    if (rejectReason != null) {
      updateData['reject_reason'] = rejectReason;
    }
    return await db.update(
      'real_name_auth',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object?>? arguments]) async {
    // 简单的查询实现
    return [];
  }

  Future<int> insert(String table, Map<String, dynamic> values,
      {String? nullColumnHack}) async {
    if (!_tables.containsKey(table)) {
      _tables[table] = {};
      _autoIncrementIds[table] = 1;
    }

    final id = values.containsKey('id') && values['id'] != null
        ? values['id'].toString()
        : _autoIncrementIds[table]!.toString();
    _tables[table]![id] = values;
    _autoIncrementIds[table] = _autoIncrementIds[table]! + 1;

    // 修复：如果ID是字符串且不是数字，返回自增ID，否则返回实际ID的整数形式
    try {
      return int.parse(id);
    } catch (e) {
      // 如果ID不是数字格式，返回自增ID
      return _autoIncrementIds[table]! - 1;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
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

    // 简单的排序
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

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
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

  Future<int> delete(
    String table, {
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
