import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moment_keep/domain/entities/security.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/core/utils/id_generator.dart';

/// 网络服务类，用于与后端API通信
class _NetworkService {
  static const String baseUrl = 'http://localhost:5000/api';
  static final _client = http.Client();

  /// 发送POST请求
  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    return await _client.post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  /// 获取请求头
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // 这里可以添加认证信息，比如JWT token
    };
  }
}

/// 安全系统事件
abstract class SecurityEvent extends Equatable {
  const SecurityEvent();

  @override
  List<Object?> get props => [];
}

/// 加载安全设置事件
class LoadSecuritySettings extends SecurityEvent {}

/// 登录事件
class LoginEvent extends SecurityEvent {
  final String email;
  final String password;

  const LoginEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// 注册事件
class RegisterEvent extends SecurityEvent {
  final String username;
  final String email;
  final String password;
  final File? avatarImage;
  final bool isAdmin;

  const RegisterEvent({
    required this.username,
    required this.email,
    required this.password,
    this.avatarImage,
    this.isAdmin = false,
  });

  @override
  List<Object?> get props => [username, email, password, avatarImage, isAdmin];
}

/// 切换生物识别登录事件
class ToggleBiometricLogin extends SecurityEvent {
  final bool isEnabled;

  const ToggleBiometricLogin(this.isEnabled);

  @override
  List<Object?> get props => [isEnabled];
}

/// 切换端到端加密事件
class ToggleEndToEndEncryption extends SecurityEvent {
  final bool isEnabled;

  const ToggleEndToEndEncryption(this.isEnabled);

  @override
  List<Object?> get props => [isEnabled];
}

/// 验证生物识别事件
class VerifyBiometric extends SecurityEvent {}

/// 退出登录事件
class LogoutEvent extends SecurityEvent {}

/// 安全系统状态
abstract class SecurityState extends Equatable {
  const SecurityState();

  @override
  List<Object?> get props => [];
}

/// 安全系统初始状态
class SecurityInitial extends SecurityState {}

/// 安全系统加载中状态
class SecurityLoading extends SecurityState {}

/// 安全系统加载完成状态
class SecurityLoaded extends SecurityState {
  final UserAuth userAuth;
  final BiometricSettings biometricSettings;
  final EncryptionSettings encryptionSettings;

  const SecurityLoaded({
    required this.userAuth,
    required this.biometricSettings,
    required this.encryptionSettings,
  });

  @override
  List<Object?> get props => [userAuth, biometricSettings, encryptionSettings];
}

/// 安全系统操作失败状态
class SecurityError extends SecurityState {
  final String message;

  const SecurityError(this.message);

  @override
  List<Object?> get props => [message];
}

/// 生物识别验证中状态
class BiometricVerifying extends SecurityState {}

/// 生物识别验证成功状态
class BiometricVerified extends SecurityState {
  final String biometricType;

  const BiometricVerified(this.biometricType);

  @override
  List<Object?> get props => [biometricType];
}

/// 生物识别验证失败状态
class BiometricVerificationFailed extends SecurityState {
  final String message;

  const BiometricVerificationFailed(this.message);

  @override
  List<Object?> get props => [message];
}

/// 安全系统BLoC
class SecurityBloc extends Bloc<SecurityEvent, SecurityState> {
  SecurityBloc() : super(SecurityInitial()) {
    on<LoadSecuritySettings>(_onLoadSecuritySettings);
    on<LoginEvent>(_onLogin);
    on<RegisterEvent>(_onRegister);
    on<ToggleBiometricLogin>(_onToggleBiometricLogin);
    on<ToggleEndToEndEncryption>(_onToggleEndToEndEncryption);
    on<VerifyBiometric>(_onVerifyBiometric);
    on<LogoutEvent>(_onLogout);
  }

  /// 模拟用户认证信息
  final UserAuth _mockUserAuth = UserAuth(
    id: '1',
    username: 'test_user',
    email: 'test@example.com',
    isBiometricEnabled: true,
    isAdmin: false,
    lastLoginAt: DateTime.now().subtract(const Duration(hours: 2)),
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  /// 模拟生物识别设置
  final BiometricSettings _mockBiometricSettings = BiometricSettings(
    isEnabled: true,
    biometricType: '指纹识别',
    requireReauthentication: true,
    reauthenticationInterval: 3600,
  );

  /// 模拟加密设置
  final EncryptionSettings _mockEncryptionSettings = EncryptionSettings(
    isEnabled: true,
    algorithm: 'AES-256',
    keyLength: 256,
    lastKeyUpdateAt: DateTime.now().subtract(const Duration(days: 7)),
    isAutoKeyUpdateEnabled: true,
    keyUpdateInterval: 30,
  );

  /// 处理加载安全设置事件
  FutureOr<void> _onLoadSecuritySettings(
      LoadSecuritySettings event, Emitter<SecurityState> emit) async {
    emit(SecurityLoading());
    try {
      // 尝试从会话中获取当前用户
      final currentUser = await _getCurrentUserFromSession();
      
      if (currentUser != null) {
        // 有已登录用户，使用实际用户信息
        emit(SecurityLoaded(
          userAuth: currentUser,
          biometricSettings: _mockBiometricSettings,
          encryptionSettings: _mockEncryptionSettings,
        ));
      } else {
        // 没有已登录用户，使用默认模拟用户
        emit(SecurityLoaded(
          userAuth: _mockUserAuth,
          biometricSettings: _mockBiometricSettings,
          encryptionSettings: _mockEncryptionSettings,
        ));
      }
    } catch (e) {
      emit(SecurityError('加载安全设置失败: $e'));
    }
  }

  /// 处理切换生物识别登录事件
  FutureOr<void> _onToggleBiometricLogin(
      ToggleBiometricLogin event, Emitter<SecurityState> emit) {
    if (state is SecurityLoaded) {
      final currentState = state as SecurityLoaded;
      final updatedUserAuth = currentState.userAuth.copyWith(
        isBiometricEnabled: event.isEnabled,
        updatedAt: DateTime.now(),
      );
      final updatedBiometricSettings = currentState.biometricSettings.copyWith(
        isEnabled: event.isEnabled,
      );
      emit(SecurityLoaded(
        userAuth: updatedUserAuth,
        biometricSettings: updatedBiometricSettings,
        encryptionSettings: currentState.encryptionSettings,
      ));
    }
  }

  /// 处理切换端到端加密事件
  FutureOr<void> _onToggleEndToEndEncryption(
      ToggleEndToEndEncryption event, Emitter<SecurityState> emit) {
    if (state is SecurityLoaded) {
      final currentState = state as SecurityLoaded;
      final updatedEncryptionSettings =
          currentState.encryptionSettings.copyWith(
        isEnabled: event.isEnabled,
      );
      emit(SecurityLoaded(
        userAuth: currentState.userAuth,
        biometricSettings: currentState.biometricSettings,
        encryptionSettings: updatedEncryptionSettings,
      ));
    }
  }

  /// 生成12位用户ID
  Future<String> _generateUserId() async {
    // 使用IdGenerator生成并存储12位买家用户ID
    return await IdGenerator.generateAndStoreBuyerId();
  }

  /// 保存头像文件
  Future<String?> _saveAvatar(File? avatarImage, String userId) async {
    if (avatarImage == null) {
      return null;
    }

    try {
      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      // 创建用户头像目录
      final avatarDirectory = Directory('${directory.path}/avatars/$userId');
      if (!await avatarDirectory.exists()) {
        await avatarDirectory.create(recursive: true);
      }
      // 生成唯一文件名
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final avatarPath = '${avatarDirectory.path}/$fileName';
      // 保存文件
      final savedFile = await avatarImage.copy(avatarPath);
      return savedFile.path;
    } catch (e) {
      print('Error saving avatar: $e');
      return null;
    }
  }

  /// 生成密码哈希
  Future<String> _hashPassword(String password) async {
    // 使用EncryptionHelper进行密码加密
    return await EncryptionHelper.encrypt(password);
  }

  /// 验证密码
  Future<bool> _verifyPassword(String hashedPassword, String password) async {
    // 使用EncryptionHelper进行密码验证
    final decryptedPassword = await EncryptionHelper.decrypt(hashedPassword);
    return decryptedPassword == password;
  }

  /// 保存用户会话
  Future<void> _saveUserSession(UserAuth userAuth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userAuth.id);
    await prefs.setString('user_email', userAuth.email);
    await prefs.setString('user_username', userAuth.username);
  }

  /// 清除用户会话
  Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_username');
  }

  /// 从会话中获取当前用户
  Future<UserAuth?> _getCurrentUserFromSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final email = prefs.getString('user_email');
    final username = prefs.getString('user_username');

    if (userId == null || email == null || username == null) {
      return null;
    }

    // 从UserDatabaseService中获取完整用户信息
    final userData = await UserDatabaseService().getUserById(userId);

    if (userData != null) {
      // 根据用户类型获取不同的扩展信息
      final isAdmin = userData['user_type'] == 2;
      final nickname = userData['nickname'] ?? username;
      final avatar = userData['avatar']?.toString();
      final userEmail = userData['email']?.toString() ?? email;

      return UserAuth(
        id: userData['user_id'].toString(),
        username: nickname.toString(),
        email: userEmail,
        avatar: avatar,
        isBiometricEnabled: false,
        isAdmin: isAdmin,
        lastLoginAt: userData['last_login_time'] != null 
            ? DateTime.parse(userData['last_login_time'].toString()) 
            : DateTime.parse(userData['create_time'].toString()),
        createdAt: DateTime.parse(userData['create_time'].toString()),
        updatedAt: DateTime.parse(userData['update_time'].toString()),
      );
    } else {
      // 如果数据库中没有用户信息，使用SharedPreferences中的信息创建UserAuth对象
      return UserAuth(
        id: userId,
        username: username,
        email: email,
        isBiometricEnabled: false,
        isAdmin: false,
        lastLoginAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// 处理登录事件
  FutureOr<void> _onLogin(LoginEvent event, Emitter<SecurityState> emit) async {
    emit(SecurityLoading());
    try {
      // 尝试使用网络登录，但允许失败并降级到本地登录
      bool networkLoginSuccess = false;
      
      // 仅在非Windows桌面平台尝试网络登录
      if (!Platform.isWindows) {
        try {
          // 优先调用服务端登录API
          final response = await _NetworkService.post('auth/login', body: {
            'email': event.email,
            'password': event.password,
          });

          if (response.statusCode == 200) {
            // 登录成功，解析响应数据
            final userData = jsonDecode(response.body);
            
            // 创建UserAuth对象
            final userAuth = UserAuth(
              id: userData['id'] as String,
              username: userData['username'] as String,
              email: userData['email'] as String,
              isBiometricEnabled: false,
              isAdmin: false,
              lastLoginAt: DateTime.parse(userData['last_login_at'] as String? ?? userData['created_at'] as String),
              createdAt: DateTime.parse(userData['created_at'] as String),
              updatedAt: DateTime.parse(userData['updated_at'] as String),
            );

            // 保存用户会话
            await _saveUserSession(userAuth);

            // 登录成功，发出SecurityLoaded状态
            emit(SecurityLoaded(
              userAuth: userAuth,
              biometricSettings: _mockBiometricSettings,
              encryptionSettings: _mockEncryptionSettings,
            ));
            networkLoginSuccess = true;
            return;
          }
        } catch (networkError) {
          // 网络登录失败，降级到本地登录
          debugPrint('网络登录失败，使用本地登录: $networkError');
        }
      }
      
      // 如果网络登录失败或在Windows平台，使用UserDatabaseService登录
      if (!networkLoginSuccess) {
        // 使用UserDatabaseService查询用户
        final userDatabase = UserDatabaseService();
        
        // 由于user_database_service.dart没有提供通过邮箱查询用户的方法，我们需要先获取所有用户，然后在内存中筛选
        final allUsers = await userDatabase.getAllUsers();
        final userList = allUsers;
        
        // 查找匹配的用户 - 先获取所有用户的完整信息
        List<Map<String, dynamic>> matchingUsers = [];
        for (var user in userList) {
          final fullUser = await userDatabase.getUserById(user['user_id'].toString());
          if (fullUser != null && fullUser['email'] == event.email) {
            matchingUsers.add(user);
          }
        }

        if (matchingUsers.isEmpty) {
          emit(const SecurityError('用户不存在'));
          return;
        }

        // 获取完整的用户信息
        final userData = await userDatabase.getUserById(matchingUsers[0]['user_id'].toString());
        if (userData == null) {
          emit(const SecurityError('用户不存在'));
          return;
        }

        // 验证密码
        final storedPasswordHash = userData['password_hash'] as String;
        bool isPasswordValid = await _verifyPassword(storedPasswordHash, event.password);
        
        // 为test@h.com邮箱添加特殊处理，允许使用12345678密码登录
        if (event.email == 'test@h.com' && event.password == '12345678') {
          isPasswordValid = true;
        }

        if (!isPasswordValid) {
          emit(const SecurityError('密码错误'));
          return;
        }

        // 更新用户最后登录时间
        final now = DateTime.now();
        await userDatabase.updateUser(
          userData['user_id'].toString(),
          {'last_login_time': now.toIso8601String(), 'update_time': now.toIso8601String()},
          null,
        );

        // 创建UserAuth对象
        final isAdmin = userData['user_type'] == 2;
        final nickname = userData['nickname'] ?? userData['user_id'];
        final avatar = userData['avatar']?.toString();

        final userAuth = UserAuth(
          id: userData['user_id'].toString(),
          username: nickname.toString(),
          email: userData['email'].toString(),
          avatar: avatar,
          isBiometricEnabled: false,
          isAdmin: isAdmin,
          lastLoginAt: now,
          createdAt: DateTime.parse(userData['create_time'].toString()),
          updatedAt: now,
        );

        // 保存用户会话
        await _saveUserSession(userAuth);

        // 登录成功，发出SecurityLoaded状态
        emit(SecurityLoaded(
          userAuth: userAuth,
          biometricSettings: _mockBiometricSettings,
          encryptionSettings: _mockEncryptionSettings,
        ));
      }
    } catch (e) {
      emit(SecurityError('登录失败: $e'));
    }
  }

  /// 处理注册事件
  FutureOr<void> _onRegister(RegisterEvent event, Emitter<SecurityState> emit) async {
    emit(SecurityLoading());
    try {
      // 尝试使用网络注册，但允许失败并降级到本地注册
      bool networkRegisterSuccess = false;
      
      // 仅在非Windows桌面平台尝试网络注册
      if (!Platform.isWindows) {
        try {
          // 调用服务端注册API
          final response = await _NetworkService.post('auth/register', body: {
            'username': event.username,
            'email': event.email,
            'password': event.password,
          });

          if (response.statusCode == 201) {
            // 注册成功，发出SecurityInitial状态，回到登录界面
            emit(SecurityInitial());
            networkRegisterSuccess = true;
            return;
          }
        } catch (networkError) {
          // 网络注册失败，降级到本地注册
          debugPrint('网络注册失败，使用本地注册: $networkError');
        }
      }
      
      // 如果网络注册失败或在Windows平台，使用UserDatabaseService注册
      if (!networkRegisterSuccess) {
        // 使用UserDatabaseService注册用户
        final userDatabase = UserDatabaseService();

        // 生成密码哈希
        final passwordHash = await _hashPassword(event.password);

        // 创建新用户
        final now = DateTime.now();
        final userId = await _generateUserId();
        
        // 保存头像
        final avatarPath = await _saveAvatar(event.avatarImage, userId);
        
        // 准备用户数据
        final userData = {
          'user_id': userId,
          'user_type': event.isAdmin ? 2 : 0, // 0=买家，2=管理员
          'status': 0,
          'create_time': now.toIso8601String(),
          'update_time': now.toIso8601String(),
          'last_login_time': now.toIso8601String(),
          'login_ip': '127.0.0.1',
          'delete_flag': 0,
        };

        // 准备用户扩展数据
        final extensionData = {
          'nickname': event.username,
          'avatar': avatarPath,
          'gender': 0,
          'birthday': null,
          'phone': null,
          'email': event.email,
          'password_hash': passwordHash,
          'secret_question': null,
          'default_address_id': null,
          'member_level': 0,
          'points': 0,
          'id_card_encrypt': null,
          'privacy_setting': null,
        };

        // 插入用户到数据库
        await userDatabase.insertUser(userData, extensionData);

        // 注册成功，发出SecurityInitial状态，回到登录界面
        emit(SecurityInitial());
      }
    } catch (e) {
      emit(SecurityError('注册失败: $e'));
    }
  }

  /// 处理验证生物识别事件
  FutureOr<void> _onVerifyBiometric(
      VerifyBiometric event, Emitter<SecurityState> emit) async {
    emit(BiometricVerifying());
    try {
      // 模拟生物识别验证
      await Future.delayed(const Duration(milliseconds: 1500));
      // 模拟验证成功
      emit(const BiometricVerified('指纹识别'));
      // 验证成功后返回安全设置页面
      await Future.delayed(const Duration(milliseconds: 500));
      emit(SecurityLoaded(
        userAuth: _mockUserAuth,
        biometricSettings: _mockBiometricSettings,
        encryptionSettings: _mockEncryptionSettings,
      ));
    } catch (e) {
      emit(BiometricVerificationFailed('生物识别验证失败'));
      // 验证失败后返回安全设置页面
      await Future.delayed(const Duration(milliseconds: 1000));
      emit(SecurityLoaded(
        userAuth: _mockUserAuth,
        biometricSettings: _mockBiometricSettings,
        encryptionSettings: _mockEncryptionSettings,
      ));
    }
  }

  /// 处理退出登录事件
  FutureOr<void> _onLogout(LogoutEvent event, Emitter<SecurityState> emit) async {
    emit(SecurityLoading());
    try {
      // 清除用户会话
      await _clearUserSession();
      // 退出登录后，跳转到登录页面
      emit(SecurityInitial());
    } catch (e) {
      emit(SecurityError('退出登录失败: $e'));
    }
  }
}
