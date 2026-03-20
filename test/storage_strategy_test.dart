import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/services/storage_path_service.dart';
import 'package:moment_keep/services/storage_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('存储策略测试', () {
    setUpAll(() async {
      // 设置测试模式
      StoragePathService.setTestMode();
      SecurityService.setTestMode();
      // 初始化所有服务
      await StoragePathService.initialize();
      await DatabaseService.initialize();
      await SecurityService.initialize();
    });

    test('StoragePathService - 目录结构创建', () async {
      // 测试获取各种目录路径
      expect(StoragePathService.getAppSupportDirectory(), isNotEmpty);
      expect(StoragePathService.getCloudDirectory(), isNotEmpty);
      expect(StoragePathService.getLocalDirectory(), isNotEmpty);
      expect(StoragePathService.getServerDatabaseDirectory(), isNotEmpty);
      expect(StoragePathService.getLocalDatabaseDirectory(), isNotEmpty);
      expect(StoragePathService.getDefaultDirectory(), isNotEmpty);
      expect(StoragePathService.getProductsDirectory(), isNotEmpty);
      expect(StoragePathService.getUsersDirectory(), isNotEmpty);
      expect(StoragePathService.getSystemDirectory(), isNotEmpty);
      expect(StoragePathService.getLogsDirectory(), isNotEmpty);

      // 测试用户目录
      String userId = 'test_user_123';
      expect(StoragePathService.getUserFilesDirectory(userId), isNotEmpty);
      expect(StoragePathService.getUserImagesDirectory(userId), isNotEmpty);
      expect(StoragePathService.getUserAudioDirectory(userId), isNotEmpty);
      expect(StoragePathService.getUserVideoDirectory(userId), isNotEmpty);
      expect(StoragePathService.getUserOtherFilesDirectory(userId), isNotEmpty);
    });

    test('StorageService - 文件存储', () async {
      // 测试保存文件
      String testContent = 'Hello, World!';
      Uint8List testData = Uint8List.fromList(testContent.codeUnits);
      bool saveResult = await StorageService.saveFile(
        StorageType.local,
        'test_file.txt',
        testData,
      );
      expect(saveResult, true);

      // 测试读取文件
      Uint8List? readData = await StorageService.readFile(
        StorageType.local,
        'test_file.txt',
      );
      expect(readData, isNotNull);
      expect(String.fromCharCodes(readData!), equals(testContent));

      // 测试文件存在检查
      bool exists = StorageService.fileExists(
        StorageType.local,
        'test_file.txt',
      );
      expect(exists, true);

      // 测试获取文件列表
      List<String> files = StorageService.getFileList(StorageType.local);
      expect(files.isNotEmpty, true);
      expect(files[0].endsWith('test_file.txt'), true);

      // 测试获取文件大小
      int fileSize = StorageService.getFileSize(
        StorageType.local,
        'test_file.txt',
      );
      expect(fileSize, equals(testData.length));

      // 测试删除文件
      bool deleteResult = await StorageService.deleteFile(
        StorageType.local,
        'test_file.txt',
      );
      expect(deleteResult, true);

      // 测试文件不存在
      exists = StorageService.fileExists(
        StorageType.local,
        'test_file.txt',
      );
      expect(exists, false);
    });

    test('DatabaseService - 数据库操作', () async {
      // 测试创建表
      await DatabaseService.executeQuery(
        DatabaseType.local,
        'test_db.db',
        '''
        CREATE TABLE IF NOT EXISTS test_table (
          id INTEGER PRIMARY KEY,
          name TEXT,
          value INTEGER
        );
        ''',
        null,
      );

      // 测试插入数据
      int insertResult = await DatabaseService.insert(
        DatabaseType.local,
        'test_db.db',
        'test_table',
        {'name': 'Test', 'value': 123},
      );
      expect(insertResult, greaterThan(0));

      // 测试查询数据
      List<Map<String, dynamic>> queryResult = await DatabaseService.query(
        DatabaseType.local,
        'test_db.db',
        'test_table',
        null, // columns
        null, // where
        null, // whereArgs
        null, // orderBy
        null, // limit
      );
      expect(queryResult.length, greaterThan(0));
      expect(queryResult[0]['name'], equals('Test'));
      expect(queryResult[0]['value'], equals(123));

      // 测试更新数据
      int updateResult = await DatabaseService.update(
        DatabaseType.local,
        'test_db.db',
        'test_table',
        {'name': 'Updated Test', 'value': 456},
        'id = ?',
        [1],
      );
      expect(updateResult, greaterThan(0));

      // 测试删除数据
      int deleteResult = await DatabaseService.delete(
        DatabaseType.local,
        'test_db.db',
        'test_table',
        'id = ?',
        [1],
      );
      expect(deleteResult, greaterThan(0));

      // 测试事务
      await DatabaseService.transaction(
        DatabaseType.local,
        'test_db.db',
        (txn) async {
          await txn.insert('test_table', {'name': 'Transaction Test', 'value': 789});
        },
      );

      queryResult = await DatabaseService.query(
        DatabaseType.local,
        'test_db.db',
        'test_table',
        null, // columns
        null, // where
        null, // whereArgs
        null, // orderBy
        null, // limit
      );
      expect(queryResult.length, greaterThan(0));
      expect(queryResult[0]['name'], equals('Transaction Test'));
    });

    test('SecurityService - 安全功能', () async {
      // 测试加密和解密
      String testData = 'This is a test message';
      String? encrypted = SecurityService.encrypt(testData);
      expect(encrypted, isNotNull);
      expect(encrypted, isNot(equals(testData)));

      String? decrypted = SecurityService.decrypt(encrypted!);
      expect(decrypted, equals(testData));

      // 测试密码哈希
      String password = 'Password123!';
      String hashedPassword = SecurityService.hashPassword(password);
      expect(hashedPassword, isNot(equals(password)));

      // 测试密码验证
      bool passwordValid = SecurityService.verifyPassword(password, hashedPassword);
      expect(passwordValid, true);

      bool passwordInvalid = SecurityService.verifyPassword('WrongPassword', hashedPassword);
      expect(passwordInvalid, false);

      // 测试安全存储
      bool storeResult = await SecurityService.secureStore('test_key', 'test_value');
      expect(storeResult, true);

      String? storedValue = await SecurityService.secureRead('test_key');
      expect(storedValue, equals('test_value'));

      bool deleteResult = await SecurityService.secureDelete('test_key');
      expect(deleteResult, true);

      storedValue = await SecurityService.secureRead('test_key');
      expect(storedValue, isNull);

      // 测试令牌生成
      String token = SecurityService.generateToken();
      expect(token, isNotEmpty);
      expect(token.length, greaterThan(20));

      // 测试密码强度检查
      int strength = SecurityService.checkPasswordStrength('Password123!');
      expect(strength, greaterThanOrEqualTo(4));

      String strengthDescription = SecurityService.getPasswordStrengthDescription(strength);
      expect(strengthDescription, isNotEmpty);

      // 测试生成安全密码
      String securePassword = SecurityService.generateSecurePassword();
      expect(securePassword, isNotEmpty);
      expect(securePassword.length, equals(12));
    });

    test('SecurityService - 文件加密', () async {
      // 测试文件加密
      String testContent = 'This is a test file';
      Uint8List testData = Uint8List.fromList(testContent.codeUnits);

      Uint8List? encryptedData = SecurityService.encryptFile(testData);
      expect(encryptedData, isNotNull);
      expect(encryptedData!.length, greaterThan(testData.length));

      // 测试文件解密
      Uint8List? decryptedData = SecurityService.decryptFile(encryptedData);
      expect(decryptedData, isNotNull);
      expect(String.fromCharCodes(decryptedData!), equals(testContent));
    });
  });
}
