import 'dart:async';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';

/// 重置测试账户的优惠券、红包和购物卡
Future<void> resetTestAccount() async {
  try {
    print('开始重置测试账户...');
    
    // 初始化数据库服务
    final databaseService = DatabaseService();
    await databaseService.fullyInitialize();
    
    // 初始化用户数据库服务
    final userDatabaseService = UserDatabaseService();
    
    // 根据邮箱获取用户ID
    print('获取test@h.com用户信息...');
    final user = await userDatabaseService.getUserByEmail('test@h.com');
    if (user == null) {
      print('未找到test@h.com用户');
      return;
    }
    
    final userId = user['user_id'];
    print('找到用户: $userId');
    
    // 清空用户的所有优惠券
    print('清空用户的所有优惠券...');
    await _clearUserCoupons(databaseService, userId);
    
    // 清空用户的所有红包
    print('清空用户的所有红包...');
    await _clearUserRedPackets(databaseService, userId);
    
    // 清空用户的所有购物卡
    print('清空用户的所有购物卡...');
    await _clearUserShoppingCards(databaseService, userId);
    
    // 重新发放测试用的优惠券、红包和购物卡
    print('重新发放测试用的优惠券、红包和购物卡...');
    await _reissueTestItems(databaseService, userId);
    
    print('测试账户重置完成！');
  } catch (e) {
    print('重置测试账户失败: $e');
    rethrow;
  }
}

/// 清空用户的所有优惠券
Future<void> _clearUserCoupons(DatabaseService dbService, String userId) async {
  final db = await dbService.database;
  await db.delete('coupons', where: 'user_id = ?', whereArgs: [userId]);
  print('优惠券已清空');
}

/// 清空用户的所有红包
Future<void> _clearUserRedPackets(DatabaseService dbService, String userId) async {
  final db = await dbService.database;
  await db.delete('red_packets', where: 'user_id = ?', whereArgs: [userId]);
  print('红包已清空');
}

/// 清空用户的所有购物卡
Future<void> _clearUserShoppingCards(DatabaseService dbService, String userId) async {
  final db = await dbService.database;
  await db.delete('shopping_cards', where: 'user_id = ?', whereArgs: [userId]);
  print('购物卡已清空');
}

/// 重新发放测试用的优惠券、红包和购物卡
Future<void> _reissueTestItems(DatabaseService dbService, String userId) async {
  final db = await dbService.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  final validity = '2026-01-31';
  
  // 发放8折优惠券
  await db.insert('coupons', {
    'id': 'coupon_${now}_1',
    'user_id': userId,
    'name': '8折优惠券',
    'amount': 0,
    'condition': 0,
    'validity': validity,
    'status': '可用',
    'type': '折扣券',
    'discount': 0.8,
    'created_at': now,
    'updated_at': now,
  });
  print('已发放8折优惠券');
  
  // 发放500元红包
  await db.insert('red_packets', {
    'id': 'red_packet_${now}_1',
    'user_id': userId,
    'name': '500元红包',
    'amount': 500,
    'validity': validity,
    'status': '可用',
    'type': '现金红包',
    'created_at': now,
    'updated_at': now,
  });
  print('已发放500元红包');
  
  // 发放500星星红包
  await db.insert('red_packets', {
    'id': 'red_packet_${now}_2',
    'user_id': userId,
    'name': '500星星红包',
    'amount': 500,
    'validity': validity,
    'status': '可用',
    'type': '星星红包',
    'created_at': now,
    'updated_at': now,
  });
  print('已发放500星星红包');
  
  // 发放2000元购物卡
  await db.insert('shopping_cards', {
    'id': 'shopping_card_${now}_1',
    'user_id': userId,
    'name': '2000元购物卡',
    'amount': 2000,
    'validity': validity,
    'status': '可用',
    'type': '电子卡',
    'created_at': now,
    'updated_at': now,
  });
  print('已发放2000元购物卡');
  
  // 发放2000星星购物卡
  await db.insert('shopping_cards', {
    'id': 'shopping_card_${now}_2',
    'user_id': userId,
    'name': '2000星星购物卡',
    'amount': 2000,
    'validity': validity,
    'status': '可用',
    'type': '电子卡',
    'created_at': now,
    'updated_at': now,
  });
  print('已发放2000星星购物卡');
}

/// 运行脚本
void main() async {
  await resetTestAccount();
  print('脚本执行完成');
}
