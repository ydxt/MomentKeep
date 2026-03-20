import 'dart:async';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';

/// 诊断并修复用户积分问题
Future<void> diagnoseAndFixPoints() async {
  print('========================================');
  print('开始执行积分诊断...');
  print('========================================');
  
  try {
    // 1. 初始化数据库服务
    print('\n[步骤 1] 初始化数据库服务...');
    final databaseService = DatabaseService();
    await databaseService.fullyInitialize();
    
    // 2. 根据邮箱查找用户
    print('\n[步骤 2] 查找用户 test@h.com...');
    final userDatabaseService = UserDatabaseService();
    final user = await userDatabaseService.getUserByEmail('test@h.com');
    
    if (user == null) {
      print('错误: 未找到用户 test@h.com');
      return;
    }
    
    final userId = user['user_id'];
    print('找到用户: $userId');
    print('用户详细信息: $user');
    
    // 3. 获取当前积分
    print('\n[步骤 3] 获取当前用户积分...');
    final currentPoints = await databaseService.getUserPoints(userId);
    print('当前积分: $currentPoints');
    
    // 4. 获取所有积分明细
    print('\n[步骤 4] 获取所有积分明细...');
    final allBillItems = await databaseService.getBillItems(userId);
    print('积分明细数量: ${allBillItems.length}');
    
    if (allBillItems.isEmpty) {
      print('警告: 没有找到任何积分明细记录!');
    } else {
      print('\n积分明细详情:');
      print('-' * 100);
      print('序号 | 类型       | 金额   | 交易类型       | 描述');
      print('-' * 100);
      
      int calculatedTotalIncome = 0;
      int calculatedTotalExpense = 0;
      
      for (int i = 0; i < allBillItems.length; i++) {
        final item = allBillItems[i];
        print('${i + 1}    | ${item.type.padRight(10)} | ${item.amount.toString().padLeft(6)} | ${item.transactionType.padRight(12)} | ${item.description}');
        
        if (item.type == 'income') {
          calculatedTotalIncome += item.amount.round();
        } else {
          calculatedTotalExpense += item.amount.round();
        }
      }
      
      print('-' * 100);
      print('收入总计: $calculatedTotalIncome');
      print('支出总计: $calculatedTotalExpense');
      final calculatedPoints = calculatedTotalIncome - calculatedTotalExpense;
      print('计算得到积分: $calculatedPoints');
      print('数据库显示积分: $currentPoints');
      
      // 5. 检查是否一致
      print('\n[步骤 5] 验证积分一致性...');
      if (currentPoints.round() == calculatedPoints) {
        print('✓ 积分一致，没有问题!');
      } else {
        print('✗ 积分不一致!');
        print('  - 数据库显示: ${currentPoints.round()}');
        print('  - 实际应该是: $calculatedPoints');
        print('  - 差异: ${calculatedPoints - currentPoints.round()}');
        
        // 6. 修复积分
        print('\n[步骤 6] 修复积分问题...');
        print('正在将积分更新为: $calculatedPoints');
        await databaseService.updatePointsDirectly(userId, calculatedPoints);
        
        // 7. 验证修复
        print('\n[步骤 7] 验证修复结果...');
        final updatedPoints = await databaseService.getUserPoints(userId);
        print('修复后的积分: $updatedPoints');
        
        if (updatedPoints.round() == calculatedPoints) {
          print('✓ 积分修复成功!');
        } else {
          print('✗ 积分修复失败!');
        }
      }
    }
    
    // 8. 直接查询数据库验证
    print('\n[步骤 8] 直接数据库查询验证...');
    final db = await databaseService.database;
    
    // 查询buyer_extensions表
    print('\n查询 buyer_extensions 表:');
    final buyerExtensionsResult = await db.query(
      'buyer_extensions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    print('buyer_extensions 记录: $buyerExtensionsResult');
    
    // 查询bill_items表（不通过getBillItems，直接查询）
    print('\n直接查询 bill_items 表:');
    final rawBillItemsResult = await db.query(
      'bill_items',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    print('bill_items 记录数量: ${rawBillItemsResult.length}');
    
    if (rawBillItemsResult.isNotEmpty) {
      print('原始 bill_items 数据:');
      int rawIncome = 0;
      int rawExpense = 0;
      for (final item in rawBillItemsResult) {
        final type = item['type'] as String?;
        final amount = item['amount'] as num?;
        print('  - type: $type, amount: $amount, raw: $item');
        
        if (type == 'income' && amount != null) {
          rawIncome += amount.round();
        } else if (amount != null) {
          rawExpense += amount.round();
        }
      }
      print('原始数据收入: $rawIncome, 支出: $rawExpense, 结余: ${rawIncome - rawExpense}');
    }
    
    print('\n========================================');
    print('积分诊断完成!');
    print('========================================');
    
  } catch (e, stackTrace) {
    print('诊断执行错误: $e');
    print('堆栈跟踪: $stackTrace');
  }
}

/// 运行脚本
void main() async {
  await diagnoseAndFixPoints();
  print('脚本执行完成');
}
