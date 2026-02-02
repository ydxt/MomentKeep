import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/theme_manager.dart';

// 主题类型枚举
enum ThemeType {
  simpleGreen, // 简约绿主题
  vibrant, // 缤纷活力主题
  darkNight, // 暗夜主题
}

// 主题配色配置类
class ThemeConfig {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color errorColor;

  // 浅色模式中性色
  final Color offWhite;
  final Color lightGray;
  final Color mediumGray;
  final Color darkGray;

  // 暗黑模式中性色
  final Color deepSpaceGray;
  final Color darkSurfaceGray;
  final Color mediumSurfaceGray;
  final Color lightSurfaceGray;

  const ThemeConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.errorColor,
    required this.offWhite,
    required this.lightGray,
    required this.mediumGray,
    required this.darkGray,
    required this.deepSpaceGray,
    required this.darkSurfaceGray,
    required this.mediumSurfaceGray,
    required this.lightSurfaceGray,
  });
}

// 主题配色方案配置
class ThemeConfigs {
  // 简约绿主题配色
  static const ThemeConfig simpleGreen = ThemeConfig(
    primaryColor: Color(0xFF13EC5B), // 绿色（主色调，简约清新）
    secondaryColor: Color(0xFF0EA33F), // 深绿色（辅助色）
    accentColor: Color(0xFF13EC5B), // 绿色（强调色）
    errorColor: Color(0xFFFF4757), // 红色（错误，优先级高）

    // 浅色模式中性色
    offWhite: Color(0xFFF6F8F6), // 浅绿（主背景）
    lightGray: Color(0xFFEDF2F7), // 浅灰色
    mediumGray: Color(0xFFE2E8F0), // 中灰色
    darkGray: Color(0xFF718096), // 深灰色

    // 暗黑模式中性色 - 匹配HTML设计
    deepSpaceGray: Color(0xFF102216), // 深绿黑（主背景）
    darkSurfaceGray: Color(0xFF112217), // 深色表面
    mediumSurfaceGray: Color(0xFF1A3322), // 中色表面（卡片背景）
    lightSurfaceGray: Color(0xFF326744), // 浅色表面
  );

  // 缤纷活力主题配色
  static const ThemeConfig vibrant = ThemeConfig(
    primaryColor: Color(0xFFFF6B6B), // 珊瑚红（主色调，充满活力）
    secondaryColor: Color(0xFF4ECDC4), // 青绿色（辅助色）
    accentColor: Color(0xFF45B7D1), // 天蓝色（强调色）
    errorColor: Color(0xFFFF4757), // 红色（错误）

    // 浅色模式中性色
    offWhite: Color(0xFFFFFAF0), // 暖白色（主背景）
    lightGray: Color(0xFFF9F9F9), // 浅灰色
    mediumGray: Color(0xFFE0E0E0), // 中灰色
    darkGray: Color(0xFF757575), // 深灰色

    // 暗黑模式中性色
    deepSpaceGray: Color(0xFF121212), // 深黑（主背景）
    darkSurfaceGray: Color(0xFF1E1E1E), // 深色表面
    mediumSurfaceGray: Color(0xFF2D2D2D), // 中色表面
    lightSurfaceGray: Color(0xFF424242), // 浅色表面
  );

  // 暗夜主题配色
  static const ThemeConfig darkNight = ThemeConfig(
    primaryColor: Color(0xFF00FF88), // 亮绿色（主色调，暗夜中的亮点）
    secondaryColor: Color(0xFF00C4FF), // 亮蓝色（辅助色）
    accentColor: Color(0xFFFF6B9D), // 粉色（强调色）
    errorColor: Color(0xFFFF4757), // 红色（错误）

    // 浅色模式中性色
    offWhite: Color(0xFFF5F5F5), // 浅灰色（主背景）
    lightGray: Color(0xFFE0E0E0), // 浅灰色
    mediumGray: Color(0xFFBDBDBD), // 中灰色
    darkGray: Color(0xFF616161), // 深灰色

    // 暗黑模式中性色 - 暗夜主题专用
    deepSpaceGray: Color(0xFF0A0A0A), // 极深黑（主背景）
    darkSurfaceGray: Color(0xFF121212), // 深色表面
    mediumSurfaceGray: Color(0xFF1E1E1E), // 中色表面
    lightSurfaceGray: Color(0xFF2D2D2D), // 浅色表面
  );
}

class AppTheme {
  // 默认主题为简约绿主题
  static ThemeConfig currentTheme = ThemeConfigs.simpleGreen;

  // 设置当前主题
  static void setTheme(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.simpleGreen:
        currentTheme = ThemeConfigs.simpleGreen;
        break;
      case ThemeType.vibrant:
        currentTheme = ThemeConfigs.vibrant;
        break;
      case ThemeType.darkNight:
        currentTheme = ThemeConfigs.darkNight;
        break;
    }
  }

  // 获取当前主题类型
  static ThemeType getCurrentThemeType() {
    if (currentTheme == ThemeConfigs.simpleGreen) return ThemeType.simpleGreen;
    if (currentTheme == ThemeConfigs.vibrant) return ThemeType.vibrant;
    return ThemeType.darkNight;
  }

  // 兼容旧代码的颜色常量 - 使用当前主题的颜色
  static Color get primaryColor => currentTheme.primaryColor;
  static Color get secondaryColor => currentTheme.secondaryColor;
  static Color get accentColor => currentTheme.accentColor;
  static Color get errorColor => currentTheme.errorColor;
  static Color get offWhite => currentTheme.offWhite;
  static Color get lightGray => currentTheme.lightGray;
  static Color get mediumGray => currentTheme.mediumGray;
  static Color get darkGray => currentTheme.darkGray;
  static Color get deepSpaceGray => currentTheme.deepSpaceGray;
  static Color get darkSurfaceGray => currentTheme.darkSurfaceGray;
  static Color get mediumSurfaceGray => currentTheme.mediumSurfaceGray;
  static Color get lightSurfaceGray => currentTheme.lightSurfaceGray;

  // 兼容旧代码的颜色常量 - 不再是const，因为依赖于当前主题
  static Color get white => offWhite;
  static Color get gray400 => darkGray;
  static Color get gray600 => deepSpaceGray;

  // 字体样式 - 现代无衬线体
  static const String fontFamily = 'Inter'; // 使用现代无衬线字体

  // Material Design 3 主题 - 简约时尚风格
  static ThemeData get materialTheme {
    // 每次调用都重新创建主题，确保使用最新的currentTheme
    final currentThemeConfig = currentTheme;
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: currentThemeConfig.primaryColor,
        primary: currentThemeConfig.primaryColor,
        secondary: currentThemeConfig.secondaryColor,
        tertiary: currentThemeConfig.accentColor,
        error: currentThemeConfig.errorColor,
        surface: currentThemeConfig.offWhite,
        onPrimary: currentThemeConfig.offWhite,
        onSecondary: currentThemeConfig.deepSpaceGray,
        onTertiary: currentThemeConfig.deepSpaceGray,
        onError: currentThemeConfig.offWhite,
        onSurface: currentThemeConfig.deepSpaceGray,
      ),
      textTheme: TextTheme(
        // 重点数字使用大字号
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: offWhite,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 大圆角
          ),
          elevation: 2, // 细腻阴影
          shadowColor: Colors.black.withOpacity(0.1), // 柔和阴影颜色
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primaryColor, width: 1),
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 大圆角
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角
          borderSide: BorderSide(color: mediumGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角
          borderSide: BorderSide(color: mediumGray, width: 1),
        ),
        filled: true,
        fillColor: lightGray,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 3, // 细腻阴影
        shadowColor: Colors.black.withOpacity(0.1), // 柔和阴影颜色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // 大圆角卡片
        ),
        color: offWhite,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      scaffoldBackgroundColor: offWhite, // 米白色主背景
      dividerTheme: DividerThemeData(
        color: mediumGray,
        thickness: 1,
        indent: 20,
        endIndent: 20,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: offWhite,
        foregroundColor: deepSpaceGray,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: deepSpaceGray,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24), // 大圆角底部
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: offWhite,
        selectedItemColor: primaryColor,
        unselectedItemColor: darkGray,
        elevation: 2,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      // 自定义PopupMenu样式 - 极简、现代、禅意风格
      popupMenuTheme: PopupMenuThemeData(
        color: offWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角设计
        ),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.1), // 柔和阴影
        surfaceTintColor: offWhite,
        textStyle: TextStyle(
          color: deepSpaceGray,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // 暗黑模式 Material 主题 - 简约时尚风格
  static ThemeData get darkMaterialTheme {
    // 每次调用都重新创建主题，确保使用最新的currentTheme
    final currentThemeConfig = currentTheme;
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: currentThemeConfig.primaryColor,
        brightness: Brightness.dark,
        primary: currentThemeConfig.primaryColor,
        secondary: currentThemeConfig.secondaryColor,
        tertiary: currentThemeConfig.accentColor,
        error: currentThemeConfig.errorColor,
        surface: currentThemeConfig.darkSurfaceGray,
        onPrimary: currentThemeConfig.deepSpaceGray,
        onSecondary: currentThemeConfig.deepSpaceGray,
        onTertiary: currentThemeConfig.deepSpaceGray,
        onError: currentThemeConfig.deepSpaceGray,
        onSurface: currentThemeConfig.offWhite,
      ),
      textTheme: TextTheme(
        // 重点数字使用大字号
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.5,
          color: offWhite,
        ),
        displayMedium: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.5,
          color: offWhite,
        ),
        displaySmall: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: offWhite,
        ),
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: offWhite,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: offWhite,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: offWhite,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: offWhite,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          color: offWhite,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: offWhite,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: offWhite,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: offWhite,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: offWhite,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: offWhite,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: offWhite,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: offWhite,
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: deepSpaceGray,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 大圆角
          ),
          elevation: 3, // 细腻阴影
          shadowColor: Colors.black.withOpacity(0.3), // 柔和阴影颜色
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primaryColor, width: 1),
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 大圆角
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角
          borderSide: BorderSide(color: mediumSurfaceGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角
          borderSide: BorderSide(color: mediumSurfaceGray, width: 1),
        ),
        filled: true,
        fillColor: mediumSurfaceGray,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 4, // 细腻阴影
        shadowColor: Colors.black.withOpacity(0.3), // 柔和阴影颜色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // 大圆角卡片
        ),
        color: darkSurfaceGray,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      scaffoldBackgroundColor: deepSpaceGray, // 深空灰主背景
      dividerTheme: DividerThemeData(
        color: mediumSurfaceGray,
        thickness: 1,
        indent: 20,
        endIndent: 20,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurfaceGray,
        foregroundColor: offWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: offWhite,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24), // 大圆角底部
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurfaceGray,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightSurfaceGray,
        elevation: 3,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      // 自定义PopupMenu样式 - 极简、现代、禅意风格
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurfaceGray,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // 大圆角设计
        ),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.3), // 柔和阴影
        surfaceTintColor: darkSurfaceGray,
        textStyle: TextStyle(
          color: offWhite,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // Cupertino 主题 - 简约时尚风格
  static CupertinoThemeData get cupertinoTheme {
    // 每次调用都重新创建主题，确保使用最新的currentTheme
    final currentThemeConfig = currentTheme;
    return CupertinoThemeData(
      primaryColor: currentThemeConfig.primaryColor,
      brightness: Brightness.light,
      textTheme: CupertinoTextThemeData(
        navTitleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: fontFamily,
        ),
        actionTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
        tabLabelTextStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
      ),
      barBackgroundColor: currentThemeConfig.offWhite,
      scaffoldBackgroundColor: currentThemeConfig.offWhite,
    );
  }

  // 暗黑模式 Cupertino 主题 - 简约时尚风格
  static CupertinoThemeData get darkCupertinoTheme {
    // 每次调用都重新创建主题，确保使用最新的currentTheme
    final currentThemeConfig = currentTheme;
    return CupertinoThemeData(
      primaryColor: currentThemeConfig.primaryColor,
      brightness: Brightness.dark,
      textTheme: CupertinoTextThemeData(
        navTitleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          color: currentThemeConfig.offWhite,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
          color: currentThemeConfig.offWhite,
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: fontFamily,
          color: currentThemeConfig.offWhite,
        ),
        actionTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
          color: currentThemeConfig.primaryColor,
        ),
        tabLabelTextStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
          color: currentThemeConfig.offWhite,
        ),
      ),
      barBackgroundColor: currentThemeConfig.darkSurfaceGray,
      scaffoldBackgroundColor: currentThemeConfig.deepSpaceGray,
    );
  }

  // 获取主题，根据当前主题模式返回相应的主题
  static ThemeData getLightTheme() {
    return materialTheme;
  }

  static ThemeData getDarkTheme() {
    return darkMaterialTheme;
  }

  static ThemeData getTheme(BuildContext context) {
    // Get the current theme mode from ThemeManager
    final themeMode = ThemeManager.instance.currentThemeMode;
    
    // Determine if we should use dark theme based on theme mode and system brightness
    bool isDarkMode;
    if (themeMode == ThemeMode.system) {
      final brightness = MediaQuery.of(context).platformBrightness;
      isDarkMode = brightness == Brightness.dark;
    } else {
      isDarkMode = themeMode == ThemeMode.dark;
    }
    
    return isDarkMode ? darkMaterialTheme : materialTheme;
  }
}
