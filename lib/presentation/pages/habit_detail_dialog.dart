import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 日期范围选项
enum DateRange {
  last7Days,
  last30Days,
  allTime,
}

/// 习惯详情页面
class HabitDetailDialog extends ConsumerStatefulWidget {
  /// 习惯数据
  final Habit habit;
  
  /// 分类列表
  final List<Category> categories;
  
  /// 构造函数
  const HabitDetailDialog({
    super.key,
    required this.habit,
    required this.categories,
  });

  @override
  ConsumerState<HabitDetailDialog> createState() => _HabitDetailDialogState();
}

class _HabitDetailDialogState extends ConsumerState<HabitDetailDialog> {
  /// 当前选中的日期范围
  DateRange _selectedDateRange = DateRange.last7Days;
  
  /// 习惯名称控制器
  late TextEditingController _nameController;
  
  /// 内容块列表
  late List<ContentBlock> _contentBlocks;
  
  /// 重复周期
  late HabitFrequency _frequency;
  
  /// 每周选择的天数
  late List<int> _selectedDays;
  
  /// 满星数
  late int _fullStars;
  
  /// 提醒开关
  late bool _isReminderEnabled;
  
  /// 提醒时间
  late TimeOfDay _reminderTime;
  
  /// 选中的分类ID
  late String? _selectedCategoryId;
  
  /// 卡片主题色
  late int _cardColor;
  
  /// 是否已修改
  bool _isModified = false;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化编辑状态
    _nameController = TextEditingController(text: widget.habit.name);
    _contentBlocks = List.from(widget.habit.content);
    _frequency = widget.habit.frequency;
    _selectedDays = List.from(widget.habit.reminderDays);
    _fullStars = widget.habit.fullStars;
    _isReminderEnabled = widget.habit.reminderTime != null;
    _reminderTime = widget.habit.reminderTime != null 
        ? TimeOfDay.fromDateTime(widget.habit.reminderTime!) 
        : const TimeOfDay(hour: 7, minute: 0);
    _selectedCategoryId = widget.habit.categoryId;
    _cardColor = widget.habit.color;
    
    // 初始化日期筛选器状态
    _selectedDateLabel = '最近一周';
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 6));
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  /// 保存习惯修改
  void _saveHabit() {
    // 找到选中的分类
    final selectedCategory = widget.categories.firstWhere(
      (cat) => cat.id == _selectedCategoryId,
      orElse: () => Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '默认分类',
        type: CategoryType.habit,
        icon: 'book',
        color: 0xFF13ec5b,
        isExpanded: true,
      ),
    );
    
    final now = DateTime.now();
    
    // 更新习惯
    final updatedHabit = widget.habit.copyWith(
      name: _nameController.text,
      content: _contentBlocks,
      categoryId: selectedCategory.id,
      category: selectedCategory.name,
      icon: selectedCategory.icon,
      color: _cardColor,
      frequency: _frequency,
      reminderDays: _selectedDays,
      reminderTime: _isReminderEnabled 
          ? DateTime(
              now.year,
              now.month,
              now.day,
              _reminderTime.hour,
              _reminderTime.minute,
            )
          : null,
      fullStars: _fullStars,
      updatedAt: now,
    );
    
    // 发送更新事件
    context.read<HabitBloc>().add(UpdateHabit(updatedHabit));
    
    // 返回上一页
    Navigator.pop(context);
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    // 计算打卡天数统计
    final checkInStats = _calculateCheckInStats();
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '习惯详情',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // 只有当内容被修改时，才显示保存按钮
          if (_isModified)
            TextButton(
              onPressed: _saveHabit,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
              child: Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 习惯名称和动力输入
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // 习惯名称
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (text) {
                      setState(() {
                        _isModified = true;
                      });
                    },
                  ),
                  // 动力或计划
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: RichTextEditor(
                      initialContent: _contentBlocks,
                      onContentChanged: (content) {
                        setState(() {
                          _contentBlocks = content;
                          _isModified = true;
                        });
                      },
                      readOnly: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 重复周期
            Text(
              '重复周期',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFrequencyButton('每日', HabitFrequency.daily, theme),
                  _buildFrequencyButton('每周', HabitFrequency.weekly, theme),
                  _buildFrequencyButton('每月', HabitFrequency.monthly, theme),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // 每周天数选择
            if (_frequency == HabitFrequency.weekly) 
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDayButton(-1, '一', theme),
                  _buildDayButton(1, '二', theme),
                  _buildDayButton(2, '三', theme),
                  _buildDayButton(3, '四', theme),
                  _buildDayButton(4, '五', theme),
                  _buildDayButton(5, '六', theme),
                  _buildDayButton(0, '日', theme),
                ],
              ),
            const SizedBox(height: 16),
            
            // 满星数设置
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surface,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.star,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '满星数',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '设置最高可获得星星数量',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildTargetButton('-', () {
                        setState(() {
                          if (_fullStars > 1) {
                            _fullStars--;
                            _isModified = true;
                          }
                        });
                      }, theme),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Text(
                            '$_fullStars',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      _buildTargetButton('+', () {
                        setState(() {
                          _fullStars++;
                          _isModified = true;
                        });
                      }, theme),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 提醒设置
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surface,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.notifications,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '提醒',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} ${_reminderTime.hour >= 12 ? 'PM' : 'AM'}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _isReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isReminderEnabled = value;
                        _isModified = true;
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.surface,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 分类选择
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surface,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.category,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Text(
                        '分类',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 分类标签
                      for (var category in widget.categories.take(3)) 
                        _buildCategoryTag(category, theme),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 卡片主题色
            Text(
              '卡片主题色',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildColorOption(0xFF13ec5b, theme),
                _buildColorOption(0xFFe53935, theme),
                _buildColorOption(0xFF1e88e5, theme),
                _buildColorOption(0xFF8d6e63, theme),
                _buildColorOption(0xFF6a1b9a, theme),
              ],
            ),
            const SizedBox(height: 24),
            
            // 统计信息区域
            _buildStatsSection(checkInStats, theme),
          ],
        ),
      ),
    );
  }
  
  /// 构建频率选择按钮
  Widget _buildFrequencyButton(String label, HabitFrequency frequency, ThemeData theme) {
    final isSelected = _frequency == frequency;
    return GestureDetector(
      onTap: () {
        setState(() {
          _frequency = frequency;
          _isModified = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.transparent : theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  /// 构建分类标签
  Widget _buildCategoryTag(Category category, ThemeData theme) {
    final isSelected = _selectedCategoryId == category.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = category.id;
          _isModified = true;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.transparent : theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          category.name,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  /// 构建颜色选项
  Widget _buildColorOption(int colorValue, ThemeData theme) {
    final isSelected = _cardColor == colorValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _cardColor = colorValue;
          _isModified = true;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: theme.colorScheme.onSurface, width: 3)
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: theme.colorScheme.onSurface,
                size: 20,
              )
            : null,
      ),
    );
  }
  
  /// 构建星期按钮
  Widget _buildDayButton(int dayIndex, String dayName, ThemeData theme) {
    final isSelected = _selectedDays.contains(dayIndex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(dayIndex);
          } else {
            _selectedDays.add(dayIndex);
          }
          _isModified = true;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            dayName,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建目标增减按钮
  Widget _buildTargetButton(String label, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primary,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  

  
  /// 构建统计信息区域
  Widget _buildStatsSection(Map<String, dynamic> stats, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计信息标题
          Text(
            '统计信息',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // 日期筛选器
          _buildDateFilter(theme),
          const SizedBox(height: 24),
          
          // 统计卡片
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 打卡天数卡片
              _buildStatCard(
                icon: Icons.fireplace,
                label: '打卡天数',
                value: '${stats['actualDays']}',
                unit: '/ ${stats['totalDays']} 天',
                theme: theme,
              ),
              // 总分数卡片
              _buildStatCard(
                icon: Icons.star,
                label: '总分数',
                value: '${stats['habitScore']}',
                unit: '分',
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 打卡分数趋势图
          _buildTrendChart(theme),
        ],
      ),
    );
  }
  
  /// 构建统计卡片
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 开始日期
  DateTime? _startDate;
  
  /// 结束日期
  DateTime? _endDate;
  
  /// 当前选中的日期范围标签
  String? _selectedDateLabel;
  
  /// 构建日期筛选器
  Widget _buildDateFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickDateButton('最近一周', theme),
          _buildQuickDateButton('最近30天', theme),
          _buildQuickDateButton('全部时间', theme),
          _buildCustomDateButton(theme),
        ],
      ),
    );
  }
  
  /// 构建快速日期选择按钮
  Widget _buildQuickDateButton(String label, ThemeData theme) {
    final isSelected = _selectedDateLabel == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateLabel = label;
          // 设置默认日期范围
          if (label == '最近一周') {
            _endDate = DateTime.now();
            _startDate = _endDate!.subtract(const Duration(days: 6));
          } else if (label == '最近30天') {
            _endDate = DateTime.now();
            _startDate = _endDate!.subtract(const Duration(days: 29));
          } else if (label == '全部时间') {
            // 全部时间指的是从习惯建立时间开始到今天
            _startDate = widget.habit.createdAt;
            _endDate = DateTime.now();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.transparent : theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  /// 构建自定义日期选择按钮
  Widget _buildCustomDateButton(ThemeData theme) {
    final isSelected = _selectedDateLabel == '自定义';
    return GestureDetector(
      onTap: () async {
        // 确保初始日期范围不早于习惯创建日期
        final safeStartDate = _startDate != null && _startDate!.isAfter(widget.habit.createdAt)
            ? _startDate!
            : widget.habit.createdAt;
        final safeEndDate = _endDate != null ? _endDate! : DateTime.now();
        
        // 显示日期范围选择器
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: widget.habit.createdAt,
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: DateTimeRange(start: safeStartDate, end: safeEndDate),
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: theme.colorScheme.primary,
                  onPrimary: theme.colorScheme.onPrimary,
                  surface: theme.colorScheme.surface,
                  onSurface: theme.colorScheme.onSurface,
                ),
              ),
              child: child!,
            );
          },
        );
        
        if (picked != null) {
          setState(() {
            _startDate = picked.start;
            _endDate = picked.end;
            _selectedDateLabel = '自定义'; // 设置为自定义，以便高亮显示
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.transparent : theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          '自定义',
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  /// 计算打卡统计信息
  Map<String, dynamic> _calculateCheckInStats() {
    // 根据选择的日期范围计算实际统计数据
    DateTime startDate = _startDate ?? widget.habit.createdAt;
    DateTime endDate = _endDate ?? DateTime.now();
    
    // 计算总天数
    final totalDays = endDate.difference(startDate).inDays + 1;
    
    // 过滤出指定日期范围内的打卡记录
    final filteredRecords = widget.habit.checkInRecords.where((record) {
      final recordDate = record.timestamp;
      return recordDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
             recordDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    // 计算实际打卡天数（去重，因为一天可能有多次打卡）
    final checkedInDays = <DateTime>{};
    for (final record in filteredRecords) {
      final checkInDate = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      checkedInDays.add(checkInDate);
    }
    final actualDays = checkedInDays.length;
    
    // 计算总分数（所有打卡记录的score之和）
    final totalScore = filteredRecords.fold(0, (sum, record) => sum + record.score);
    
    return {
      'actualDays': actualDays,
      'totalDays': totalDays,
      'habitScore': totalScore,
      'checkInRecords': filteredRecords,
    };
  }
  
  /// 构建趋势图
  Widget _buildTrendChart(ThemeData theme) {
    // 计算统计数据，获取实际打卡记录
    final checkInStats = _calculateCheckInStats();
    final filteredRecords = checkInStats['checkInRecords'] as List<CheckInRecord>;
    
    // 生成趋势数据和日期标签
    final data = _generateTrendData(filteredRecords);
    final dates = _generateDates(filteredRecords);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '打卡分数趋势',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '得分',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: MouseRegion(
              onHover: (event) {
                // 处理鼠标悬停事件
                // 这里可以添加显示提示信息的逻辑
              },
              child: _InteractiveTrendChart(
                data: data,
                dates: dates,
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 根据实际打卡记录生成趋势数据
  List<int> _generateTrendData(List<CheckInRecord> checkInRecords) {
    if (checkInRecords.isEmpty) {
      return [];
    }
    
    // 按日期排序打卡记录
    final sortedRecords = List.from(checkInRecords)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // 按天分组，计算每天的平均得分
    final dailyScores = <DateTime, List<int>>{};
    for (final record in sortedRecords) {
      final date = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      if (!dailyScores.containsKey(date)) {
        dailyScores[date] = [];
      }
      dailyScores[date]!.add(record.score);
    }
    
    // 计算每天的平均得分
    final trendData = <int>[];
    for (final scores in dailyScores.values) {
      final avgScore = scores.reduce((a, b) => a + b) ~/ scores.length;
      trendData.add(avgScore);
    }
    
    return trendData;
  }
  
  /// 根据实际打卡记录生成日期标签
  List<String> _generateDates(List<CheckInRecord> checkInRecords) {
    if (checkInRecords.isEmpty) {
      return [];
    }
    
    // 按日期排序打卡记录
    final sortedRecords = List.from(checkInRecords)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // 获取所有唯一日期
    final uniqueDates = <DateTime>{};
    for (final record in sortedRecords) {
      final date = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      uniqueDates.add(date);
    }
    
    // 排序日期
    final sortedDates = uniqueDates.toList()..sort();
    
    // 生成日期标签
    final dates = <String>[];
    if (sortedDates.length <= 7) {
      // 如果日期数量较少，显示所有日期
      for (final date in sortedDates) {
        dates.add('${date.day}日');
      }
    } else {
      // 如果日期数量较多，显示等间隔的日期
      final step = sortedDates.length ~/ 5;
      for (var i = 0; i < sortedDates.length; i += step) {
        dates.add('${sortedDates[i].day}日');
      }
    }
    
    return dates;
  }
}

/// 交互式趋势图组件
class _InteractiveTrendChart extends StatefulWidget {
  final List<int> data;
  final List<String> dates;
  final ThemeData theme;
  
  const _InteractiveTrendChart({required this.data, required this.dates, required this.theme});
  
  @override
  State<_InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<_InteractiveTrendChart> {
  /// 鼠标悬停位置
  Offset? _hoverPosition;
  
  /// 悬停的数据点索引
  int? _hoverIndex;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final renderBox = context.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(event.position);
        
        setState(() {
          _hoverPosition = localPosition;
          _hoverIndex = _findClosestDataPoint(localPosition, widget.data.length, renderBox.size.width);
        });
      },
      onExit: (event) {
        setState(() {
          _hoverPosition = null;
          _hoverIndex = null;
        });
      },
      child: Stack(
        children: [
          CustomPaint(
            painter: _TrendChartPainter(
              data: widget.data,
              hoverIndex: _hoverIndex,
              theme: widget.theme,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: widget.dates.map((date) {
                return Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        date,
                        style: TextStyle(
                          color: widget.theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // 显示悬停提示
          if (_hoverPosition != null && _hoverIndex != null && _hoverIndex! < widget.data.length) 
            Positioned(
              left: _hoverPosition!.dx - 30,
              top: _hoverPosition!.dy - 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.data[_hoverIndex!]} 分',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 查找最近的数据点索引
  int _findClosestDataPoint(Offset position, int dataLength, double width) {
    // 当数据长度为0或1时，直接返回0
    if (dataLength <= 1) {
      return 0;
    }
    
    final pointWidth = width / (dataLength - 1);
    final index = (position.dx / pointWidth).round();
    return index.clamp(0, dataLength - 1);
  }
}

/// 趋势图绘制器
class _TrendChartPainter extends CustomPainter {
  final List<int> data;
  final int? hoverIndex;
  final ThemeData theme;
  
  _TrendChartPainter({required this.data, this.hoverIndex, required this.theme});
  
  @override
  void paint(Canvas canvas, Size size) {
    // 如果没有数据，直接返回
    if (data.isEmpty) {
      return;
    }
    
    final paint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    final dotPaint = Paint()
      ..color = theme.colorScheme.primary
      ..style = PaintingStyle.fill;
      
    final hoverDotPaint = Paint()
      ..color = theme.colorScheme.onSurface
      ..style = PaintingStyle.fill;
      
    final bgPaint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [
          theme.colorScheme.primary.withOpacity(0.3),
          theme.colorScheme.primary.withOpacity(0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
    // 计算坐标
    final maxValue = data.reduce((a, b) => a > b ? a : b).toDouble();
    final minValue = data.reduce((a, b) => a < b ? a : b).toDouble();
    final valueRange = maxValue - minValue;
    
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      double normalizedValue = 0.0;
      if (valueRange > 0) {
        normalizedValue = (data[i] - minValue) / valueRange;
      } else {
        // 当所有值都相同时，使用默认值0.5
        normalizedValue = 0.5;
      }
      final y = size.height - (normalizedValue * size.height * 0.7) - 20; // 留一些边距
      points.add(Offset(x, y));
    }
    
    // 绘制渐变填充
    final path = Path()..moveTo(points.first.dx, size.height);
    for (var point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(points.last.dx, size.height);
    path.close();
    canvas.drawPath(path, bgPaint);
    
    // 绘制折线
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
    
    // 绘制数据点
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (i == hoverIndex) {
        // 绘制悬停数据点（放大并添加主题颜色边框）
        canvas.drawCircle(point, 8, hoverDotPaint);
        canvas.drawCircle(point, 4, dotPaint);
      } else {
        // 绘制普通数据点
        canvas.drawCircle(point, 4, dotPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
