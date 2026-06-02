import 'package:flutter/material.dart';

/// 图表渐变色板
/// 提供统一的配色方案，正向绿/负向红/待办蓝/习惯紫/日记橙/积分金
class ChartGradientPalette {
  /// 正向渐变（用于收入、好习惯、完成率上升）
  static const positiveGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 正向主色
  static const Color positiveColor = Color(0xFF4CAF50);

  /// 正向浅色
  static const Color positiveLightColor = Color(0xFF81C784);

  /// 负向渐变（用于支出、坏习惯、逾期）
  static const negativeGradient = LinearGradient(
    colors: [Color(0xFFEF5350), Color(0xFFE57373)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 负向主色
  static const Color negativeColor = Color(0xFFEF5350);

  /// 负向浅色
  static const Color negativeLightColor = Color(0xFFE57373);

  /// 待办渐变
  static const todoGradient = LinearGradient(
    colors: [Color(0xFF42A5F5), Color(0xFF90CAF9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 待办主色
  static const Color todoColor = Color(0xFF42A5F5);

  /// 待办浅色
  static const Color todoLightColor = Color(0xFF90CAF9);

  /// 习惯渐变
  static const habitGradient = LinearGradient(
    colors: [Color(0xFFAB47BC), Color(0xFFCE93D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 习惯主色
  static const Color habitColor = Color(0xFFAB47BC);

  /// 习惯浅色
  static const Color habitLightColor = Color(0xFFCE93D8);

  /// 日记渐变
  static const diaryGradient = LinearGradient(
    colors: [Color(0xFFFFA726), Color(0xFFFFCC80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 日记主色
  static const Color diaryColor = Color(0xFFFFA726);

  /// 日记浅色
  static const Color diaryLightColor = Color(0xFFFFCC80);

  /// 积分渐变
  static const pointsGradient = LinearGradient(
    colors: [Color(0xFFFFD54F), Color(0xFFFFF176)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 积分主色
  static const Color pointsColor = Color(0xFFFFD54F);

  /// 积分浅色
  static const Color pointsLightColor = Color(0xFFFFF176);

  /// 中性色
  static const Color neutralColor = Color(0xFF78909C);

  /// 中性浅色
  static const Color neutralLightColor = Color(0xFF90A4AE);

  /// 生成填充渐变（从线条颜色到透明）
  /// [lineColor] 线条颜色
  /// 返回从上到下的纵向渐变
  static LinearGradient fillGradient(Color lineColor) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withOpacity(0.35),
        lineColor.withOpacity(0.15),
        lineColor.withOpacity(0.02),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// 生成发光渐变（用于卡片背景微渐变）
  /// [primaryColor] 主色
  static LinearGradient cardGlowGradient(Color primaryColor) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor.withOpacity(0.08),
        primaryColor.withOpacity(0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// 心情颜色映射
  /// [mood] 心情值 1-5
  static Color moodColor(int mood) {
    switch (mood) {
      case 1:
        return const Color(0xFFE76F51);
      case 2:
        return const Color(0xFFF4A261);
      case 3:
        return const Color(0xFFE9C46A);
      case 4:
        return const Color(0xFF2A9D8F);
      case 5:
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFFE9C46A);
    }
  }

  /// 心情emoji映射
  /// [mood] 心情值 1-5
  static String moodEmoji(int mood) {
    switch (mood) {
      case 1:
        return '😢';
      case 2:
        return '😟';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  /// 心情标签映射
  /// [mood] 心情值 1-5
  static String moodLabel(int mood) {
    switch (mood) {
      case 1:
        return '糟糕';
      case 2:
        return '不好';
      case 3:
        return '一般';
      case 4:
        return '不错';
      case 5:
        return '很棒';
      default:
        return '一般';
    }
  }

  /// 优先级颜色映射
  /// [priority] 优先级名称
  static Color priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
      case '紧急':
        return const Color(0xFFE53935);
      case 'high':
      case '高':
        return const Color(0xFFFF7043);
      case 'medium':
      case '中':
        return const Color(0xFFFFA726);
      case 'low':
      case '低':
        return const Color(0xFF66BB6A);
      default:
        return neutralColor;
    }
  }

  /// 优先级图标映射
  /// [priority] 优先级名称
  static IconData priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
      case '紧急':
        return Icons.bolt;
      case 'high':
      case '高':
        return Icons.arrow_upward;
      case 'medium':
      case '中':
        return Icons.remove;
      case 'low':
      case '低':
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }

  /// 通用分类颜色列表（用于环形图等）
  static const List<Color> categoryColors = [
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFFFA726),
    Color(0xFF4CAF50),
    Color(0xFFEF5350),
    Color(0xFF26C6DA),
    Color(0xFFFFEE58),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];

  /// 根据索引获取分类颜色
  /// [index] 索引
  static Color categoryColor(int index) {
    return categoryColors[index % categoryColors.length];
  }
}
