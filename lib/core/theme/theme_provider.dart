import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme_manager.dart';
import 'app_theme.dart';

// 主题状态类
class ThemeState {
  final ThemeMode themeMode;
  final bool isDarkMode;
  final ThemeType themeType;

  ThemeState({
    required this.themeMode,
    required this.isDarkMode,
    required this.themeType,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDarkMode,
    ThemeType? themeType,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      themeType: themeType ?? this.themeType,
    );
  }
}

// 主题提供者
class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    // 从ThemeManager获取初始主题模式和主题类型
    final themeMode = ThemeManager.instance.currentThemeMode;
    final themeType = ThemeManager.instance.currentThemeType;
    bool isDark;
    
    // 初始化主题配置
    AppTheme.setTheme(themeType);
    
    if (themeMode == ThemeMode.system) {
      isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } else {
      isDark = themeMode == ThemeMode.dark;
    }

    // 监听系统主题变化
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (state.themeMode == ThemeMode.system) {
        final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
        state = state.copyWith(isDarkMode: isDark);
      }
    };
    
    // 监听ThemeManager主题模式变化
    ThemeManager.instance.themeModeNotifier.addListener(() {
      final newThemeMode = ThemeManager.instance.currentThemeMode;
      bool isDark;
      
      if (newThemeMode == ThemeMode.system) {
        isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      } else {
        isDark = newThemeMode == ThemeMode.dark;
      }
      
      state = state.copyWith(
        themeMode: newThemeMode,
        isDarkMode: isDark,
      );
    });

    // 监听ThemeManager主题类型变化
    ThemeManager.instance.themeTypeNotifier.addListener(() {
      final newThemeType = ThemeManager.instance.currentThemeType;
      final oldThemeType = state.themeType;
      // 当主题类型变化时，更新AppTheme的当前主题配置
      AppTheme.setTheme(newThemeType);
      
      // 如果选择的是暗夜主题，自动切换到深色模式
      if (newThemeType == ThemeType.darkNight) {
        // 更新主题模式为深色
        ThemeManager.instance.setThemeMode(ThemeMode.dark);
        // 由于setThemeMode会触发themeModeNotifier，这里不需要再更新isDarkMode
        state = state.copyWith(
          themeType: newThemeType,
        );
      } else if (oldThemeType == ThemeType.darkNight) {
        // 从暗夜主题切换到其他主题，恢复到系统主题模式
        ThemeManager.instance.setThemeMode(ThemeMode.system);
        // 由于setThemeMode会触发themeModeNotifier，这里不需要再更新isDarkMode
        state = state.copyWith(
          themeType: newThemeType,
        );
      } else {
        // 更新state，确保currentThemeProvider重建
        state = state.copyWith(
          themeType: newThemeType,
          // 强制更新isDarkMode，确保currentThemeProvider重建
          isDarkMode: state.isDarkMode,
        );
      }
    });

    return ThemeState(
      themeMode: themeMode,
      isDarkMode: isDark,
      themeType: themeType,
    );
  }

  // 切换主题模式
  void setThemeMode(ThemeMode mode) {
    bool isDark;
    if (mode == ThemeMode.system) {
      isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    } else {
      isDark = mode == ThemeMode.dark;
    }
    state = state.copyWith(
      themeMode: mode,
      isDarkMode: isDark,
    );
  }

  // 切换明暗主题
  void toggleTheme() {
    final newMode =
        state.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }
}

// 主题提供者实例
final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(() {
  return ThemeNotifier();
});

// 获取当前主题（根据平台自适应）
final currentThemeProvider = Provider<ThemeData>((ref) {
  // 监听主题状态变化，包括themeType
  final themeState = ref.watch(themeProvider);
  // 当themeState.themeType变化时，这个provider会重建
  return themeState.isDarkMode
      ? AppTheme.darkMaterialTheme
      : AppTheme.materialTheme;
});

// 获取当前Cupertino主题（根据平台自适应）
final currentCupertinoThemeProvider = Provider<CupertinoThemeData>((ref) {
  // 监听主题状态变化，包括themeType
  final themeState = ref.watch(themeProvider);
  return themeState.isDarkMode
      ? AppTheme.darkCupertinoTheme
      : AppTheme.cupertinoTheme;
});
