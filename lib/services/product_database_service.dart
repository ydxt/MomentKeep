import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_package;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite_package;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    if (dart.library.html) 'package:moment_keep/services/empty_sqflite_ffi.dart';
import 'package:moment_keep/services/user_database_service.dart';

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
  static const int _databaseVersion = 8;

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

      // 所有用户都使用default目录下的数据库文件
      // 直接使用_getDefaultDirectory()方法获取default目录，确保所有数据库连接都使用相同的目录
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

  /// 获取默认目录（default目录） - 使用与DatabaseService相同的目录结构
  Future<Directory?> _getDefaultDirectory() async {
    try {
      // 从SharedPreferences获取自定义存储路径
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('storage_path');

      Directory storageDir;
      Directory baseDir;

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // 移动端使用应用文档目录
        baseDir = await getApplicationDocumentsDirectory();
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Windows使用文档目录
        baseDir = Directory(path_package.join(
            Platform.environment['USERPROFILE']!, 'Documents'));
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        // macOS使用文档目录
        baseDir = Directory(
            path_package.join(Platform.environment['HOME']!, 'Documents'));
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        // Linux使用文档目录
        baseDir = Directory(
            path_package.join(Platform.environment['HOME']!, 'Documents'));
      } else {
        throw UnsupportedError('Unsupported platform');
      }

      if (customPath != null && customPath.isNotEmpty) {
        // 使用自定义存储路径
        storageDir = Directory(customPath);
      } else {
        // 使用默认路径，添加MomentKeep子目录，与database_service.dart保持一致
        storageDir =
            Directory(path_package.join(baseDir.path, 'MomentKeep'));
      }

      // 确保存储目录存在
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }

      // 使用default目录存储所有用户共享的数据库
      final defaultDir =
          Directory(path_package.join(storageDir.path, 'default'));
      if (!await defaultDir.exists()) {
        await defaultDir.create(recursive: true);
      }

      return defaultDir;
    } catch (e) {
      _log('Error getting default directory: $e');
      return null;
    }
  }

  /// 创建数据库表结构
  Future<void> _onCreate(dynamic db, int version) async {
    _log('Creating product database tables, version: $version');

    // 创建星星商店分类表
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

    // 创建星星商店商品表
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
        -- 添加在版本16中添加的字段
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
        -- 支付方式相关字段
        support_points_payment INTEGER NOT NULL DEFAULT 1,
        support_cash_payment INTEGER NOT NULL DEFAULT 1,
        support_hybrid_payment INTEGER NOT NULL DEFAULT 1,
        -- 混合支付相关字段
        hybrid_price INTEGER DEFAULT 0,
        hybrid_points INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES star_categories(id) ON DELETE CASCADE
      );
    ''');
    _log('Created star_products table');

    // 创建星星商品SKU表
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
        -- 支付方式相关字段
        support_points_payment INTEGER NOT NULL DEFAULT 1,
        support_cash_payment INTEGER NOT NULL DEFAULT 1,
        support_hybrid_payment INTEGER NOT NULL DEFAULT 1,
        -- 混合支付相关字段
        hybrid_price INTEGER DEFAULT 0,
        hybrid_points INTEGER DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created star_product_skus table');

    // 创建星星商品规格表
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

    // 创建订单表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
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
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES star_products(id) ON DELETE CASCADE
      );
    ''');
    _log('Created orders table');

    // 创建评论表
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

    // 创建退积分申请表
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

    // 创建退积分设置表
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

    // 插入默认退积分设置
    await db.insert('refund_settings', {
      'days': 7,
      'hours': 0,
      'minutes': 0,
      'seconds': 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });
    _log('Inserted default refund settings');

    // 创建清理日志表
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

    // 创建操作记录表
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

    // 立即创建索引（如果不存在）
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_cleanup_time ON cleanup_logs (cleanup_time)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_created_at ON cleanup_logs (created_at)');
    _log('Created indexes for cleanup_logs table');

    // 创建索引以提高查询性能
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

    _log('Product database tables created successfully');
  }

  /// 数据库升级处理
  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    _log('Upgrading product database from version $oldVersion to $newVersion');

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
    _log('Created cleanup_logs table in upgrade');

    // 创建清理日志表索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_cleanup_time ON cleanup_logs (cleanup_time)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cleanup_logs_created_at ON cleanup_logs (created_at)');
    _log('Created indexes for cleanup_logs table in upgrade');

    // 创建操作记录表（如果不存在）
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
    _log('Created operation_logs table in upgrade');

    // 创建操作记录表索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_operation_logs_order_id ON operation_logs (order_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at ON operation_logs (created_at)');
    _log('Created indexes for operation_logs table in upgrade');

    // 升级版本1到3：添加混合支付字段和支付方式相关字段
    if (oldVersion < 3) {
      // 为star_products表添加支付方式相关字段
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

      // 为star_products表添加混合支付字段
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
        _log('Added support_points_payment column to star_product_skus table');
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
        _log('Added support_hybrid_payment column to star_product_skus table');
      } catch (e) {
        _log(
            'support_hybrid_payment column might already exist in star_product_skus: $e');
      }

      // 为star_product_skus表添加混合支付字段
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
    }

    // 升级版本3到4：为orders表添加支付方式相关字段和创建reviews表
    if (oldVersion < 4) {
      // 为orders表添加缺失的字段
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN product_price INTEGER NOT NULL DEFAULT 0');
        _log('Added product_price column to orders table');
      } catch (e) {
        _log('product_price column might already exist: $e');
      }

      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN total_amount REAL NOT NULL DEFAULT 0');
        _log('Added total_amount column to orders table');
      } catch (e) {
        _log('total_amount column might already exist: $e');
      }

      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN points_used INTEGER NOT NULL DEFAULT 0');
        _log('Added points_used column to orders table');
      } catch (e) {
        _log('points_used column might already exist: $e');
      }

      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN cash_amount REAL NOT NULL DEFAULT 0');
        _log('Added cash_amount column to orders table');
      } catch (e) {
        _log('cash_amount column might already exist: $e');
      }

      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN payment_method TEXT NOT NULL DEFAULT "cash"');
        _log('Added payment_method column to orders table');
      } catch (e) {
        _log('payment_method column might already exist: $e');
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
      _log('Created reviews table in upgrade');

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
      _log('Created refund_requests table in upgrade');
    }

    // 升级版本4到5：为reviews表添加缺失的匿名评论相关字段，为orders表添加variant字段
    if (oldVersion < 5) {
      // 为orders表添加variant字段
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN variant TEXT');
        _log('Added variant column to orders table');
      } catch (e) {
        _log('variant column might already exist: $e');
      }

      // 为reviews表添加缺失的字段
      try {
        await db.execute(
            'ALTER TABLE reviews ADD COLUMN is_anonymous INTEGER NOT NULL DEFAULT 1');
        _log('Added is_anonymous column to reviews table');
      } catch (e) {
        _log('is_anonymous column might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE reviews ADD COLUMN user_id TEXT');
        _log('Added user_id column to reviews table');
      } catch (e) {
        _log('user_id column might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE reviews ADD COLUMN user_name TEXT');
        _log('Added user_name column to reviews table');
      } catch (e) {
        _log('user_name column might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE reviews ADD COLUMN user_avatar TEXT');
        _log('Added user_avatar column to reviews table');
      } catch (e) {
        _log('user_avatar column might already exist: $e');
      }
    }

    // 升级版本5到6：为orders表添加delivery_address和buyer_note字段
    if (oldVersion < 6) {
      // 为orders表添加delivery_address字段
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN delivery_address TEXT DEFAULT ""');
        _log('Added delivery_address column to orders table');
      } catch (e) {
        _log('delivery_address column might already exist: $e');
      }

      // 为orders表添加buyer_note字段
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN buyer_note TEXT DEFAULT ""');
        _log('Added buyer_note column to orders table');
      } catch (e) {
        _log('buyer_note column might already exist: $e');
      }
    }

    // 升级版本6到7：为orders表添加buyer_name和buyer_phone字段
    if (oldVersion < 7) {
      // 为orders表添加buyer_name字段
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN buyer_name TEXT DEFAULT "匿名用户"');
        _log('Added buyer_name column to orders table');
      } catch (e) {
        _log('buyer_name column might already exist: $e');
      }

      // 为orders表添加buyer_phone字段
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN buyer_phone TEXT DEFAULT ""');
        _log('Added buyer_phone column to orders table');
      } catch (e) {
        _log('buyer_phone column might already exist: $e');
      }
    }

    // 升级版本7到8：为orders表添加original_points和original_cash字段
    if (oldVersion < 8) {
      // 为orders表添加original_points字段
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN original_points INTEGER NOT NULL DEFAULT 0');
        _log('Added original_points column to orders table');
      } catch (e) {
        _log('original_points column might already exist: $e');
      }

      // 为orders表添加original_cash字段
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN original_cash INTEGER NOT NULL DEFAULT 0');
        _log('Added original_cash column to orders table');
      } catch (e) {
        _log('original_cash column might already exist: $e');
      }
    }
  }

  /// 检查并创建所有缺失的表
  Future<void> _checkAndCreateMissingTables(dynamic db) async {
    _log('Checking and creating missing tables...');

    // 为orders表添加variant字段（如果不存在）
    try {
      await db.execute('ALTER TABLE orders ADD COLUMN variant TEXT');
      _log('Added variant column to orders table');
    } catch (e) {
      _log('variant column might already exist in orders table: $e');
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
      'logistics_info'
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

  /// 同意退款申请
  Future<int> approveRefund(String orderId, String operator, String description,
      {dynamic databaseService}) async {
    final db = await database;
    final userDatabaseService = UserDatabaseService();

    // 1. 获取订单信息
    final orderResult = await db.query(
      'orders',
      columns: [
        'user_id',
        'payment_method',
        'points_used',
        'cash_amount',
        'product_name'
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

    // 2. 更新订单状态为已退款
    final updatedCount = await db.update(
      'orders',
      {
        'after_sales_status': 'approved',
        'status': '已退款',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );

    // 3. 退还客户积分或金钱
    if (pointsUsed > 0 && userId.isNotEmpty) {
      try {
        if (databaseService != null) {
          // 使用传入的DatabaseService来更新积分，会自动创建账单记录
          await databaseService.updateUserPoints(
            userId,
            pointsUsed,
            description: '退款 - $productName',
            transactionType: 'refund',
            relatedId: orderId,
          );
        } else {
          // 直接使用UserDatabaseService来更新用户积分
          final userData = await userDatabaseService.getUserById(userId);
          if (userData != null) {
            final currentPoints = userData['points'] ?? 0;
            final newPoints = currentPoints + pointsUsed;

            // 更新用户积分
            await userDatabaseService.updateUser(
              userId,
              {},
              {'points': newPoints},
            );
          }
        }
      } catch (e) {
        debugPrint('Error refunding points: $e');
        rethrow;
      }
    }

    // 现金退款处理 - 这里可以添加现金退款的逻辑，比如调用支付平台API
    // if (cashAmount > 0) {
    //   // 调用支付平台API退款
    //   // await paymentService.refund(orderId, cashAmount);
    // }

    // 4. 添加操作记录
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
