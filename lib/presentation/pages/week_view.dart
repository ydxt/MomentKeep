import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/core/utils/habit_date_utils.dart';
import 'package:moment_keep/core/services/user_settings_service.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/components/habit_checkin_dialog.dart';

/// 周视图组件
class WeekView extends StatefulWidget {
  /// 习惯列表
  final List<Habit> habits;

  /// 分类列表
  final List<Category> categories;

  /// 主题数据
  final ThemeData theme;

  /// 选中的分类ID
  final String? selectedCategoryId;
  final bool allowRetroactiveCheckIn;

  const WeekView({
    super.key,
    required this.habits,
    required this.categories,
    required this.theme,
    this.selectedCategoryId,
    this.allowRetroactiveCheckIn = true,
  });

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  /// 当前显示的周的基准日期
  late DateTime _currentWeekDate;

  /// 获取星期的短名称
  static const List<String> _weekDayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _currentWeekDate = DateTime.now();
  }

  /// 导航到上一周
  void _previousWeek() {
    setState(() {
      _currentWeekDate = _currentWeekDate.subtract(const Duration(days: 7));
    });
  }

  /// 导航到下一周
  void _nextWeek() {
    setState(() {
      _currentWeekDate = _currentWeekDate.add(const Duration(days: 7));
    });
  }

  void _showMonthYearPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentWeekDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _currentWeekDate = picked;
      });
    }
  }

  /// 获取习惯图标
  IconData _getIcon(Habit habit) {
    switch (habit.icon) {
      case 'water_drop':
        return Icons.water_drop;
      case 'menu_book':
        return Icons.menu_book;
      case 'directions_run':
        return Icons.directions_run;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'mic':
        return Icons.mic;
      default:
        return Icons.book;
    }
  }

  /// 构建周标题
  Widget _buildWeekHeader(List<Habit> filteredHabits) {
    final weekRange = HabitDateUtils.getWeekRange(_currentWeekDate);
    final startDate = weekRange.start;
    final endDate = weekRange.end;

    String dateText;
    if (startDate.month == endDate.month) {
      dateText = '${startDate.year}年${startDate.month}月';
    } else {
      dateText = '${startDate.year}年${startDate.month}月 - ${endDate.month}月';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousWeek,
            icon: Icon(
              Icons.chevron_left,
              color: widget.theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          GestureDetector(
            onTap: _showMonthYearPicker,
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: _nextWeek,
            icon: Icon(
              Icons.chevron_right,
              color: widget.theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建表头
  Widget _buildTableHeader() {
    final weekDays = HabitDateUtils.getWeekDays(_currentWeekDate);
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '习惯名称',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: widget.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_weekDayNames.length, (index) {
                final isToday = HabitDateUtils.isSameDay(weekDays[index], today);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: isToday
                          ? BoxDecoration(
                              color: widget.theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Center(
                        child: Text(
                          _weekDayNames[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isToday
                                ? widget.theme.colorScheme.onPrimary
                                : widget.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${weekDays[index].day}',
                      style: TextStyle(
                        fontSize: 9,
                        color: isToday
                            ? widget.theme.colorScheme.primary
                            : widget.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '本周积分',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: widget.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建习惯卡片
  Widget _buildHabitCard(Habit habit, List<DateTime> weekDays) {
    final today = DateTime.now();
    final weekRange = HabitDateUtils.getWeekRange(_currentWeekDate);
    final weekPoints = HabitDateUtils.calculatePointsInDateTimeRange(habit, weekRange);
    final weekCompletions = HabitDateUtils.countCompletionsInDateTimeRange(habit, weekRange);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: widget.theme.colorScheme.outline,
                    ),
                    child: Center(
                      child: Icon(
                        _getIcon(habit),
                        color: widget.theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Tooltip(
                                message: '${habit.name}\n类型：${habit.type == HabitType.negative ? '负向习惯' : '正向习惯'}\n积分：${habit.type == HabitType.negative ? '-${habit.fullStars}分' : '+${habit.fullStars}分'}\n本周已打卡：$weekCompletions次',
                                child: Text(
                                  habit.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: widget.theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: weekPoints >= 0
                                    ? widget.theme.colorScheme.primary
                                    : widget.theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${weekPoints >= 0 ? '+' : ''}$weekPoints',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '本周已打卡 $weekCompletions 次',
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: weekDays.map((date) {
                  final isChecked = HabitDateUtils.isHabitCheckedOnDate(habit, date);
                  final isToday = HabitDateUtils.isSameDay(date, today);
                  final isFuture = date.isAfter(today);

                  return GestureDetector(
                    onTap: isToday || (widget.allowRetroactiveCheckIn && !isFuture)
                        ? () {
                            if (isChecked) {
                              _showUndoCheckInDialog(habit, date: date);
                            } else {
                              _showCheckInDialog(habit, date: isToday ? null : date);
                            }
                          }
                        : null,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: isToday && !isChecked
                          ? BoxDecoration(
                              color: widget.theme.colorScheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Center(
                        child: Icon(
                          isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isChecked
                              ? widget.theme.colorScheme.primary
                              : isToday
                                  ? widget.theme.colorScheme.primary.withValues(alpha: 0.6)
                                  : widget.theme.colorScheme.outline,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                '${weekPoints >= 0 ? '+' : ''}$weekPoints',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: weekPoints >= 0
                      ? widget.theme.colorScheme.primary
                      : widget.theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示打卡对话框
  void _showCheckInDialog(Habit habit, {DateTime? date}) {
    showDialog(
      context: context,
      builder: (context) => HabitCheckInDialog(
        habit: habit,
        date: date,
      ),
    );
  }

  /// 显示撤销打卡确认对话框
  void _showUndoCheckInDialog(Habit habit, {DateTime? date}) {
    final checkDate = date ?? DateTime.now();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: widget.theme.colorScheme.surface,
          title: Text(
            '撤销打卡',
            style: TextStyle(color: widget.theme.colorScheme.onSurface),
          ),
          content: Text(
            '确定要撤销「${habit.name}」在 ${HabitDateUtils.formatDateToChinese(checkDate, includeYear: false)} 的打卡记录吗？撤销后积分将相应扣除。',
            style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () {
                context.read<HabitBloc>().add(UndoHabitCompletion(
                  habit.id,
                  date: checkDate,
                ));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${habit.name} 打卡已撤销')),
                );
              },
              child: Text(
                '确认撤销',
                style: TextStyle(color: widget.theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 根据选中的分类过滤习惯
    final filteredHabits = widget.selectedCategoryId == null
        ? widget.habits
        : widget.habits.where((habit) => habit.categoryId == widget.selectedCategoryId).toList();

    final weekDays = HabitDateUtils.getWeekDays(_currentWeekDate);

    if (filteredHabits.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.task_alt,
                size: 64,
                color: widget.theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '还没有习惯',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击 + 按钮添加你的第一个习惯',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        _buildWeekHeader(filteredHabits),
        _buildTableHeader(),
        ...filteredHabits.map((habit) => _buildHabitCard(habit, weekDays)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.theme.colorScheme.outline,
                  widget.theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -10,
                  right: -10,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -8,
                  left: -8,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '坚持就是胜利',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '你本周已经完成了 ${_getTotalCompletions(filteredHabits, weekDays)} 次打卡！继续保持。',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  /// 获取本周总打卡次数
  int _getTotalCompletions(List<Habit> habits, List<DateTime> weekDays) {
    int total = 0;
    for (final habit in habits) {
      for (final date in weekDays) {
        if (HabitDateUtils.isHabitCheckedOnDate(habit, date)) {
          total++;
        }
      }
    }
    return total;
  }
}
