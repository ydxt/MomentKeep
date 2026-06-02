import 'dart:math';
import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/core/utils/habit_date_utils.dart';

/// 圆形进度环组件
class CircularProgressRing extends StatefulWidget {
  /// 完成百分比 (0-100)
  final double percentage;

  /// 环的大小
  final double size;

  /// 进度环宽度
  final double strokeWidth;

  /// 背景环颜色
  final Color backgroundColor;

  /// 进度环颜色
  final Color progressColor;

  /// 动画时长
  final Duration duration;

  /// 环内部显示的文本
  final String? centerText;

  /// 环内部显示的子组件
  final Widget? child;

  const CircularProgressRing({
    super.key,
    required this.percentage,
    this.size = 80,
    this.strokeWidth = 6,
    required this.backgroundColor,
    required this.progressColor,
    this.duration = const Duration(milliseconds: 800),
    this.centerText,
    this.child,
  })  : assert(percentage >= 0 && percentage <= 100),
        assert(strokeWidth < size / 2);

  @override
  State<CircularProgressRing> createState() => _CircularProgressRingState();
}

class _CircularProgressRingState extends State<CircularProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.percentage / 100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CircularProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation =
          Tween<double>(begin: _animation.value, end: widget.percentage / 100)
              .animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _CircularProgressPainter(
              animation: _animation,
              strokeWidth: widget.strokeWidth,
              backgroundColor: widget.backgroundColor,
              progressColor: widget.progressColor,
            ),
          ),
          if (widget.child != null)
            widget.child!
          else if (widget.centerText != null)
            Text(
              widget.centerText!,
              style: TextStyle(
                fontSize: widget.size * 0.22,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final Animation<double> animation;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.animation,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (animation.value > 0) {
      final sweepAngle = 2 * pi * animation.value;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return animation.value != oldDelegate.animation.value ||
        strokeWidth != oldDelegate.strokeWidth ||
        backgroundColor != oldDelegate.backgroundColor ||
        progressColor != oldDelegate.progressColor;
  }
}

/// 月视图习惯列表组件
class MonthHabitList extends StatefulWidget {
  /// 习惯列表
  final List<Habit> habits;

  /// 分类列表
  final List<Category> categories;

  /// 主题数据
  final ThemeData theme;

  /// 选中的分类ID
  final String? selectedCategoryId;

  /// 当前显示月份的基准日期
  final DateTime? currentMonthDate;

  const MonthHabitList({
    super.key,
    required this.habits,
    required this.categories,
    required this.theme,
    this.selectedCategoryId,
    this.currentMonthDate,
  });

  @override
  State<MonthHabitList> createState() => _MonthHabitListState();
}

class _MonthHabitListState extends State<MonthHabitList> {
  /// 当前显示的月的基准日期
  late DateTime _currentMonthDate;

  @override
  void initState() {
    super.initState();
    _currentMonthDate = widget.currentMonthDate ?? DateTime.now();
  }

  @override
  void didUpdateWidget(MonthHabitList oldWidget) {
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

  /// 获取进度环颜色（使用主题系统）
  Color _getProgressColor(Habit habit, double percentage) {
    final colorScheme = widget.theme.colorScheme;
    if (habit.type == HabitType.negative) {
      return colorScheme.error;
    }
    if (percentage >= 80) {
      return colorScheme.primary;
    } else if (percentage >= 50) {
      return colorScheme.primary.withValues(alpha: 0.5);
    } else if (percentage >= 30) {
      return colorScheme.primary.withValues(alpha: 0.25);
    } else {
      return colorScheme.primary.withValues(alpha: 0.25);
    }
  }

  /// 获取积分变化的颜色（使用主题系统）
  Color _getPointsChangeColor(int points) {
    final colorScheme = widget.theme.colorScheme;
    return points >= 0 ? colorScheme.primary : colorScheme.error;
  }

  /// 构建习惯卡片（使用主题系统）
  Widget _buildHabitCard(Habit habit) {
    final colorScheme = widget.theme.colorScheme;
    final monthRange = HabitDateUtils.getMonthRange(_currentMonthDate);
    final daysInMonth = monthRange.end.day;
    final completions =
        HabitDateUtils.countCompletionsInDateTimeRange(habit, monthRange);
    final percentage = (completions / daysInMonth * 100).clamp(0.0, 100.0);
    final points =
        HabitDateUtils.calculatePointsInDateTimeRange(habit, monthRange);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: '${habit.name}\n'
                        '类型：${habit.type == HabitType.negative ? '负向习惯' : '正向习惯'}\n'
                        '积分：${habit.type == HabitType.negative ? '-${habit.fullStars}分' : '+${habit.fullStars}分'}\n'
                        '本月已打卡：$completions天',
                    child: Text(
                      habit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '本月打卡: $completions 天',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircularProgressRing(
              percentage: percentage,
              size: 56,
              strokeWidth: 4,
              backgroundColor: colorScheme.outline,
              progressColor: _getProgressColor(habit, percentage),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${percentage.toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    points >= 0 ? '+$points' : points.toString(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: _getPointsChangeColor(points),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '分',
                    style: TextStyle(
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '习惯进度',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        ...filteredHabits.map((habit) => _buildHabitCard(habit)),
      ],
    );
  }
}
