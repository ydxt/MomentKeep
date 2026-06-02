import 'package:equatable/equatable.dart';

/// 用户认证信息实体类
class UserAuth extends Equatable {
  /// 唯一标识符
  final String id;

  /// 用户名
  final String username;

  /// 邮箱
  final String email;

  /// 用户头像路径
  final String? avatar;

  /// 是否启用生物识别登录
  final bool isBiometricEnabled;

  /// 是否为管理员
  final bool isAdmin;

  /// 上次登录时间
  final DateTime lastLoginAt;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 构造函数
  const UserAuth({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    required this.isBiometricEnabled,
    required this.isAdmin,
    required this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 复制方法，用于更新用户认证信息
  UserAuth copyWith({
    String? id,
    String? username,
    String? email,
    String? avatar,
    bool? isBiometricEnabled,
    bool? isAdmin,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAuth(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isAdmin: isAdmin ?? this.isAdmin,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        avatar,
        isBiometricEnabled,
        isAdmin,
        lastLoginAt,
        createdAt,
        updatedAt,
      ];
}

/// 生物识别设置实体类
class BiometricSettings extends Equatable {
  /// 是否启用生物识别登录
  final bool isEnabled;

  /// 生物识别类型（指纹/面部识别）
  final String biometricType;

  /// 是否需要重新验证
  final bool requireReauthentication;

  /// 重新验证间隔（秒）
  final int reauthenticationInterval;

  /// 构造函数
  const BiometricSettings({
    required this.isEnabled,
    required this.biometricType,
    required this.requireReauthentication,
    required this.reauthenticationInterval,
  });

  /// 复制方法，用于更新生物识别设置
  BiometricSettings copyWith({
    bool? isEnabled,
    String? biometricType,
    bool? requireReauthentication,
    int? reauthenticationInterval,
  }) {
    return BiometricSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      biometricType: biometricType ?? this.biometricType,
      requireReauthentication:
          requireReauthentication ?? this.requireReauthentication,
      reauthenticationInterval:
          reauthenticationInterval ?? this.reauthenticationInterval,
    );
  }

  @override
  List<Object?> get props => [
        isEnabled,
        biometricType,
        requireReauthentication,
        reauthenticationInterval,
      ];
}

/// 加密设置实体类
class EncryptionSettings extends Equatable {
  /// 是否启用端到端加密
  final bool isEnabled;

  /// 加密算法
  final String algorithm;

  /// 密钥长度
  final int keyLength;

  /// 上次密钥更新时间
  final DateTime lastKeyUpdateAt;

  /// 是否启用自动密钥更新
  final bool isAutoKeyUpdateEnabled;

  /// 密钥更新间隔（天）
  final int keyUpdateInterval;

  /// 构造函数
  const EncryptionSettings({
    required this.isEnabled,
    required this.algorithm,
    required this.keyLength,
    required this.lastKeyUpdateAt,
    required this.isAutoKeyUpdateEnabled,
    required this.keyUpdateInterval,
  });

  /// 复制方法，用于更新加密设置
  EncryptionSettings copyWith({
    bool? isEnabled,
    String? algorithm,
    int? keyLength,
    DateTime? lastKeyUpdateAt,
    bool? isAutoKeyUpdateEnabled,
    int? keyUpdateInterval,
  }) {
    return EncryptionSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      algorithm: algorithm ?? this.algorithm,
      keyLength: keyLength ?? this.keyLength,
      lastKeyUpdateAt: lastKeyUpdateAt ?? this.lastKeyUpdateAt,
      isAutoKeyUpdateEnabled:
          isAutoKeyUpdateEnabled ?? this.isAutoKeyUpdateEnabled,
      keyUpdateInterval: keyUpdateInterval ?? this.keyUpdateInterval,
    );
  }

  @override
  List<Object?> get props => [
        isEnabled,
        algorithm,
        keyLength,
        lastKeyUpdateAt,
        isAutoKeyUpdateEnabled,
        keyUpdateInterval,
      ];
}
