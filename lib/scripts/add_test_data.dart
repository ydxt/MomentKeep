import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/database_service.dart';

Future<void> main() async {
  // 初始化数据库服务
  final userDatabaseService = UserDatabaseService();
  final databaseService = DatabaseService();
  
  // 邮箱账号
  const String email = 'test@h.com';
  
  print('正在查找用户 $email...');
  
  // 根据邮箱获取用户数据
  final user = await userDatabaseService.getUserByEmail(email);
  
  if (user == null) {
    print('未找到用户 $email');
    return;
  }
  
  final String userId = user['user_id'];
  print('找到用户，ID: $userId');
  
  // 有效期到2026年1月31日
  const String validityDate = '2026-01-31';
  
  // 获取当前时间戳
  final int now = DateTime.now().millisecondsSinceEpoch;
  
  try {
    // 1. 插入500元红包
    print('插入500元红包...');
    await databaseService.database.then((db) async {
      await db.insert('red_packets', {
        'id': 'test_cash_red_packet_500',
        'user_id': userId,
        'name': '500元红包',
        'amount': 500,
        'validity': validityDate,
        'status': '可用',
        'type': '现金红包',
        'created_at': now,
        'updated_at': now,
      });
    });
    
    // 2. 插入500星星红包（积分红包）
    print('插入500星星红包...');
    await databaseService.database.then((db) async {
      await db.insert('red_packets', {
        'id': 'test_points_red_packet_500',
        'user_id': userId,
        'name': '500星星红包',
        'amount': 500,
        'validity': validityDate,
        'status': '可用',
        'type': '积分红包',
        'created_at': now,
        'updated_at': now,
      });
    });
    
    // 3. 插入全场9折优惠券
    print('插入全场9折优惠券...');
    await databaseService.database.then((db) async {
      await db.insert('coupons', {
        'id': 'test_discount_coupon_90',
        'user_id': userId,
        'name': '全场9折优惠券',
        'amount': 0,
        'condition': 0,
        'validity': validityDate,
        'status': '可用',
        'type': '折扣券',
        'discount': 0.9,
        'created_at': now,
        'updated_at': now,
      });
    });
    
    // 4. 插入500元购物卡
    print('插入500元购物卡...');
    await databaseService.database.then((db) async {
      await db.insert('shopping_cards', {
        'id': 'test_cash_card_500',
        'user_id': userId,
        'name': '500元购物卡',
        'amount': 500,
        'validity': validityDate,
        'status': '可用',
        'type': '电子卡',
        'created_at': now,
        'updated_at': now,
      });
    });
    
    // 5. 插入500星星购物卡（积分购物卡）
    print('插入500星星购物卡...');
    await databaseService.database.then((db) async {
      await db.insert('shopping_cards', {
        'id': 'test_points_card_500',
        'user_id': userId,
        'name': '500星星购物卡',
        'amount': 500,
        'validity': validityDate,
        'status': '可用',
        'type': '积分卡',
        'created_at': now,
        'updated_at': now,
      });
    });
    
    print('所有测试数据插入成功！');
    
  } catch (e) {
    print('插入测试数据失败: $e');
  }
}