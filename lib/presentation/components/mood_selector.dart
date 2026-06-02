import 'package:flutter/material.dart';

/// 心情枚举
enum Mood {
  veryBad,    // 非常差 😢
  bad,        // 差 😟
  neutral,    // 一般 😐
  good,       // 好 😊
  veryGood,   // 非常好 😄
}

/// 心情扩展方法
extension MoodExtension on Mood {
  /// 获取心情表情
  String get emoji {
    switch (this) {
      case Mood.veryBad:
        return '😢';
      case Mood.bad:
        return '😟';
      case Mood.neutral:
        return '😐';
      case Mood.good:
        return '😊';
      case Mood.veryGood:
        return '😄';
    }
  }

  /// 获取心情标签
  String get label {
    switch (this) {
      case Mood.veryBad:
        return '糟糕';
      case Mood.bad:
        return '不好';
      case Mood.neutral:
        return '一般';
      case Mood.good:
        return '不错';
      case Mood.veryGood:
        return '很棒';
    }
  }

  /// 获取心情颜色
  Color getColor(ThemeData theme) {
    switch (this) {
      case Mood.veryBad:
        return const Color(0xFFE76F51);
      case Mood.bad:
        return const Color(0xFFF4A261);
      case Mood.neutral:
        return const Color(0xFFE9C46A);
      case Mood.good:
        return const Color(0xFF2A9D8F);
      case Mood.veryGood:
        return const Color(0xFF4CAF50);
    }
  }

  /// 获取心情数值（1-5）
  int get value {
    switch (this) {
      case Mood.veryBad:
        return 1;
      case Mood.bad:
        return 2;
      case Mood.neutral:
        return 3;
      case Mood.good:
        return 4;
      case Mood.veryGood:
        return 5;
    }
  }

  /// 从数值创建心情
  static Mood fromValue(int value) {
    switch (value) {
      case 1:
        return Mood.veryBad;
      case 2:
        return Mood.bad;
      case 3:
        return Mood.neutral;
      case 4:
        return Mood.good;
      case 5:
        return Mood.veryGood;
      default:
        return Mood.neutral;
    }
  }
}

/// 心情选择器组件
class MoodSelector extends StatelessWidget {
  /// 当前选中的心情
  final Mood? selectedMood;

  /// 心情变化回调
  final Function(Mood? mood) onChanged;

  /// 是否显示标签
  final bool showLabels;

  /// 是否显示为紧凑模式
  final bool compact;

  const MoodSelector({
    Key? key,
    this.selectedMood,
    required this.onChanged,
    this.showLabels = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moods = Mood.values;
    final size = compact ? 40.0 : 56.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今天的心情如何？',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moods.map((mood) {
            final isSelected = selectedMood == mood;
            return _MoodChip(
              mood: mood,
              isSelected: isSelected,
              size: size,
              showLabel: showLabels,
              onTap: () {
                if (isSelected) {
                  onChanged(null);
                } else {
                  onChanged(mood);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 心情芯片组件
class _MoodChip extends StatelessWidget {
  final Mood mood;
  final bool isSelected;
  final double size;
  final bool showLabel;
  final VoidCallback onTap;

  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.size,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = mood.getColor(theme);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mood.emoji,
              style: TextStyle(fontSize: size * 0.45),
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                mood.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 心情显示组件（用于查看已选择的心情）
class MoodDisplay extends StatelessWidget {
  final Mood mood;
  final bool showLabel;
  final double size;

  const MoodDisplay({
    Key? key,
    required this.mood,
    this.showLabel = true,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = mood.getColor(theme);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mood.emoji,
          style: TextStyle(fontSize: size),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            mood.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}
