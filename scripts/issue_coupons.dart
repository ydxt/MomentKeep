import 'dart:io';
import 'dart:async';
import '../lib/services/database_service.dart';
import '../lib/services/user_database_service.dart';

void main() async {
  print('开始为test@h.com账户发放优惠券...');
  
  try {
    // 1. 获取用户ID
    final userService = UserDatabaseService();
    final user = await userService.getUserByEmail('test@h.com');
    
    String userId;
    if (user != null) {
      userId = user['user_id'];
      print('找到用户: ${user['nickname'] ?? '未知用户'}, ID: $userId');
    } else {
      // 使用用户指定的正确ID
      userId = '010037007440';
      print('未找到用户，使用指定的用户ID: $userId');
    }
    
    // 2. 初始化数据库服务
    final dbService = DatabaseService();
    await dbService.fullyInitialize();
    
    // 3. 批量发放优惠券
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
      
      final db = await dbService.database;
      await db.insert('coupons', couponData);
      issuedCount++;
      print('发放第 $issuedCount 个优惠券成功，ID: $couponId');
    }
    
    // 4. 验证发放结果
    final coupons = await dbService.getUserCoupons(userId);
    final eightDiscountCoupons = coupons.where((c) => 
      c['name'] == '8折优惠券' && 
      c['validity'] == validityDate && 
      c['status'] == '可用'
    ).toList();
    
    print('\n发放结果验证:');
    print('总共发放: $couponCount 个8折优惠券');
    print('实际发放成功: ${eightDiscountCoupons.length} 个8折优惠券');
    print('用户现有优惠券总数: ${coupons.length} 个');
    
    // 5. 清理数据库连接
    await dbService.closeDatabase();
    
    print('\n操作完成！');
  } catch (e) {
    print('操作失败: $e');
  }
}
