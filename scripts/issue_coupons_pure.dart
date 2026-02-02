import 'dart:io';
import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path_package;

void main() async {
  print('开始为test@h.com账户发放优惠券...');
  
  try {
    // 初始化sqflite_ffi
    sqfliteFfiInit();
    
    // 1. 获取数据库路径
    final databasePath = await _getDatabasePath();
    print('数据库路径: $databasePath');
    
    // 2. 打开数据库
    final db = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 17,
        onCreate: (db, version) async {
          print('数据库不存在，正在创建...');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('数据库需要升级，从版本 $oldVersion 到 $newVersion');
        },
      ),
    );
    print('数据库连接成功');
    
    // 3. 获取用户ID
    String userId = '010037007440'; // 使用用户指定的正确ID
    print('使用用户ID: $userId');
    
    // 4. 批量发放优惠券
    final couponCount = 10;
    final validityDate = '2026-01-31';
    
    print('开始发放 $couponCount 个8折优惠券，有效期至: $validityDate');
    
    int issuedCount = 0;
    for (int i = 1; i <= couponCount; i++) {
      final couponId = 'coupon_${DateTime.now().millisecondsSinceEpoch}_$i';
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final couponData = {
        'id': couponId,
        'user_id': userId,
        'name': '8折优惠券',
        'amount': 0,
        'condition': 0,
        'validity': validityDate,
        'status': '可用',
        'type': '折扣券',
        'discount': 0.8,
        'created_at': now,
        'updated_at': now,
        'used_at': null,
        'used_order_id': null
      };
      
      await db.insert('coupons', couponData);
      issuedCount++;
      print('发放第 $issuedCount 个优惠券成功，ID: $couponId');
    }
    
    // 5. 验证发放结果
    final coupons = await db.query('coupons', where: 'user_id = ?', whereArgs: [userId]);
    final eightDiscountCoupons = coupons.where((c) => 
      c['name'] == '8折优惠券' && 
      c['validity'] == validityDate && 
      c['status'] == '可用'
    ).toList();
    
    print('\n发放结果验证:');
    print('总共发放: $couponCount 个8折优惠券');
    print('实际发放成功: ${eightDiscountCoupons.length} 个8折优惠券');
    print('用户现有优惠券总数: ${coupons.length} 个');
    
    // 6. 清理数据库连接
    await db.close();
    
    print('\n操作完成！');
  } catch (e) {
    print('操作失败: $e');
  }
}

/// 获取数据库路径
Future<String> _getDatabasePath() async {
  Directory directory;
  if (Platform.isWindows) {
    // Windows使用文档目录
    directory = Directory(path_package.join(
        Platform.environment['USERPROFILE']!, 'Documents'));
  } else if (Platform.isMacOS) {
    // macOS使用文档目录
    directory = Directory(
        path_package.join(Platform.environment['HOME']!, 'Documents'));
  } else if (Platform.isLinux) {
    // Linux使用文档目录
    directory = Directory(
        path_package.join(Platform.environment['HOME']!, 'Documents'));
  } else {
    throw UnsupportedError('Unsupported platform');
  }

  // 创建软件数据目录
  final storageDir = Directory(path_package.join(directory.path, 'MomentKeep', 'default'));
  if (!await storageDir.exists()) {
    await storageDir.create(recursive: true);
  }

  return path_package.join(storageDir.path, 'moment_keep.db');
}
