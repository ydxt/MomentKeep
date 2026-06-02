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
import 'package:moment_keep/presentation/components/charts/premium_trend_chart.dart';
import 'package:moment_keep/presentation/components/charts/premium_donut_chart.dart';
import 'package:moment_keep/presentation/components/charts/premium_bar_chart.dart';
import 'package:moment_keep/presentation/components/charts/chart_gradient_palette.dart';
import 'package:moment_keep/core/utils/icon_helper.dart';
import 'package:moment_keep/presentation/pages/settings_page.dart';

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

  // 习惯列表（动态从HabitBloc获取）
  List<Map<String, dynamic>> _habits = [
    {'name': '全部', 'icon': Icons.grid_view.codePoint.toString()},
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

          return BlocListener<HabitBloc, HabitState>(
            listener: (context, habitState) {
              if (habitState is HabitLoaded && !context.read<DashboardBloc>().isRefreshing) {
                _updateHabitList(habitState.habits);
                context.read<DashboardBloc>().add(RefreshDashboard(
                  timeRange: _selectedDateLabel ?? '最近一周',
                  startDate: _startDate,
                  endDate: _endDate,
                ));
              }
            },
            child: BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                if (state is DashboardLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is DashboardLoaded) {
                  final dashboard = state.dashboard;
                  final habitState = context.read<HabitBloc>().state;
                  if (habitState is HabitLoaded && _habits.length <= 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateHabitList(habitState.habits);
                    });
                  }
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
          ),
          );
        },
      ),
    );
  }

  /// 从HabitBloc更新习惯筛选列表
  void _updateHabitList(List<dynamic> habits) {
    final newHabits = <Map<String, dynamic>>[
      {'name': '全部', 'icon': Icons.grid_view.codePoint.toString()},
    ];
    for (final habit in habits) {
      newHabits.add({
        'name': habit.name,
        'icon': habit.icon,
        'id': habit.id,
      });
    }
    if (!mounted) return;
    setState(() {
      _habits = newHabits;
      if (_selectedHabit != '全部') {
        final exists = _habits.any((h) => h['name'] == _selectedHabit);
        if (!exists) {
          _selectedHabit = '全部';
        }
      }
    });
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
          MaterialPageRoute(builder: (context) => SettingsPage()),
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
          child: user?.avatar != null && user?.avatar!.isNotEmpty == true
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
                      user?.username != null && user?.username.isNotEmpty == true
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
    if (_habits.length <= 1) {
      return const SizedBox.shrink();
    }

    final selectedHabitData = _habits.firstWhere(
      (h) => h['name'] == _selectedHabit,
      orElse: () => _habits.isNotEmpty ? _habits[0] : <String, dynamic>{'name': '全部', 'icon': Icons.grid_view.codePoint.toString()},
    );
    final selectedIconStr = (selectedHabitData['icon'] as String?) ?? Icons.grid_view.codePoint.toString();

    return PopupMenuButton<String>(
      offset: const Offset(0, 4),
      position: PopupMenuPosition.under,
      constraints: _habits.length > 8
          ? BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: theme.colorScheme.surface,
      elevation: 8,
      onSelected: _selectHabit,
      itemBuilder: (context) => _habits.map((habit) {
        final name = habit['name'] as String;
        final iconStr = habit['icon'] as String;
        final isSelected = _selectedHabit == name;
        return PopupMenuItem<String>(
          value: name,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ChartGradientPalette.habitColor.withOpacity(0.2)
                      : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconHelper.buildIconWidget(iconStr, size: 18,
                  color: isSelected
                      ? ChartGradientPalette.habitColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isSelected
                        ? ChartGradientPalette.habitColor
                        : theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 20, color: ChartGradientPalette.habitColor),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconHelper.buildIconWidget(selectedIconStr, size: 16, color: theme.colorScheme.onPrimary),
            const SizedBox(width: 6.0),
            Text(
              _selectedHabit,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }


  void _selectHabit(String name) {
    setState(() {
      _selectedHabit = name;
    });
    context.read<DashboardBloc>().add(LoadDashboard(
      timeRange: _selectedDateLabel ?? '最近一周',
      habitFilter: name,
    ));
  }

  Widget _buildAverageConsistencyCard(Dashboard dashboard) {
    final completionRatePercentage = (dashboard.completionRate * 100).round();

    final trendData = dashboard.weeklyCompletionRates;
    final sortedWeeks = trendData.keys.toList()..sort();
    final trendValues = sortedWeeks.map((k) => trendData[k]! * 100).toList();
    final trendDates = sortedWeeks;

    String trendArrow = '';
    double trendValue = 0;
    if (trendValues.length >= 2) {
      trendValue = trendValues.last - trendValues[trendValues.length - 2];
      trendArrow = trendValue >= 0 ? '↑' : '↓';
    }

    final List<ChartSeries> chartSeries = [];
    if (trendValues.isNotEmpty) {
      chartSeries.add(ChartSeries(
        id: 'completion',
        name: '完成率',
        color: ChartGradientPalette.habitColor,
        values: trendValues,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
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
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (trendArrow.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (trendValue >= 0 ? ChartGradientPalette.positiveColor : ChartGradientPalette.negativeColor).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  trendValue >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 12,
                                  color: trendValue >= 0 ? ChartGradientPalette.positiveColor : ChartGradientPalette.negativeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${trendValue.abs().toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: trendValue >= 0 ? ChartGradientPalette.positiveColor : ChartGradientPalette.negativeColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation(
                            ChartGradientPalette.habitColor.withOpacity(0.15),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: completionRatePercentage / 100,
                          strokeWidth: 6,
                          valueColor: const AlwaysStoppedAnimation(
                            ChartGradientPalette.habitColor,
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        size: 32,
                        color: ChartGradientPalette.habitColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '习惯趋势',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _selectedDateLabel ?? '最近7天',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: chartSeries.isNotEmpty
                      ? PremiumTrendChart(
                          series: chartSeries,
                          dates: trendDates,
                          title: '',
                          compact: true,
                          height: 120,
                          showGradientFill: true,
                          showGlowEffect: true,
                          showDots: false,
                        )
                      : Center(
                          child: Text(
                            '暂无趋势数据',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCards(Dashboard dashboard) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ChartGradientPalette.habitColor.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: ChartGradientPalette.habitColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: ChartGradientPalette.habitColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${dashboard.currentStreak}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前连续',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ChartGradientPalette.pointsColor.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: ChartGradientPalette.pointsColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: ChartGradientPalette.pointsColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${dashboard.streakDays}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '最佳连续',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitTypeCards(Dashboard dashboard) {
    final positiveRate = dashboard.totalHabits > 0
        ? (dashboard.completionRate * 100).round()
        : 0;
    final negativeRate = (dashboard.negativeHabitControlRate * 100).round();

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
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
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ChartGradientPalette.positiveColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: ChartGradientPalette.positiveColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '正向习惯',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${dashboard.positiveHabitCount}',
                      style: TextStyle(
                        color: ChartGradientPalette.positiveColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '个',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: positiveRate / 100,
                    minHeight: 6,
                    backgroundColor: ChartGradientPalette.positiveColor.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(ChartGradientPalette.positiveColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '完成率 $positiveRate%',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
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
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ChartGradientPalette.negativeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_down,
                        color: ChartGradientPalette.negativeColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '反向习惯',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${dashboard.negativeHabitCount}',
                      style: TextStyle(
                        color: ChartGradientPalette.negativeColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '个',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: negativeRate / 100,
                    minHeight: 6,
                    backgroundColor: ChartGradientPalette.negativeColor.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(ChartGradientPalette.negativeColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '控制率 $negativeRate%',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
                  
                  final dayScore = dashboard.dailyCheckInScores[dateString] ?? 0.0;
                  
                  Color heatColor;
                  if (!isCheckedIn || dayScore == 0.0) {
                    heatColor = Colors.transparent;
                  } else if (dayScore < 0) {
                    final intensity = (dayScore.abs() / 5.0).clamp(0.2, 1.0);
                    if (isToday) {
                      heatColor = theme.colorScheme.error;
                    } else {
                      heatColor = theme.colorScheme.error.withOpacity(intensity);
                    }
                  } else {
                    final intensity = (dayScore / 5.0).clamp(0.2, 1.0);
                    if (isToday) {
                      heatColor = theme.colorScheme.primary;
                    } else {
                      heatColor = theme.colorScheme.primary.withOpacity(intensity);
                    }
                  }

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
                          color: heatColor,
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
                              color: isCheckedIn && dayScore != 0
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: isCheckedIn && dayScore != 0
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
          
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '扣分',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              ...List.generate(5, (index) {
                final intensity = (5 - index) / 5.0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.error.withOpacity(intensity.clamp(0.2, 1.0)),
                  ),
                );
              }),
              const SizedBox(width: 8),
              ...List.generate(5, (index) {
                final intensity = (index + 1) / 5.0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(intensity.clamp(0.2, 1.0)),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '加分',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 10,
                ),
              ),
            ],
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

    // 计算当天每个习惯的打卡情况
    List<Map<String, dynamic>> checkInDetails = [];

    for (final habit in habits) {
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
        'icon': habit.icon,
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
                                            children: [
                                              Expanded(
                                                child: Row(
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
                                                      child: IconHelper.buildIconWidget(
                                                        detail['icon']
                                                            as String,
                                                        size: 18,
                                                        color: detail['color']
                                                            as Color,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
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
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
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
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
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
                                                  if (isCheckedIn &&
                                                      score != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 6),
                                                      child: Text(
                                                        score > 0
                                                            ? '+${score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1)}'
                                                            : score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1),
                                                        style: TextStyle(
                                                          color: score >= 0
                                                              ? theme.colorScheme.primary
                                                              : theme.colorScheme.error,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
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
    final List<Habit> habits = context.read<DashboardBloc>().habitBloc?.state
            is HabitLoaded
        ? (context.read<DashboardBloc>().habitBloc!.state as HabitLoaded).habits
        : [];

    final List<Map<String, dynamic>> habitConsistencyRates = [];

    for (final habit in habits) {
      final streak = dashboard.habitStreaks[habit.id] ?? 0;
      final categoryRate = dashboard.categoryCompletionRates[habit.category] ?? 0.0;

      habitConsistencyRates.add({
        'name': habit.name,
        'rate': (categoryRate * 100).round(),
        'icon': habit.icon,
        'color': Color(habit.color),
        'streak': streak,
      });
    }

    habitConsistencyRates
        .sort((a, b) => (b['rate'] as int).compareTo(a['rate'] as int));

    if (habitConsistencyRates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '坚持率排行',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '暂无习惯数据',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
                    color: ChartGradientPalette.habitColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              ...(_showAllConsistencyRanking
                      ? habitConsistencyRates
                      : habitConsistencyRates.take(3))
                  .map((item) {
                final name = item['name'] as String;
                final rate = item['rate'] as int;
                final iconStr = item['icon'] as String;
                final color = item['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildRankingItem(
                    name,
                    iconStr,
                    rate,
                    color,
                  ),
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
    String iconStr,
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
          child: IconHelper.buildIconWidget(iconStr, size: 16, color: color),
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
        _buildTodoOverview(dashboard),
        const SizedBox(height: 16),

        _buildTodoTrendChart(dashboard),
        const SizedBox(height: 16),

        _buildTodoCategoryChart(dashboard),
        const SizedBox(height: 16),

        _buildTodoPriorityChart(dashboard),
        const SizedBox(height: 16),

        _buildTodoCompletionTimeChart(dashboard),
        const SizedBox(height: 16),

        _buildOverdueTodoList(dashboard),
      ],
    );
  }

  /// 构建待办概览数据
  Widget _buildTodoOverview(Dashboard dashboard) {
    final totalTodos = dashboard.totalTodos;
    final completedTodos = dashboard.completedTodos;
    final uncompletedTodos = totalTodos - completedTodos;
    final completionRate = (dashboard.todoCompletionRate * 100).round();
    final lastPeriod = dashboard.lastPeriodCompleted;
    final completedDiff = completedTodos - lastPeriod;
    final uncompletedDiff = uncompletedTodos > 0 ? -(completedDiff) : 0;
    final rateDiff = lastPeriod > 0
        ? ((dashboard.todoCompletionRate - (lastPeriod / (totalTodos > 0 ? totalTodos : 1))) * 100).round()
        : (completionRate > 0 ? completionRate : 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ChartGradientPalette.cardGlowGradient(ChartGradientPalette.todoColor),
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ChartGradientPalette.todoColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ChartGradientPalette.todoColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ChartGradientPalette.todoColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: 16,
                  color: ChartGradientPalette.todoColor,
                ),
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStatItem(
                '总待办',
                '$totalTodos',
                Icons.format_list_bulleted,
                ChartGradientPalette.todoColor,
                null,
              ),
              _buildHeroStatItem(
                '已完成',
                '$completedTodos',
                Icons.check_circle_outline,
                ChartGradientPalette.positiveColor,
                completedDiff,
              ),
              _buildHeroStatItem(
                '未完成',
                '$uncompletedTodos',
                Icons.pending_actions,
                ChartGradientPalette.negativeColor,
                uncompletedDiff != 0 ? uncompletedDiff : null,
              ),
              _buildHeroStatItem(
                '完成率',
                '$completionRate%',
                Icons.analytics_outlined,
                ChartGradientPalette.todoLightColor,
                rateDiff != 0 ? rateDiff : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem(
      String label, String value, IconData icon, Color color, int? trend) {
    final isPositive = trend != null && trend > 0;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trend != null && trend != 0) ...[
              const SizedBox(width: 4),
              Text(
                isPositive ? '↑+${trend.abs()}' : '↓-${trend.abs()}',
                style: TextStyle(
                  color: isPositive
                      ? ChartGradientPalette.positiveColor
                      : ChartGradientPalette.negativeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
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

  /// 构建概览单项


  /// 构建待办完成趋势图
  Widget _buildTodoTrendChart(Dashboard dashboard) {
    final sortedDates = dashboard.todoTrendData.keys.toList()..sort();
    final values = sortedDates
        .map((date) => dashboard.todoTrendData[date]?.toDouble() ?? 0.0)
        .toList();

    if (sortedDates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartGradientPalette.todoColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    size: 16,
                    color: ChartGradientPalette.todoColor,
                  ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ChartGradientPalette.todoColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up,
                  size: 16,
                  color: ChartGradientPalette.todoColor,
                ),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: PremiumTrendChart(
              series: [
                ChartSeries(
                  id: 'todo',
                  name: '完成数',
                  color: ChartGradientPalette.todoColor,
                  values: values,
                ),
              ],
              dates: sortedDates,
              title: '',
              height: 250,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建待办分类分布图
  Widget _buildTodoCategoryChart(Dashboard dashboard) {
    if (dashboard.todoCategoryDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartGradientPalette.todoColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.pie_chart_outline,
                    size: 16,
                    color: ChartGradientPalette.todoColor,
                  ),
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

    final total = dashboard.todoCategoryDistribution.values.fold(0, (sum, count) => sum + count);
    final segments = dashboard.todoCategoryDistribution.entries.map((entry) {
      final index = dashboard.todoCategoryDistribution.keys.toList().indexOf(entry.key);
      return DonutSegment(
        label: entry.key,
        value: entry.value.toDouble(),
        color: ChartGradientPalette.categoryColor(index),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ChartGradientPalette.todoColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pie_chart_outline,
                  size: 16,
                  color: ChartGradientPalette.todoColor,
                ),
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
          const SizedBox(height: 16),
          PremiumDonutChart(
            segments: segments,
            centerText: '$total',
            centerSubText: '总待办',
            size: 140,
            ringWidth: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildTodoPriorityChart(Dashboard dashboard) {
    if (dashboard.todoPriorityDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartGradientPalette.todoColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.flag,
                    size: 16,
                    color: ChartGradientPalette.todoColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '优先级分布',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无优先级数据',
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

    final total = dashboard.todoPriorityDistribution.values.fold(0, (sum, count) => sum + count);
    final segments = dashboard.todoPriorityDistribution.entries.map((entry) {
      return DonutSegment(
        label: entry.key,
        value: entry.value.toDouble(),
        color: ChartGradientPalette.priorityColor(entry.key),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ChartGradientPalette.todoColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flag,
                  size: 16,
                  color: ChartGradientPalette.todoColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '优先级分布',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PremiumDonutChart(
            segments: segments,
            centerText: '$total',
            centerSubText: '总待办',
            size: 140,
            ringWidth: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCompletionTimeChart(Dashboard dashboard) {
    if (dashboard.todoCompletionTimeDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartGradientPalette.todoColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.schedule,
                    size: 16,
                    color: ChartGradientPalette.todoColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '完成时段分布',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无完成时段数据',
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

    final timeSlotOrder = ['上午', '下午', '晚上', '深夜'];
    final timeSlotColors = {
      '上午': ChartGradientPalette.positiveColor,
      '下午': ChartGradientPalette.todoColor,
      '晚上': ChartGradientPalette.habitColor,
      '深夜': ChartGradientPalette.neutralColor,
    };

    final items = timeSlotOrder
        .where((slot) => dashboard.todoCompletionTimeDistribution.containsKey(slot))
        .map((slot) {
      return BarDataItem(
        label: slot,
        value: dashboard.todoCompletionTimeDistribution[slot]?.toDouble() ?? 0.0,
        color: timeSlotColors[slot] ?? ChartGradientPalette.neutralColor,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ChartGradientPalette.todoColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  size: 16,
                  color: ChartGradientPalette.todoColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '完成时段分布',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PremiumBarChart(
            items: items,
            height: 160,
            maxBarWidth: 40,
            barRadius: 6,
            showValueLabel: true,
            showGradient: true,
            ySuffix: '',
          ),
        ],
      ),
    );
  }

  /// 构建逾期待办列表
  Widget _buildOverdueTodoList(Dashboard dashboard) {
    final displayedTodos =
        _showAllOverdueTodos ? dashboard.overdueTodos : dashboard.overdueTodos.take(3).toList();

    if (dashboard.overdueTodos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartGradientPalette.negativeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history_toggle_off,
                    size: 16,
                    color: ChartGradientPalette.negativeColor,
                  ),
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
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: ChartGradientPalette.positiveColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无逾期待办',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ChartGradientPalette.cardGlowGradient(ChartGradientPalette.negativeColor),
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ChartGradientPalette.negativeColor.withOpacity(0.2),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ChartGradientPalette.negativeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history_toggle_off,
                      size: 16,
                      color: ChartGradientPalette.negativeColor,
                    ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ChartGradientPalette.negativeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '共${dashboard.overdueTodos.length}项',
                  style: TextStyle(
                    color: ChartGradientPalette.negativeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              for (var todo in displayedTodos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildOverdueItem(
                      todo['title'] as String, todo['date'] as String),
                ),
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
                    color: ChartGradientPalette.todoColor,
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
        _buildHabitFilters(),
        const SizedBox(height: 16),

        _buildAverageConsistencyCard(dashboard),
        const SizedBox(height: 16),

        _buildStreakCards(dashboard),
        const SizedBox(height: 16),

        _buildHabitTypeCards(dashboard),
        const SizedBox(height: 16),

        _buildCheckInCalendar(dashboard),
        const SizedBox(height: 16),

        _buildConsistencyRanking(dashboard),
      ],
    );
  }

  Widget _buildDiaryInsights(Dashboard dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDiaryOverview(dashboard),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildMoodDistributionChart(dashboard)),
            const SizedBox(width: 16),
            Expanded(child: _buildMoodTrendChart(dashboard)),
          ],
        ),
        const SizedBox(height: 16),
        _buildDiaryTrendChart(dashboard),
        const SizedBox(height: 16),
        _buildWritingFrequencyChart(dashboard),
        const SizedBox(height: 16),
        _buildDiaryTagChart(dashboard),
        const SizedBox(height: 16),
        _buildMediaUsageStats(dashboard),
      ],
    );
  }

  Widget _buildDiaryOverview(Dashboard dashboard) {
    final totalDiaries = dashboard.totalDiaries;
    final weeklyAverage =
        totalDiaries > 0 ? (totalDiaries / 4.0).toStringAsFixed(1) : '0.0';
    final currentStreak = dashboard.currentWritingStreak;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ChartGradientPalette.cardGlowGradient(ChartGradientPalette.diaryColor),
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ChartGradientPalette.diaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ChartGradientPalette.diaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories,
                  size: 20,
                  color: ChartGradientPalette.diaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '日记概览',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.insights_outlined,
                size: 18,
                color: ChartGradientPalette.diaryColor.withOpacity(0.6),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStatItem(
                '总日记',
                '$totalDiaries',
                Icons.book_outlined,
                ChartGradientPalette.diaryColor,
                totalDiaries > 0 ? totalDiaries : null,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
              _buildHeroStatItem(
                '每周平均',
                weeklyAverage,
                Icons.calendar_month_outlined,
                ChartGradientPalette.diaryColor,
                null,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
              _buildHeroStatItem(
                '连续写作',
                '$currentStreak天',
                Icons.local_fire_department_outlined,
                currentStreak > 0 ? ChartGradientPalette.positiveColor : ChartGradientPalette.neutralColor,
                currentStreak > 0 ? currentStreak : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryTrendChart(Dashboard dashboard) {
    final sortedDates = dashboard.diaryTrendData.keys.toList()..sort();
    final values = sortedDates
        .map((d) => dashboard.diaryTrendData[d]?.toDouble() ?? 0.0)
        .toList();

    if (sortedDates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
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
                Icon(Icons.show_chart, size: 18, color: ChartGradientPalette.diaryColor),
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
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      '暂无日记数据',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.show_chart, size: 18, color: ChartGradientPalette.diaryColor),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PremiumTrendChart(
              series: [
                ChartSeries(
                  id: 'diary',
                  name: '日记数',
                  color: ChartGradientPalette.diaryColor,
                  values: values,
                ),
              ],
              dates: sortedDates,
              title: '',
              height: 200,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodDistributionChart(Dashboard dashboard) {
    final moodDist = dashboard.moodDistribution;
    final segments = <DonutSegment>[];
    for (int mood = 1; mood <= 5; mood++) {
      final count = moodDist[mood] ?? 0;
      if (count > 0) {
        segments.add(DonutSegment(
          label: ChartGradientPalette.moodLabel(mood),
          value: count.toDouble(),
          color: ChartGradientPalette.moodColor(mood),
          icon: null,
        ));
      }
    }

    final avgMood = dashboard.averageMood.round().clamp(1, 5);
    final centerEmoji = ChartGradientPalette.moodEmoji(avgMood);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.mood_outlined, size: 18, color: ChartGradientPalette.diaryColor),
              const SizedBox(width: 8),
              Text(
                '心情分布',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (segments.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  '暂无心情数据',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                ),
              ),
            )
          else
            PremiumDonutChart(
              segments: segments,
              centerText: centerEmoji,
              centerSubText: '平均心情',
              size: 120,
              ringWidth: 14,
              showLegend: false,
            ),
        ],
      ),
    );
  }

  Widget _buildMoodTrendChart(Dashboard dashboard) {
    final sortedDates = dashboard.moodTrend.keys.toList()..sort();
    final values = sortedDates.map((d) => dashboard.moodTrend[d] ?? 0.0).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.trending_up, size: 18, color: ChartGradientPalette.diaryColor),
              const SizedBox(width: 8),
              Text(
                '心情趋势',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedDates.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  '暂无心情趋势',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: PremiumTrendChart(
                series: [
                  ChartSeries(
                    id: 'mood',
                    name: '心情',
                    color: ChartGradientPalette.diaryColor,
                    values: values,
                  ),
                ],
                dates: sortedDates,
                title: '',
                height: 100,
                compact: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiaryTagChart(Dashboard dashboard) {
    final tagDistribution = dashboard.diaryTagDistribution;

    final maxCount = tagDistribution.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.label_outline, size: 18, color: ChartGradientPalette.diaryColor),
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
          const SizedBox(height: 16),
          if (tagDistribution.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.label_off_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      '暂无标签数据',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: tagDistribution.entries.map((entry) {
                final ratio = maxCount > 0 ? entry.value / maxCount : 0.0;
                final fontSize = (11.0 + ratio * 7.0).clamp(11.0, 18.0);
                final bgOpacity = (0.08 + ratio * 0.15).clamp(0.08, 0.23);
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: (8 + ratio * 8).clamp(8.0, 16.0),
                    vertical: (4 + ratio * 4).clamp(4.0, 8.0),
                  ),
                  decoration: BoxDecoration(
                    color: ChartGradientPalette.diaryColor.withOpacity(bgOpacity),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ChartGradientPalette.diaryColor.withOpacity(0.2 + ratio * 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: fontSize,
                          fontWeight: ratio > 0.5 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: ChartGradientPalette.diaryColor.withOpacity(0.2 + ratio * 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: TextStyle(
                            color: ChartGradientPalette.diaryColor,
                            fontSize: (fontSize - 2).clamp(9.0, 14.0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWritingFrequencyChart(Dashboard dashboard) {
    final monthlyCounts = dashboard.monthlyDiaryCounts;
    final sortedMonths = monthlyCounts.keys.toList()..sort();

    final items = sortedMonths.map((month) {
      return BarDataItem(
        label: month.length >= 7 ? month.substring(5) : month,
        value: (monthlyCounts[month] ?? 0).toDouble(),
        color: ChartGradientPalette.diaryColor,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.bar_chart, size: 18, color: ChartGradientPalette.diaryColor),
              const SizedBox(width: 8),
              Text(
                '写作频次',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  '暂无写作频次数据',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                ),
              ),
            )
          else
            PremiumBarChart(
              items: items,
              title: '',
              height: 160,
              showGradient: true,
            ),
        ],
      ),
    );
  }

  Widget _buildMediaUsageStats(Dashboard dashboard) {
    final mediaUsage = dashboard.diaryMediaUsage;

    final mediaTypeLabels = {
      'image': '图片',
      'audio': '音频',
      'video': '视频',
      'drawing': '绘图',
      'text': '文本',
    };

    final segments = <DonutSegment>[];
    final entries = mediaUsage.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final label = mediaTypeLabels[entry.key.toLowerCase()] ?? entry.key;
      segments.add(DonutSegment(
        label: label,
        value: entry.value.toDouble(),
        color: ChartGradientPalette.categoryColors[i % ChartGradientPalette.categoryColors.length],
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.perm_media_outlined, size: 18, color: ChartGradientPalette.diaryColor),
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
          const SizedBox(height: 16),
          if (segments.isEmpty)
            SizedBox(
              height: 150,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.perm_media_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      '暂无媒体数据',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            PremiumDonutChart(
              segments: segments,
              centerText: '${segments.length}',
              centerSubText: '种类型',
              size: 140,
              ringWidth: 18,
              showLegend: true,
            ),
        ],
      ),
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
  bool _normalized = false;
  List<String> _selectedHabits = [];
  Map<String, List<double>> _habitValues = {};
  Map<String, Color> _habitColors = {};
  Map<String, int> _habitFullStars = {};
  Map<String, String> _habitNames = {};
  List<String> _dates = [];
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _selectedHabits =
        widget.trendData.map((data) => data['id'] as String).toList();
  }

  @override
  void didUpdateWidget(covariant _EnhancedTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trendData != widget.trendData) {
      _initializeData();
      _selectedHabits =
          widget.trendData.map((data) => data['id'] as String).toList();
    }
  }

  void _initializeData() {
    if (widget.trendData.isEmpty) return;
    final totalData = widget.trendData[0];
    _dates = totalData['dates'] as List<String>;
    _habitColors = {};
    _habitFullStars = {};
    _habitNames = {};
    for (final data in widget.trendData) {
      _habitColors[data['id'] as String] = data['color'] as Color;
      _habitFullStars[data['id'] as String] = data['fullStars'] ?? 5;
      _habitNames[data['id'] as String] = data['name'] as String;
    }
    _updateChartData();
  }

  void _updateChartData() {
    _habitValues = {};
    for (final data in widget.trendData) {
      _habitValues[data['id'] as String] = [];
    }
    for (int i = 0; i < _dates.length; i++) {
      for (final data in widget.trendData) {
        final habitId = data['id'] as String;
        final values = data['data'] as List<double>;
        if (i < values.length) {
          double value = values[i];
          if (_normalized) {
            final fullStars = _habitFullStars[habitId] ?? 5;
            if (fullStars > 0) {
              value = (value / fullStars) * 100;
            } else {
              value = 0;
            }
          }
          _habitValues[habitId]!.add(value);
        }
      }
    }
  }

  double get _minY {
    double min = double.infinity;
    for (final habitId in _selectedHabits) {
      if (_habitValues.containsKey(habitId)) {
        for (final v in _habitValues[habitId]!) {
          if (v < min) min = v;
        }
      }
    }
    if (min == double.infinity) return 0;
    if (min >= 0) return 0;
    final padding = min.abs() * 0.15;
    return (min - padding).floorToDouble();
  }

  double get _maxY {
    double max = -double.infinity;
    for (final habitId in _selectedHabits) {
      if (_habitValues.containsKey(habitId)) {
        for (final v in _habitValues[habitId]!) {
          if (v > max) max = v;
        }
      }
    }
    if (max == -double.infinity) return 5;
    if (max <= 0) return 0;
    final padding = max * 0.15;
    return (max + padding).ceilToDouble();
  }

  List<PopupMenuEntry<String>> _buildHabitFilterMenu() {
    final menuItems = <PopupMenuEntry<String>>[];
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
                    _selectedHabits = widget.trendData
                        .map((data) => data['id'] as String)
                        .toList();
                  } else {
                    _selectedHabits.clear();
                  }
                });
                Navigator.of(context).pop();
              },
              activeColor: widget.theme.colorScheme.primary,
            ),
            Text('全部',
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
    menuItems.add(const PopupMenuDivider());
    for (final data in widget.trendData) {
      final habitId = data['id'] as String;
      final habitName = data['name'] as String;
      final isSelected = _selectedHabits.contains(habitId);
      final hasNegValues = (_habitValues[habitId] ?? []).any((v) => v < 0);
      menuItems.add(
        PopupMenuItem<String>(
          value: habitId,
          height: 48,
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
                  });
                  Navigator.of(context).pop();
                },
                activeColor: hasNegValues
                    ? widget.theme.colorScheme.error
                    : _habitColors[habitId],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(habitName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                        fontSize: 13)),
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
    final minY = _minY;
    final maxY = _maxY;
    final hasNegative = minY < 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.title,
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                )),
            Row(
              children: [
                Row(children: [
                  Text('归一化',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
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
                ]),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: widget.theme.colorScheme.onSurfaceVariant,
                      size: 20),
                  itemBuilder: (context) => _buildHabitFilterMenu(),
                  padding: const EdgeInsets.all(6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                  shadowColor: widget.theme.colorScheme.shadow,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: MouseRegion(
            onHover: (details) {
              final chartWidth = context.size?.width ?? 400;
              final plotLeft = 45.0;
              final plotWidth = chartWidth - plotLeft - 10;
              final dx = details.localPosition.dx - plotLeft;
              if (dx >= 0 && _dates.isNotEmpty) {
                final spacing = plotWidth / (_dates.length - 1).clamp(1, 99999);
                final idx = (dx / spacing).round().clamp(0, _dates.length - 1);
                setState(() => _hoverIndex = idx);
              }
            },
            onExit: (_) => setState(() => _hoverIndex = null),
            child: CustomPaint(
              painter: _ScoreTrendPainter(
                habitValues: _habitValues,
                habitColors: _habitColors,
                selectedHabits: _selectedHabits,
                dates: _dates,
                minY: minY,
                maxY: maxY,
                hasNegative: hasNegative,
                normalized: _normalized,
                theme: widget.theme,
                hoverIndex: _hoverIndex,
                habitNameMap: _habitNames,
              ),
              size: Size.infinite,
            ),
          ),
        ),
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
                  final values = _habitValues[habitId] ?? [];
                  final isNeg = values.any((v) => v < 0);
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isNeg
                                ? widget.theme.colorScheme.error
                                : color,
                            borderRadius: BorderRadius.circular(2),
                          )),
                      const SizedBox(width: 6),
                      Text(habitName,
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          )),
                    ]),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ScoreTrendPainter extends CustomPainter {
  final Map<String, List<double>> habitValues;
  final Map<String, Color> habitColors;
  final List<String> selectedHabits;
  final List<String> dates;
  final double minY;
  final double maxY;
  final bool hasNegative;
  final bool normalized;
  final ThemeData theme;
  final int? hoverIndex;
  final Map<String, String> habitNameMap;

  _ScoreTrendPainter({
    required this.habitValues,
    required this.habitColors,
    required this.selectedHabits,
    required this.dates,
    required this.minY,
    required this.maxY,
    required this.hasNegative,
    required this.normalized,
    required this.theme,
    required this.habitNameMap,
    this.hoverIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty || selectedHabits.isEmpty) return;

    final plotLeft = 45.0;
    final plotRight = size.width - 10.0;
    final plotTop = 10.0;
    final plotBottom = size.height - 35.0;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    final valueRange = maxY - minY;
    if (valueRange <= 0) return;

    double valueToY(double v) {
      return plotBottom - ((v - minY) / valueRange) * plotHeight;
    }

    double indexToX(int i) {
      if (dates.length == 1) return plotLeft + plotWidth / 2;
      return plotLeft + (i / (dates.length - 1)) * plotWidth;
    }

    final gridPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final dashPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = plotTop + (i / 4) * plotHeight;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
    }

    if (dates.length > 7) {
      final vInterval = (dates.length / 6).floor();
      for (int i = 0; i < dates.length; i += vInterval) {
        final x = indexToX(i);
        canvas.drawLine(Offset(x, plotTop), Offset(x, plotBottom), dashPaint);
      }
    }

    if (hasNegative && minY < 0 && maxY > 0) {
      final zeroY = valueToY(0);
      final zeroPaint = Paint()
        ..color = theme.colorScheme.outline.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      double startX = plotLeft;
      while (startX < plotRight) {
        final endX = startX + 6;
        canvas.drawLine(
            Offset(startX, zeroY),
            Offset(endX.clamp(plotLeft, plotRight), zeroY),
            zeroPaint);
        startX = endX + 4;
      }

      final negFillPaint = Paint()
        ..color = theme.colorScheme.error.withValues(alpha: 0.05)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
          Rect.fromLTRB(plotLeft, zeroY, plotRight, plotBottom), negFillPaint);

      final posFillPaint = Paint()
        ..color = theme.colorScheme.primary.withValues(alpha: 0.03)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
          Rect.fromLTRB(plotLeft, plotTop, plotRight, zeroY), posFillPaint);
    }

    final borderPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom),
        borderPaint);

    for (int i = 0; i <= 4; i++) {
      final value = maxY - (i / 4) * valueRange;
      final y = plotTop + (i / 4) * plotHeight;
      String label = value.toInt().toString();
      if (normalized) label = '$label%';
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(plotLeft - tp.width - 8, y - tp.height / 2));
    }

    int labelInterval = (dates.length / 5).ceil();
    if (labelInterval < 1) labelInterval = 1;
    for (int i = 0; i < dates.length; i++) {
      if (i % labelInterval != 0 && i != dates.length - 1) continue;
      if (i != dates.length - 1 &&
          (dates.length - 1 - i) < labelInterval / 2) continue;
      final x = indexToX(i);
      String displayDate = dates[i];
      try {
        final parts = dates[i].split('-');
        if (parts.length >= 3) displayDate = '${parts[1]}-${parts[2]}';
      } catch (_) {}
      final tp = TextPainter(
        text: TextSpan(
            text: displayDate,
            style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, plotBottom + 8));
    }

    for (final habitId in selectedHabits) {
      final values = habitValues[habitId];
      final color = habitColors[habitId] ?? theme.colorScheme.primary;
      if (values == null || values.isEmpty) continue;

      final points = <Offset>[];
      final pointIsNeg = <bool>[];
      for (int i = 0; i < values.length; i++) {
        final x = indexToX(i);
        final y = valueToY(values[i]);
        points.add(Offset(x, y));
        pointIsNeg.add(values[i] < 0);
      }

      if (hasNegative) {
        final zeroY = valueToY(0);
        for (int i = 0; i < points.length - 1; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];
          final midY = (p1.dy + p2.dy) / 2;
          final segPaint = Paint()
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          if (midY < zeroY) {
            segPaint.color = color;
          } else {
            segPaint.color = theme.colorScheme.error;
          }
          canvas.drawLine(p1, p2, segPaint);
        }
      } else {
        final linePaint = Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final path = Path();
        for (int i = 0; i < points.length; i++) {
          if (i == 0) {
            path.moveTo(points[i].dx, points[i].dy);
          } else {
            path.lineTo(points[i].dx, points[i].dy);
          }
        }
        canvas.drawPath(path, linePaint);
      }

      for (int i = 0; i < points.length; i++) {
        final isHovered = i == hoverIndex;
        final isNeg = pointIsNeg[i];
        final dotColor = hasNegative && isNeg
            ? theme.colorScheme.error
            : color;
        final radius = isHovered ? 6.0 : 3.5;
        final dotPaint = Paint()..color = dotColor;
        canvas.drawCircle(points[i], radius, dotPaint);
        if (isHovered) {
          final borderPaint2 = Paint()
            ..color = Colors.white
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(points[i], radius, borderPaint2);
          canvas.drawCircle(points[i], radius, dotPaint);
        }
      }
    }

    if (hoverIndex != null && hoverIndex! < dates.length) {
      final x = indexToX(hoverIndex!);
      final hoverLinePaint = Paint()
        ..color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, plotTop), Offset(x, plotBottom), hoverLinePaint);

      final tooltipItems = <MapEntry<String, double>>[];
      for (final habitId in selectedHabits) {
        final values = habitValues[habitId];
        if (values != null && hoverIndex! < values.length) {
          tooltipItems.add(MapEntry(habitId, values[hoverIndex!]));
        }
      }
      if (tooltipItems.isNotEmpty) {
        final dateTp = TextPainter(
          text: TextSpan(
              text: dates[hoverIndex!],
              style: TextStyle(color: Colors.white70, fontSize: 10)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        dateTp.layout();

        final namePainters = <TextPainter>[];
        final scorePainters = <TextPainter>[];
        for (int i = 0; i < tooltipItems.length; i++) {
          final habitId = tooltipItems[i].key;
          final value = tooltipItems[i].value;
          final habitData = habitId == 'total'
              ? null
              : habitColors[habitId];
          final c = habitData ?? theme.colorScheme.primary;
          final isNeg = value < 0;
          final displayColor = hasNegative && isNeg
              ? theme.colorScheme.error
              : c;
          final scoreText = value >= 0 ? '+${value.toStringAsFixed(1)}' : value.toStringAsFixed(1);
          final scoreTp = TextPainter(
            text: TextSpan(
                text: scoreText,
                style: TextStyle(color: displayColor, fontSize: 11, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          );
          scoreTp.layout();
          scorePainters.add(scoreTp);

          final nameTp = TextPainter(
            text: TextSpan(
                text: _getHabitName(habitId),
                style: TextStyle(color: Colors.white70, fontSize: 11)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          );
          namePainters.add(nameTp);
        }

        final maxScoreWidth = scorePainters.fold(0.0, (max, tp) => tp.width > max ? tp.width : max);
        final tooltipW = (dateTp.width + maxScoreWidth + 60).clamp(140.0, 260.0);
        final nameMaxWidth = tooltipW - maxScoreWidth - 28;
        for (final nameTp in namePainters) {
          nameTp.layout(maxWidth: nameMaxWidth);
        }

        final tooltipH = 12.0 + tooltipItems.length * 20.0 + 8.0;
        double tooltipX = x - tooltipW / 2;
        double tooltipY = plotTop + 5;
        if (tooltipX < plotLeft) tooltipX = plotLeft;
        if (tooltipX + tooltipW > plotRight) tooltipX = plotRight - tooltipW;

        final tooltipRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
          Radius.circular(8),
        );
        canvas.drawRRect(
            tooltipRect,
            Paint()..color = Colors.black.withValues(alpha: 0.85));
        canvas.drawRRect(
            tooltipRect,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.1)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);

        canvas.save();
        canvas.translate(tooltipX + 8, tooltipY + 6);
        dateTp.paint(canvas, Offset.zero);
        canvas.restore();

        for (int i = 0; i < tooltipItems.length; i++) {
          final y = tooltipY + 22 + i * 20;
          canvas.save();
          canvas.translate(tooltipX + 8, y);
          namePainters[i].paint(canvas, Offset.zero);
          canvas.restore();

          canvas.save();
          canvas.translate(tooltipX + tooltipW - scorePainters[i].width - 8, y);
          scorePainters[i].paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
    }
  }

  String _getHabitName(String habitId) {
    return habitNameMap[habitId] ?? habitId;
  }

  @override
  bool shouldRepaint(covariant _ScoreTrendPainter oldDelegate) {
    return oldDelegate.hoverIndex != hoverIndex ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.selectedHabits != selectedHabits ||
        oldDelegate.normalized != normalized ||
        oldDelegate.habitNameMap != habitNameMap;
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
