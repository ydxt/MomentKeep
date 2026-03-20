import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:moment_keep/services/storage_path_service.dart';

/// 密码重置令牌服务类
/// 负责生成、存储、验证和管理密码重置令牌
class PasswordResetService {
  /// 静态单例实例
  static final PasswordResetService _instance = PasswordResetService._internal();

  /// 私有构造函数
  PasswordResetService._internal();

  /// 工厂构造函数返回单例
  factory PasswordResetService() => _instance;

  /// UUID生成器实例
  static const Uuid _uuid = Uuid();

  /// 随机数生成器（加密安全）
  static final Random _secureRandom = Random.secure();

  /// 默认令牌过期时间（小时）
  static const int _defaultExpirationHours = 24;

  /// 使用简单的日志函数
  void _log(String message) {
    if (kDebugMode) {
      print('[PasswordResetService] $message');
    }
  }

  /// 生成加密安全的密码重置令牌
  /// [useUuid] 是否使用UUID格式，默认为true
  /// 返回生成的令牌字符串
  String generateResetToken({bool useUuid = true}) {
    if (useUuid) {
      return _uuid.v4();
    } else {
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final buffer = StringBuffer();
      for (int i = 0; i < 32; i++) {
        buffer.write(chars[_secureRandom.nextInt(chars.length)]);
      }
      return buffer.toString();
    }
  }

  /// 创建并保存密码重置令牌
  /// [userId] 用户ID
  /// [email] 用户邮箱
  /// [expirationHours] 令牌有效期（小时），默认为24小时
  /// 返回创建的令牌信息
  Future<PasswordResetToken> createResetToken(
    String userId,
    String email, {
    int expirationHours = _defaultExpirationHours,
  }) async {
    final token = generateResetToken();
    final now = DateTime.now();
    final expirationTime = now.add(Duration(hours: expirationHours));

    final resetToken = PasswordResetToken(
      token: token,
      userId: userId,
      email: email,
      createdAt: now,
      expiresAt: expirationTime,
      isUsed: false,
    );

    await _saveTokenToFile(resetToken);
    _log('创建密码重置令牌成功: userId=$userId, email=$email, token=$token');

    return resetToken;
  }

  /// 验证密码重置令牌的有效性
  /// [token] 待验证的令牌
  /// 返回令牌信息，如果无效则返回null
  Future<PasswordResetToken?> verifyToken(String token) async {
    final resetToken = await _loadTokenFromFile(token);

    if (resetToken == null) {
      _log('令牌验证失败: 令牌不存在 - $token');
      return null;
    }

    if (resetToken.isUsed) {
      _log('令牌验证失败: 令牌已使用 - $token');
      return null;
    }

    if (DateTime.now().isAfter(resetToken.expiresAt)) {
      _log('令牌验证失败: 令牌已过期 - $token');
      return null;
    }

    _log('令牌验证成功: $token');
    return resetToken;
  }

  /// 标记令牌为已使用
  /// [token] 要标记的令牌
  /// 返回是否成功标记
  Future<bool> markTokenAsUsed(String token) async {
    final resetToken = await _loadTokenFromFile(token);

    if (resetToken == null) {
      _log('标记令牌失败: 令牌不存在 - $token');
      return false;
    }

    final updatedToken = resetToken.copyWith(isUsed: true);
    await _saveTokenToFile(updatedToken);
    _log('标记令牌为已使用成功: $token');

    return true;
  }

  /// 根据邮箱查找所有有效的重置令牌
  /// [email] 用户邮箱
  /// 返回有效的令牌列表
  Future<List<PasswordResetToken>> findValidTokensByEmail(String email) async {
    final directory = await StoragePathService.getPasswordResetsDirectory();
    final dir = Directory(directory);

    if (!await dir.exists()) {
      return [];
    }

    final validTokens = <PasswordResetToken>[];
    final now = DateTime.now();

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final token = PasswordResetToken.fromJson(json);

          if (token.email == email && !token.isUsed && now.isBefore(token.expiresAt)) {
            validTokens.add(token);
          }
        } catch (e) {
          _log('读取令牌文件失败: ${entity.path}, error: $e');
        }
      }
    }

    return validTokens;
  }

  /// 删除过期或已使用的令牌文件
  /// 返回清理的文件数量
  Future<int> cleanupExpiredTokens() async {
    final directory = await StoragePathService.getPasswordResetsDirectory();
    final dir = Directory(directory);

    if (!await dir.exists()) {
      return 0;
    }

    int cleanedCount = 0;
    final now = DateTime.now();

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final token = PasswordResetToken.fromJson(json);

          if (token.isUsed || now.isAfter(token.expiresAt)) {
            await entity.delete();
            cleanedCount++;
            _log('清理令牌文件: ${entity.path}');
          }
        } catch (e) {
          _log('清理令牌文件失败: ${entity.path}, error: $e');
        }
      }
    }

    return cleanedCount;
  }

  /// 将令牌保存到文件
  /// [token] 令牌对象
  Future<void> _saveTokenToFile(PasswordResetToken token) async {
    final directory = await StoragePathService.getPasswordResetsDirectory();
    final file = File('$directory/${token.token}.json');

    await file.writeAsString(jsonEncode(token.toJson()));
  }

  /// 从文件加载令牌
  /// [token] 令牌字符串
  /// 返回令牌对象，如果文件不存在则返回null
  Future<PasswordResetToken?> _loadTokenFromFile(String token) async {
    final directory = await StoragePathService.getPasswordResetsDirectory();
    final file = File('$directory/$token.json');

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return PasswordResetToken.fromJson(json);
    } catch (e) {
      _log('加载令牌文件失败: $token, error: $e');
      return null;
    }
  }
}

/// 密码重置令牌数据模型
class PasswordResetToken {
  /// 令牌字符串
  final String token;

  /// 用户ID
  final String userId;

  /// 用户邮箱
  final String email;

  /// 创建时间
  final DateTime createdAt;

  /// 过期时间
  final DateTime expiresAt;

  /// 是否已使用
  final bool isUsed;

  PasswordResetToken({
    required this.token,
    required this.userId,
    required this.email,
    required this.createdAt,
    required this.expiresAt,
    required this.isUsed,
  });

  /// 从JSON创建令牌对象
  factory PasswordResetToken.fromJson(Map<String, dynamic> json) {
    return PasswordResetToken(
      token: json['token'] as String,
      userId: json['user_id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isUsed: json['is_used'] as bool,
    );
  }

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user_id': userId,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_used': isUsed,
    };
  }

  /// 创建副本并更新指定字段
  PasswordResetToken copyWith({
    String? token,
    String? userId,
    String? email,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
  }) {
    return PasswordResetToken(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
    );
  }
}
