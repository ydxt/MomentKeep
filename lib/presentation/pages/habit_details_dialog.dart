import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/core/utils/responsive_utils.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 习惯详情对话框（使用ConsumerStatefulWidget管理状态）
class HabitDetailsDialog extends ConsumerStatefulWidget {
  final Habit habit;

  const HabitDetailsDialog({
    Key? key,
    required this.habit,
  }) : super(key: key);

  @override
  ConsumerState<HabitDetailsDialog> createState() => _HabitDetailsDialogState();
}

class _HabitDetailsDialogState extends ConsumerState<HabitDetailsDialog> {
  // 状态变量
  DateTime currentDate = DateTime.now();
  String calendarView = 'month'; // year, month, week
  DateTime? selectedDate;
  bool isViewButtonsExpanded = true;
  DateTime? startDate;
  DateTime? endDate;
  bool isNotesExpanded = false;

  /// 构建备注部分
  Widget _buildNotesSection(Habit habit, ThemeData theme) {
    // 检查是否有备注
    final hasNotes = habit.notes != null && habit.notes!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 调整按钮位置，将图标放在文本右侧，避免与滚动条干扰
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      isNotesExpanded = !isNotesExpanded;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        '备注',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isNotesExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isNotesExpanded ? null : 0,
            child: SingleChildScrollView(
              physics:
                  isNotesExpanded ? null : const NeverScrollableScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surfaceVariant,
                  border:
                      Border.all(color: theme.colorScheme.outline, width: 1),
                ),
                child: Text(
                  hasNotes ? habit.notes! : '暂无备注',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasNotes
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用BlocBuilder监听HabitBloc的状态变化
    return BlocBuilder<HabitBloc, HabitState>(
      builder: (context, state) {
        // 获取主题
        final theme = ref.watch(currentThemeProvider);
        // 查找最新的habit对象
        Habit latestHabit = widget.habit;
        if (state is HabitLoaded) {
          latestHabit = state.habits.firstWhere(
            (h) => h.id == widget.habit.id,
            orElse: () => widget.habit,
          );
        }

        // 确保latestHabit不为null
        if (latestHabit == null) {
          return const Center(child: Text('习惯数据加载中...'));
        }

        // 计算当前月份的天数
        int getDaysInMonth(int year, int month) {
          return DateTime(year, month + 1, 0).day;
        }

        // 切换到上一个月
        void previousMonth() {
          setState(() {
            currentDate = DateTime(currentDate.year, currentDate.month - 1);
          });
        }

        // 切换到下一个月
        void nextMonth() {
          setState(() {
            currentDate = DateTime(currentDate.year, currentDate.month + 1);
          });
        }

        // 切换到上一年
        void previousYear() {
          setState(() {
            currentDate = DateTime(currentDate.year - 1, currentDate.month);
          });
        }

        // 切换到下一年
        void nextYear() {
          setState(() {
            currentDate = DateTime(currentDate.year + 1, currentDate.month);
          });
        }

        // 获取某一天的打卡记录
        CheckInRecord? getCheckInRecordForDate(String dateString) {
          // 查找匹配的打卡记录
          final matchingRecords = latestHabit.checkInRecords.where((record) {
            final recordDate = record.timestamp.toIso8601String().split('T')[0];
            return recordDate == dateString;
          }).toList();

          // 如果找到匹配的记录，返回第一个；否则返回 null
          return matchingRecords.isNotEmpty ? matchingRecords.first : null;
        }

        // 回到今天
        void goToToday() {
          setState(() {
            currentDate = DateTime.now();
            selectedDate = DateTime.now(); // 回到今天的位置
          });
        }

        // 显示打卡详情
        void showCheckInDetails(
            BuildContext context, CheckInRecord? record, DateTime date) {
          // 设置当前选中的日期
          setState(() {
            selectedDate = date;
          });

          // 如果没有记录，显示未打卡信息
          if (record == null) {
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  backgroundColor: theme.cardColor,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: theme.cardColor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${date.year}年${date.month}月${date.day}日',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '今日未打卡',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '记得完成习惯打卡哦！',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('关闭'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
            return;
          }

          showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxHeight: 600),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${date.year}年${date.month}月${date.day}日',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 打卡时间
                            Row(
                              children: [
                                Text(
                                  '打卡时间: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 得星数
                            Row(
                              children: [
                                Text(
                                  '得星数: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  '${record.score}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.star,
                                  size: 18,
                                  color: theme.colorScheme.tertiary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 备注
                            if (record.comment.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '备注: ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: RichTextEditor(
                                      initialContent: record.comment,
                                      onContentChanged: (content) {},
                                      readOnly: true,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('关闭'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // 构建日期单元格
        Widget buildDateCell(DateTime date, Habit habit,
            {bool isMonthCard = false}) {
          final dateString =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final isChecked = habit.history.contains(dateString);
          final checkInRecord = getCheckInRecordForDate(dateString);
          final hasStars = checkInRecord != null && checkInRecord.score > 0;
          final starCount = checkInRecord?.score ?? 0;

          // 检查是否是今天
          final today = DateTime.now();
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          // 检查是否是选中日期
          final isSelected = selectedDate != null &&
              selectedDate!.year == date.year &&
              selectedDate!.month == date.month &&
              selectedDate!.day == date.day;

          // 检查是否是周末
          final isWeekend = date.weekday == 6 || date.weekday == 7;

          // 使用主题颜色
          final morandiBlue = theme.colorScheme.primary;
          final morandiRed = theme.colorScheme.error;
          final morandiGreen = theme.colorScheme.secondary;
          final morandiYellow = theme.colorScheme.tertiary;
          final morandiPurple = theme.colorScheme.surfaceContainerHighest;
          final morandiGray = theme.colorScheme.surfaceVariant;
          final selectedColor = theme.colorScheme.primary;

          // 根据打卡记录分数选择不同颜色
          Color cellColor = Colors.transparent;
          if (isToday) {
            cellColor = morandiRed;
          } else if (isChecked) {
            // 根据分数选择不同颜色
            if (starCount >= 4) {
              cellColor = morandiBlue;
            } else if (starCount >= 3) {
              cellColor = morandiGreen;
            } else if (starCount >= 2) {
              cellColor = morandiYellow;
            } else {
              cellColor = morandiPurple;
            }
          } else if (isWeekend) {
            cellColor = morandiGray;
          }

          // 年视图卡片中的日期单元格，使用更小的尺寸和字体
          if (isMonthCard) {
            return GestureDetector(
              onTap: () {
                showCheckInDetails(context, checkInRecord, date);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? selectedColor
                        : isToday
                            ? morandiRed
                            : isChecked
                                ? cellColor
                                : Colors.transparent,
                    width: isSelected || isToday ? 1.5 : 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: (isToday || isChecked)
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: isToday || isChecked
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            );
          }

          // 普通日期单元格（月视图和周视图）
          return GestureDetector(
            onTap: () {
              showCheckInDetails(context, checkInRecord, date);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? selectedColor
                          : isToday
                              ? morandiRed
                              : isChecked
                                  ? cellColor
                                  : Colors.transparent,
                      width: isSelected || isToday ? 2.5 : 1,
                    ),
                    boxShadow: (isToday || isChecked || isSelected)
                        ? [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: (isToday || isChecked)
                            ? theme.colorScheme.onPrimary
                            : (isWeekend
                                ? theme.colorScheme.onSurface.withOpacity(0.4)
                                : theme.colorScheme.onSurface),
                        fontWeight: isToday || isChecked
                            ? FontWeight.bold
                            : (isWeekend ? FontWeight.normal : FontWeight.w500),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (hasStars && starCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '$starCount',
                          style: TextStyle(
                            fontSize: 9,
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.star,
                          size: 9,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }

        // 构建月视图日期单元格
        Widget buildDateCellForMonthView(
            int year, int month, int day, Habit habit, bool isEmpty) {
          if (isEmpty) {
            return const SizedBox(height: 70);
          }

          final date = DateTime(year, month, day);
          final dateString =
              '${year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          final isChecked = habit.history.contains(dateString);
          final checkInRecord = getCheckInRecordForDate(dateString);
          final hasStars = checkInRecord != null && checkInRecord.score > 0;
          final starCount = checkInRecord?.score ?? 0;

          // 检查是否是今天
          final today = DateTime.now();
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          // 检查是否是选中日期
          final isSelected = selectedDate != null &&
              selectedDate!.year == date.year &&
              selectedDate!.month == date.month &&
              selectedDate!.day == date.day;

          // 检查是否是周末
          final isWeekend = date.weekday == 6 || date.weekday == 7;

          // 使用主题颜色
          final morandiBlue = theme.colorScheme.primary;
          final morandiRed = theme.colorScheme.error;
          final morandiGreen = theme.colorScheme.secondary;
          final morandiYellow = theme.colorScheme.tertiary;
          final morandiPurple = theme.colorScheme.surfaceContainerHighest;
          final morandiGray = theme.colorScheme.surfaceVariant;
          final selectedColor = theme.colorScheme.primary;

          // 根据打卡记录分数选择不同颜色
          Color cellColor = Colors.transparent;
          if (isToday) {
            cellColor = morandiRed;
          } else if (isChecked) {
            // 根据分数选择不同颜色
            if (starCount >= 4) {
              cellColor = morandiBlue;
            } else if (starCount >= 3) {
              cellColor = morandiGreen;
            } else if (starCount >= 2) {
              cellColor = morandiYellow;
            } else {
              cellColor = morandiPurple;
            }
          } else if (isWeekend) {
            cellColor = morandiGray;
          }

          return GestureDetector(
            onTap: () {
              showCheckInDetails(context, checkInRecord, date);
            },
            child: SizedBox(
              height: 70,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? selectedColor
                            : isToday
                                ? morandiRed
                                : isChecked
                                    ? cellColor
                                    : Colors.transparent,
                        width: isSelected || isToday ? 3 : 1,
                      ),
                      boxShadow: (isToday || isChecked || isSelected)
                          ? [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: (isToday || isChecked)
                            ? theme.colorScheme.onPrimary
                            : (isWeekend
                                ? theme.colorScheme.onSurface.withOpacity(0.4)
                                : theme.colorScheme.onSurface),
                        fontWeight: isToday || isChecked
                            ? FontWeight.bold
                            : (isWeekend
                                ? FontWeight.normal
                                : FontWeight.w500),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    ),
                  ),
                  if (hasStars && starCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$starCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
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

        // 构建月份卡片（用于年视图）
        Widget buildMonthCard(
            DateTime monthDate, Habit habit, ThemeData theme) {
          final year = monthDate.year;
          final month = monthDate.month;
          final daysInMonth = getDaysInMonth(year, month);
          final firstDayOfMonth = DateTime(year, month, 1);
          int firstDayWeekday = firstDayOfMonth.weekday;
          firstDayWeekday = firstDayWeekday == 7 ? 7 : firstDayWeekday;
          final emptyDays = firstDayWeekday - 1;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${month}月',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var day in ['一', '二', '三', '四', '五', '六', '日'])
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
                GridView.count(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
                    for (int i = 0; i < emptyDays; i++) const SizedBox(),
                    for (int day = 1; day <= daysInMonth; day++)
                      buildDateCell(DateTime(year, month, day), habit,
                          isMonthCard: true),
                  ],
                ),
              ],
            ),
          );
        }

        // 构建年视图
        Widget buildYearView(
            DateTime currentDate, Habit habit, ThemeData theme) {
          return GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (int month = 1; month <= 12; month++)
                buildMonthCard(
                    DateTime(currentDate.year, month, 1), habit, theme),
            ],
          );
        }

        // 构建月视图
        Widget buildMonthView(
            DateTime currentDate, Habit habit, ThemeData theme) {
          final year = currentDate.year;
          final month = currentDate.month;
          final daysInMonth = getDaysInMonth(year, month);
          final firstDayOfMonth = DateTime(year, month, 1);
          int firstDayWeekday = firstDayOfMonth.weekday;
          firstDayWeekday = firstDayWeekday == 7 ? 7 : firstDayWeekday;
          final emptyDays = firstDayWeekday - 1;

          // 计算周数
          final totalDays = emptyDays + daysInMonth;
          final weeks = (totalDays / 7).ceil();

          // 计算周数（实际周数，从1开始）
          final firstDayOfYear = DateTime(year, 1, 1);
          final daysFromStartOfYear =
              firstDayOfMonth.difference(firstDayOfYear).inDays;
          final firstWeekOfMonth = (daysFromStartOfYear / 7).ceil() + 1;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: theme.colorScheme.outline, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 30),
                      for (var day in ['一', '二', '三', '四', '五', '六', '日'])
                        Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (int week = 0; week < weeks; week++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: week < weeks - 1
                        ? const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Color(0xFFF0F0F0), width: 0.5),
                            ),
                          )
                        : null,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Center(
                            child: Text(
                              '${firstWeekOfMonth + week}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        for (int dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
                          Expanded(
                            child: buildDateCellForMonthView(
                              year,
                              month,
                              week * 7 + dayOfWeek - emptyDays + 1,
                              habit,
                              week * 7 + dayOfWeek < emptyDays ||
                                  week * 7 + dayOfWeek >=
                                      emptyDays + daysInMonth,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }

        // 构建周视图
        Widget buildWeekView(
            DateTime currentDate, Habit habit, ThemeData theme) {
          // 计算当前周的起始日期（周一）
          int weekday = currentDate.weekday;
          if (weekday == 7) weekday = 0;
          final startOfWeek = currentDate.subtract(Duration(days: weekday));

          // 计算周数
          final firstDayOfYear = DateTime(currentDate.year, 1, 1);
          final daysFromStartOfYear =
              startOfWeek.difference(firstDayOfYear).inDays;
          final weekNumber = (daysFromStartOfYear / 7).ceil() + 1;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Center(
                        child: Text(
                          '$weekNumber周',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    for (int dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final date =
                                startOfWeek.add(Duration(days: dayOfWeek));
                            final checkInRecord = getCheckInRecordForDate(
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
                            showCheckInDetails(context, checkInRecord, date);
                          },
                          child: SizedBox(
                            height: 80,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  [
                                    '一',
                                    '二',
                                    '三',
                                    '四',
                                    '五',
                                    '六',
                                    '日'
                                  ][dayOfWeek],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                buildDateCell(
                                  startOfWeek.add(Duration(days: dayOfWeek)),
                                  habit,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        // 构建主内容
        Widget buildMainContent(ThemeData theme) {
          Widget calendarViewWidget;

          // 根据选择的视图类型构建不同的日历视图
          switch (calendarView) {
            case 'year':
              calendarViewWidget =
                  buildYearView(currentDate, latestHabit, theme);
              break;
            case 'week':
              calendarViewWidget =
                  buildWeekView(currentDate, latestHabit, theme);
              break;
            default:
              calendarViewWidget =
                  buildMonthView(currentDate, latestHabit, theme);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 年月导航和收起/展开图标
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (calendarView == 'year')
                    Row(
                      children: [
                        IconButton(
                          onPressed: previousYear,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${currentDate.year}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          onPressed: nextYear,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          onPressed: previousMonth,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${currentDate.year}年${currentDate.month}月',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          onPressed: nextMonth,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: goToToday,
                        child: Text(
                          '今天',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            isViewButtonsExpanded = !isViewButtonsExpanded;
                          });
                        },
                        icon: Icon(
                          isViewButtonsExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 视图切换按钮（放在年月导航和日历之间）
              if (isViewButtonsExpanded)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              calendarView = 'year';
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: calendarView == 'year'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: const Text('年'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              calendarView = 'month';
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: calendarView == 'month'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: const Text('月'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              calendarView = 'week';
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: calendarView == 'week'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: const Text('周'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // 日历视图
              calendarViewWidget,
              const SizedBox(height: 20),

              // 统计信息卡片（放在下方）
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 统计区间选择器
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: theme.colorScheme.surfaceVariant,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '统计区间',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              // 开始日期选择
                              TextButton(
                                onPressed: () async {
                                  // 根据当前视图类型设置默认初始日期
                                  DateTime defaultInitialDate;
                                  final now = DateTime.now();

                                  switch (calendarView) {
                                    case 'year':
                                      defaultInitialDate =
                                          DateTime(now.year, 1, 1);
                                      break;
                                    case 'month':
                                      defaultInitialDate =
                                          DateTime(now.year, now.month, 1);
                                      break;
                                    case 'week':
                                      // 计算本周一的日期
                                      final daysSinceMonday = now.weekday == 7
                                          ? 6
                                          : now.weekday - 1;
                                      defaultInitialDate = now.subtract(
                                          Duration(days: daysSinceMonday));
                                      break;
                                    default:
                                      defaultInitialDate =
                                          latestHabit.createdAt;
                                  }

                                  final initialDate =
                                      startDate ?? defaultInitialDate;
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime(2020), // 允许选择更早的日期
                                    lastDate: DateTime.now(),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      startDate = pickedDate;
                                      // 确保结束日期不早于开始日期
                                      if (endDate != null &&
                                          endDate!.isBefore(pickedDate)) {
                                        endDate = pickedDate;
                                      }
                                    });
                                  }
                                },
                                child: Text(
                                  // 根据当前视图类型显示默认日期
                                  () {
                                    if (startDate != null) {
                                      return '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}';
                                    } else {
                                      final now = DateTime.now();
                                      switch (calendarView) {
                                        case 'year':
                                          return '${now.year}-01-01';
                                        case 'month':
                                          return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
                                        case 'week':
                                          // 计算本周一的日期
                                          final daysSinceMonday =
                                              now.weekday == 7
                                                  ? 6
                                                  : now.weekday - 1;
                                          final monday = now.subtract(
                                              Duration(days: daysSinceMonday));
                                          return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
                                        default:
                                          return '开始日期';
                                      }
                                    }
                                  }(),
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              Text(
                                '至',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface),
                              ),
                              // 结束日期选择
                              TextButton(
                                onPressed: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: endDate ?? DateTime.now(),
                                    firstDate: startDate ??
                                        DateTime(2020), // 允许选择更早的日期
                                    lastDate: DateTime.now(),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      endDate = pickedDate;
                                    });
                                  }
                                },
                                child: Text(
                                  // 显示结束日期，默认显示今天
                                  endDate != null
                                      ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                                      : () {
                                          final now = DateTime.now();
                                          return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                                        }(),
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              // 重置按钮
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    startDate = null;
                                    endDate = null;
                                  });
                                },
                                child: const Text('重置'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 统计数据显示
                    Builder(builder: (context) {
                      // 计算统计数据，考虑用户选择的统计区间
                      // 确定统计区间
                      // 根据当前视图类型设置默认统计区间
                      DateTime defaultStartDate;
                      final now = DateTime.now();

                      switch (calendarView) {
                        case 'year':
                          defaultStartDate = DateTime(now.year, 1, 1);
                          break;
                        case 'month':
                          defaultStartDate = DateTime(now.year, now.month, 1);
                          break;
                        case 'week':
                          // 计算本周一的日期
                          final daysSinceMonday =
                              now.weekday == 7 ? 6 : now.weekday - 1;
                          defaultStartDate =
                              now.subtract(Duration(days: daysSinceMonday));
                          break;
                        default:
                          defaultStartDate = latestHabit.createdAt;
                      }

                      final effectiveStartDate = startDate ?? defaultStartDate;
                      final effectiveEndDate = endDate ?? DateTime.now();

                      // 筛选出统计区间内的打卡记录
                      final filteredRecords =
                          latestHabit.checkInRecords.where((record) {
                        return record.timestamp.isAfter(effectiveStartDate
                                .subtract(const Duration(days: 1))) &&
                            record.timestamp.isBefore(
                                effectiveEndDate.add(const Duration(days: 1)));
                      }).toList();

                      // 筛选出统计区间内的历史记录
                      final filteredHistory =
                          latestHabit.history.where((dateString) {
                        final date = DateTime.parse(dateString);
                        return date.isAfter(effectiveStartDate
                                .subtract(const Duration(days: 1))) &&
                            date.isBefore(
                                effectiveEndDate.add(const Duration(days: 1)));
                      }).toList();

                      // 总完成次数
                      final totalCompletions = filteredHistory.length;
                      // 总天数（统计区间内的天数）
                      final totalDays = effectiveEndDate
                              .difference(effectiveStartDate)
                              .inDays +
                          1;
                      // 总计星星数量
                      final totalStars = filteredRecords.fold(
                          0, (sum, record) => sum + record.score);

                      // 重新计算当前连续打卡天数
                      int currentStreak = 0;
                      int bestStreak = 0;
                      int tempStreak = 0;

                      // 将历史记录转换为日期对象并排序
                      final sortedDates = filteredHistory
                          .map(DateTime.parse)
                          .toList()
                          .where((date) => date.isBefore(
                              DateTime.now().add(const Duration(days: 1))))
                          .toList()
                        ..sort((a, b) => a.compareTo(b));

                      // 计算当前连续打卡
                      if (sortedDates.isNotEmpty) {
                        // 检查最近的打卡是否是今天或昨天
                        final today = DateTime.now();
                        final yesterday =
                            today.subtract(const Duration(days: 1));
                        final lastCheckIn = sortedDates.last;

                        // 格式化日期，只保留年、月、日
                        final formatDate = (DateTime date) =>
                            DateTime(date.year, date.month, date.day);

                        if (formatDate(lastCheckIn) == formatDate(today) ||
                            formatDate(lastCheckIn) == formatDate(yesterday)) {
                          // 从最近的打卡开始往前计算连续天数
                          tempStreak = 1;
                          for (int i = sortedDates.length - 2; i >= 0; i--) {
                            final currentDate = formatDate(sortedDates[i]);
                            final previousDate = formatDate(sortedDates[i + 1]);
                            final difference =
                                previousDate.difference(currentDate).inDays;

                            if (difference == 1) {
                              tempStreak++;
                            } else {
                              break;
                            }
                          }
                          currentStreak = tempStreak;
                        }
                      }

                      // 计算最佳连续打卡
                      if (sortedDates.isNotEmpty) {
                        tempStreak = 1;
                        bestStreak = 1;

                        final formatDate = (DateTime date) =>
                            DateTime(date.year, date.month, date.day);

                        for (int i = 1; i < sortedDates.length; i++) {
                          final currentDate = formatDate(sortedDates[i]);
                          final previousDate = formatDate(sortedDates[i - 1]);
                          final difference =
                              currentDate.difference(previousDate).inDays;

                          if (difference == 1) {
                            tempStreak++;
                            if (tempStreak > bestStreak) {
                              bestStreak = tempStreak;
                            }
                          } else {
                            tempStreak = 1;
                          }
                        }
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // 当前连续打卡
                          Column(
                            children: [
                              Text(
                                '$currentStreak',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '当前连续',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),

                          // 最佳连续打卡
                          Column(
                            children: [
                              Text(
                                '$bestStreak',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '最佳连续',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),

                          // 总完成次数
                          Column(
                            children: [
                              Text(
                                '$totalCompletions/$totalDays',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '总完成次数',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),

                          // 总计星星数量
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$totalStars',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFD700),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.star,
                                    size: 24,
                                    color: Color(0xFFFFD700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '总计',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        }

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: theme.cardColor,
          child: Container(
            width: ResponsiveUtils.isPC(context) ? 800 : null,
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        latestHabit.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.close,
                            color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),

                  // 频次和每次得到星星的显示
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Row(
                      children: [
                        // 频次显示
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: theme.colorScheme.surfaceVariant,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                latestHabit.frequency == HabitFrequency.daily
                                    ? '每日'
                                    : latestHabit.frequency ==
                                            HabitFrequency.weekly
                                        ? '每周'
                                        : '每月',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 每次得到星星显示
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: theme.colorScheme.surfaceVariant,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '每次',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Color(0xFFFFD700),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${latestHabit.fullStars}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 备注信息，支持收起、展开
                  _buildNotesSection(latestHabit, theme),

                  buildMainContent(theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
