import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';

Future<void> main() async {
  try {
    // 初始化数据库服务
    final databaseService = DatabaseService();
    final userDatabaseService = UserDatabaseService();
    
    // 查找test@h.com账户
    print('正在查找test@h.com账户...');
    final user = await userDatabaseService.getUserByEmail('test@h.com');
    
    if (user == null) {
      print('未找到test@h.com账户');
      return;
    }
    
    final userId = user['user_id'];
    final currentPoints = user['points'] ?? 0;
    
    print('找到账户：');
    print('用户ID: $userId');
    print('当前积分: $currentPoints');
    
    // 充值10000积分
    print('正在充值10000积分...');
    await databaseService.updateUserPoints(userId, 10000);
    
    // 验证积分是否充值成功
    final newPoints = await databaseService.getUserPoints(userId);
    print('充值成功！');
    print('新积分: $newPoints');
    print('积分增加了: ${newPoints - currentPoints}');
  } catch (e) {
    print('充值失败: $e');
  }
}