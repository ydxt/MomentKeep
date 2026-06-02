import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('发放红包测试', () {
    test('给test@h.com账户发放500星星红包', () async {
      print('开始执行发放红包测试...');
      
      try {
        // 1. 初始化数据库服务
        print('初始化数据库服务...');
        final userDbService = UserDatabaseService();
        final dbService = DatabaseService();
        
        // 2. 根据邮箱查找用户
        print('查找用户 test@h.com...');
        final user = await userDbService.getUserByEmail('test@h.com');
        
        if (user == null) {
          print('错误: 未找到用户 test@h.com');
          return;
        }
        
        final userId = user['user_id'];
        print('找到用户: $userId');
        
        // 3. 创建500星星红包
        print('创建500星星红包...');
        final redPacketId = Uuid().v4();
        final now = DateTime.now().millisecondsSinceEpoch;
        
        final redPacketData = {
          'id': redPacketId,
          'user_id': userId,
          'name': '500星星红包',
          'amount': 500, // 500星星
          'validity': '永久',
          'status': '可用',
          'type': '星星红包',
          'created_at': now,
          'updated_at': now,
          'used_at': null,
          'used_order_id': null
        };
        
        // 4. 插入红包数据
        final db = await dbService.database;
        final result = await db.insert('red_packets', redPacketData);
        
        if (result > 0) {
          print('成功: 红包发放成功！');
          print('红包ID: $redPacketId');
          print('用户ID: $userId');
          print('红包金额: 500星星');
          print('红包状态: 可用');
        } else {
          print('错误: 红包发放失败');
        }
        
      } catch (e) {
        print('测试执行错误: $e');
      }
      
      print('红包发放测试执行完成');
    });
  });
}
