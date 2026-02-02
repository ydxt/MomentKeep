import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_package;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../core/utils/encryption_helper.dart';
import '../domain/entities/star_exchange.dart';

/// 购物车商品项
class CartItem {
  final int id;
  final int productId;
  final StarProduct product;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  CartItem({
    required this.id,
    required this.productId,
    required this.product,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      productId: map['product_id'],
      product: StarProduct.fromMap(map), // 假设StarProduct.fromMap可以处理product的json
      quantity: map['quantity'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_data': json.encode(product.toMap()),
      'quantity': quantity,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// 购物车数据库服务
class CartDatabaseService {
  static final CartDatabaseService _instance = CartDatabaseService._internal();
  static Database? _database;
  final String _databaseName = 'cart.db';
  final int _databaseVersion = 1;

  factory CartDatabaseService() {
    return _instance;
  }

  CartDatabaseService._internal();

  Future<Database> get database async {
    // 关闭现有连接（如果存在）
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    // 每次都重新初始化数据库连接
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // 使用与ProductDatabaseService相同的目录结构
    // 所有用户都使用default目录下的数据库文件
    try {
      // 从SharedPreferences获取自定义存储路径
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('storage_path');

      Directory storageDir;

      if (customPath != null && customPath.isNotEmpty) {
        // 使用自定义存储路径下的default目录
        storageDir = Directory(path_package.join(customPath, 'default'));
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

        // 创建软件设置目录，所有用户都使用default目录
        storageDir = Directory(path_package.join(directory.path, 'MomentKeep', 'default'));
      }

      // 确保存储目录存在
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }
      
      final dbPath = path_package.join(storageDir.path, _databaseName);

      return await openDatabase(
        dbPath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      // 如果自定义路径初始化失败，回退到默认数据库路径
      final databasesPath = await getDatabasesPath();
      final dbPath = path_package.join(databasesPath, _databaseName);

      return await openDatabase(
        dbPath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_data TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES star_products(id)
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items (user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON cart_items (product_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 处理数据库升级
    if (oldVersion < 1) {
      // 初始版本，无需升级
    }
  }

  /// 添加商品到购物车
  Future<int> addToCart(StarProduct product, int quantity, String userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 检查商品是否已在购物车中
    final existingItems = await db.query(
      'cart_items',
      where: 'product_id = ? AND user_id = ?',
      whereArgs: [product.id, userId],
    );

    if (existingItems.isNotEmpty) {
      // 商品已存在，更新数量
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
      // 商品不存在，添加新记录
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

  /// 获取用户购物车商品
  Future<List<Map<String, dynamic>>> getCartItems(String userId) async {
    final db = await database;
    final items = await db.query(
      'cart_items',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return items.map((item) {
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

  /// 更新购物车商品数量
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

  /// 删除购物车商品
  Future<int> removeFromCart(int itemId) async {
    final db = await database;
    return await db.delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// 清空购物车
  Future<int> clearCart(String userId) async {
    final db = await database;
    return await db.delete(
      'cart_items',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// 获取购物车商品总数
  Future<int> getCartItemCount(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantity) as total FROM cart_items WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
