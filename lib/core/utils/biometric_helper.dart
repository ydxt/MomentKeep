import 'package:local_auth/local_auth.dart';

/// 生物识别认证工具类
class BiometricHelper {
  /// 本地认证实例
  static final _auth = LocalAuthentication();

  /// 检查设备是否支持生物识别
  /// 返回true表示支持，false表示不支持
  static Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// 获取设备支持的生物识别类型
  /// 返回支持的生物识别类型列表
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// 执行生物识别认证
  /// [localizedReason] 认证原因（显示给用户）
  /// 返回true表示认证成功，false表示认证失败
  static Future<bool> authenticate({String localizedReason = '请验证您的身份'}) async {
    try {
      // 检查设备是否支持生物识别
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      // 执行认证
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
      );
    } catch (e) {
      return false;
    }
  }

  /// 执行设备认证（可以是生物识别或PIN/密码）
  /// [localizedReason] 认证原因（显示给用户）
  /// 返回true表示认证成功，false表示认证失败
  static Future<bool> authenticateWithDeviceCredential(
      {String localizedReason = '请验证您的身份'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
      );
    } catch (e) {
      return false;
    }
  }
}
