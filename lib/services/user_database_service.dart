import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_package;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite_package;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    if (dart.library.html) 'package:moment_keep/services/empty_sqflite_ffi.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/storage_path_service.dart';
import 'package:moment_keep/services/database_service.dart';

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
  static const int _databaseVersion = 3;

  /// 用户类型常量 - 位掩码方式
  static const int userTypeBuyer = 1;    // 0b001
  static const int userTypeSeller = 2;   // 0b010
  static const int userTypeAdmin = 4;    // 0b100

  /// 预初始化数据库服务（轻量级）
  /// 仅进行必要的准备工作，不执行耗时操作
  void preInitialize() {
    // 初始化存储路径服务
    StoragePathService.initialize();
    // 初始化数据库服务
    DatabaseService().preInitialize();
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
      
      // 使用服务器目录存放用户数据库
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
        // 使用StoragePathService获取默认目录
        final defaultPath = await StoragePathService.getDefaultDirectory();
        storageDir = Directory(defaultPath);
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

  /// 获取服务器目录（cloud/database/目录）
  /// 用于存放用户数据库等核心业务数据
  Future<Directory?> _getServerDirectory() async {
    try {
      // 使用StoragePathService获取服务器数据库目录
      final serverDatabasePath = await StoragePathService.getServerDatabaseDirectory();
      final serverDir = Directory(serverDatabasePath);

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
    _log('Creating user database tables, version: $version');

    // 创建用户主表（使用INT支持位掩码）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        user_type INT NOT NULL,
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

    // 创建买家信用积分表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS buyer_credit_scores (
        user_id TEXT PRIMARY KEY,
        credit_score INT NOT NULL DEFAULT 100,
        credit_level VARCHAR(20) NOT NULL DEFAULT '良好',
        total_orders INT NOT NULL DEFAULT 0,
        completed_orders INT NOT NULL DEFAULT 0,
        refund_rate REAL NOT NULL DEFAULT 0.0,
        on_time_rate REAL NOT NULL DEFAULT 100.0,
        create_time DATETIME NOT NULL,
        update_time DATETIME NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      );
    ''');
    _log('Created buyer_credit_scores table');

    // 创建卖家信用积分表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS seller_credit_scores (
        user_id TEXT PRIMARY KEY,
        credit_score INT NOT NULL DEFAULT 100,
        credit_level VARCHAR(20) NOT NULL DEFAULT '良好',
        total_orders INT NOT NULL DEFAULT 0,
        completed_orders INT NOT NULL DEFAULT 0,
        refund_rate REAL NOT NULL DEFAULT 0.0,
        on_time_delivery_rate REAL NOT NULL DEFAULT 100.0,
        average_rating REAL NOT NULL DEFAULT 5.0,
        create_time DATETIME NOT NULL,
        update_time DATETIME NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      );
    ''');
    _log('Created seller_credit_scores table');

    // 创建信用积分表索引
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_buyer_credit_user_id ON buyer_credit_scores(user_id);');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_seller_credit_user_id ON seller_credit_scores(user_id);');

    _log('User database tables created successfully');
  }

  /// 数据库升级处理
  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    _log('Upgrading user database from version $oldVersion to $newVersion');
    
    // 处理从版本1升级到版本2 - 添加real_name列到buyer_extensions表
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE buyer_extensions ADD COLUMN real_name VARCHAR(50);');
        _log('Added real_name column to buyer_extensions table');
      } catch (e) {
        _log('Error during database upgrade v1->v2: $e');
      }
    }

    // 处理从版本2升级到版本3 - 支持多重身份和添加信用积分表
    if (oldVersion < 3) {
      try {
        _log('Starting database upgrade v2->v3');

        // 1. 迁移用户类型到位掩码格式
        // 创建临时表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users_temp (
            user_id TEXT PRIMARY KEY,
            user_type INT NOT NULL,
            status TINYINT NOT NULL DEFAULT 0,
            create_time DATETIME NOT NULL,
            update_time DATETIME NOT NULL,
            last_login_time DATETIME,
            login_ip VARCHAR(50),
            delete_flag TINYINT NOT NULL DEFAULT 0
          );
        ''');
        _log('Created temporary users table');

        // 迁移数据并转换user_type
        await db.execute('''
          INSERT INTO users_temp 
          (user_id, user_type, status, create_time, update_time, last_login_time, login_ip, delete_flag)
          SELECT 
            user_id,
            CASE 
              WHEN user_type = 0 THEN 1
              WHEN user_type = 1 THEN 2
              WHEN user_type = 2 THEN 4
              ELSE 1
            END as user_type,
            status, create_time, update_time, last_login_time, login_ip, delete_flag
          FROM users;
        ''');
        _log('Migrated user data with type conversion');

        // 删除旧表并重命名新表
        await db.execute('DROP TABLE users;');
        await db.execute('ALTER TABLE users_temp RENAME TO users;');
        _log('Replaced users table');

        // 重新创建索引
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);');
        _log('Recreated users table indexes');

        // 2. 创建买家信用积分表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS buyer_credit_scores (
            user_id TEXT PRIMARY KEY,
            credit_score INT NOT NULL DEFAULT 100,
            credit_level VARCHAR(20) NOT NULL DEFAULT '良好',
            total_orders INT NOT NULL DEFAULT 0,
            completed_orders INT NOT NULL DEFAULT 0,
            refund_rate REAL NOT NULL DEFAULT 0.0,
            on_time_rate REAL NOT NULL DEFAULT 100.0,
            create_time DATETIME NOT NULL,
            update_time DATETIME NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
          );
        ''');
        _log('Created buyer_credit_scores table');

        // 3. 创建卖家信用积分表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS seller_credit_scores (
            user_id TEXT PRIMARY KEY,
            credit_score INT NOT NULL DEFAULT 100,
            credit_level VARCHAR(20) NOT NULL DEFAULT '良好',
            total_orders INT NOT NULL DEFAULT 0,
            completed_orders INT NOT NULL DEFAULT 0,
            refund_rate REAL NOT NULL DEFAULT 0.0,
            on_time_delivery_rate REAL NOT NULL DEFAULT 100.0,
            average_rating REAL NOT NULL DEFAULT 5.0,
            create_time DATETIME NOT NULL,
            update_time DATETIME NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
          );
        ''');
        _log('Created seller_credit_scores table');

        // 4. 创建信用积分表索引
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_buyer_credit_user_id ON buyer_credit_scores(user_id);');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_seller_credit_user_id ON seller_credit_scores(user_id);');
        _log('Created credit score table indexes');

        _log('Database upgrade v2->v3 completed successfully');
      } catch (e) {
        _log('Error during database upgrade v2->v3: $e');
        // 允许部分失败，继续尝试后续升级
      }
    }
  }

  /// 模拟数据库实现（Web环境使用）
  dynamic _createMockDatabase() {
    return _MockDatabaseForWeb();
  }

  /// 插入新用户（向后兼容的单身份方法）
  Future<int> insertUser(Map<String, dynamic> userData, Map<String, dynamic>? extensionData) async {
    final userType = userData['user_type'] as int;
    
    Map<String, dynamic>? buyerExtension;
    Map<String, dynamic>? sellerExtension;
    Map<String, dynamic>? adminExtension;
    
    // 根据旧的用户类型转换为位掩码并分配扩展数据
    if (userType == 0) {
      userData['user_type'] = userTypeBuyer;
      buyerExtension = extensionData;
    } else if (userType == 1) {
      userData['user_type'] = userTypeSeller;
      sellerExtension = extensionData;
    } else if (userType == 2) {
      userData['user_type'] = userTypeAdmin;
      adminExtension = extensionData;
    } else if ((userType & userTypeBuyer) != 0 || (userType & userTypeSeller) != 0 || (userType & userTypeAdmin) != 0) {
      // 已经是位掩码格式，不需要转换
      if ((userType & userTypeBuyer) != 0) buyerExtension = extensionData;
      if ((userType & userTypeSeller) != 0) sellerExtension = extensionData;
      if ((userType & userTypeAdmin) != 0) adminExtension = extensionData;
    }
    
    return await insertUserMulti(userData, buyerExtension, sellerExtension, adminExtension);
  }

  /// 插入新用户（支持多重身份）
  Future<int> insertUserMulti(Map<String, dynamic> userData, Map<String, dynamic>? buyerExtension, Map<String, dynamic>? sellerExtension, Map<String, dynamic>? adminExtension) async {
    final db = await database;
    int result = 0;

    // 开始事务
    await db.transaction((txn) async {
      // 插入用户主表
      result = await txn.insert('users', userData);

      final userType = userData['user_type'] as int;
      final userId = userData['user_id'];

      // 插入买家扩展表
      if ((userType & userTypeBuyer) != 0 && buyerExtension != null) {
        buyerExtension['user_id'] = userId;
        await txn.insert('buyer_extensions', buyerExtension);
      }

      // 插入商家扩展表
      if ((userType & userTypeSeller) != 0 && sellerExtension != null) {
        sellerExtension['user_id'] = userId;
        await txn.insert('seller_extensions', sellerExtension);
      }

      // 插入管理员扩展表
      if ((userType & userTypeAdmin) != 0 && adminExtension != null) {
        adminExtension['user_id'] = userId;
        await txn.insert('admin_extensions', adminExtension);
      }
    });

    return result;
  }

  /// 根据用户ID获取用户信息（支持多重身份）
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
    final userType = userData['user_type'] as int;

    debugPrint('获取用户ID: $userId 的信息，用户类型(位掩码): $userType');

    // 处理用户类型，兼容旧的0/1/2格式和新的位掩码格式
    final isBuyer = (userType == 0) || ((userType & userTypeBuyer) != 0);
    final isSeller = (userType == 1) || ((userType & userTypeSeller) != 0);
    final isAdmin = (userType == 2) || ((userType & userTypeAdmin) != 0);

    // 获取所有相关的扩展信息（支持多重身份）
    // 买家扩展信息
    if (isBuyer) {
      final buyerResult = await db.query(
        'buyer_extensions',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (buyerResult.isNotEmpty) {
        userData['buyer_extension'] = Map<String, dynamic>.from(buyerResult.first);
        debugPrint('从买家扩展表获取的信息: ${userData['buyer_extension']}');
      }
    }

    // 商家扩展信息
    if (isSeller) {
      final sellerResult = await db.query(
        'seller_extensions',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (sellerResult.isNotEmpty) {
        userData['seller_extension'] = Map<String, dynamic>.from(sellerResult.first);
        debugPrint('从商家扩展表获取的信息: ${userData['seller_extension']}');
      }
    }

    // 管理员扩展信息
    if (isAdmin) {
      final adminResult = await db.query(
        'admin_extensions',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (adminResult.isNotEmpty) {
        userData['admin_extension'] = Map<String, dynamic>.from(adminResult.first);
        debugPrint('从管理员扩展表获取的信息: ${userData['admin_extension']}');
      }
    }

    // 为了向后兼容，如果只有一个身份，同时把扩展信息放在根级别
    final hasOnlyBuyer = isBuyer && !isSeller && !isAdmin;
    final hasOnlySeller = isSeller && !isBuyer && !isAdmin;
    final hasOnlyAdmin = isAdmin && !isBuyer && !isSeller;
    
    debugPrint('合并扩展信息 - hasOnlyBuyer: $hasOnlyBuyer, hasOnlySeller: $hasOnlySeller, hasOnlyAdmin: $hasOnlyAdmin');
    debugPrint('合并前userData keys: ${userData.keys.toList()}');
    
    if (hasOnlyBuyer && userData.containsKey('buyer_extension')) {
      debugPrint('合并买家扩展信息到根级别');
      userData.addAll(userData['buyer_extension']);
    } else if (hasOnlySeller && userData.containsKey('seller_extension')) {
      debugPrint('合并商家扩展信息到根级别');
      userData.addAll(userData['seller_extension']);
    } else if (hasOnlyAdmin && userData.containsKey('admin_extension')) {
      debugPrint('合并管理员扩展信息到根级别');
      userData.addAll(userData['admin_extension']);
    }
    
    debugPrint('合并后userData keys: ${userData.keys.toList()}');

    debugPrint('合并后的用户信息: $userData');
    return userData;
  }

  /// 更新用户信息
  Future<int> updateUser(String userId, Map<String, dynamic> userData, Map<String, dynamic>? extensionData) async {
    final db = await database;
    int result = 0;

    debugPrint('更新用户ID: $userId 的信息，userData: $userData，extensionData: $extensionData');

    // 不使用事务，直接更新
    // 更新用户主表（仅当有数据时）
    if (userData.isNotEmpty) {
      result = await db.update(
        'users',
        userData,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      debugPrint('更新用户主表结果: $result');
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

      debugPrint('获取用户类型结果: $userResult');

      int userType = userTypeBuyer; // 默认用户类型为买家
      bool userExists = userResult.isNotEmpty;

      if (userExists) {
        userType = userResult.first['user_type'] as int;
        debugPrint('用户类型: $userType');
      } else {
        debugPrint('数据库中没有找到用户ID: $userId 的记录，使用默认用户类型: $userType');
        
        // 如果用户记录不存在，尝试创建一个新的用户记录
        try {
          final now = DateTime.now().toIso8601String();
          await db.insert('users', {
            'user_id': userId,
            'user_type': userType,
            'status': 0,
            'create_time': now,
            'update_time': now,
            'last_login_time': now,
            'login_ip': '127.0.0.1',
            'delete_flag': 0,
          });
          debugPrint('创建新用户记录成功，用户ID: $userId');
        } catch (e) {
          debugPrint('创建新用户记录失败: $e');
        }
      }

      // 无论用户是否存在，都尝试更新或插入扩展数据
      // 处理用户类型，兼容旧的0/1/2格式和新的位掩码格式
      final isBuyer = (userType == 0) || ((userType & userTypeBuyer) != 0);
      final isSeller = (userType == 1) || ((userType & userTypeSeller) != 0);
      final isAdmin = (userType == 2) || ((userType & userTypeAdmin) != 0);
      
      if (isBuyer) {
        // 买家
        final updateResult = await db.update(
          'buyer_extensions',
          extensionData,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        debugPrint('更新买家扩展表结果: $updateResult');
        
        // 如果没有记录被更新，说明扩展表中不存在对应的用户记录，需要插入一条新记录
        if (updateResult == 0) {
          // 确保提供所有必填字段
          final insertData = {...extensionData};
          insertData['user_id'] = userId;
          // 添加必填字段的默认值
          insertData['nickname'] = insertData['nickname'] ?? userId;
          insertData['email'] = insertData['email'] ?? '';
          insertData['gender'] = insertData['gender'] ?? 0;
          insertData['birthday'] = insertData['birthday'];
          insertData['phone'] = insertData['phone'];
          insertData['password_hash'] = insertData['password_hash'] ?? '';
          insertData['secret_question'] = insertData['secret_question'];
          insertData['default_address_id'] = insertData['default_address_id'];
          insertData['member_level'] = insertData['member_level'] ?? 0;
          insertData['points'] = insertData['points'] ?? 0;
          insertData['id_card_encrypt'] = insertData['id_card_encrypt'];
          insertData['privacy_setting'] = insertData['privacy_setting'];
          
          await db.insert('buyer_extensions', insertData);
          debugPrint('插入买家扩展表记录成功');
        }
      }
      if (isSeller) {
        // 商家 - 移除不适用的字段
        final sellerExtensionData = {...extensionData};
        sellerExtensionData.remove('points');
        sellerExtensionData.remove('avatar');
        sellerExtensionData.remove('member_level');
        sellerExtensionData.remove('nickname');
        sellerExtensionData.remove('gender');
        sellerExtensionData.remove('birthday');
        sellerExtensionData.remove('email');
        sellerExtensionData.remove('phone');
        sellerExtensionData.remove('password_hash');
        sellerExtensionData.remove('secret_question');
        sellerExtensionData.remove('default_address_id');
        sellerExtensionData.remove('id_card_encrypt');
        sellerExtensionData.remove('real_name');
        sellerExtensionData.remove('privacy_setting');

        if (sellerExtensionData.isNotEmpty) {
          final updateResult = await db.update(
            'seller_extensions',
            sellerExtensionData,
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          debugPrint('更新商家扩展表结果: $updateResult');
          
          // 如果没有记录被更新，说明扩展表中不存在对应的用户记录，需要插入一条新记录
          if (updateResult == 0) {
            sellerExtensionData['user_id'] = userId;
            await db.insert('seller_extensions', sellerExtensionData);
            debugPrint('插入商家扩展表记录成功');
          }
        }
      }
      if (isAdmin) {
        // 管理员 - 移除不适用的字段
        final adminExtensionData = {...extensionData};
        adminExtensionData.remove('points');
        adminExtensionData.remove('avatar');
        adminExtensionData.remove('member_level');
        adminExtensionData.remove('nickname');
        adminExtensionData.remove('gender');
        adminExtensionData.remove('birthday');
        adminExtensionData.remove('email');
        adminExtensionData.remove('phone');
        adminExtensionData.remove('password_hash');
        adminExtensionData.remove('secret_question');
        adminExtensionData.remove('default_address_id');
        adminExtensionData.remove('id_card_encrypt');
        adminExtensionData.remove('real_name');
        adminExtensionData.remove('privacy_setting');

        if (adminExtensionData.isNotEmpty) {
          final updateResult = await db.update(
            'admin_extensions',
            adminExtensionData,
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          debugPrint('更新管理员扩展表结果: $updateResult');
          
          // 如果没有记录被更新，说明扩展表中不存在对应的用户记录，需要插入一条新记录
          if (updateResult == 0) {
            adminExtensionData['user_id'] = userId;
            await db.insert('admin_extensions', adminExtensionData);
            debugPrint('插入管理员扩展表记录成功');
          }
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
  
  /// 根据邮箱查找用户（不区分大小写）
  /// 
  /// 支持从买家扩展表、商家扩展表和管理员扩展表中查询用户
  /// 支持多重身份，返回完整的用户信息
  /// 
  /// [email] 用户邮箱地址
  /// 返回用户信息Map，如果未找到返回null
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final lowerEmail = email.toLowerCase();
    
    // 首先查找买家扩展表
    final buyerResult = await db.query(
      'buyer_extensions',
      where: 'LOWER(email) = ?',
      whereArgs: [lowerEmail],
      limit: 1,
    );
    
    if (buyerResult.isNotEmpty) {
      final buyerData = Map<String, dynamic>.from(buyerResult.first);
      final userId = buyerData['user_id'];
      return await getUserById(userId);
    }
    
    // 然后查找商家扩展表
    final sellerResult = await db.query(
      'seller_extensions',
      where: 'LOWER(email) = ?',
      whereArgs: [lowerEmail],
      limit: 1,
    );
    
    if (sellerResult.isNotEmpty) {
      final sellerData = Map<String, dynamic>.from(sellerResult.first);
      final userId = sellerData['user_id'];
      return await getUserById(userId);
    }
    
    // 最后查找管理员扩展表
    final adminResult = await db.query(
      'admin_extensions',
      where: 'LOWER(enterprise_email) = ?',
      whereArgs: [lowerEmail],
      limit: 1,
    );
    
    if (adminResult.isNotEmpty) {
      final adminData = Map<String, dynamic>.from(adminResult.first);
      final userId = adminData['user_id'];
      return await getUserById(userId);
    }
    
    return null;
  }

  // ==========================================
  // 多重身份检查方法
  // ==========================================

  /// 检查用户是否是买家
  Future<bool> isBuyer(String userId) async {
    final userData = await getUserById(userId);
    if (userData == null) return false;
    final userType = userData['user_type'] as int;
    return (userType & userTypeBuyer) != 0;
  }

  /// 检查用户是否是商家
  Future<bool> isSeller(String userId) async {
    final userData = await getUserById(userId);
    if (userData == null) return false;
    final userType = userData['user_type'] as int;
    return (userType & userTypeSeller) != 0;
  }

  /// 检查用户是否是管理员
  Future<bool> isAdmin(String userId) async {
    final userData = await getUserById(userId);
    if (userData == null) return false;
    final userType = userData['user_type'] as int;
    return (userType & userTypeAdmin) != 0;
  }

  /// 为用户添加身份（不删除现有身份）
  Future<void> addUserRole(String userId, int role) async {
    final db = await database;
    final userResult = await db.query(
      'users',
      columns: ['user_type'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (userResult.isNotEmpty) {
      final currentType = userResult.first['user_type'] as int;
      final newType = currentType | role;
      await db.update(
        'users',
        {'user_type': newType, 'update_time': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
  }

  /// 移除用户的某个身份
  Future<void> removeUserRole(String userId, int role) async {
    final db = await database;
    final userResult = await db.query(
      'users',
      columns: ['user_type'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (userResult.isNotEmpty) {
      final currentType = userResult.first['user_type'] as int;
      final newType = currentType & ~role;
      await db.update(
        'users',
        {'user_type': newType, 'update_time': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
  }

  /// 获取用户的所有身份
  Future<List<String>> getUserRoles(String userId) async {
    final userData = await getUserById(userId);
    if (userData == null) return [];
    final userType = userData['user_type'] as int;
    final roles = <String>[];
    if ((userType & userTypeBuyer) != 0) roles.add('买家');
    if ((userType & userTypeSeller) != 0) roles.add('商家');
    if ((userType & userTypeAdmin) != 0) roles.add('管理员');
    return roles;
  }

  // ==========================================
  // 买家信用积分操作方法
  // ==========================================

  /// 获取买家信用积分
  Future<BuyerCreditScore?> getBuyerCreditScore(String userId) async {
    final db = await database;
    final result = await db.query(
      'buyer_credit_scores',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return BuyerCreditScore.fromMap(result.first);
    }
    return null;
  }

  /// 创建或更新买家信用积分
  Future<int> saveBuyerCreditScore(BuyerCreditScore creditScore) async {
    final db = await database;
    final existing = await getBuyerCreditScore(creditScore.userId);
    if (existing == null) {
      return await db.insert('buyer_credit_scores', creditScore.toMap());
    } else {
      return await db.update(
        'buyer_credit_scores',
        creditScore.toMap(),
        where: 'user_id = ?',
        whereArgs: [creditScore.userId],
      );
    }
  }

  // ==========================================
  // 卖家信用积分操作方法
  // ==========================================

  /// 获取卖家信用积分
  Future<SellerCreditScore?> getSellerCreditScore(String userId) async {
    final db = await database;
    final result = await db.query(
      'seller_credit_scores',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return SellerCreditScore.fromMap(result.first);
    }
    return null;
  }

  /// 创建或更新卖家信用积分
  Future<int> saveSellerCreditScore(SellerCreditScore creditScore) async {
    final db = await database;
    final existing = await getSellerCreditScore(creditScore.userId);
    if (existing == null) {
      return await db.insert('seller_credit_scores', creditScore.toMap());
    } else {
      return await db.update(
        'seller_credit_scores',
        creditScore.toMap(),
        where: 'user_id = ?',
        whereArgs: [creditScore.userId],
      );
    }
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
    List<String>? columns,
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

    // 如果指定了列，只返回指定的列
    if (columns != null && columns.isNotEmpty) {
      rows = rows.map((row) {
        final filteredRow = <String, dynamic>{};
        for (final column in columns) {
          if (row.containsKey(column)) {
            filteredRow[column] = row[column];
          }
        }
        return filteredRow;
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
