import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// 主题管理器，用于管理应用的主题模式和主题类型
class ThemeManager {
  /// 主题模式的存储键
  static const String _themeModeKey = 'theme_mode';

  /// 主题类型的存储键
  static const String _themeTypeKey = 'theme_type';

  /// 私有构造函数
  ThemeManager._();

  /// 单例实例
  static final ThemeManager instance = ThemeManager._();

  /// 主题模式变化的监听器
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.system);

  /// 主题类型变化的监听器
  final ValueNotifier<ThemeType> themeTypeNotifier = 
      ValueNotifier(ThemeType.simpleGreen);

  /// 初始化主题管理器
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 初始化主题模式
    final themeModeString = prefs.getString(_themeModeKey);
    final themeMode = themeModeString != null
        ? ThemeMode.values.firstWhere((mode) => mode.name == themeModeString)
        : ThemeMode.system;
    themeModeNotifier.value = themeMode;

    // 初始化主题类型
    final themeTypeString = prefs.getString(_themeTypeKey);
    final themeType = themeTypeString != null
        ? ThemeType.values.firstWhere((type) => type.name == themeTypeString, orElse: () => ThemeType.simpleGreen)
        : ThemeType.simpleGreen;
    themeTypeNotifier.value = themeType;
    AppTheme.setTheme(themeType);
  }

  /// 获取当前主题模式
  ThemeMode get currentThemeMode => themeModeNotifier.value;

  /// 获取当前主题类型
  ThemeType get currentThemeType => themeTypeNotifier.value;

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode.name);
    themeModeNotifier.value = themeMode;
  }

  /// 设置主题类型
  Future<void> setThemeType(ThemeType themeType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeTypeKey, themeType.name);
    themeTypeNotifier.value = themeType;
    AppTheme.setTheme(themeType);
  }

  /// 切换主题模式
  Future<void> toggleThemeMode() async {
    final currentMode = themeModeNotifier.value;
    ThemeMode newMode;

    switch (currentMode) {
      case ThemeMode.light:
        newMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        newMode = ThemeMode.light;
        break;
      case ThemeMode.system:
        newMode = ThemeMode.dark;
        break;
    }

    await setThemeMode(newMode);
  }

  /// 根据主题模式获取对应的ThemeData
  ThemeData getThemeData(ThemeMode themeMode, BuildContext context) {
    switch (themeMode) {
      case ThemeMode.light:
        return AppTheme.getLightTheme();
      case ThemeMode.dark:
        return AppTheme.getDarkTheme();
      case ThemeMode.system:
        final brightness = MediaQuery.of(context).platformBrightness;
        return brightness == Brightness.dark
            ? AppTheme.getDarkTheme()
            : AppTheme.getLightTheme();
    }
  }
}
