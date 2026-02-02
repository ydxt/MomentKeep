import 'dart:math';
import 'dart:async';
import 'package:moment_keep/services/user_database_service.dart';

/// ID生成器工具类
/// 用于生成12位用户ID（买家/商家）和8位管理员ID
class IdGenerator {
  /// 平台基准日（2025-01-01）
  static final DateTime _baseDate = DateTime(2025, 1, 1);
  
  /// 机器码（分布式部署时，每台服务器配置不同值）
  static int _machineCode = 0;
  
  /// 随机数生成器
  static final Random _random = Random.secure();
  
  /// 设置机器码
  /// [machineCode] - 机器码（0-9）
  static void setMachineCode(int machineCode) {
    if (machineCode < 0 || machineCode > 9) {
      throw ArgumentError('机器码必须在0-9之间');
    }
    _machineCode = machineCode;
  }
  
  /// 生成12位用户ID
  /// [userType] - 用户类型：01=买家，02=商家
  /// 返回12位纯数字ID
  static String generateUserId(String userType) {
    // 1. 主体类型前缀校验
    if (!['01', '02', '03', '04', '05', '06', '07', '08', '09'].contains(userType)) {
      throw ArgumentError('用户类型必须是01-09之间的有效值');
    }
    
    // 2. 计算相对时间戳（天数差值）
    final now = DateTime.now();
    final daysDiff = now.difference(_baseDate).inDays;
    final relativeTimestamp = daysDiff.toString().padLeft(5, '0');
    
    // 3. 生成4位随机数
    final randomNum = _random.nextInt(10000).toString().padLeft(4, '0');
    
    // 4. 组合生成12位ID
    return '$userType$relativeTimestamp$randomNum$_machineCode';
  }
  
  /// 生成并存储用户ID
  /// [userType] - 用户类型：01=买家，02=商家
  /// [username] - 用户名（可选）
  /// 返回12位纯数字ID
  static Future<String> generateAndStoreUserId(String userType, {String? username}) async {
    // 限制重试次数，避免无限循环
    const maxRetries = 5;
    String? id;
    bool isUnique = false;
    int retryCount = 0;

    while (!isUnique && retryCount < maxRetries) {
      id = generateUserId(userType);
      // 检查ID是否已存在
      final metadata = await getIdMetadata(id);
      isUnique = metadata == null;
      retryCount++;
    }

    if (id == null || !isUnique) {
      throw Exception('无法生成唯一的用户ID，请稍后重试');
    }

    // 将ID及其元数据存储到id_management表
    await _storeIdMetadata(id, userType, username);
    return id;
  }
  
  /// 生成买家用户ID
  /// 返回12位纯数字ID
  static String generateBuyerId() {
    return generateUserId('01');
  }
  
  /// 生成并存储买家用户ID
  /// [username] - 用户名（可选）
  /// 返回12位纯数字ID
  static Future<String> generateAndStoreBuyerId({String? username}) async {
    return await generateAndStoreUserId('01', username: username);
  }
  
  /// 生成商家用户ID
  /// 返回12位纯数字ID
  static String generateSellerId() {
    return generateUserId('02');
  }
  
  /// 生成并存储商家用户ID
  /// [username] - 用户名（可选）
  /// 返回12位纯数字ID
  static Future<String> generateAndStoreSellerId({String? username}) async {
    return await generateAndStoreUserId('02', username: username);
  }
  
  /// 生成8位管理员ID
  /// [departmentCode] - 部门代码：01=运营部，02=客服部，03=技术部，04=财务部，05=风控部
  /// 返回8位纯数字ID
  static String generateAdminId(String departmentCode) {
    // 1. 部门代码校验
    if (!['01', '02', '03', '04', '05'].contains(departmentCode)) {
      throw ArgumentError('部门代码必须是01-05之间的有效值');
    }
    
    // 2. 生成4位随机数
    final randomNum = _random.nextInt(10000).toString().padLeft(4, '0');
    
    // 3. 组合生成8位ID
    return '10$departmentCode$randomNum';
  }
  
  /// 生成并存储管理员ID
  /// [departmentCode] - 部门代码：01=运营部，02=客服部，03=技术部，04=财务部，05=风控部，06-99=预留
  /// 返回8位纯数字ID
  static Future<String> generateAndStoreAdminId(String departmentCode) async {
    // 限制重试次数，避免无限循环
    const maxRetries = 5;
    String? id;
    bool isUnique = false;
    int retryCount = 0;

    while (!isUnique && retryCount < maxRetries) {
      id = generateAdminId(departmentCode);
      // 检查ID是否已存在
      final metadata = await getIdMetadata(id);
      isUnique = metadata == null;
      retryCount++;
    }

    if (id == null || !isUnique) {
      throw Exception('无法生成唯一的管理员ID，请稍后重试');
    }

    // 将ID及其元数据存储到id_management表
    await _storeAdminIdMetadata(id, departmentCode);
    return id;
  }
  
  /// 脱敏用户ID
  /// [userId] - 12位用户ID
  /// 返回脱敏后的ID
  static String maskUserId(String userId) {
    if (userId.length != 12) {
      return userId;
    }
    // 隐藏中间4位
    return '${userId.substring(0, 4)}****${userId.substring(8)}';
  }
  
  /// 脱敏管理员ID
  /// [adminId] - 8位管理员ID
  /// 返回脱敏后的ID
  static String maskAdminId(String adminId) {
    if (adminId.length != 8) {
      return adminId;
    }
    // 隐藏最后4位
    return '${adminId.substring(0, 4)}****';
  }
  
  /// 校验ID格式是否正确
  /// [id] - 要校验的ID
  /// 返回是否为有效的ID
  static bool isValidId(String id) {
    if (id.isEmpty) return false;
    
    // 检查是否为纯数字
    if (int.tryParse(id) == null) return false;
    
    // 检查长度
    final length = id.length;
    if (length != 8 && length != 12) return false;
    
    // 检查前缀
    final prefix = id.substring(0, 2);
    if (length == 12) {
      // 12位用户ID前缀必须是01-09
      return ['01', '02', '03', '04', '05', '06', '07', '08', '09'].contains(prefix);
    } else {
      // 8位管理员ID前缀必须是10
      return prefix == '10';
    }
  }
  
  /// 获取ID类型
  /// [id] - 要获取类型的ID
  /// 返回ID类型：buyer/seller/admin/invalid
  static String getIdType(String id) {
    if (!isValidId(id)) return 'invalid';
    
    final prefix = id.substring(0, 2);
    if (id.length == 12) {
      if (prefix == '01') return 'buyer';
      if (prefix == '02') return 'seller';
      return 'user';
    } else {
      return 'admin';
    }
  }
  

  /// 存储ID元数据
  /// [id] - 生成的ID
  /// [userType] - 用户类型：01=买家，02=商家
  /// [username] - 用户名（可选）
  static Future<void> _storeIdMetadata(String id, String userType, String? username) async {
    // 不再使用id_management表，直接将用户信息存储到users表
    // 此处不需要单独存储ID元数据，因为用户信息已经包含了所有需要的信息
    // 这个方法现在是空的，但保留它是为了向后兼容
  }
  
  /// 存储管理员ID元数据
  /// [id] - 生成的ID
  /// [departmentCode] - 部门代码
  static Future<void> _storeAdminIdMetadata(String id, String departmentCode) async {
    // 不再使用id_management表，直接将用户信息存储到users表
    // 此处不需要单独存储ID元数据，因为用户信息已经包含了所有需要的信息
    // 这个方法现在是空的，但保留它是为了向后兼容
  }
  
  /// 根据用户ID获取ID元数据
  /// [userId] - 用户ID
  /// 返回ID元数据Map，如果不存在则返回null
  static Future<Map<String, dynamic>?> getIdMetadata(String userId) async {
    final db = await UserDatabaseService().database;
    final results = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  /// 关联ID到用户
  /// [id] - ID
  /// [userId] - 用户ID
  static Future<void> linkIdToUser(String id, String userId) async {
    // 不再使用id_management表，直接将用户信息存储到users表
    // 此处不需要单独关联ID到用户，因为用户ID已经是users表的主键
    // 这个方法现在是空的，但保留它是为了向后兼容
  }
}