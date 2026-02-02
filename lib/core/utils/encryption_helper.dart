import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 加密工具类，用于AES-256加密和解密
class EncryptionHelper {
  /// 安全存储实例
  static final _secureStorage = FlutterSecureStorage();

  /// 加密密钥存储键
  static const _keyStorageKey = 'moment_keep_encryption_key';

  /// 初始化向量存储键
  static const _ivStorageKey = 'moment_keep_iv';

  /// 初始化加密工具
  /// 如果不存在密钥，会生成新的密钥并存储
  static Future<void> initialize() async {
    // 检查是否已经存在密钥
    final existingKey = await _readKey(_keyStorageKey);
    if (existingKey == null) {
      // 生成新的32字节密钥（AES-256）
      final key = Key.fromSecureRandom(32);
      await _writeKey(_keyStorageKey, key.base64);

      // 生成新的16字节初始化向量
      final iv = IV.fromSecureRandom(16);
      await _writeKey(_ivStorageKey, iv.base64);
    }
  }

  /// 获取加密密钥
  static Future<Key> _getKey() async {
    final keyBase64 = await _readKey(_keyStorageKey);
    if (keyBase64 == null) {
      throw Exception('Encryption key not found');
    }
    return Key.fromBase64(keyBase64);
  }

  /// 获取初始化向量
  static Future<IV> _getIV() async {
    final ivBase64 = await _readKey(_ivStorageKey);
    if (ivBase64 == null) {
      throw Exception('Initialization vector not found');
    }
    return IV.fromBase64(ivBase64);
  }

  /// 平台特定的密钥读取方法
  /// 在Web平台上使用SharedPreferences，其他平台使用FlutterSecureStorage
  static Future<String?> _readKey(String key) async {
    if (kIsWeb) {
      // Web平台使用SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      try {
        // 其他平台使用FlutterSecureStorage
        return await _secureStorage.read(key: key);
      } catch (e) {
        // 如果FlutterSecureStorage不可用，回退到SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      }
    }
  }

  /// 平台特定的密钥写入方法
  /// 在Web平台上使用SharedPreferences，其他平台使用FlutterSecureStorage
  static Future<void> _writeKey(String key, String value) async {
    if (kIsWeb) {
      // Web平台使用SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      try {
        // 其他平台使用FlutterSecureStorage
        await _secureStorage.write(key: key, value: value);
      } catch (e) {
        // 如果FlutterSecureStorage不可用，回退到SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      }
    }
  }

  /// 平台特定的密钥删除方法
  /// 在Web平台上使用SharedPreferences，其他平台使用FlutterSecureStorage
  static Future<void> _deleteKey(String key) async {
    if (kIsWeb) {
      // Web平台使用SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      try {
        // 其他平台使用FlutterSecureStorage
        await _secureStorage.delete(key: key);
      } catch (e) {
        // 如果FlutterSecureStorage不可用，回退到SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      }
    }
  }

  /// 加密字符串
  /// [plainText] 要加密的明文
  /// 返回加密后的密文（Base64格式）
  static Future<String> encrypt(String plainText) async {
    final key = await _getKey();
    final iv = await _getIV();
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// 解密字符串
  /// [encryptedText] 要解密的密文（Base64格式）
  /// 返回解密后的明文
  static Future<String> decrypt(String encryptedText) async {
    try {
      final key = await _getKey();
      final iv = await _getIV();
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
      return decrypted;
    } catch (e) {
      // 解密失败时返回原始密文或空字符串，避免应用崩溃
      print('解密失败: $e');
      return '';
    }
  }

  /// 清除所有加密相关数据
  static Future<void> clear() async {
    await _deleteKey(_keyStorageKey);
    await _deleteKey(_ivStorageKey);
  }
}
