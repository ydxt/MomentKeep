import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/security_service.dart';

/// 混合认证服务
/// 支持本地认证 + Supabase Auth 云端认证
/// 离线时可使用本地账号，在线时可同步到云端
class HybridAuthService {
  /// 单例实例
  static final HybridAuthService _instance = HybridAuthService._internal();

  /// Supabase 服务
  final SupabaseService _supabase = SupabaseService();

  /// 用户数据库服务
  final UserDatabaseService _userDb = UserDatabaseService();

  /// 私有构造函数
  HybridAuthService._internal();

  /// 工厂构造函数
  factory HybridAuthService() => _instance;

  // ==================== 认证状态 ====================

  /// 当前认证模式
  AuthMode get currentMode {
    if (_supabase.isInitialized && _supabase.currentUser != null) {
      return AuthMode.cloud;
    }
    return AuthMode.local;
  }

  /// 是否已登录（本地或云端）
  bool get isLoggedIn => currentMode != AuthMode.notLoggedIn;

  /// 获取当前用户 ID
  Future<String?> getCurrentUserId() async {
    // 优先使用云端用户 ID
    if (_supabase.isInitialized && _supabase.currentUser != null) {
      return _supabase.currentUser!.id;
    }

    // 否则使用本地用户 ID
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  /// 获取当前用户信息
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = await getCurrentUserId();
    if (userId == null) return null;

    return await _userDb.getUserById(userId);
  }

  // ==================== 本地认证 ====================

  /// 本地登录
  /// 离线时可用，使用本地 SQLite 中的用户数据
  Future<AuthResult> localLogin({
    required String email,
    required String password,
  }) async {
    try {
      // 查询本地用户
      final user = await _userDb.getUserByEmail(email);

      if (user == null) {
        return AuthResult(
          success: false,
          errorMessage: '邮箱或密码错误',
          mode: AuthMode.local,
        );
      }

      // 验证密码 (假设 password_hash 存储在用户记录中)
      final storedHash = user['password_hash'] as String?;
      if (storedHash == null || storedHash.isEmpty) {
        return AuthResult(
          success: false,
          errorMessage: '用户密码未设置',
          mode: AuthMode.local,
        );
      }

      final hashedInput = SecurityService.hashPassword(password);
      if (hashedInput != storedHash) {
        return AuthResult(
          success: false,
          errorMessage: '邮箱或密码错误',
          mode: AuthMode.local,
        );
      }

      final userId = user['user_id'] as String? ?? user['id'] as String?;
      final username = user['username'] as String? ?? '';

      // 保存会话信息
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('user_email', email);
      await prefs.setString('user_username', username);

      return AuthResult(
        success: true,
        userId: userId,
        mode: AuthMode.local,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: '本地登录失败: $e',
        mode: AuthMode.local,
      );
    }
  }

  /// 本地注册
  /// 创建本地用户账号
  Future<AuthResult> localRegister({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      // 检查邮箱是否已存在
      final existingUser = await _userDb.getUserByEmail(email);
      if (existingUser != null) {
        return AuthResult(
          success: false,
          errorMessage: '该邮箱已被注册',
          mode: AuthMode.local,
        );
      }

      // 创建本地用户
      final userId = await _createLocalUser(
        username: username,
        email: email,
        password: password,
      );

      if (userId == null) {
        return AuthResult(
          success: false,
          errorMessage: '创建用户失败',
          mode: AuthMode.local,
        );
      }

      // 自动登录
      return await localLogin(email: email, password: password);
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: '注册失败: $e',
        mode: AuthMode.local,
      );
    }
  }

  /// 创建本地用户 (内部辅助方法)
  Future<String?> _createLocalUser({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final hashedPassword = SecurityService.hashPassword(password);

      final userData = {
        'user_id': userId,
        'username': username,
        'email': email,
        'password_hash': hashedPassword,
        'user_type': UserDatabaseService.userTypeBuyer,
        'status': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _userDb.insertUser(userData, null);
      return userId;
    } catch (e) {
      debugPrint('创建本地用户失败: $e');
      return null;
    }
  }

  // ==================== Supabase Auth 认证 ====================

  /// Supabase 云登录
  /// 需要网络连接，登录成功后可同步数据
  Future<AuthResult> cloudLogin({
    required String email,
    required String password,
  }) async {
    try {
      if (!_supabase.isInitialized) {
        return AuthResult(
          success: false,
          errorMessage: 'Supabase 未初始化，请先配置同步设置',
          mode: AuthMode.cloud,
        );
      }

      final response = await _supabase.signInWithEmail(email, password);

      if (response.user == null) {
        return AuthResult(
          success: false,
          errorMessage: '邮箱或密码错误',
          mode: AuthMode.cloud,
        );
      }

      // 保存会话信息到本地（缓存）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', response.user!.id);
      await prefs.setString('user_email', response.user!.email ?? '');
      await prefs.setString('user_username', response.user!.userMetadata?['username'] ?? '');

      // 同步本地用户数据
      await _syncUserFromCloud(response.user!);

      return AuthResult(
        success: true,
        userId: response.user!.id,
        mode: AuthMode.cloud,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: '云登录失败: $e',
        mode: AuthMode.cloud,
      );
    }
  }

  /// Supabase 云注册
  /// 创建云端账号，同时创建本地备份
  Future<AuthResult> cloudRegister({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      if (!_supabase.isInitialized) {
        return AuthResult(
          success: false,
          errorMessage: 'Supabase 未初始化，请先配置同步设置',
          mode: AuthMode.cloud,
        );
      }

      final response = await _supabase.signUp(email, password);

      if (response.user == null) {
        return AuthResult(
          success: false,
          errorMessage: '注册失败，请稍后重试',
          mode: AuthMode.cloud,
        );
      }

      // 保存用户信息到 Supabase
      await _supabase.client!.from('profiles').upsert({
        'id': response.user!.id,
        'username': username,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 同时在本地创建用户备份
      await _createLocalUser(
        username: username,
        email: email,
        password: '', // 云端用户没有本地密码
      );

      // 自动登录
      return await cloudLogin(email: email, password: password);
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: '云注册失败: $e',
        mode: AuthMode.cloud,
      );
    }
  }

  // ==================== 登出 ====================

  /// 登出
  /// 根据当前模式选择登出方式
  Future<void> logout() async {
    if (currentMode == AuthMode.cloud) {
      await cloudLogout();
    } else {
      await localLogout();
    }
  }

  /// 本地登出
  Future<void> localLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_username');
  }

  /// 云端登出
  Future<void> cloudLogout() async {
    try {
      await _supabase.signOut();
      await localLogout();
    } catch (e) {
      debugPrint('云端登出失败: $e');
      // 仍然清除本地会话
      await localLogout();
    }
  }

  // ==================== 账号链接 ====================

  /// 将本地账号链接到云端
  /// 用户先创建了本地账号，现在想同步到云端
  Future<AuthResult> linkLocalAccountToCloud({
    required String email,
    required String password,
  }) async {
    try {
      // 1. 获取当前本地用户
      final localUserId = await getCurrentUserId();
      if (localUserId == null) {
        return AuthResult(
          success: false,
          errorMessage: '未登录本地账号',
          mode: AuthMode.cloud,
        );
      }

      final localUser = await _userDb.getUserById(localUserId);
      if (localUser == null) {
        return AuthResult(
          success: false,
          errorMessage: '本地用户不存在',
          mode: AuthMode.cloud,
        );
      }

      // 2. 尝试在 Supabase 注册
      final response = await _supabase.signUp(email, password);

      if (response.user == null) {
        return AuthResult(
          success: false,
          errorMessage: '云端注册失败',
          mode: AuthMode.cloud,
        );
      }

      // 3. 保存用户名到云端
      await _supabase.client!.from('profiles').upsert({
        'id': response.user!.id,
        'username': localUser['username'],
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. 同步本地数据到云端
      // （由 SupabaseSyncManager 处理）

      return AuthResult(
        success: true,
        userId: response.user!.id,
        mode: AuthMode.cloud,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: '链接账号失败: $e',
        mode: AuthMode.cloud,
      );
    }
  }

  // ==================== 会话管理 ====================

  /// 恢复会话
  /// 应用启动时调用，尝试恢复之前的登录状态
  Future<AuthResult> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        return AuthResult(
          success: false,
          errorMessage: '无会话信息',
          mode: AuthMode.notLoggedIn,
        );
      }

      // 尝试恢复 Supabase 会话
      if (_supabase.isInitialized) {
        await _supabase.refreshSession();

        if (_supabase.currentUser != null) {
          return AuthResult(
            success: true,
            userId: _supabase.currentUser!.id,
            mode: AuthMode.cloud,
          );
        }
      }

      // 否则使用本地会话
      return AuthResult(
        success: true,
        userId: userId,
        mode: AuthMode.local,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: '恢复会话失败: $e',
        mode: AuthMode.notLoggedIn,
      );
    }
  }

  /// 监听认证状态变化
  Stream<AuthMode> get authModeStream {
    if (_supabase.isInitialized) {
      return _supabase.authStateChanges.map((event) {
        if (event.session != null) {
          return AuthMode.cloud;
        }
        return AuthMode.local;
      });
    }

    // 返回空流
    return Stream.value(AuthMode.local);
  }

  // ==================== 辅助方法 ====================

  /// 从云端同步用户信息到本地
  Future<void> _syncUserFromCloud(User cloudUser) async {
    try {
      final localUser = await _userDb.getUserById(cloudUser.id);

      if (localUser == null) {
        // 本地不存在，创建备份
        await _createLocalUser(
          username: cloudUser.userMetadata?['username'] ?? '',
          email: cloudUser.email ?? '',
          password: '', // 云端用户没有本地密码
        );
      } else {
        // 本地存在，更新信息
        final updatedData = {
          'username': cloudUser.userMetadata?['username'] ?? localUser['username'],
          'email': cloudUser.email ?? localUser['email'],
        };
        await _userDb.updateUser(cloudUser.id, updatedData, null);
      }
    } catch (e) {
      debugPrint('同步用户信息失败: $e');
    }
  }
}

/// 认证模式枚举
enum AuthMode {
  notLoggedIn, // 未登录
  local,       // 本地登录
  cloud,       // 云端登录
}

/// 认证模式扩展
extension AuthModeExtension on AuthMode {
  String get displayName {
    switch (this) {
      case AuthMode.notLoggedIn:
        return '未登录';
      case AuthMode.local:
        return '本地账号';
      case AuthMode.cloud:
        return '云端账号';
    }
  }
}

/// 认证结果
class AuthResult {
  final bool success;
  final String? userId;
  final AuthMode mode;
  final String? errorMessage;

  AuthResult({
    required this.success,
    this.userId,
    required this.mode,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'AuthResult{success: $success, userId: $userId, mode: $mode, errorMessage: $errorMessage}';
  }
}
