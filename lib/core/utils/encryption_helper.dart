import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/services/user_database_service.dart';

/// 加密工具类，用于AES-256加密和解密
class EncryptionHelper {
  /// 安全存储实例
  static final _secureStorage = FlutterSecureStorage();

  /// 加密密钥存储键
  static const _keyStorageKey = 'moment_keep_encryption_key';

  /// 初始化向量存储键
  static const _ivStorageKey = 'moment_keep_iv';

  /// 初始化加密工具
  /// 如果不存在密钥，会尝试从数据库备份恢复，最后才生成新的密钥
  static Future<void> initialize() async {
    final existingKey = await _readKey(_keyStorageKey);
    if (existingKey != null) {
      await _ensureDatabaseBackup(existingKey);
      return;
    }

    final dbBackup = await _readKeyFromDatabase();
    if (dbBackup != null) {
      await _writeKey(_keyStorageKey, dbBackup['key']!);
      await _writeKey(_ivStorageKey, dbBackup['iv']!);
      print('EncryptionHelper: 从数据库备份恢复了加密密钥');
      return;
    }

    print('EncryptionHelper: 加密密钥不存在且无备份，生成新密钥');

    final key = Key.fromSecureRandom(32);
    await _writeKey(_keyStorageKey, key.base64);

    final iv = IV.fromSecureRandom(16);
    await _writeKey(_ivStorageKey, iv.base64);

    await _saveKeyToDatabase(key.base64, iv.base64);
  }

  /// 确保数据库中存在密钥备份
  static Future<void> _ensureDatabaseBackup(String keyBase64) async {
    try {
      final userDb = UserDatabaseService();
      final db = await userDb.database;

      final result = await db.rawQuery(
        "SELECT value FROM app_config WHERE key = ?",
        ['encryption_key_backup'],
      );
      if (result.isNotEmpty) return;

      final ivBase64 = await _readKey(_ivStorageKey);
      if (ivBase64 != null) {
        await _saveKeyToDatabase(keyBase64, ivBase64);
      }
    } catch (e) {
      // 静默失败，不影响主流程
    }
  }

  /// 从用户数据库中读取密钥备份
  static Future<Map<String, String>?> _readKeyFromDatabase() async {
    try {
      final userDb = UserDatabaseService();
      final db = await userDb.database;

      final result = await db.rawQuery(
        "SELECT value FROM app_config WHERE key = ?",
        ['encryption_key_backup'],
      );
      if (result.isEmpty) return null;

      final jsonStr = result.first['value'] as String?;
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final key = data['key'] as String?;
      final iv = data['iv'] as String?;
      if (key != null && iv != null) {
        return {'key': key, 'iv': iv};
      }
      return null;
    } catch (e) {
      print('EncryptionHelper: 从数据库读取密钥备份失败: $e');
      return null;
    }
  }

  /// 将密钥备份保存到用户数据库
  static Future<void> _saveKeyToDatabase(String keyBase64, String ivBase64) async {
    try {
      final userDb = UserDatabaseService();
      final db = await userDb.database;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      final jsonStr = jsonEncode({'key': keyBase64, 'iv': ivBase64});
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.execute(
        'INSERT OR REPLACE INTO app_config (key, value, updated_at) VALUES (?, ?, ?)',
        ['encryption_key_backup', jsonStr, now],
      );
      print('EncryptionHelper: 密钥备份已保存到数据库');
    } catch (e) {
      print('EncryptionHelper: 保存密钥备份到数据库失败: $e');
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
  static Future<String?> _readKey(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      try {
        return await _secureStorage.read(key: key);
      } catch (e) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      }
    }
  }

  /// 平台特定的密钥写入方法
  static Future<void> _writeKey(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      try {
        await _secureStorage.write(key: key, value: value);
      } catch (e) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      }
    }
  }

  /// 平台特定的密钥删除方法
  static Future<void> _deleteKey(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      try {
        await _secureStorage.delete(key: key);
      } catch (e) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      }
    }
  }

  /// 加密字符串
  static Future<String> encrypt(String plainText) async {
    final key = await _getKey();
    final iv = await _getIV();
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// 解密字符串
  static Future<String> decrypt(String encryptedText) async {
    try {
      final key = await _getKey();
      final iv = await _getIV();
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
      return decrypted;
    } catch (e) {
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
