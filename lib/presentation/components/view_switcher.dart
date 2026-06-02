import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/core/theme/app_theme.dart';

/// 视图切换器组件 - 匹配 HTML 设计风格
class ViewSwitcher extends StatelessWidget {
  final HabitViewType selectedView;
  final Function(HabitViewType) onViewChanged;

  const ViewSwitcher({
    super.key,
    required this.selectedView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.htmlBorderDark : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: HabitViewType.values.map((viewType) {
            final isSelected = viewType == selectedView;
            return Expanded(
              child: GestureDetector(
                onTap: () => onViewChanged(viewType),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode ? AppTheme.htmlBackgroundDark : theme.colorScheme.primary)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 0),
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      viewType.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? AppTheme.htmlAccentPurple : theme.colorScheme.onSurfaceVariant),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
