import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';

class UserSettingsService {
  static final UserSettingsService _instance = UserSettingsService._internal();
  final DatabaseService _dbService = DatabaseService();

  UserSettingsService._internal();
  factory UserSettingsService() => _instance;

  Future<String> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.userId) ?? 'default_user';
  }

  Future<String?> getSetting(String key) async {
    final userId = await _getCurrentUserId();
    return _dbService.getUserSetting(userId, key);
  }

  Future<int> getSettingInt(String key, {int defaultValue = 0}) async {
    final value = await getSetting(key);
    if (value != null) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final userId = await _getCurrentUserId();
    await _dbService.setUserSetting(userId, key, value);
  }

  Future<void> setSettingInt(String key, int value) async {
    await setSetting(key, value.toString());
  }

  static const String allowRetroactiveCheckIn = 'allow_retroactive_checkin';

  Future<bool> isRetroactiveCheckInAllowed() async {
    final value = await getSetting(allowRetroactiveCheckIn);
    return value != 'false';
  }

  Future<void> setRetroactiveCheckInAllowed(bool allowed) async {
    await setSetting(allowRetroactiveCheckIn, allowed.toString());
  }

  Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _getCurrentUserId();

    final migrationMap = {
      StorageKeys.pointsPerTodo: '5',
      StorageKeys.pointsPerDiary: '5',
      StorageKeys.maxTodoPointsPerDay: '50',
      StorageKeys.maxDiaryPointsPerDay: '50',
      StorageKeys.recycleBinRetentionDays: '30',
    };

    for (final entry in migrationMap.entries) {
      final existingValue = await _dbService.getUserSetting(userId, entry.key);
      if (existingValue == null) {
        final prefsValue = prefs.getInt(entry.key) ?? prefs.getString(entry.key);
        if (prefsValue != null) {
          await _dbService.setUserSetting(userId, entry.key, prefsValue.toString());
        } else {
          await _dbService.setUserSetting(userId, entry.key, entry.value);
        }
      }
    }
  }
}
