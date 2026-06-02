import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// 安全服务
/// 负责数据加密、密码哈希和访问控制
class SecurityService {
  // 安全存储实例
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  // 内存存储（用于测试模式）
  static final Map<String, String> _memoryStorage = {};
  // 加密密钥
  static Encrypter? _encrypter;
  // 初始化状态
  static bool _isInitialized = false;
  // 测试模式
  static bool _isTestMode = false;

  /// 设置测试模式
  /// 在测试环境中使用模拟实现
  static void setTestMode() {
    _isTestMode = true;
  }

  /// 初始化安全服务
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // 生成或获取加密密钥
    await _initEncryption();
    
    _isInitialized = true;
  }

  /// 初始化加密
  static Future<void> _initEncryption() async {
    try {
      Key key;

      if (_isTestMode) {
        // 测试模式：使用固定密钥
        final keyBytes = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          keyBytes[i] = i % 256;
        }
        key = Key(keyBytes);
      } else {
        // 正常模式：从安全存储获取密钥
        // 尝试从安全存储获取密钥
        String? keyString = await _secureStorage.read(key: 'encryption_key');

        if (keyString == null) {
          // 生成新密钥
          final random = Random.secure();
          final keyBytes = Uint8List(32);
          for (int i = 0; i < 32; i++) {
            keyBytes[i] = random.nextInt(256);
          }
          key = Key(keyBytes);
          // 保存密钥
          await _secureStorage.write(key: 'encryption_key', value: base64.encode(key.bytes));
        } else {
          // 使用现有密钥
          key = Key(base64.decode(keyString));
        }
      }

      // 创建加密器
      final iv = IV.fromLength(16);
      _encrypter = Encrypter(AES(key));
    } catch (e) {
      print('加密初始化失败: $e');
    }
  }

  /// 加密数据
  /// [data] 要加密的数据
  static String? encrypt(String data) {
    if (!_isInitialized || _encrypter == null) {
      print('安全服务未初始化');
      return null;
    }

    try {
      final iv = IV.fromLength(16);
      final encrypted = _encrypter!.encrypt(data, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print('加密失败: $e');
      return null;
    }
  }

  /// 解密数据
  /// [encryptedData] 加密的数据
  static String? decrypt(String encryptedData) {
    if (!_isInitialized || _encrypter == null) {
      print('安全服务未初始化');
      return null;
    }

    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        throw Exception('无效的加密数据格式');
      }
      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('解密失败: $e');
      return null;
    }
  }

  /// 哈希密码
  /// [password] 原始密码
  static String hashPassword(String password) {
    try {
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('密码哈希失败: $e');
      return password;
    }
  }

  /// 验证密码
  /// [password] 原始密码
  /// [hashedPassword] 哈希后的密码
  static bool verifyPassword(String password, String hashedPassword) {
    try {
      final hashed = hashPassword(password);
      return hashed == hashedPassword;
    } catch (e) {
      print('密码验证失败: $e');
      return false;
    }
  }

  /// 安全存储数据
  /// [key] 键
  /// [value] 值
  static Future<bool> secureStore(String key, String value) async {
    try {
      if (_isTestMode) {
        // 测试模式：使用内存存储
        _memoryStorage[key] = value;
        return true;
      } else {
        // 正常模式：使用安全存储
        await _secureStorage.write(key: key, value: value);
        return true;
      }
    } catch (e) {
      print('安全存储失败: $e');
      return false;
    }
  }

  /// 安全读取数据
  /// [key] 键
  static Future<String?> secureRead(String key) async {
    try {
      if (_isTestMode) {
        // 测试模式：使用内存存储
        return _memoryStorage[key];
      } else {
        // 正常模式：使用安全存储
        return await _secureStorage.read(key: key);
      }
    } catch (e) {
      print('安全读取失败: $e');
      return null;
    }
  }

  /// 安全删除数据
  /// [key] 键
  static Future<bool> secureDelete(String key) async {
    try {
      if (_isTestMode) {
        // 测试模式：使用内存存储
        _memoryStorage.remove(key);
        return true;
      } else {
        // 正常模式：使用安全存储
        await _secureStorage.delete(key: key);
        return true;
      }
    } catch (e) {
      print('安全删除失败: $e');
      return false;
    }
  }

  /// 生成随机令牌
  /// [length] 令牌长度
  static String generateToken({int length = 32}) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64.encode(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  }

  /// 验证访问权限
  /// [userId] 用户ID
  /// [requiredRole] 所需角色
  static Future<bool> checkAccess(String userId, int requiredRole) async {
    try {
      // 这里可以根据实际的权限系统实现
      // 暂时返回true，实际项目中需要根据用户角色进行验证
      return true;
    } catch (e) {
      print('权限检查失败: $e');
      return false;
    }
  }

  /// 加密文件
  /// [data] 文件数据
  static Uint8List? encryptFile(Uint8List data) {
    if (!_isInitialized || _encrypter == null) {
      print('安全服务未初始化');
      return null;
    }

    try {
      final iv = IV.fromLength(16);
      final encrypted = _encrypter!.encryptBytes(data, iv: iv);
      // 前16字节是IV，后面是加密数据
      final result = Uint8List(16 + encrypted.bytes.length);
      result.setAll(0, iv.bytes);
      result.setAll(16, encrypted.bytes);
      return result;
    } catch (e) {
      print('文件加密失败: $e');
      return null;
    }
  }

  /// 解密文件
  /// [encryptedData] 加密的文件数据
  static Uint8List? decryptFile(Uint8List encryptedData) {
    if (!_isInitialized || _encrypter == null) {
      print('安全服务未初始化');
      return null;
    }

    try {
      if (encryptedData.length < 16) {
        throw Exception('无效的加密文件数据');
      }
      // 前16字节是IV，后面是加密数据
      final iv = IV(Uint8List.view(encryptedData.buffer, 0, 16));
      final encrypted = Encrypted(Uint8List.view(encryptedData.buffer, 16));
      final decryptedList = _encrypter!.decryptBytes(encrypted, iv: iv);
      return Uint8List.fromList(decryptedList);
    } catch (e) {
      print('文件解密失败: $e');
      return null;
    }
  }

  /// 生成安全的随机密码
  /// [length] 密码长度
  static String generateSecurePassword({int length = 12}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()_+-=[]{}|;:,.<>?';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// 检查密码强度
  /// [password] 密码
  static int checkPasswordStrength(String password) {
    int strength = 0;
    
    // 长度检查
    if (password.length >= 8) strength += 1;
    if (password.length >= 12) strength += 1;
    
    // 包含数字
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 1;
    
    // 包含小写字母
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 1;
    
    // 包含大写字母
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 1;
    
    // 包含特殊字符
    if (RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password)) strength += 1;
    
    return strength;
  }

  /// 获取密码强度描述
  /// [strength] 密码强度值
  static String getPasswordStrengthDescription(int strength) {
    switch (strength) {
      case 0:
        return '非常弱';
      case 1:
        return '弱';
      case 2:
        return '一般';
      case 3:
        return '良好';
      case 4:
        return '强';
      case 5:
        return '非常强';
      default:
        return '未知';
    }
  }
}
