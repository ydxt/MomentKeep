import 'dart:async';
import '../lib/services/user_database_service.dart';
import '../lib/core/utils/encryption_helper.dart';

/// 重置用户密码脚本
Future<void> main() async {
  try {
    // 初始化加密助手
    await EncryptionHelper.initialize();
    
    // 获取用户数据库服务实例
    final userDatabase = UserDatabaseService();
    
    // 要重置密码的邮箱
    const targetEmail = 'test@h.com';
    // 新密码
    const newPassword = '12345678';
    
    print('开始重置 $targetEmail 的密码...');
    
    // 根据邮箱查找用户
    final user = await userDatabase.getUserByEmail(targetEmail);
    
    if (user == null) {
      print('未找到邮箱为 $targetEmail 的用户');
      return;
    }
    
    // 获取用户ID
    final userId = user['user_id'];
    // 获取用户类型
    final userType = user['user_type'];
    
    print('找到用户: $userId, 类型: $userType');
    
    // 生成新密码的哈希值
    final passwordHash = await EncryptionHelper.encrypt(newPassword);
    print('生成密码哈希成功');
    
    // 准备扩展数据，包含新的密码哈希
    Map<String, dynamic> extensionData = {};
    
    if (userType == 0) {
      // 买家
      extensionData['password_hash'] = passwordHash;
    } else if (userType == 1) {
      // 商家
      extensionData['password_hash'] = passwordHash;
    } else if (userType == 2) {
      // 管理员
      extensionData['password_hash'] = passwordHash;
    }
    
    // 更新用户信息
    final result = await userDatabase.updateUser(userId, {}, extensionData);
    
    if (result > 0) {
      print('密码重置成功！新密码: $newPassword');
    } else {
      print('密码重置失败');
    }
    
  } catch (e) {
    print('发生错误: $e');
  }
}
