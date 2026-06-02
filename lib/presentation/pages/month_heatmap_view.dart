import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/core/utils/habit_date_utils.dart';

/// 月视图热力图组件
class MonthHeatmapView extends StatefulWidget {
  /// 习惯列表
  final List<Habit> habits;

  /// 分类列表
  final List<Category> categories;

  /// 主题数据
  final ThemeData theme;

  /// 选中的分类ID
  final String? selectedCategoryId;

  /// 是否显示标题
  final bool showHeader;

  /// 当前显示的月份日期
  final DateTime? currentMonthDate;

  /// 是否显示导航按钮
  final bool showNavigation;

  /// 构造函数
  const MonthHeatmapView({
    super.key,
    required this.habits,
    required this.categories,
    required this.theme,
    this.selectedCategoryId,
    this.showHeader = true,
    this.currentMonthDate,
    this.showNavigation = true,
  });

  @override
  State<MonthHeatmapView> createState() => _MonthHeatmapViewState();
}

class _MonthHeatmapViewState extends State<MonthHeatmapView> {
  /// 当前显示的月份的基准日期
  late DateTime _currentMonthDate;

  /// 星期的短名称（从周日开始）
  static const List<String> _weekDayNames = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  void initState() {
    super.initState();
    _currentMonthDate = widget.currentMonthDate ?? DateTime.now();
  }

  @override
  void didUpdateWidget(MonthHeatmapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentMonthDate != null) {
      final newDate = widget.currentMonthDate!;
      if (newDate.year != _currentMonthDate.year ||
          newDate.month != _currentMonthDate.month) {
        setState(() {
          _currentMonthDate = newDate;
        });
      }
    }
  }

  /// 导航到上一月
  void _previousMonth() {
    setState(() {
      _currentMonthDate =
          DateTime(_currentMonthDate.year, _currentMonthDate.month - 1);
    });
  }

  /// 导航到下一月
  void _nextMonth() {
    setState(() {
      _currentMonthDate =
          DateTime(_currentMonthDate.year, _currentMonthDate.month + 1);
    });
  }

  /// 获取指定日期的打卡次数（所有习惯的总打卡次数）
  int _getCompletionCountForDate(DateTime date, List<Habit> habits) {
    int count = 0;
    for (final habit in habits) {
      if (HabitDateUtils.isHabitCheckedOnDate(habit, date)) {
        count++;
      }
    }
    return count;
  }

  /// 获取热力图颜色（基于打卡次数） - 使用主题系统
  Color _getHeatmapColor(int completionCount, int totalHabits) {
    final colorScheme = widget.theme.colorScheme;
    if (totalHabits == 0) {
      return colorScheme.outline.withValues(alpha: 0.3);
    }

    final ratio = completionCount / totalHabits;

    if (ratio == 0) {
      return colorScheme.outline.withValues(alpha: 0.3);
    } else if (ratio <= 0.25) {
      return colorScheme.primary.withValues(alpha: 0.25);
    } else if (ratio <= 0.5) {
      return colorScheme.primary.withValues(alpha: 0.5);
    } else if (ratio <= 0.75) {
      return colorScheme.primary.withValues(alpha: 0.75);
    } else {
      return colorScheme.primary;
    }
  }

  /// 获取热力图等级颜色（用于图例显示，level: 0-4）
  Color _getHeatmapLevelColor(int level) {
    final colorScheme = widget.theme.colorScheme;
    switch (level) {
      case 0:
        return colorScheme.outline.withValues(alpha: 0.3);
      case 1:
        return colorScheme.primary.withValues(alpha: 0.25);
      case 2:
        return colorScheme.primary.withValues(alpha: 0.5);
      case 3:
        return colorScheme.primary.withValues(alpha: 0.75);
      case 4:
        return colorScheme.primary;
      default:
        return colorScheme.outline.withValues(alpha: 0.3);
    }
  }

  /// 构建月份标题 - 使用主题系统
  Widget _buildMonthHeader() {
    final colorScheme = widget.theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${_currentMonthDate.year}年${_currentMonthDate.month}月',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showNavigation)
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                  color: colorScheme.onSurfaceVariant,
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              if (widget.showNavigation)
                const SizedBox(width: 8),
              if (widget.showNavigation)
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                  color: colorScheme.onSurfaceVariant,
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建月份标题和导航 - 使用主题系统
  Widget _buildHeatmap(List<Habit> filteredHabits) {
    final colorScheme = widget.theme.colorScheme;
    final monthDays = HabitDateUtils.getMonthDays(_currentMonthDate);
    final firstDayOfMonth = monthDays.first;

    final leadingEmptyDays = firstDayOfMonth.weekday % 7;

    final totalCells = leadingEmptyDays + monthDays.length;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: _weekDayNames.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ...List.generate(rows, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;

                    if (cellIndex < leadingEmptyDays) {
                      return Expanded(child: Container(height: 32));
                    }

                    final dayIndex = cellIndex - leadingEmptyDays;
                    if (dayIndex >= monthDays.length) {
                      return Expanded(child: Container(height: 32));
                    }

                    final date = monthDays[dayIndex];
                    final completionCount =
                        _getCompletionCountForDate(date, filteredHabits);
                    final isToday =
                        HabitDateUtils.isSameDay(date, DateTime.now());
                    final cellColor = _getHeatmapColor(
                        completionCount, filteredHabits.length);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Tooltip(
                          message: '${HabitDateUtils.formatDateToChinese(date)}\n'
                              '打卡次数：$completionCount次',
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(2),
                              border: isToday
                                  ? Border.all(
                                      color: colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      isToday ? FontWeight.bold : FontWeight.normal,
                                  color: completionCount > 0
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
            const SizedBox(height: 12),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  /// 构建颜色图例 - 使用主题系统
  Widget _buildLegend() {
    final colorScheme = widget.theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '少',
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _getHeatmapLevelColor(index),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          '多',
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;
    final filteredHabits = widget.selectedCategoryId == null
        ? widget.habits
        : widget.habits
            .where((habit) => habit.categoryId == widget.selectedCategoryId)
            .toList();

    if (filteredHabits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有习惯',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击 + 按钮添加你的第一个习惯',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (widget.showHeader) _buildMonthHeader(),
        _buildHeatmap(filteredHabits),
      ],
    );
  }
}
