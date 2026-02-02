import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/dashboard.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/security.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/presentation/blocs/dashboard_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/pages/new_settings_page.dart';

/// 数据统计页面
class DashboardPage extends ConsumerStatefulWidget {
  /// 构造函数
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends ConsumerState<DashboardPage> {
  // 主题变量，在build方法中初始化
  late ThemeData theme;
  // 当前选中的分类
  String _selectedCategory = '习惯统计';
  // 当前选中的习惯
  String _selectedHabit = '全部';
  // 是否显示全部逾期待办
  bool _showAllOverdueTodos = false;
  // 是否显示全部坚持率排行
  bool _showAllConsistencyRanking = false;
  // 打卡日历当前显示的年月
  DateTime _currentCalendarDate = DateTime.now();

  // 习惯分类相关状态
  // 控制是否显示删除按钮
  bool _showDeleteButtons = false;
  // 控制长按动画状态
  bool _isLongPressing = false;
  // 控制是否正在闪烁
  bool _isBlinking = false;
  // 习惯列表
  List<Map<String, dynamic>> _habits = [
    {'name': '全部', 'icon': Icons.grid_view},
    {'name': '晨跑', 'icon': Icons.directions_run},
    {'name': '喝水', 'icon': Icons.water_drop},
    {'name': '阅读', 'icon': Icons.menu_book},
    {'name': '冥想', 'icon': Icons.self_improvement},
  ];

  @override
  Widget build(BuildContext context) {
    // 从ref获取主题
    theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: BlocBuilder<SecurityBloc, SecurityState>(
        builder: (context, securityState) {
          // 默认用户信息
          UserAuth? user = UserAuth(
            id: 'default',
            username: '用户',
            email: '',
            avatar: '',
            isBiometricEnabled: false,
            isAdmin: false,
            lastLoginAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // 从SecurityState获取用户信息
          if (securityState is SecurityLoaded) {
            user = securityState.userAuth;
          } else {
            // 如果还没有加载用户信息，发送加载事件
            context.read<SecurityBloc>().add(LoadSecuritySettings());
          }

          return BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              if (state is DashboardLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is DashboardLoaded) {
                final dashboard = state.dashboard;
                return CustomScrollView(
                  slivers: [
                    // 顶部日期和标题
                    _buildHeader(user),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 日期筛选器
                            _buildDateFilter(),
                            const SizedBox(height: 16),

                            // 分类标签
                            _buildCategoryTabs(),
                            const SizedBox(height: 20),

                            // 根据选中的分类显示不同的内容
                            if (_selectedCategory == '待办统计')
                              _buildTodoStatistics(dashboard)
                            else if (_selectedCategory == '习惯统计')
                              _buildHabitStatistics(dashboard)
                            else if (_selectedCategory == '日记洞察')
                              _buildDiaryInsights(dashboard),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              } else if (state is DashboardError) {
                return Center(child: Text(state.message));
              } else {
                // 初始状态，加载数据
                context.read<DashboardBloc>().add(LoadDashboard(
                      timeRange: _selectedDateLabel ?? '最近一周',
                    ));
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        },
      ),
    );
  }

  /// 构建顶部AppBar
  AppBar _buildAppBar() {
    final theme = ref.watch(currentThemeProvider);
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: theme.colorScheme.onSurface,
          size: 24,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        '数据统计',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
    );
  }

  /// 构建顶部Header（日期和用户头像）
  Widget _buildHeader(UserAuth? user) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧：日期
            Text(
              _getCurrentDate(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            // 右侧：用户头像
            _buildUserAvatar(context, user),
          ],
        ),
      ),
    );
  }

  /// 获取当前日期
  String _getCurrentDate() {
    final now = DateTime.now();
    final weekday = _getWeekdayName(now.weekday);
    final month = _getMonthName(now.month);
    return '$weekday, $month ${now.day}日';
  }

  /// 获取完整星期名称
  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return '星期一';
      case 2:
        return '星期二';
      case 3:
        return '星期三';
      case 4:
        return '星期四';
      case 5:
        return '星期五';
      case 6:
        return '星期六';
      case 7:
        return '星期日';
      default:
        return '';
    }
  }

  /// 获取月份名称
  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return '一月';
      case 2:
        return '二月';
      case 3:
        return '三月';
      case 4:
        return '四月';
      case 5:
        return '五月';
      case 6:
        return '六月';
      case 7:
        return '七月';
      case 8:
        return '八月';
      case 9:
        return '九月';
      case 10:
        return '十月';
      case 11:
        return '十一月';
      case 12:
        return '十二月';
      default:
        return '';
    }
  }

  /// 构建用户头像
  Widget _buildUserAvatar(BuildContext context, UserAuth? user) {
    final theme = ref.watch(currentThemeProvider);
    return GestureDetector(
      onTap: () {
        // 导航到个人设置页面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NewSettingsPage()),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: user?.avatar != null && user!.avatar!.isNotEmpty
              ? Image.file(
                  File(user!.avatar!),
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                )
              : Container(
                  color: theme.colorScheme.primary,
                  child: Center(
                    child: Text(
                      user?.username != null && user!.username.isNotEmpty
                          ? user!.username.substring(0, 1).toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// 开始日期
  DateTime? _startDate;

  /// 结束日期
  DateTime? _endDate;

  /// 当前选中的日期范围标签
  String? _selectedDateLabel = '最近7天';

  /// 构建日期筛选器
  Widget _buildDateFilter() {
    return Container(
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
          _buildQuickDateButton('最近7天'),
          _buildQuickDateButton('最近30天'),
          _buildQuickDateButton('全部时间'),
          _buildCustomDateButton(),
        ],
      ),
    );
  }

  /// 构建快速日期选择按钮
  Widget _buildQuickDateButton(String label) {
    final isSelected = _selectedDateLabel == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateLabel = label;
          // 设置默认日期范围
          if (label == '最近7天') {
            _endDate = DateTime.now();
            _startDate = _endDate!.subtract(const Duration(days: 6));
          } else if (label == '最近30天') {
            _endDate = DateTime.now();
            _startDate = _endDate!.subtract(const Duration(days: 29));
          } else if (label == '全部时间') {
            // 全部时间指的是从最早的记录开始到今天
            _startDate = DateTime.now().subtract(const Duration(days: 365));
            _endDate = DateTime.now();
          }
        });
        // 发送加载事件，传递所选时间范围和日期
        context.read<DashboardBloc>().add(LoadDashboard(
              timeRange: label,
              startDate: _startDate,
              endDate: _endDate,
            ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 构建自定义日期选择按钮
  Widget _buildCustomDateButton() {
    final isSelected = _selectedDateLabel == '自定义';
    return GestureDetector(
      onTap: () async {
        // 确保初始日期范围合理
        final safeStartDate =
            _startDate ?? DateTime.now().subtract(const Duration(days: 6));
        final safeEndDate = _endDate ?? DateTime.now();

        // 显示日期范围选择器
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
          initialDateRange:
              DateTimeRange(start: safeStartDate, end: safeEndDate),
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme,
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
          // 发送加载事件，传递所选时间范围和日期
          context.read<DashboardBloc>().add(LoadDashboard(
                timeRange: '自定义',
                startDate: picked.start,
                endDate: picked.end,
              ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        ),
        child: Text(
          '自定义',
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 构建分类标签
  Widget _buildCategoryTabs() {
    return Row(
      children: [
        _buildCategoryTab('待办统计', _selectedCategory == '待办统计'),
        _buildCategoryTab('习惯统计', _selectedCategory == '习惯统计'),
        _buildCategoryTab('日记洞察', _selectedCategory == '日记洞察'),
      ],
    );
  }

  /// 构建分类标签
  Widget _buildCategoryTab(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = label;
          });
        },
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 8.0),
                height: 2,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建习惯筛选标签
  Widget _buildHabitFilters() {
    return GestureDetector(
      onTap: () {
        // 点击任意位置关闭删除按钮和闪烁效果
        setState(() {
          _showDeleteButtons = false;
          _isLongPressing = false;
          _isBlinking = false;
        });
      },
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 全部标签
              _buildHabitFilter(_habits[0]['name'], _habits[0]['icon'],
                  isSelected: _selectedHabit == _habits[0]['name'], index: 0),
              // 其他习惯标签
              ...List.generate(
                _habits.length - 1,
                (index) => _buildDraggableHabitFilter(
                  _habits[index + 1]['name'],
                  _habits[index + 1]['icon'],
                  isSelected: _selectedHabit == _habits[index + 1]['name'],
                  index: index + 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建习惯筛选标签
  Widget _buildHabitFilter(String label, IconData icon,
      {bool isSelected = false, required int index}) {
    // 构建基础芯片内容
    Widget chipContent = Container(
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : theme.colorScheme.outline,
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );

    // 构建完整的芯片
    Widget chipContainer = chipContent;

    // 只有非"全部"标签才添加闪烁动画效果
    if (_showDeleteButtons && label != '全部') {
      // 使用循环动画实现闪烁效果
      chipContainer = AnimatedOpacity(
        opacity: _isLongPressing ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: chipContainer,
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedHabit = label;
          // 点击分类时隐藏删除按钮
          _showDeleteButtons = false;
          _isLongPressing = false;
          _isBlinking = false;
        });
        // 发送加载事件，传递所选习惯筛选条件和当前选中的日期范围
        context.read<DashboardBloc>().add(LoadDashboard(
              timeRange: _selectedDateLabel ?? '最近一周',
              habitFilter: label,
            ));
      },
      onLongPress: () {
        // 只有非"全部"标签才允许长按
        if (label != '全部') {
          setState(() {
            _showDeleteButtons = true;
            _isLongPressing = true;
          });
          // 启动持续闪烁动画
          _startBlinkingAnimation();
        }
      },
      child: chipContainer,
    );
  }

  /// 构建可拖动的习惯筛选标签
  Widget _buildDraggableHabitFilter(String label, IconData icon,
      {bool isSelected = false, required int index}) {
    // 构建基础芯片内容
    Widget chipContent =
        _buildHabitFilter(label, icon, isSelected: isSelected, index: index);

    // 只有当显示删除按钮时，才允许拖动排序
    if (_showDeleteButtons) {
      // 构建带有拖动功能的芯片
      return LongPressDraggable(
        data: index,
        delay: const Duration(milliseconds: 0), // 立即开始拖动，因为已经显示了删除按钮
        feedback: Container(
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected ? Colors.transparent : theme.colorScheme.outline,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        childWhenDragging: Container(
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 1,
            ),
          ),
        ),
        child: DragTarget<int>(
          onAcceptWithDetails: (details) {
            _reorderHabits(details.data, index);
          },
          builder: (context, candidateData, rejectedData) {
            return chipContent;
          },
        ),
      );
    }

    return chipContent;
  }

  /// 启动闪烁动画
  void _startBlinkingAnimation() {
    // 已经在执行闪烁动画，直接返回
    if (_isBlinking) return;

    _isBlinking = true;

    // 定义闪烁动画函数
    void blink() {
      if (mounted && _showDeleteButtons) {
        setState(() {
          _isLongPressing = !_isLongPressing;
        });

        // 减慢闪烁频率到800毫秒
        Future.delayed(const Duration(milliseconds: 800), blink);
      } else {
        // 停止闪烁
        _isBlinking = false;
      }
    }

    // 开始闪烁
    blink();
  }

  /// 重新排序习惯
  void _reorderHabits(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _habits.removeAt(oldIndex);
      _habits.insert(newIndex, item);
    });
  }

  /// 构建统计卡片
  Widget _buildStatCards(Dashboard dashboard) {
    // 计算时间范围内的完成天数
    final completedDaysInRange = dashboard.checkInHistory.length;

    return Column(
      children: [
        // 平均坚持率卡片
        _buildAverageConsistencyCard(dashboard),
        const SizedBox(height: 16),

        // 总坚持天数和平均得分卡片
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '总坚持天数',
                Icons.local_fire_department,
                '$completedDaysInRange',
                '天',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                '总打卡次数',
                Icons.stars,
                '${dashboard.totalCheckIns}',
                '次',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建平均坚持率卡片
  Widget _buildAverageConsistencyCard(Dashboard dashboard) {
    // 计算时间范围内的完成率
    int totalDaysInRange;
    if (_selectedDateLabel == '最近7天') {
      totalDaysInRange = 7;
    } else if (_selectedDateLabel == '最近30天') {
      totalDaysInRange = 30;
    } else if (_selectedDateLabel == '全部时间') {
      totalDaysInRange = 365;
    } else if (_selectedDateLabel == '自定义' && _startDate != null && _endDate != null) {
      totalDaysInRange = _endDate!.difference(_startDate!).inDays + 1;
    } else {
      totalDaysInRange = 30; // 默认30天
    }

    // 计算时间范围内的完成天数和完成率
    final completedDaysInRange = dashboard.checkInHistory.length;
    final completionRate = totalDaysInRange > 0 ? completedDaysInRange / totalDaysInRange : 0.0;
    final completionRatePercentage = (completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // 背景渐变
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 卡片内容
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '平均坚持率',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$completionRatePercentage',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 20,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '4.2%',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '较上月',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 环形图
              _buildCircularProgress(completionRatePercentage),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建环形进度图
  Widget _buildCircularProgress(int percentage) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆环
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation(
                theme.colorScheme.outline.withOpacity(0.2),
              ),
              backgroundColor: Colors.transparent,
            ),
          ),

          // 进度圆环
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation(
                theme.colorScheme.primary,
              ),
              backgroundColor: Colors.transparent,
            ),
          ),

          // 中心对勾
          Icon(
            Icons.check_circle,
            size: 32,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatCard(
      String title, IconData icon, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建打卡分数趋势
  Widget _buildScoreTrend(Dashboard dashboard) {
    // 从HabitBloc获取真实的习惯数据
    final List<Habit> habits = context.read<DashboardBloc>().habitBloc?.state
            is HabitLoaded
        ? (context.read<DashboardBloc>().habitBloc!.state as HabitLoaded).habits
        : [];

    // 生成习惯颜色映射
    final Map<String, Color> habitColorMap = {};
    final List<Color> colorPalette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.lime,
    ];

    for (int i = 0; i < habits.length; i++) {
      habitColorMap[habits[i].id] = colorPalette[i % colorPalette.length];
    }

    // 生成数据和标签
    List<Map<String, dynamic>> generateTrendData() {
      final result = <Map<String, dynamic>>[];

      // 添加总计数据
      final Map<String, dynamic> totalData = {
        'id': 'total',
        'name': '总计',
        'color': theme.colorScheme.primary,
        'data': <double>[],
        'dates': <String>[],
      };

      final sortedDates = dashboard.scoreTrendData.keys.toList()..sort();
      for (final date in sortedDates) {
        totalData['data']!.add(dashboard.scoreTrendData[date] ?? 0.0);
        totalData['dates']!.add(date);
      }

      result.add(totalData);

      // 添加每个习惯的数据
      for (final habit in habits) {
        if (dashboard.habitScoreTrendData.containsKey(habit.id)) {
          final Map<String, dynamic> habitData = {
            'id': habit.id,
            'name': habit.name,
            'color': habitColorMap[habit.id] ?? Colors.grey,
            'data': <double>[],
            'dates': <String>[],
            'fullStars': habit.fullStars,
          };

          for (final date in sortedDates) {
            habitData['data']!
                .add(dashboard.habitScoreTrendData[habit.id]![date] ?? 0.0);
            habitData['dates']!.add(date);
          }

          result.add(habitData);
        }
      }

      return result;
    }

    final trendData = generateTrendData();

    // 如果没有数据，显示提示信息
    if (trendData.isEmpty || trendData[0]['data'].isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
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
              ],
            ),
            const SizedBox(height: 20),

            // 无数据提示
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无打卡分数数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分数趋势图
          SizedBox(
            height: 350, // 增加图表高度，为X轴标签留出更多空间
            child: _EnhancedTrendChart(
              trendData: trendData,
              theme: theme,
              title: '打卡分数趋势',
            ),
          ),
        ],
      ),
    );
  }

  /// 构建打卡日历
  Widget _buildCheckInCalendar(Dashboard dashboard) {
    // 获取当前日历显示的年月
    final currentYear = _currentCalendarDate.year;
    final currentMonth = _currentCalendarDate.month;
    final now = DateTime.now();
    final currentDay = now.day;

    // 构建当前月的日期字符串格式（yyyy-MM-dd）
    String buildDateString(int day) {
      final date = DateTime(currentYear, currentMonth, day);
      return date.toIso8601String().split('T')[0];
    }

    // 计算当前月的第一天是星期几（1-7，周一到周日）
    final firstDayOfMonth = DateTime(currentYear, currentMonth, 1);
    int firstDayWeekday = firstDayOfMonth.weekday;
    if (firstDayWeekday == 7) firstDayWeekday = 0; // 把周日（7）转换为0

    // 计算当前月有多少天
    int daysInMonth;
    if (currentMonth == 2) {
      // 二月，需要判断是否是闰年
      bool isLeapYear = (currentYear % 4 == 0 && currentYear % 100 != 0) ||
          (currentYear % 400 == 0);
      daysInMonth = isLeapYear ? 29 : 28;
    } else if ([4, 6, 9, 11].contains(currentMonth)) {
      // 小月
      daysInMonth = 30;
    } else {
      // 大月
      daysInMonth = 31;
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '打卡日历',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 16,
                    ),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () {
                      // 上一月
                      setState(() {
                        _currentCalendarDate =
                            DateTime(currentYear, currentMonth - 1, 1);
                      });
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      // 点击年月文本，允许用户选择年月
                      _showYearMonthPicker();
                    },
                    child: Text(
                      '$currentYear年 ${currentMonth}月',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.colorScheme.primary,
                        decorationThickness: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      size: 16,
                    ),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () {
                      // 下一月
                      setState(() {
                        _currentCalendarDate =
                            DateTime(currentYear, currentMonth + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 日历网格 - 与分数趋势图宽度对齐
          Container(
            padding: const EdgeInsets.only(left: 20.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount:
                  7 + firstDayWeekday + daysInMonth, // 星期标题 + 上个月的日期 + 当前月的日期
              itemBuilder: (context, index) {
                // 星期标题
                if (index < 7) {
                  final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
                  return Center(
                    child: Text(
                      weekDays[index],
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                }

                // 计算日期
                final dayIndex = index - 7;
                final day = dayIndex - firstDayWeekday + 1;

                if (day <= 0) {
                  // 上个月的日期
                  final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
                  final prevYear =
                      currentMonth == 1 ? currentYear - 1 : currentYear;
                  final prevMonthDays = prevMonth == 2
                      ? ((prevYear % 4 == 0 && prevYear % 100 != 0) ||
                              (prevYear % 400 == 0))
                          ? 29
                          : 28
                      : [4, 6, 9, 11].contains(prevMonth)
                          ? 30
                          : 31;
                  final prevMonthDay = prevMonthDays + day;

                  return Center(
                    child: Text(
                      '$prevMonthDay',
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
                        fontSize: 12,
                      ),
                    ),
                  );
                } else if (day > daysInMonth) {
                  // 下个月的日期
                  final nextMonthDay = day - daysInMonth;
                  return Center(
                    child: Text(
                      '$nextMonthDay',
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
                        fontSize: 12,
                      ),
                    ),
                  );
                } else {
                  // 当前月的日期
                  final dateString = buildDateString(day);
                  final isCheckedIn =
                      dashboard.checkInHistory.contains(dateString);
                  final isToday = day == currentDay &&
                      currentMonth == now.month &&
                      currentYear == now.year;

                  return Center(
                    child: GestureDetector(
                      onTap: () {
                        // 点击日期，显示当天的习惯打卡情况
                        _showCheckInDetails(dateString, dashboard);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCheckedIn
                              ? (isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainer)
                              : Colors.transparent,
                          border: isToday
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                          boxShadow: isToday
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: isCheckedIn
                                  ? (isToday
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: isCheckedIn
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 显示年月选择器
  void _showYearMonthPicker() {
    // 简单实现：显示一个对话框让用户输入年月
    showDialog(
      context: context,
      builder: (context) {
        int selectedYear = _currentCalendarDate.year;
        int selectedMonth = _currentCalendarDate.month;

        // 使用TextEditingController来设置初始值，避免initialValue参数问题
        final yearController =
            TextEditingController(text: selectedYear.toString());
        final monthController =
            TextEditingController(text: selectedMonth.toString());

        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text(
            '选择年月',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 年份选择
              Row(
                children: [
                  Text(
                    '年:',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: yearController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: theme.colorScheme.primary),
                        ),
                        fillColor: theme.colorScheme.surface,
                        filled: true,
                      ),
                      onChanged: (value) {
                        final year = int.tryParse(value);
                        if (year != null) {
                          selectedYear = year;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 月份选择
              Row(
                children: [
                  Text(
                    '月:',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: monthController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: theme.colorScheme.primary),
                        ),
                        fillColor: theme.colorScheme.surface,
                        filled: true,
                      ),
                      onChanged: (value) {
                        final month = int.tryParse(value);
                        if (month != null && month >= 1 && month <= 12) {
                          selectedMonth = month;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentCalendarDate =
                      DateTime(selectedYear, selectedMonth, 1);
                });
                Navigator.of(context).pop();
              },
              child: Text(
                '确定',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 显示当天的习惯打卡情况
  void _showCheckInDetails(String dateString, Dashboard dashboard) {
    // 解析日期字符串，格式为 yyyy-MM-dd
    final dateParts = dateString.split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    final displayDate = '$year年$month月$day日';

    // 从HabitBloc获取真实的习惯数据
    final List<Habit> habits = context.read<DashboardBloc>().habitBloc?.state
            is HabitLoaded
        ? (context.read<DashboardBloc>().habitBloc!.state as HabitLoaded).habits
        : [];

    // 准备习惯图标映射
    final Map<String, IconData> iconMap = {
      'directions_run': Icons.directions_run,
      'water_drop': Icons.water_drop,
      'menu_book': Icons.menu_book,
      'self_improvement': Icons.self_improvement,
      'fitness_center': Icons.fitness_center,
      'account_balance_wallet': Icons.account_balance_wallet,
      'local_drink': Icons.local_drink,
      'book': Icons.book,
      'language': Icons.language,
      'cleaning_services': Icons.cleaning_services,
      'bedtime': Icons.bedtime,
      'outdoor_grill': Icons.outdoor_grill,
      'edit_note': Icons.edit_note,
    };

    // 计算当天每个习惯的打卡情况
    List<Map<String, dynamic>> checkInDetails = [];

    for (final habit in habits) {
      // 检查当天是否有打卡记录
      final checkInRecord = habit.checkInRecords.firstWhere(
        (record) =>
            record.timestamp.toIso8601String().split('T')[0] == dateString,
        orElse: () => CheckInRecord(
          id: '',
          habitId: habit.id,
          score: 0,
          comment: [],
          timestamp: DateTime.now(),
        ),
      );

      final isCheckedIn = checkInRecord.id.isNotEmpty;

      checkInDetails.add({
        'name': habit.name,
        'description': habit.content.isNotEmpty &&
                habit.content.first.type == ContentBlockType.text
            ? habit.content.first.data
            : '',
        'icon': iconMap[habit.icon] ?? Icons.category,
        'color': Color(habit.color),
        'category': habit.category,
        'isCheckedIn': isCheckedIn,
        'score': isCheckedIn ? checkInRecord.score.toDouble() : null,
        'comment': isCheckedIn ? checkInRecord.comment : [],
      });
    }

    // 计算完成率
    final completedCount =
        checkInDetails.where((item) => item['isCheckedIn'] as bool).length;
    final totalCount = checkInDetails.length;
    final completionRate =
        totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

    // 按类别分组
    Map<String, List<Map<String, dynamic>>> categorizedCheckInDetails = {};
    for (var detail in checkInDetails) {
      final category = detail['category'] as String;
      if (!categorizedCheckInDetails.containsKey(category)) {
        categorizedCheckInDetails[category] = [];
      }
      categorizedCheckInDetails[category]!.add(detail);
    }

    // 显示打卡详情弹窗
    showDialog(
      context: context,
      builder: (context) {
        // 将筛选状态移到StatefulBuilder外部，确保状态可以被持久化
        String filterStatus = 'all';

        return StatefulBuilder(
          builder: (context, setState) {
            // 根据筛选状态过滤数据
            List<Map<String, dynamic>> filteredDetails = [];
            if (filterStatus == 'all') {
              filteredDetails = checkInDetails;
            } else if (filterStatus == 'completed') {
              filteredDetails = checkInDetails
                  .where((item) => item['isCheckedIn'] as bool)
                  .toList();
            } else {
              filteredDetails = checkInDetails
                  .where((item) => !(item['isCheckedIn'] as bool))
                  .toList();
            }

            // 按类别分组过滤后的数据
            Map<String, List<Map<String, dynamic>>> categorizedFilteredDetails =
                {};
            for (var detail in filteredDetails) {
              final category = detail['category'] as String;
              if (!categorizedFilteredDetails.containsKey(category)) {
                categorizedFilteredDetails[category] = [];
              }
              categorizedFilteredDetails[category]!.add(detail);
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题和完成率
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayDate,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 完成率显示
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '完成率',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${completionRate.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: completionRate / 100,
                            backgroundColor:
                                theme.colorScheme.outline.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary),
                            borderRadius: BorderRadius.circular(10),
                            minHeight: 6,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$completedCount/$totalCount 习惯已完成',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 筛选按钮
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  label: const Text('全部'),
                                  selected: filterStatus == 'all',
                                  onSelected: (selected) {
                                    setState(() {
                                      filterStatus = 'all';
                                    });
                                  },
                                  selectedColor: theme.colorScheme.primary,
                                  backgroundColor: theme.colorScheme.surface,
                                  labelStyle: TextStyle(
                                    color: filterStatus == 'all'
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: theme.colorScheme.outline),
                                  ),
                                  checkmarkColor: theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('已完成'),
                                  selected: filterStatus == 'completed',
                                  onSelected: (selected) {
                                    setState(() {
                                      filterStatus = 'completed';
                                    });
                                  },
                                  selectedColor: theme.colorScheme.primary,
                                  backgroundColor: theme.colorScheme.surface,
                                  labelStyle: TextStyle(
                                    color: filterStatus == 'completed'
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: theme.colorScheme.outline),
                                  ),
                                  checkmarkColor: theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('未完成'),
                                  selected: filterStatus == 'uncompleted',
                                  onSelected: (selected) {
                                    setState(() {
                                      filterStatus = 'uncompleted';
                                    });
                                  },
                                  selectedColor: theme.colorScheme.primary,
                                  backgroundColor: theme.colorScheme.surface,
                                  labelStyle: TextStyle(
                                    color: filterStatus == 'uncompleted'
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: theme.colorScheme.outline),
                                  ),
                                  checkmarkColor: theme.colorScheme.onPrimary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 习惯列表（可滚动）
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (filteredDetails.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 48,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        filterStatus == 'all'
                                            ? '暂无习惯数据'
                                            : filterStatus == 'completed'
                                                ? '暂无已完成习惯'
                                                : '暂无未完成习惯',
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              // 按类别显示习惯
                              ...categorizedFilteredDetails.entries
                                  .map((entry) {
                                final category = entry.key;
                                final details = entry.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 类别标题
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 16, bottom: 8),
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    // 类别下的习惯列表
                                    ...details.map((detail) {
                                      final isCheckedIn =
                                          detail['isCheckedIn'] as bool;
                                      final score = detail['score'] as double?;

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isCheckedIn
                                                ? theme.colorScheme.surface
                                                : theme.colorScheme.error
                                                    .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isCheckedIn
                                                  ? theme.colorScheme.primary
                                                      .withOpacity(0.3)
                                                  : theme.colorScheme.error
                                                      .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // 习惯图标和名称
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: (detail['color']
                                                              as Color)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Icon(
                                                      detail['icon']
                                                          as IconData,
                                                      size: 18,
                                                      color: detail['color']
                                                          as Color,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        detail['name']
                                                            as String,
                                                        style: TextStyle(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 3),
                                                        child: Text(
                                                          detail['description']
                                                              as String,
                                                          style: TextStyle(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                            fontSize: 12,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),

                                              // 打卡状态和分数
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  // 打卡状态
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isCheckedIn
                                                          ? theme.colorScheme
                                                              .primary
                                                          : theme
                                                              .colorScheme.error
                                                              .withOpacity(0.3),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14),
                                                    ),
                                                    child: Text(
                                                      isCheckedIn
                                                          ? '已打卡'
                                                          : '未打卡',
                                                      style: TextStyle(
                                                        color: isCheckedIn
                                                            ? theme.colorScheme
                                                                .onPrimary
                                                            : theme.colorScheme
                                                                .onError,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),

                                                  // 分数显示
                                                  if (isCheckedIn &&
                                                      score != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 6),
                                                      child: Row(
                                                        children: [
                                                          // 星级评分
                                                          ...List.generate(5,
                                                              (index) {
                                                            return Icon(
                                                              Icons.star,
                                                              size: 14,
                                                              color: index <
                                                                      score
                                                                          .floor()
                                                                  ? theme
                                                                      .colorScheme
                                                                      .primary
                                                                  : theme
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            );
                                                          }),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            score.toString(),
                                                            style: TextStyle(
                                                              color: theme
                                                                  .colorScheme
                                                                  .primary,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ),

                    // 关闭按钮
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '关闭',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 构建坚持率排行
  Widget _buildConsistencyRanking(Dashboard dashboard) {
    // 从HabitBloc获取真实的习惯数据
    final List<Habit> habits = context.read<DashboardBloc>().habitBloc?.state
            is HabitLoaded
        ? (context.read<DashboardBloc>().habitBloc!.state as HabitLoaded).habits
        : [];

    // 计算每个习惯的坚持率
    final List<Map<String, dynamic>> habitConsistencyRates = [];

    // 使用用户选择的时间范围
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    DateTime startTime;
    DateTime endTime = now;
    
    if (_selectedDateLabel == '最近7天') {
      startTime = todayStart.subtract(const Duration(days: 6));
      endTime = now;
    } else if (_selectedDateLabel == '最近30天') {
      startTime = todayStart.subtract(const Duration(days: 29));
      endTime = now;
    } else if (_selectedDateLabel == '全部时间') {
      startTime = todayStart.subtract(const Duration(days: 364));
      endTime = now;
    } else if (_selectedDateLabel == '自定义' && _startDate != null && _endDate != null) { // 自定义
      startTime = _startDate!;
      endTime = _endDate!;
    } else { // 默认
      startTime = todayStart.subtract(const Duration(days: 6));
      endTime = now;
    }

    for (final habit in habits) {
      // 计算时间范围内的打卡天数
      final checkInDays = habit.checkInRecords
          .where((record) => 
              record.timestamp.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
              record.timestamp.isBefore(endTime.add(const Duration(days: 1))))
          .map((record) => record.timestamp.toIso8601String().split('T')[0])
          .toSet()
          .length;

      // 计算坚持率（打卡天数 / 总天数）
      final totalDays = (endTime.difference(startTime).inDays) + 1;
      final consistencyRate =
          totalDays > 0 ? (checkInDays / totalDays) * 100 : 0;

      habitConsistencyRates.add({
        'name': habit.name,
        'rate': consistencyRate.round(),
        'icon': habit.icon,
        'color': Color(habit.color),
      });
    }

    // 排序
    habitConsistencyRates
        .sort((a, b) => (b['rate'] as int).compareTo(a['rate'] as int));

    // 准备习惯图标映射
    final Map<String, IconData> iconMap = {
      'directions_run': Icons.directions_run,
      'water_drop': Icons.water_drop,
      'menu_book': Icons.menu_book,
      'self_improvement': Icons.self_improvement,
      'fitness_center': Icons.fitness_center,
      'account_balance_wallet': Icons.account_balance_wallet,
      'local_drink': Icons.local_drink,
      'book': Icons.book,
      'language': Icons.language,
      'cleaning_services': Icons.cleaning_services,
      'bedtime': Icons.bedtime,
      'outdoor_grill': Icons.outdoor_grill,
    };

    // 模拟数据，用于演示
    final mockRankingData = [
      {
        'name': '阅读',
        'icon': Icons.menu_book,
        'rate': 95,
        'color': const Color(0xFFFF9800)
      },
      {
        'name': '喝水',
        'icon': Icons.water_drop,
        'rate': 88,
        'color': const Color(0xFF2196F3)
      },
      {
        'name': '晨跑',
        'icon': Icons.directions_run,
        'rate': 62,
        'color': AppTheme.secondaryColor
      },
      {
        'name': '冥想',
        'icon': Icons.self_improvement,
        'rate': 85,
        'color': const Color(0xFF9C27B0)
      },
      {
        'name': '健身',
        'icon': Icons.fitness_center,
        'rate': 78,
        'color': const Color(0xFFE91E63)
      },
      {
        'name': '记账',
        'icon': Icons.account_balance_wallet,
        'rate': 70,
        'color': const Color(0xFF4CAF50)
      },
    ]..sort((a, b) => (b['rate'] as int).compareTo(a['rate'] as int)); // 从大到小排序

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '坚持率排行',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllConsistencyRanking = !_showAllConsistencyRanking;
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child: Text(
                  _showAllConsistencyRanking ? '收起' : '查看全部',
                  style: TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 排行列表
          Column(
            children: [
              // 如果有真实数据，使用真实数据，否则使用模拟数据
              if (habitConsistencyRates.isNotEmpty)
                ...(_showAllConsistencyRanking
                        ? habitConsistencyRates
                        : habitConsistencyRates.take(3))
                    .map((item) {
                  final name = item['name'] as String;
                  final rate = item['rate'] as int;
                  final iconName = item['icon'] as String;
                  final color = item['color'] as Color;

                  // 获取图标
                  final icon = iconMap[iconName] ?? Icons.category;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildRankingItem(
                      name,
                      icon,
                      rate,
                      color,
                    ),
                  );
                }).toList()
              else
                ...(_showAllConsistencyRanking
                        ? mockRankingData
                        : mockRankingData.take(3))
                    .map((item) {
                  return Column(
                    children: [
                      _buildRankingItem(
                        item['name'] as String,
                        item['icon'] as IconData,
                        item['rate'] as int,
                        item['color'] as Color,
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建排行项
  Widget _buildRankingItem(
    String name,
    IconData icon,
    int percentage,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建待办统计模块
  Widget _buildTodoStatistics(Dashboard dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 概览数据
        _buildTodoOverview(dashboard),
        const SizedBox(height: 20),

        // 待办完成趋势图
        _buildTodoTrendChart(dashboard),
        const SizedBox(height: 20),

        // 待办分类分布图
        _buildTodoCategoryChart(dashboard),
        const SizedBox(height: 20),

        // 逾期待办列表
        _buildOverdueTodoList(dashboard),
      ],
    );
  }

  /// 构建待办概览数据
  Widget _buildTodoOverview(Dashboard dashboard) {
    // 使用真实的待办数据
    final totalTodos = dashboard.totalTodos;
    final completedTodos = dashboard.completedTodos;
    final uncompletedTodos = totalTodos - completedTodos;
    final completionRate = (dashboard.todoCompletionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '待办概览',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewItem(
                '总待办',
                '$totalTodos',
                Icons.format_list_bulleted,
                theme.colorScheme.onSurface,
                theme.colorScheme.onSurface.withOpacity(0.1),
              ),
              _buildOverviewItem(
                '已完成',
                '$completedTodos',
                Icons.check_circle_outline,
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.1),
              ),
              _buildOverviewItem(
                '未完成',
                '$uncompletedTodos',
                Icons.pending_actions,
                theme.colorScheme.secondary,
                theme.colorScheme.secondary.withOpacity(0.1),
              ),
              _buildOverviewItem(
                '完成率',
                '$completionRate%',
                Icons.analytics_outlined,
                theme.colorScheme.tertiary,
                theme.colorScheme.tertiary.withOpacity(0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建概览单项
  Widget _buildOverviewItem(
      String label, String value, IconData icon, Color color, Color bgColor) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// 构建待办完成趋势图
  Widget _buildTodoTrendChart(Dashboard dashboard) {
    // 生成趋势数据
    List<Map<String, dynamic>> generateTrendData() {
      final result = <Map<String, dynamic>>[];

      // 添加总计数据
      final Map<String, dynamic> totalData = {
        'id': 'total',
        'name': '总计',
        'color': const Color(0xFF2196F3),
        'data': <double>[],
        'dates': <String>[],
      };

      final sortedDates = dashboard.todoTrendData.keys.toList()..sort();
      for (final date in sortedDates) {
        totalData['data']!.add(dashboard.todoTrendData[date]?.toDouble() ?? 0.0);
        totalData['dates']!.add(date);
      }

      result.add(totalData);

      return result;
    }

    final trendData = generateTrendData();

    // 如果没有数据，显示提示信息
    if (trendData.isEmpty || trendData[0]['data'].isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '待办完成趋势',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 无数据提示
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无待办完成数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 待办完成趋势图
          SizedBox(
            height: 300, // 增加图表高度，为X轴标签留出更多空间
            child: _EnhancedTrendChart(
              trendData: trendData,
              theme: theme,
              title: '待办完成趋势',
            ),
          ),
        ],
      ),
    );
  }

  /// 构建待办分类分布图
  Widget _buildTodoCategoryChart(Dashboard dashboard) {
    // 生成分类颜色映射
    final Map<String, Color> categoryColorMap = {
      '工作': Colors.blue,
      '生活': Colors.green,
      '学习': Colors.orange,
      '其他': Colors.grey,
    };

    // 如果没有数据，显示提示信息
    if (dashboard.todoCategoryDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '待办分类分布',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 无数据提示
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无待办分类数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 计算总待办数
    final total = dashboard.todoCategoryDistribution.values.fold(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '待办分类分布',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 分类分布列表
          Column(
            children: [
              for (final entry in dashboard.todoCategoryDistribution.entries)
                Column(
                  children: [
                    _buildCategoryItem(
                      entry.key,
                      total > 0 ? (entry.value * 100 ~/ total) : 0,
                      categoryColorMap[entry.key] ?? Colors.grey,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建分类项
  Widget _buildCategoryItem(String name, int percentage, Color color) {
    return Row(
      children: [
        Text(
          name,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$percentage%',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 构建逾期待办列表
  Widget _buildOverdueTodoList(Dashboard dashboard) {
    // 根据展开状态决定显示多少项
    final displayedTodos =
        _showAllOverdueTodos ? dashboard.overdueTodos : dashboard.overdueTodos.take(3).toList();

    // 如果没有数据，显示提示信息
    if (dashboard.overdueTodos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_toggle_off,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '逾期待办',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 无数据提示
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无逾期待办数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '逾期待办',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '共${dashboard.overdueTodos.length}项',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 逾期待办列表
          Column(
            children: [
              // 显示逾期项目
              for (var todo in displayedTodos)
                Column(
                  children: [
                    _buildOverdueItem(
                        todo['title'] as String, todo['date'] as String),
                    const SizedBox(height: 12),
                  ],
                ),

              // 查看全部按钮
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllOverdueTodos = !_showAllOverdueTodos;
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child: Text(
                  _showAllOverdueTodos ? '收起' : '查看全部',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建逾期待办项
  Widget _buildOverdueItem(String title, String date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: theme.colorScheme.error.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Text(
          date,
          style: TextStyle(
            color: theme.colorScheme.error,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// 构建习惯统计模块
  Widget _buildHabitStatistics(Dashboard dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 习惯筛选标签
        _buildHabitFilters(),
        const SizedBox(height: 20),

        // 统计卡片
        _buildStatCards(dashboard),
        const SizedBox(height: 20),

        // 打卡分数趋势
        _buildScoreTrend(dashboard),
        const SizedBox(height: 20),

        // 打卡日历
        _buildCheckInCalendar(dashboard),
        const SizedBox(height: 20),

        // 坚持率排行
        _buildConsistencyRanking(dashboard),
      ],
    );
  }

  /// 构建日记洞察模块
  Widget _buildDiaryInsights(Dashboard dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 概览数据
        _buildDiaryOverview(dashboard),
        const SizedBox(height: 20),

        // 日记数量趋势图
        _buildDiaryTrendChart(dashboard),
        const SizedBox(height: 20),

        // 日记标签分布图
        _buildDiaryTagChart(dashboard),
        const SizedBox(height: 20),

        // 媒体使用统计
        _buildMediaUsageStats(dashboard),
      ],
    );
  }

  /// 构建日记概览数据
  Widget _buildDiaryOverview(Dashboard dashboard) {
    // 使用真实的日记数据
    final totalDiaries = dashboard.totalDiaries;
    // 计算每周平均日记数（假设数据范围为30天）
    final weeklyAverage =
        totalDiaries > 0 ? (totalDiaries / 4.0).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '日记概览',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewItem(
                '总日记',
                '$totalDiaries',
                Icons.book_outlined,
                theme.colorScheme.onSurface,
                theme.colorScheme.onSurface.withOpacity(0.1),
              ),
              _buildOverviewItem(
                '每周平均',
                weeklyAverage,
                Icons.calendar_month_outlined,
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.1),
              ),
              _buildOverviewItem(
                '分类数量',
                '${dashboard.diaryCategoryDistribution.length}',
                Icons.category_outlined,
                theme.colorScheme.secondary,
                theme.colorScheme.secondary.withOpacity(0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建日记数量趋势图
  Widget _buildDiaryTrendChart(Dashboard dashboard) {
    // 生成趋势数据
    List<Map<String, dynamic>> generateTrendData() {
      final result = <Map<String, dynamic>>[];

      // 添加总计数据
      final Map<String, dynamic> totalData = {
        'id': 'total',
        'name': '总计',
        'color': const Color(0xFF9C27B0),
        'data': <double>[],
        'dates': <String>[],
      };

      final sortedDates = dashboard.diaryTrendData.keys.toList()..sort();
      for (final date in sortedDates) {
        totalData['data']!.add(dashboard.diaryTrendData[date]?.toDouble() ?? 0.0);
        totalData['dates']!.add(date);
      }

      result.add(totalData);

      return result;
    }

    final trendData = generateTrendData();

    // 如果没有数据，显示提示信息
    if (trendData.isEmpty || trendData[0]['data'].isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '日记数量趋势',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 无数据提示
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无日记数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日记数量统计图
          SizedBox(
            height: 300, // 增加图表高度，为X轴标签留出更多空间
            child: _EnhancedTrendChart(
              trendData: trendData,
              theme: theme,
              title: '日记数量统计图',
            ),
          ),
        ],
      ),
    );
  }

  /// 构建日记标签分布图
  Widget _buildDiaryTagChart(Dashboard dashboard) {
    // 使用真实的日记标签数据
    final tagDistribution = dashboard.diaryTagDistribution;
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '日记标签分布',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 标签云或分布列表
          if (tagDistribution.isEmpty)
            // 无标签数据时显示提示
            SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.label_off_outlined,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无标签数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tagDistribution.entries
                  .map((entry) => _buildTagItem(entry.key, entry.value))
                  .toList(),
            ),
        ],
      ),
    );
  }

  /// 构建标签项
  Widget _buildTagItem(String name, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建媒体使用统计
  Widget _buildMediaUsageStats(Dashboard dashboard) {
    // 使用真实的日记媒体使用数据
    final mediaUsage = dashboard.diaryMediaUsage;
    
    // 媒体类型映射，用于显示友好的名称和图标
    final mediaTypeMap = {
      'image': {'name': '图片', 'icon': Icons.image_outlined, 'color': Colors.pink},
      'audio': {'name': '音频', 'icon': Icons.keyboard_voice_outlined, 'color': Colors.blue},
      'video': {'name': '视频', 'icon': Icons.videocam_outlined, 'color': Colors.red},
      'drawing': {'name': '绘图', 'icon': Icons.gesture_outlined, 'color': Colors.green},
      'text': {'name': '文本', 'icon': Icons.text_fields_outlined, 'color': Colors.grey},
    };
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.perm_media_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '媒体使用统计',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 媒体使用列表
          if (mediaUsage.isEmpty)
            // 无媒体数据时显示提示
            SizedBox(
              height: 150,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.perm_media_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无媒体数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...(() {
                  final entriesList = mediaUsage.entries.toList();
                  return entriesList.asMap().entries.map((mapEntry) {
                    final index = mapEntry.key;
                    final entry = mapEntry.value;
                    final mediaType = entry.key;
                    final count = entry.value;
                    final mediaInfo = mediaTypeMap[mediaType.toLowerCase()] ?? 
                        {'name': mediaType, 'icon': Icons.insert_drive_file_outlined, 'color': Colors.grey};
                    
                    return Column(
                      children: [
                        _buildMediaItem(
                          mediaInfo['name'] as String,
                          count,
                          mediaInfo['icon'] as IconData,
                          mediaInfo['color'] as Color,
                        ),
                        if (index < entriesList.length - 1)
                          const SizedBox(height: 16),
                      ],
                    );
                  }).toList();
                })(),
              ],
            ),
        ],
      ),
    );
  }

  /// 构建媒体项
  Widget _buildMediaItem(String name, int count, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '共 $count 个',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// 待办趋势图组件
class _TodoTrendChart extends StatefulWidget {
  final Map<String, int> trendData;
  final ThemeData theme;
  final String selectedDateLabel;
  final DateTime? startDate;
  final DateTime? endDate;

  const _TodoTrendChart({
    required this.trendData,
    required this.theme,
    required this.selectedDateLabel,
    this.startDate,
    this.endDate,
  });

  @override
  _TodoTrendChartState createState() => _TodoTrendChartState();
}

class _TodoTrendChartState extends State<_TodoTrendChart> {
  List<FlSpot> _dataSpots = [];
  List<String> _dates = [];
  double _minY = 0;
  double _maxY = 100;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(covariant _TodoTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trendData != widget.trendData || 
        oldWidget.selectedDateLabel != widget.selectedDateLabel ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _initializeData();
    }
  }

  /// 初始化数据
  void _initializeData() {
    _dataSpots = [];
    _dates = [];

    if (widget.trendData.isEmpty) {
      // 生成默认数据
      int dataPointsCount = 7;
      DateTime startDate = DateTime.now().subtract(Duration(days: 6));
      DateTime endDate = DateTime.now();
      
      if (widget.selectedDateLabel == '最近30天') {
        dataPointsCount = 30;
        startDate = DateTime.now().subtract(Duration(days: 29));
      } else if (widget.selectedDateLabel == '全部时间') {
        dataPointsCount = 365;
        startDate = DateTime.now().subtract(Duration(days: 364));
      } else if (widget.selectedDateLabel == '自定义' && widget.startDate != null && widget.endDate != null) {
        // 自定义时间范围
        startDate = widget.startDate!;
        endDate = widget.endDate!;
        dataPointsCount = endDate.difference(startDate).inDays + 1;
      }
      
      for (int i = dataPointsCount - 1; i >= 0; i--) {
        final date = startDate.add(Duration(days: i));
        _dates.add('${date.month}-${date.day}');
        _dataSpots.add(FlSpot((dataPointsCount - 1 - i).toDouble(), 0));
      }
      _maxY = 5;
    } else {
      // 使用真实数据
      final sortedDates = widget.trendData.keys.toList()..sort();
      for (int i = 0; i < sortedDates.length; i++) {
        final date = sortedDates[i];
        final value = widget.trendData[date] ?? 0;
        _dates.add('${date.split('-')[1]}-${date.split('-')[2]}');
        _dataSpots.add(FlSpot(i.toDouble(), value.toDouble()));
      }
      
      // 更新Y轴范围
      if (_dataSpots.isNotEmpty) {
        final values = _dataSpots.map((spot) => spot.y).toList();
        _maxY = values.reduce((a, b) => a > b ? a : b) * 1.2;
        _maxY = _maxY.ceilToDouble();
      } else {
        _maxY = 5;
      }
    }
  }

  /// 构建X轴标签
  Widget _buildXAxisLabels(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= _dates.length) {
      return const SizedBox.shrink();
    }

    // 控制标签显示密度
    int interval = (_dates.length / 5).ceil();
    if (interval < 1) interval = 1;

    if (index % interval != 0 && index != _dates.length - 1) {
      return const SizedBox.shrink();
    }

    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        _dates[index],
        style: TextStyle(
          color: widget.theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建Y轴标签
  Widget _buildYAxisLabels(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        value.toInt().toString(),
        style: TextStyle(
          color: widget.theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 18,
                  color: widget.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '待办完成趋势',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 图表
        Expanded(
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _dataSpots,
                  isCurved: true,
                  color: const Color(0xFF2196F3),
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4.5,
                        color: const Color(0xFF2196F3),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: false,
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: 1,
                    getTitlesWidget: _buildXAxisLabels,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: _maxY / 4,
                    getTitlesWidget: _buildYAxisLabels,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                drawHorizontalLine: true,
                horizontalInterval: _maxY > 0 ? _maxY / 4 : 1,
                verticalInterval: _dates.length > 7 ? (_dates.length ~/ 6).toDouble() : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: widget.theme.colorScheme.outline.withOpacity(0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: widget.theme.colorScheme.outline.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  );
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: widget.theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              minX: 0,
              maxX: (_dates.length - 1).toDouble(),
              minY: _minY,
              maxY: _maxY,
            ),
            duration: Duration(milliseconds: 700),
          ),
        ),
      ],
    );
  }
}

/// 日记趋势图组件
class _DiaryTrendChart extends StatefulWidget {
  final Map<String, int> trendData;
  final ThemeData theme;
  final String selectedDateLabel;
  final DateTime? startDate;
  final DateTime? endDate;

  const _DiaryTrendChart({
    required this.trendData,
    required this.theme,
    required this.selectedDateLabel,
    this.startDate,
    this.endDate,
  });

  @override
  _DiaryTrendChartState createState() => _DiaryTrendChartState();
}

class _DiaryTrendChartState extends State<_DiaryTrendChart> {
  List<FlSpot> _dataSpots = [];
  List<String> _dates = [];
  double _minY = 0;
  double _maxY = 100;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(covariant _DiaryTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trendData != widget.trendData || 
        oldWidget.selectedDateLabel != widget.selectedDateLabel ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _initializeData();
    }
  }

  /// 初始化数据
  void _initializeData() {
    _dataSpots = [];
    _dates = [];

    if (widget.trendData.isEmpty) {
      // 生成默认数据
      int dataPointsCount = 7;
      DateTime startDate = DateTime.now().subtract(Duration(days: 6));
      DateTime endDate = DateTime.now();
      
      if (widget.selectedDateLabel == '最近30天') {
        dataPointsCount = 30;
        startDate = DateTime.now().subtract(Duration(days: 29));
      } else if (widget.selectedDateLabel == '全部时间') {
        dataPointsCount = 365;
        startDate = DateTime.now().subtract(Duration(days: 364));
      } else if (widget.selectedDateLabel == '自定义' && widget.startDate != null && widget.endDate != null) {
        // 自定义时间范围
        startDate = widget.startDate!;
        endDate = widget.endDate!;
        dataPointsCount = endDate.difference(startDate).inDays + 1;
      }
      
      for (int i = dataPointsCount - 1; i >= 0; i--) {
        final date = startDate.add(Duration(days: i));
        _dates.add('${date.month}-${date.day}');
        _dataSpots.add(FlSpot((dataPointsCount - 1 - i).toDouble(), 0));
      }
      _maxY = 5;
    } else {
      // 使用真实数据
      final sortedDates = widget.trendData.keys.toList()..sort();
      for (int i = 0; i < sortedDates.length; i++) {
        final date = sortedDates[i];
        final value = widget.trendData[date] ?? 0;
        _dates.add('${date.split('-')[1]}-${date.split('-')[2]}');
        _dataSpots.add(FlSpot(i.toDouble(), value.toDouble()));
      }
      
      // 更新Y轴范围
      if (_dataSpots.isNotEmpty) {
        final values = _dataSpots.map((spot) => spot.y).toList();
        _maxY = values.reduce((a, b) => a > b ? a : b) * 1.2;
        _maxY = _maxY.ceilToDouble();
      } else {
        _maxY = 5;
      }
    }
  }

  /// 构建X轴标签
  Widget _buildXAxisLabels(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= _dates.length) {
      return const SizedBox.shrink();
    }

    // 控制标签显示密度
    int interval = (_dates.length / 5).ceil();
    if (interval < 1) interval = 1;

    if (index % interval != 0 && index != _dates.length - 1) {
      return const SizedBox.shrink();
    }

    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        _dates[index],
        style: TextStyle(
          color: widget.theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建Y轴标签
  Widget _buildYAxisLabels(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        value.toInt().toString(),
        style: TextStyle(
          color: widget.theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 18,
                  color: widget.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '日记数量趋势',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 图表
        Expanded(
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _dataSpots,
                  isCurved: true,
                  color: const Color(0xFF9C27B0),
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4.5,
                        color: const Color(0xFF9C27B0),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: false,
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: 1,
                    getTitlesWidget: _buildXAxisLabels,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: _maxY / 4,
                    getTitlesWidget: _buildYAxisLabels,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                drawHorizontalLine: true,
                horizontalInterval: _maxY > 0 ? _maxY / 4 : 1,
                verticalInterval: _dates.length > 7 ? (_dates.length ~/ 6).toDouble() : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: widget.theme.colorScheme.outline.withOpacity(0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: widget.theme.colorScheme.outline.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  );
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: widget.theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              minX: 0,
              maxX: (_dates.length - 1).toDouble(),
              minY: _minY,
              maxY: _maxY,
            ),
            duration: Duration(milliseconds: 700),
          ),
        ),
      ],
    );
  }
}

/// 增强版趋势图组件
class _EnhancedTrendChart extends StatefulWidget {
  final List<Map<String, dynamic>> trendData;
  final ThemeData theme;
  final String title;

  const _EnhancedTrendChart({
    required this.trendData,
    required this.theme,
    this.title = '打卡分数趋势',
  });

  @override
  _EnhancedTrendChartState createState() => _EnhancedTrendChartState();
}

class _EnhancedTrendChartState extends State<_EnhancedTrendChart> {
  bool _normalized = false; // 是否归一化显示
  List<String> _selectedHabits = []; // 选中的习惯ID列表
  Map<String, List<FlSpot>> _habitSpots = {}; // 各习惯曲线数据点
  Map<String, Color> _habitColors = {}; // 习惯颜色映射
  Map<String, int> _habitFullStars = {}; // 习惯满分值
  List<String> _dates = []; // 日期列表
  double _minY = 0; // Y轴最小值
  double _maxY = 100; // Y轴最大值

  @override
  void initState() {
    super.initState();
    // 初始化数据
    _initializeData();
    // 初始化选中的习惯
    _selectedHabits =
        widget.trendData.map((data) => data['id'] as String).toList();
  }

  @override
  void didUpdateWidget(covariant _EnhancedTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当数据更新时重新初始化
    if (oldWidget.trendData != widget.trendData) {
      _initializeData();
      _selectedHabits =
          widget.trendData.map((data) => data['id'] as String).toList();
    }
  }

  /// 初始化数据
  void _initializeData() {
    if (widget.trendData.isEmpty) return;

    // 初始化日期列表
    final totalData = widget.trendData[0];
    _dates = totalData['dates'] as List<String>;

    // 初始化习惯颜色和满分值
    _habitColors = {};
    _habitFullStars = {};

    for (final data in widget.trendData) {
      _habitColors[data['id'] as String] = data['color'] as Color;
      _habitFullStars[data['id'] as String] = data['fullStars'] ?? 5;
    }

    // 更新数据点
    _updateChartData();
  }

  /// 更新图表数据
  void _updateChartData() {
    // 重置数据
    _habitSpots = {};

    // 初始化习惯数据点
    for (final data in widget.trendData) {
      _habitSpots[data['id'] as String] = [];
    }

    // 填充数据点
    for (int i = 0; i < _dates.length; i++) {
      for (final data in widget.trendData) {
        final habitId = data['id'] as String;
        final values = data['data'] as List<double>;

        if (i < values.length) {
          double value = values[i];

          // 计算归一化值
          if (_normalized) {
            final fullStars = _habitFullStars[habitId] ?? 5;
            // 避免除零错误
            if (fullStars > 0) {
              value = (value / fullStars) * 100;
            } else {
              value = 0;
            }
          }

          _habitSpots[habitId]!.add(FlSpot(i.toDouble(), value));
        }
      }
    }

    // 更新Y轴范围
    _updateYAxisRange();
  }

  /// 更新Y轴范围
  void _updateYAxisRange() {
    if (_normalized) {
      // 归一化模式下固定为0-100%
      _minY = 0;
      _maxY = 100;
    } else {
      // 原始模式下根据选中的习惯计算范围
      double min = double.infinity;
      double max = -double.infinity;

      for (final habitId in _selectedHabits) {
        if (_habitSpots.containsKey(habitId)) {
          for (final spot in _habitSpots[habitId]!) {
            if (spot.y < min) min = spot.y;
            if (spot.y > max) max = spot.y;
          }
        }
      }

      // 如果没有数据，设置默认值
      if (min == double.infinity) {
        min = 0;
        max = 5;
      } else {
        // 留出一些空间
        min = 0;
        max = (max * 1.2).ceilToDouble();
      }

      _minY = min;
      _maxY = max;
    }
  }

  /// 构建曲线数据
  List<LineChartBarData> _buildLineBarsData() {
    final lineBarsData = <LineChartBarData>[];

    for (int i = 0; i < widget.trendData.length; i++) {
      final data = widget.trendData[i];
      final habitId = data['id'] as String;

      // 只添加选中的习惯
      if (_selectedHabits.contains(habitId)) {
        final spots = _habitSpots[habitId] ?? [];
        final color = _habitColors[habitId]!;

        lineBarsData.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        );
      }
    }

    return lineBarsData;
  }

  /// 构建X轴标签和Y轴标签
  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          interval: 1, // 设置为1，在getTitlesWidget中自行控制显示频率
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= _dates.length) {
              return const SizedBox.shrink();
            }

            // 控制标签显示密度，最多显示6个标签
            int interval = (_dates.length / 5).ceil();
            if (interval < 1) interval = 1;

            // 只在特定间隔显示，且始终尝试显示最后一个
            if (index % interval != 0 && index != _dates.length - 1) {
              return const SizedBox.shrink();
            }

            // 如果最后一个点离前一个显示的点太近，则不显示前一个或不显示最后一个（这里选择显示最后一个）
            if (index != _dates.length - 1 &&
                (_dates.length - 1 - index) < interval / 2) {
              return const SizedBox.shrink();
            }

            final dateStr = _dates[index];
            String displayDate = dateStr;
            try {
              final parts = dateStr.split('-');
              if (parts.length >= 3) {
                displayDate = '${parts[1]}-${parts[2]}'; // 显示月-日
              }
            } catch (e) {
              // 忽略解析错误
            }

            return SideTitleWidget(
              meta: meta,
              space: 8,
              child: Text(
                displayDate,
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          getTitlesWidget: (value, meta) {
            // 格式化Y轴值，如果是归一化显示，增加%
            String label = value.toInt().toString();
            if (_normalized) {
              label = '$label%';
            }

            return SideTitleWidget(
              meta: meta,
              space: 8,
              child: Text(
                label,
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// 构建网格
  FlGridData _buildGridData() {
    // 确保 horizontalInterval 不为零
    final double horizontalInterval = _maxY > 0 ? _maxY / 4 : 1;
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: true,
      horizontalInterval: horizontalInterval,
      verticalInterval: _dates.length > 7 ? (_dates.length ~/ 6).toDouble() : 1,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: widget.theme.colorScheme.outline.withOpacity(0.15),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: widget.theme.colorScheme.outline.withOpacity(0.1),
          strokeWidth: 1,
          dashArray: [3, 3],
        );
      },
    );
  }

  /// 构建习惯筛选菜单
  List<PopupMenuEntry<String>> _buildHabitFilterMenu() {
    final menuItems = <PopupMenuEntry<String>>[];

    // 添加全选/取消全选选项
    menuItems.add(
      PopupMenuItem<String>(
        value: 'all',
        child: Row(
          children: [
            Checkbox(
              value: _selectedHabits.length == widget.trendData.length,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    // 全选
                    _selectedHabits = widget.trendData
                        .map((data) => data['id'] as String)
                        .toList();
                  } else {
                    // 取消全选
                    _selectedHabits.clear();
                  }
                  _updateYAxisRange();
                });
                Navigator.of(context).pop();
              },
              activeColor: widget.theme.colorScheme.primary,
            ),
            Text(
              '全部',
              style: TextStyle(
                color: widget.theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    // 添加分隔线
    menuItems.add(const PopupMenuDivider());

    // 添加每个习惯的选项
    for (final data in widget.trendData) {
      final habitId = data['id'] as String;
      final habitName = data['name'] as String;
      final isSelected = _selectedHabits.contains(habitId);

      menuItems.add(
        PopupMenuItem<String>(
          value: habitId,
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedHabits.add(habitId);
                    } else {
                      _selectedHabits.remove(habitId);
                    }
                    _updateYAxisRange();
                  });
                  Navigator.of(context).pop();
                },
                activeColor: _habitColors[habitId],
              ),
              Text(
                habitName,
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return menuItems;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标题和控制栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 标题
            Text(
              widget.title,
              style: TextStyle(
                color: widget.theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            // 归一化开关和菜单按钮
            Row(
              children: [
                // 归一化开关
                Row(
                  children: [
                    Text(
                      '归一化',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _normalized,
                      onChanged: (value) {
                        setState(() {
                          _normalized = value;
                          _updateChartData();
                        });
                      },
                      activeColor: widget.theme.colorScheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // 三个点菜单按钮
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: widget.theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  itemBuilder: (context) => _buildHabitFilterMenu(),
                  padding: const EdgeInsets.all(6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: widget.theme.colorScheme.shadow,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 图表
        Expanded(
          child: LineChart(
            LineChartData(
              lineBarsData: _buildLineBarsData(),
              titlesData: _buildTitlesData(),
              gridData: _buildGridData(),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: widget.theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              minX: 0,
              maxX: (_dates.length - 1).toDouble(),
              minY: _minY,
              maxY: _maxY,
            ),
            // 动画持续时间
            duration: Duration(milliseconds: 700),
          ),
        ),

        // 图例说明
        if (_selectedHabits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 30,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedHabits.length,
                itemBuilder: (context, index) {
                  final habitId = _selectedHabits[index];
                  final habitData = widget.trendData.firstWhere(
                    (data) => data['id'] == habitId,
                    orElse: () =>
                        {'name': '', 'color': widget.theme.colorScheme.primary},
                  );
                  final habitName = habitData['name'] as String;
                  final color = habitData['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          habitName,
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// 交互式趋势图组件
class _InteractiveTrendChart extends StatefulWidget {
  /// 数据点
  final List<double> data;

  /// X轴标签
  final List<String> labels;

  /// 图表颜色
  final Color color;

  /// 提示标签
  final String tooltipLabel;

  /// Y轴最大值
  final double yMax;

  /// Y轴最小值
  final double yMin;

  /// 构造函数
  const _InteractiveTrendChart({
    required this.data,
    required this.labels,
    required this.color,
    required this.tooltipLabel,
    required this.yMax,
    this.yMin = 0,
  });

  @override
  _InteractiveTrendChartState createState() => _InteractiveTrendChartState();
}

/// 交互式趋势图状态
class _InteractiveTrendChartState extends State<_InteractiveTrendChart> {
  /// 悬停数据点索引
  int? _hoverIndex;

  /// 图表实际宽度
  double _chartWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 更新图表宽度
        _chartWidth = constraints.maxWidth;

        return MouseRegion(
          onHover: (details) {
            setState(() {
              _hoverIndex = _findClosestDataPoint(details.localPosition.dx);
            });
          },
          onExit: (details) {
            setState(() {
              _hoverIndex = null;
            });
          },
          child: Stack(
            children: [
              // 绘制趋势图
              CustomPaint(
                painter: _TrendChartPainter(
                  data: widget.data,
                  color: widget.color,
                  hoverIndex: _hoverIndex,
                  yMax: widget.yMax,
                  yMin: widget.yMin,
                ),
                size: Size(_chartWidth, 130.0),
              ),

              // 为每个数据点创建tooltip
              for (int i = 0; i < widget.data.length; i++)
                if (_hoverIndex == i)
                  Positioned(
                    // 基于数据点索引和实际图表宽度定位tooltip
                    left: () {
                      // 每个数据点之间的间距
                      double dataPointX;
                      if (widget.data.length == 1) {
                        // 当只有一个数据点时，绘制在中间
                        dataPointX = _chartWidth / 2;
                      } else {
                        final spacing = _chartWidth / (widget.data.length - 1);
                        dataPointX = i * spacing;
                      }
                      // tooltip宽度约为120，居中显示
                      final tooltipWidth = 120.0;
                      // tooltip左侧位置
                      final left = dataPointX - tooltipWidth / 2;
                      // 确保tooltip不超出图表边界
                      return left.clamp(
                          10.0, _chartWidth - tooltipWidth - 10.0);
                    }(),
                    // 基于数据值定位tooltip
                    top: () {
                      // 图表高度约为130
                      final chartHeight = 130.0;
                      // tooltip高度约为35
                      final tooltipHeight = 35.0;
                      // 数据值
                      final dataValue = widget.data[i];
                      // 计算数据点的y坐标（从上到下）
                      double dataPointY;
                      final yRange = widget.yMax - widget.yMin;
                      if (yRange == 0) {
                        // 当所有数据相同时，绘制在中间位置
                        dataPointY = chartHeight / 2;
                      } else {
                        dataPointY = chartHeight -
                            ((dataValue - widget.yMin) / yRange) * chartHeight;
                      }
                      // tooltip显示在数据点上方，距离数据点10像素
                      final top = dataPointY - tooltipHeight - 10;
                      // 确保tooltip不超出图表边界
                      return top.clamp(
                          10.0, chartHeight - tooltipHeight - 10.0);
                    }(),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        '${widget.tooltipLabel}: ${widget.data[i].toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// 查找最近的数据点索引
  int _findClosestDataPoint(double x) {
    // 当只有一个数据点时，直接返回0
    if (widget.data.length == 1) {
      return 0;
    }

    // 使用实际图表宽度来计算数据点间距
    final spacing = _chartWidth / (widget.data.length - 1);
    // 计算索引并确保在有效范围内
    return (x / spacing).round().clamp(0, widget.data.length - 1);
  }
}

/// 趋势图绘制器
class _TrendChartPainter extends CustomPainter {
  /// 数据点
  final List<double> data;

  /// 图表颜色
  final Color color;

  /// 悬停数据点索引
  final int? hoverIndex;

  /// Y轴最大值
  final double yMax;

  /// Y轴最小值
  final double yMin;

  /// 构造函数
  const _TrendChartPainter({
    required this.data,
    required this.color,
    this.hoverIndex,
    required this.yMax,
    this.yMin = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.fill;

    final hoverPointPaint = Paint()
      ..color = color
      ..strokeWidth = 8.0
      ..style = PaintingStyle.fill;

    // 计算数据范围
    final valueRange = yMax - yMin;

    // 绘制曲线
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      // 防止除以零，当只有一个数据点时，绘制在中间
      final x = data.length == 1
          ? size.width / 2
          : (i / (data.length - 1)) * size.width;
      double y;

      // 防止除以零，当所有数据相同时，绘制在中间位置
      if (valueRange == 0) {
        y = size.height / 2;
      } else {
        y = size.height - ((data[i] - yMin) / valueRange) * size.height;
      }

      // 确保 x 和 y 不是 NaN
      if (x.isNaN || y.isNaN) {
        continue;
      }

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // 绘制数据点
      if (i == hoverIndex) {
        canvas.drawCircle(Offset(x, y), 4.0, hoverPointPaint);
      } else {
        canvas.drawCircle(Offset(x, y), 2.0, pointPaint);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
