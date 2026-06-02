import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/security.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/utils/icon_helper.dart';
import 'package:moment_keep/core/utils/habit_date_utils.dart';
import 'package:moment_keep/core/services/user_settings_service.dart';
import 'package:moment_keep/presentation/components/habit_editor_widget.dart';
import 'package:moment_keep/presentation/components/habit_checkin_dialog.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/presentation/components/app_search_bar.dart';
import 'package:moment_keep/presentation/components/view_switcher.dart';
import 'package:moment_keep/presentation/pages/add_habit_page.dart';
import 'package:moment_keep/presentation/pages/habit_detail_dialog.dart';
import 'package:moment_keep/presentation/pages/week_view.dart';
import 'package:moment_keep/presentation/pages/month_habit_list.dart';
import 'package:moment_keep/presentation/pages/month_heatmap_view.dart';

/// 习惯页面
class HabitPage extends StatefulWidget {
  /// 构造函数
  const HabitPage({super.key});

  @override
  State<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends State<HabitPage> {
  @override
  void initState() {
    super.initState();
    final habitBloc = context.read<HabitBloc>();
    if (habitBloc.state is HabitInitial) {
      habitBloc.add(LoadHabits());
    }
    context
        .read<CategoryBloc>()
        .add(const LoadCategories(type: CategoryType.habit));
  }

  @override
  Widget build(BuildContext context) {
    return const HabitView();
  }
}

/// 习惯视图
class HabitView extends ConsumerStatefulWidget {
  /// 构造函数
  const HabitView({super.key});

  @override
  ConsumerState<HabitView> createState() => _HabitViewState();
}

class _HabitViewState extends ConsumerState<HabitView> {
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocBuilder<SecurityBloc, SecurityState>(
        builder: (context, securityState) {
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
          
          if (securityState is SecurityLoaded) {
            user = securityState.userAuth;
          } else {
            context.read<SecurityBloc>().add(LoadSecuritySettings());
          }
          
          return BlocBuilder<CategoryBloc, CategoryState>(
            buildWhen: (previous, current) {
              if (previous is CategoryLoaded && current is CategoryLoaded) {
                return previous.categories != current.categories;
              }
              return previous.runtimeType != current.runtimeType;
            },
            builder: (context, categoryState) {
              if (categoryState is CategoryLoaded) {
                return BlocBuilder<HabitBloc, HabitState>(
                  builder: (context, habitState) {
                    List<Habit> habits = [];
                    bool isSearching = false;
                    String searchQuery = '';
                    int totalHabitsCount = 0;
                    if (habitState is HabitLoaded) {
                      habits = habitState.habits;
                      totalHabitsCount = habitState.habits.length;
                    } else if (habitState is HabitSearchResult) {
                      habits = habitState.filteredHabits;
                      isSearching = habitState.query.isNotEmpty;
                      searchQuery = habitState.query;
                      totalHabitsCount = habits.length;
                    }
                    return HabitContent(
                        habits: habits, 
                        categories: categoryState.categories,
                        user: user,
                        theme: theme,
                        isSearching: isSearching,
                        searchQuery: searchQuery,
                        totalHabitsCount: totalHabitsCount);
                  },
                );
              } else if (categoryState is CategoryError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('加载分类失败', style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.read<CategoryBloc>().add(const LoadCategories(type: CategoryType.habit)),
                        child: Text('重试'),
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () {
          _showAddHabitDialog(context);
        },
        shape: const CircleBorder(),
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    String icon = 'book';
    int color = 0xFF4CAF50;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '分类名称'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: icon,
                  decoration: const InputDecoration(labelText: '图标'),
                  items: [
                    {'value': 'book', 'icon': Icons.book},
                    {'value': 'run', 'icon': Icons.directions_run},
                    {'value': 'code', 'icon': Icons.code},
                    {'value': 'meditate', 'icon': Icons.self_improvement},
                  ].map((item) {
                    return DropdownMenuItem(
                      value: item['value'] as String,
                      child: Row(
                        children: [
                          Icon(item['icon'] as IconData, size: 20),
                          const SizedBox(width: 8),
                          Text(item['value'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    icon = value!;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: color,
                  decoration: const InputDecoration(labelText: '颜色'),
                  items: [
                    const DropdownMenuItem(
                        value: 0xFF4CAF50, child: Text('绿色')),
                    const DropdownMenuItem(
                        value: 0xFF2196F3, child: Text('蓝色')),
                    const DropdownMenuItem(
                        value: 0xFF9C27B0, child: Text('紫色')),
                    const DropdownMenuItem(
                        value: 0xFFFF9800, child: Text('橙色')),
                    const DropdownMenuItem(
                        value: 0xFFF44336, child: Text('红色')),
                  ],
                  onChanged: (value) {
                    color = value!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final newCategory = Category(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: CategoryType.habit,
                    icon: icon,
                    color: color,
                    isExpanded: true,
                  );
                  context.read<CategoryBloc>().add(AddCategory(newCategory));
                  Navigator.pop(context);
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  void _showAddHabitDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: BlocProvider.of<HabitBloc>(context),
          child: const AddHabitPage(),
        ),
      ),
    );
  }
}

/// 习惯内容组件
class HabitContent extends StatefulWidget {
  /// 习惯列表
  final List<Habit> habits;

  /// 分类列表
  final List<Category> categories;
  
  /// 用户信息
  final UserAuth? user;
  
  /// 主题数据
  final ThemeData theme;

  /// 是否正在搜索
  final bool isSearching;

  /// 搜索关键词
  final String searchQuery;

  /// 习惯总数（用于搜索结果指示器）
  final int totalHabitsCount;

  /// 构造函数
  const HabitContent({
    super.key, 
    required this.habits, 
    required this.categories,
    required this.user,
    required this.theme,
    this.isSearching = false,
    this.searchQuery = '',
    this.totalHabitsCount = 0,
  });

  @override
  State<HabitContent> createState() => _HabitContentState();
}

class _HabitContentState extends State<HabitContent> {
  /// 当前选中的分类ID，null表示所有习惯
  String? _selectedCategoryId;
  
  /// 是否处于多选模式
  bool _isMultiSelectMode = false;
  
  /// 选中的习惯ID集合
  Set<String> _selectedHabits = {};
  
  /// 当前视图类型
  HabitViewType _currentView = HabitViewType.day;
  
  /// 当前选中的日期
  DateTime? _selectedDate;
  
  /// 当前显示月份的基准日期
  DateTime _currentMonthDate = DateTime.now();
  bool _allowRetroactiveCheckIn = true;

  @override
  void initState() {
    super.initState();
    UserSettingsService().isRetroactiveCheckInAllowed().then((value) {
      if (mounted) setState(() => _allowRetroactiveCheckIn = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeaderContent(),
          ),
          SliverToBoxAdapter(child: _buildScoreBadge()),
          _buildViewSwitcher(),
          SliverToBoxAdapter(
            child: AppSearchBar(
              hintText: '搜索习惯名称或描述...',
              onSearchChanged: (query) {
                context.read<HabitBloc>().add(SearchHabits(query));
              },
              onClear: () {
                context.read<HabitBloc>().add(const SearchHabits(''));
              },
            ),
          ),
          if (widget.isSearching && widget.searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: SearchResultIndicator(
                resultCount: widget.habits.length,
                totalCount: widget.totalHabitsCount,
                query: widget.searchQuery,
              ),
            ),
          if (_currentView == HabitViewType.day) ...[
            _buildDateSelector(),
            _buildCategoriesHeader(),
            _buildCategoryTags(context),
          ],
          _buildHabitView(context),
        ],
      ),
    );
  }

  /// 构建顶部Header内容（非Sliver版本）
  Widget _buildHeaderContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getCurrentDate(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '我的习惯',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: widget.theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          _buildUserAvatar(),
        ],
      ),
    );
  }

  /// 构建今日积分徽章
  Widget _buildScoreBadge() {
    final colorScheme = widget.theme.colorScheme;
    int totalPoints = 0;
    String label;

    if (_currentView == HabitViewType.day) {
      final todayRange = HabitDateUtils.getDayRange(DateTime.now());
      for (final habit in widget.habits) {
        totalPoints += HabitDateUtils.calculatePointsInDateTimeRange(habit, todayRange);
      }
      label = '今日总积分';
    } else if (_currentView == HabitViewType.week) {
      final weekRange = HabitDateUtils.getWeekRange(DateTime.now());
      for (final habit in widget.habits) {
        totalPoints += HabitDateUtils.calculatePointsInDateTimeRange(habit, weekRange);
      }
      label = '本周总积分';
    } else {
      final monthRange = HabitDateUtils.getMonthRange(DateTime.now());
      for (final habit in widget.habits) {
        totalPoints += HabitDateUtils.calculatePointsInDateTimeRange(habit, monthRange);
      }
      label = '本月总积分';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${totalPoints >= 0 ? '+' : ''}$totalPoints',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建用户头像
  Widget _buildUserAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: widget.theme.colorScheme.surfaceVariant,
      ),
      child: Center(
        child: widget.user?.avatar != null && (widget.user!.avatar?.isNotEmpty ?? false)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(widget.user!.avatar!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(
                Icons.person,
                size: 24,
                color: widget.theme.colorScheme.onSurfaceVariant,
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
      case 1: return '星期一';
      case 2: return '星期二';
      case 3: return '星期三';
      case 4: return '星期四';
      case 5: return '星期五';
      case 6: return '星期六';
      case 7: return '星期日';
      default: return '';
    }
  }

  /// 获取月份名称
  String _getMonthName(int month) {
    switch (month) {
      case 1: return '一月';
      case 2: return '二月';
      case 3: return '三月';
      case 4: return '四月';
      case 5: return '五月';
      case 6: return '六月';
      case 7: return '七月';
      case 8: return '八月';
      case 9: return '九月';
      case 10: return '十月';
      case 11: return '十一月';
      case 12: return '十二月';
      default: return '';
    }
  }
  
  /// 构建习惯视图
  Widget _buildHabitView(BuildContext context) {
    switch (_currentView) {
      case HabitViewType.day:
        return DayView(
          habits: widget.habits,
          categories: widget.categories,
          theme: widget.theme,
          selectedDate: _selectedDate,
          selectedCategoryId: _selectedCategoryId,
          isMultiSelectMode: _isMultiSelectMode,
          selectedHabits: _selectedHabits,
          onToggleMultiSelectMode: _toggleMultiSelectMode,
          onToggleEntrySelection: _toggleEntrySelection,
          isSearching: widget.isSearching,
          allowRetroactiveCheckIn: _allowRetroactiveCheckIn,
        );
      case HabitViewType.week:
        return WeekView(
          habits: widget.habits,
          categories: widget.categories,
          theme: widget.theme,
          selectedCategoryId: _selectedCategoryId,
          allowRetroactiveCheckIn: _allowRetroactiveCheckIn,
        );
      case HabitViewType.month:
        return _buildMonthView();
    }
  }

  /// 构建完整的月视图（包含热力图和习惯列表）
  Widget _buildMonthView() {
    return SliverList(
      delegate: SliverChildListDelegate([
        // 月视图：热力图 + 习惯列表
        MonthHeatmapView(
          habits: widget.habits,
          categories: widget.categories,
          theme: widget.theme,
          selectedCategoryId: _selectedCategoryId,
          showHeader: true,
          showNavigation: true,
          currentMonthDate: _currentMonthDate,
        ),
        MonthHabitList(
          habits: widget.habits,
          categories: widget.categories,
          theme: widget.theme,
          selectedCategoryId: _selectedCategoryId,
          currentMonthDate: _currentMonthDate,
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  /// 构建视图切换器
  Widget _buildViewSwitcher() {
    return SliverToBoxAdapter(
      child: ViewSwitcher(
        selectedView: _currentView,
        onViewChanged: (viewType) {
          setState(() {
            _currentView = viewType;
          });
        },
      ),
    );
  }

  /// 构建日期选择器
  Widget _buildDateSelector() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 70,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: 7, // 显示7天
          itemBuilder: (context, index) {
            // 生成最近7天的日期
            final date = DateTime.now().subtract(Duration(days: 6 - index));
            final isToday = date.day == DateTime.now().day;
            final dayName = _getDayName(date.weekday);
            
            // 检查该日期是否有习惯打卡
            final dateString = date.toIso8601String().split('T')[0];
            final isChecked = widget.habits.any((habit) => habit.history.contains(dateString));
            
            return _buildDateItem(
              dayName: dayName,
              dayNumber: date.day.toString(),
              isToday: isToday,
              isChecked: isChecked,
              date: date, // 传递日期参数
            );
          },
        ),
      ),
    );
  }

  /// 构建日期项
  Widget _buildDateItem({
    required String dayName,
    required String dayNumber,
    required bool isToday,
    required bool isChecked,
    required DateTime date,
  }) {
    // 检查是否是选中的日期
    final isSelected = _selectedDate != null && 
        date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;
    
    // 确定背景色
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = widget.theme.colorScheme.primary;
    } else if (isToday) {
      backgroundColor = widget.theme.colorScheme.primary.withValues(alpha: 0.15);
    } else {
      backgroundColor = widget.theme.cardTheme.color ?? widget.theme.colorScheme.surface;
    }

    Color textColor = isSelected ? widget.theme.colorScheme.onPrimary
        : isToday ? widget.theme.colorScheme.primary
        : widget.theme.colorScheme.onSurface;
    Color dayNameColor = isSelected ? widget.theme.colorScheme.onPrimary
        : isToday ? widget.theme.colorScheme.primary
        : widget.theme.colorScheme.onSurfaceVariant;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          // 如果点击的是已经选中的日期，取消选中
          if (isSelected) {
            _selectedDate = null;
          } else {
            _selectedDate = date;
          }
        });
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 56,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: backgroundColor,
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : isToday
                        ? widget.theme.colorScheme.primary
                        : widget.theme.colorScheme.outline,
                width: isSelected ? 0 : (isToday ? 2 : 1),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: widget.theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: dayNameColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          if (isChecked && !isSelected)
            Positioned(
              bottom: 8,
              left: 25,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 控制是否显示删除按钮
  bool _showDeleteButtons = false;
  // 控制长按动画状态
  bool _isLongPressing = false;
  // 控制是否正在闪烁
  bool _isBlinking = false;

  /// 构建分类标题
  Widget _buildCategoriesHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '分类',
              style: TextStyle(
                color: widget.theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分类标签
  Widget _buildCategoryTags(BuildContext context) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          if (_showDeleteButtons)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showDeleteButtons = false;
                    _isLongPressing = false;
                    _isBlinking = false;
                  });
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                    _buildAllCategoryChip(),
                    ...widget.categories.map((category) => 
                      _buildDraggableFilterChip(context, category)),
                    _buildAddCategoryButton(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建"全部"分类芯片
  Widget _buildAllCategoryChip() {
    final isActive = _selectedCategoryId == null;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryId = null;
            // 点击分类时隐藏删除按钮
            _showDeleteButtons = false;
            _isLongPressing = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? widget.theme.colorScheme.primary : widget.theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: widget.theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            '全部',
            style: TextStyle(
              color: isActive ? widget.theme.colorScheme.onPrimary : widget.theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建添加分类按钮
  Widget _buildAddCategoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showAddCategoryDialog(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 24, // 调整为"全部"按钮高度的一半（24是垂直padding的两倍）
        height: 24,
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.theme.colorScheme.primary,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.add,
          color: widget.theme.colorScheme.onSurface,
          size: 12, // 调整图标大小
        ),
      ),
    );
  }

  /// 构建分类芯片内容
  Widget _buildCategoryChipContent(bool isActive, Category category, bool isAll) {
    // 构建基础芯片内容
    Widget chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? widget.theme.colorScheme.primary : widget.theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: widget.theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Text(
        category.name,
        style: TextStyle(
          color: isActive ? widget.theme.colorScheme.onPrimary : widget.theme.colorScheme.onSurface,
          fontSize: 14,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );

    // 构建完整的芯片
    Widget chipContainer = chipContent;

    // 添加闪烁动画效果（仅当显示删除按钮时）
    if (_showDeleteButtons) {
      // 使用循环动画实现闪烁效果
      chipContainer = AnimatedOpacity(
        opacity: _isLongPressing ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: chipContainer,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryId = category.id;
            // 点击分类时隐藏删除按钮
            _showDeleteButtons = false;
            _isLongPressing = false;
          });
        },
        onLongPress: () {
          setState(() {
            _showDeleteButtons = true;
            _isLongPressing = true;
          });
          // 启动持续闪烁动画
          _startBlinkingAnimation();
        },
        child: chipContainer,
      ),
    );
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
        
        // 进一步减慢闪烁频率到800毫秒
        Future.delayed(const Duration(milliseconds: 800), blink);
      } else {
        // 停止闪烁
        _isBlinking = false;
      }
    }
    
    // 开始闪烁
    blink();
  }
  
  /// 构建可拖动的分类芯片
  Widget _buildDraggableFilterChip(BuildContext context, Category category) {
    final index = widget.categories.indexOf(category);
    final isActive = _selectedCategoryId == category.id;

    // 构建分类芯片内容
    Widget chipContent = _buildCategoryChipContent(isActive, category, false);

    // 只有当显示删除按钮时，才允许拖动排序
    if (_showDeleteButtons) {
      Widget draggableChip = Draggable(
        data: index,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? widget.theme.colorScheme.primary : widget.theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              category.name,
              style: TextStyle(
                color: isActive ? widget.theme.colorScheme.onPrimary : widget.theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
        childWhenDragging: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: DragTarget<int>(
          onAcceptWithDetails: (details) {
            _reorderCategories(details.data, index);
          },
          builder: (context, candidateData, rejectedData) {
            return (chipContent as Padding).child as GestureDetector;
          },
        ),
      );

      // 构建带有删除按钮的完整芯片
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            draggableChip,
            // 显示删除按钮（除了"全部"分类）
            Positioned(
              top: -4, // 调整位置，确保完全显示
              right: -4, // 调整位置，确保完全显示
              child: GestureDetector(
                onTap: () {
                  // 调用CategoryBloc删除分类
                  context.read<CategoryBloc>().add(DeleteCategory(category.id));
                  if (_selectedCategoryId == category.id) {
                    setState(() {
                      _selectedCategoryId = null;
                    });
                  }
                },
                child: Container(
                  width: 22, // 稍微增大尺寸，确保完全显示
                  height: 22, // 稍微增大尺寸，确保完全显示
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 239, 68, 68),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14, // 稍微增大图标，确保清晰可见
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 不允许拖动时，直接返回分类芯片内容
    return chipContent;
  }
  
  /// 重新排序分类
  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      final List<Category> categories = List.from(widget.categories);
      final Category element = categories.removeAt(oldIndex);
      
      // 调整新索引，因为我们已经删除了一个元素
      int insertIndex = newIndex;
      if (newIndex > oldIndex) {
        insertIndex--;
      }
      
      categories.insert(insertIndex, element);
      
      // 通过Bloc更新分类顺序，持久化保存
      context.read<CategoryBloc>().add(UpdateCategoryOrder(categories));
    });
  }
  
  /// 显示添加分类对话框
  void _showAddCategoryDialog(BuildContext context) {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    String icon = 'book';
    int color = 0xFF4CAF50;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text('添加分类', style: TextStyle(color: theme.colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '分类名称',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: icon,
                  decoration: InputDecoration(
                    labelText: '图标',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  items: [
                    {'value': 'book', 'icon': Icons.book},
                    {'value': 'run', 'icon': Icons.directions_run},
                    {'value': 'code', 'icon': Icons.code},
                    {'value': 'meditate', 'icon': Icons.self_improvement},
                  ].map((item) {
                    return DropdownMenuItem(
                      value: item['value'] as String,
                      child: Row(
                        children: [
                          Icon(item['icon'] as IconData, size: 20, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 8),
                          Text(item['value'] as String, style: TextStyle(color: theme.colorScheme.onSurface)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    icon = value!;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: color,
                  decoration: InputDecoration(
                    labelText: '颜色',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  items: [
                    const DropdownMenuItem(value: 0xFF4CAF50, child: Text('绿色')),
                    const DropdownMenuItem(value: 0xFF2196F3, child: Text('蓝色')),
                    const DropdownMenuItem(value: 0xFF9C27B0, child: Text('紫色')),
                    const DropdownMenuItem(value: 0xFFFF9800, child: Text('橙色')),
                    const DropdownMenuItem(value: 0xFFF44336, child: Text('红色')),
                  ],
                  onChanged: (value) {
                    color = value!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final newCategory = Category(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: CategoryType.habit,
                    icon: icon,
                    color: color,
                    isExpanded: true,
                  );
                  context.read<CategoryBloc>().add(AddCategory(newCategory));
                  Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  /// 切换多选模式
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedHabits.clear();
      }
    });
  }
  
  /// 切换习惯选中状态
  void _toggleEntrySelection(String habitId) {
    setState(() {
      if (_selectedHabits.contains(habitId)) {
        _selectedHabits.remove(habitId);
      } else {
        _selectedHabits.add(habitId);
      }
    });
  }
  
  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      final filteredHabits = _selectedCategoryId == null
          ? widget.habits
          : widget.habits.where((habit) => habit.categoryId == _selectedCategoryId).toList();
          
      if (_selectedHabits.length == filteredHabits.length) {
        _selectedHabits.clear();
      } else {
        _selectedHabits = filteredHabits.map((habit) => habit.id).toSet();
      }
    });
  }
  
  /// 删除选中的习惯
  void _deleteSelectedHabits() {
    if (_selectedHabits.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text('删除习惯', style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Text('确定要删除选中的 ${_selectedHabits.length} 个习惯吗？', style: TextStyle(color: theme.colorScheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 删除选中的习惯
                for (final habitId in _selectedHabits) {
                  context.read<HabitBloc>().add(DeleteHabit(habitId));
                }
                // 退出多选模式
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedHabits.clear();
                });
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
  


  /// 获取星期名称
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return '一';
      case 2: return '二';
      case 3: return '三';
      case 4: return '四';
      case 5: return '五';
      case 6: return '六';
      case 7: return '日';
      default: return '';
    }
  }

  /// 获取用户名
  String _getUserName() {
    return '用户'; // 这里可以从用户信息中获取
  }
  
  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
  
  /// 获取频率文本
  String _getFrequencyText(HabitFrequency frequency) {
    switch (frequency) {
      case HabitFrequency.daily:
        return '每天';
      case HabitFrequency.weekly:
        return '每周';
      case HabitFrequency.monthly:
        return '每月';
      default:
        return '未知';
    }
  }
  
  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 多选模式工具栏代理类
class _MultiSelectToolbarDelegate extends SliverPersistentHeaderDelegate {
  /// 选中的条目数量
  final int selectedCount;
  
  /// 全选/取消全选回调
  final VoidCallback onSelectAll;
  
  /// 删除选中条目回调
  final VoidCallback onDelete;
  
  /// 取消多选模式回调
  final VoidCallback onCancel;
  
  /// 构造函数
  const _MultiSelectToolbarDelegate({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onDelete,
    required this.onCancel,
  });
  
  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：选中数量和全选按钮
          Row(
            children: [
              Text(
                '已选择 $selectedCount 项',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Text('全选'),
              ),
            ],
          ),
          // 右侧：取消和删除按钮
          Row(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  @override
  double get maxExtent => 56.0;
  
  @override
  double get minExtent => 56.0;
  
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

/// 习惯项组件
class HabitItem extends ConsumerWidget {
  final Habit habit;
  final DateTime? selectedDate;
  final bool allowRetroactiveCheckIn;

  const HabitItem({super.key, required this.habit, this.selectedDate, this.allowRetroactiveCheckIn = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    // 确定要检查的日期
    final checkDate = selectedDate ?? DateTime.now();
    final checkDateString = checkDate.toIso8601String().split('T')[0];
    
    // 只比较年月日，不比较时间
    final now = DateTime.now();
    final isToday = checkDate.year == now.year &&
                    checkDate.month == now.month &&
                    checkDate.day == now.day;
    final isFuture = checkDate.isAfter(DateTime(now.year, now.month, now.day));
    
    // 检查该日期是否已经打卡
    final isChecked = habit.history.contains(checkDateString);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: habit.type == HabitType.negative 
            ? theme.colorScheme.error.withOpacity(0.1) 
            : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: habit.type == HabitType.negative 
              ? theme.colorScheme.error 
              : theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：图标和习惯信息
          Row(
            children: [
              // 习惯图标
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Color(habit.color).withOpacity(0.15),
                ),
                child: Center(
                  child: IconHelper.buildIconWidget(habit.icon ?? '', size: 24, color: Color(habit.color)),
                ),
              ),
              // 习惯信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Tooltip(
                        message: '${habit.name}\n'
                            '类型：${habit.type == HabitType.negative ? '负向习惯' : '正向习惯'}\n'
                            '积分：${habit.type == HabitType.negative ? '-${habit.fullStars}分' : '+${habit.fullStars}分'}\n'
                            '已打卡：${habit.totalCompletions}次\n'
                            '连续：${habit.currentStreak}天',
                        child: Text(
                          habit.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: habit.type == HabitType.negative 
                                ? theme.colorScheme.error 
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: habit.type == HabitType.negative 
                              ? theme.colorScheme.error.withValues(alpha: 0.1)
                              : theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              habit.type == HabitType.negative 
                                  ? Icons.trending_down 
                                  : Icons.trending_up,
                              size: 10,
                              color: habit.type == HabitType.negative 
                                  ? theme.colorScheme.error 
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              habit.type == HabitType.negative 
                                  ? '-${habit.fullStars}' 
                                  : '+${habit.fullStars}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: habit.type == HabitType.negative 
                                    ? theme.colorScheme.error 
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusText(habit, checkDateString, isToday),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 右侧：操作按钮
          _buildActionButton(habit, isChecked, context, isToday, isFuture, checkDate),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      Habit habit, bool isChecked, BuildContext context, bool isToday, bool isFuture, DateTime checkDate) {
    final theme = Theme.of(context);
    final canCheckIn = isToday || (allowRetroactiveCheckIn && !isFuture);
    final dateForCheckIn = isToday ? null : checkDate;
    if (habit.name == 'Read Book' || habit.name == 'Morning Jog' || habit.name == 'Meditate') {
      return ElevatedButton(
        onPressed: canCheckIn ? () {
            if (isChecked) {
              _showUndoCheckInDialog(context, habit, theme);
            } else {
              _showCheckInDialog(context, habit, date: dateForCheckIn);
            }
          } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: habit.type == HabitType.negative 
              ? theme.colorScheme.errorContainer 
              : theme.colorScheme.primaryContainer,
          foregroundColor: habit.type == HabitType.negative 
              ? theme.colorScheme.onErrorContainer 
              : theme.colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          isChecked 
              ? (habit.type == HabitType.negative ? '已记录' : '已完成')
              : (isToday 
                  ? (habit.type == HabitType.negative ? '记录' : '打卡') 
                  : (habit.type == HabitType.negative ? '补记' : '补卡')),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    return ElevatedButton(
      onPressed: canCheckIn ? () {
          if (isChecked) {
            _showUndoCheckInDialog(context, habit, theme);
          } else {
            _showCheckInDialog(context, habit, date: dateForCheckIn);
          }
        } : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: habit.type == HabitType.negative 
            ? theme.colorScheme.errorContainer 
            : theme.colorScheme.primaryContainer,
        foregroundColor: habit.type == HabitType.negative 
            ? theme.colorScheme.onErrorContainer 
            : theme.colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      child: Text(
        isChecked 
            ? (habit.type == HabitType.negative ? '已记录' : '已完成')
            : (isToday 
                ? (habit.type == HabitType.negative ? '记录' : '打卡') 
                : (habit.type == HabitType.negative ? '补记' : '补卡')),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 显示撤销打卡确认对话框
  void _showUndoCheckInDialog(BuildContext context, Habit habit, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            '撤销打卡',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            '确定要撤销「${habit.name}」的打卡记录吗？撤销后积分将相应扣除。',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () {
                context.read<HabitBloc>().add(UndoHabitCompletion(habit.id));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${habit.name} 打卡已撤销')),
                );
              },
              child: Text(
                '确认撤销',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 获取状态文本
  String _getStatusText(Habit habit, String checkDateString, bool isToday) {
    final isChecked = habit.history.contains(checkDateString);
    
    if (isChecked) {
      final checkInRecord = habit.checkInRecords.where((r) {
        final rDate = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        final targetDate = DateTime.parse(checkDateString);
        return rDate.isAtSameMomentAs(targetDate) && !r.id.startsWith('reward_') && !r.id.startsWith('penalty_');
      }).firstOrNull;
      
      if (checkInRecord?.checkedInAt != null) {
        final ca = checkInRecord!.checkedInAt!;
        final makeupTime = '${ca.month.toString().padLeft(2, '0')}-${ca.day.toString().padLeft(2, '0')} ${ca.hour.toString().padLeft(2, '0')}:${ca.minute.toString().padLeft(2, '0')}';
        return '${habit.currentStreak}天连续 • 补卡于 $makeupTime';
      }
      return '${habit.currentStreak}天连续 • 已完成';
    } else {
      return '${habit.currentStreak}天连续 • ${isToday ? '待完成' : '未打卡'}';
    }
  }

  /// 显示习惯详情页面
  void _showHabitDetails(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(habit.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 习惯描述
                if (habit.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      habit.notes,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                
                // 习惯信息
                _buildDetailRow('分类', habit.category),
                _buildDetailRow('频率', _getFrequencyText(habit.frequency)),
                _buildDetailRow('当前连续', '${habit.currentStreak} 天'),
                _buildDetailRow('最佳连续', '${habit.bestStreak} 天'),
                _buildDetailRow('总完成次数', habit.totalCompletions.toString()),
                _buildDetailRow('创建时间', _formatDate(habit.createdAt)),
                _buildDetailRow('最近更新', _formatDate(habit.updatedAt)),
              ],
            ),
          ),
          actions: [
            // 删除按钮
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteHabitDialog(context, habit);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
            // 编辑按钮
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditHabitDialog(context, habit);
              },
              child: const Text('编辑'),
            ),
            // 关闭按钮
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  /// 获取频率文本
  String _getFrequencyText(HabitFrequency frequency) {
    switch (frequency) {
      case HabitFrequency.daily:
        return '每天';
      case HabitFrequency.weekly:
        return '每周';
      case HabitFrequency.monthly:
        return '每月';
      default:
        return '未知';
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 显示编辑习惯页面
  void _showEditHabitDialog(BuildContext context, Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: BlocProvider.of<HabitBloc>(context),
          child: AddHabitPage(habit: habit),
        ),
      ),
    );
  }

  /// 显示删除习惯对话框
  void _showDeleteHabitDialog(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除习惯'),
          content: Text('确定要删除习惯 "${habit.name}" 吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                context.read<HabitBloc>().add(DeleteHabit(habit.id));
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 显示打卡对话框
  void _showCheckInDialog(BuildContext context, Habit habit, {DateTime? date}) {
    showDialog(
      context: context,
      builder: (context) {
        return HabitCheckInDialog(
          habit: habit,
          date: date,
        );
      },
    );
  }
}

/// 日视图组件
class DayView extends StatelessWidget {
  /// 习惯列表
  final List<Habit> habits;
  
  /// 分类列表
  final List<Category> categories;
  
  /// 主题数据
  final ThemeData theme;
  
  /// 选中的日期
  final DateTime? selectedDate;
  
  /// 选中的分类ID
  final String? selectedCategoryId;
  
  /// 是否处于多选模式
  final bool isMultiSelectMode;
  
  /// 选中的习惯ID集合
  final Set<String> selectedHabits;
  
  /// 切换多选模式回调
  final VoidCallback onToggleMultiSelectMode;
  
  /// 切换习惯选中状态回调
  final Function(String habitId) onToggleEntrySelection;

  /// 是否正在搜索
  final bool isSearching;
  final bool allowRetroactiveCheckIn;

  const DayView({
    super.key,
    required this.habits,
    required this.categories,
    required this.theme,
    this.selectedDate,
    this.selectedCategoryId,
    required this.isMultiSelectMode,
    required this.selectedHabits,
    required this.onToggleMultiSelectMode,
    required this.onToggleEntrySelection,
    this.isSearching = false,
    this.allowRetroactiveCheckIn = true,
  });

  @override
  Widget build(BuildContext context) {
    // 根据选中的分类过滤习惯
    final filteredHabits = selectedCategoryId == null
        ? habits
        : habits.where((habit) => habit.categoryId == selectedCategoryId).toList();

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
                isSearching ? Icons.search_off : Icons.task_alt,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                isSearching ? '未找到匹配的习惯' : '还没有习惯',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearching ? '尝试其他关键词搜索' : '点击 + 按钮添加你的第一个习惯',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 构建习惯列表
    final listDelegate = SliverChildBuilderDelegate(
      (context, index) {
        final habit = filteredHabits[index];
        
        // 检查习惯是否被选中
        final isSelected = selectedHabits.contains(habit.id);
        
        // 左滑删除功能
        final slidableCard = Slidable(
          // 配置滑动方向和动画
          key: ValueKey(habit.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (context) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('删除习惯'),
                        content: Text('确定要删除习惯 "${habit.name}" 吗？'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              context.read<HabitBloc>().add(DeleteHabit(habit.id));
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('删除'),
                          ),
                        ],
                      );
                    },
                  );
                },
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: '删除',
              ),
            ],
          ),
          // 主内容区域
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (isMultiSelectMode) {
                  // 多选模式下，点击切换选择状态
                  onToggleEntrySelection(habit.id);
                } else {
                  // 非多选模式下，进入详情页
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider.value(
                        value: BlocProvider.of<HabitBloc>(context),
                        child: HabitDetailDialog(
                          habit: habit,
                          categories: categories,
                        ),
                      ),
                    ),
                  );
                }
              },
              onLongPress: () {
                // 长按进入多选模式
                if (!isMultiSelectMode) {
                  onToggleMultiSelectMode();
                  onToggleEntrySelection(habit.id);
                }
              },
              child: Stack(
                children: [
                  HabitItem(
                    habit: habit,
                    selectedDate: selectedDate,
                    allowRetroactiveCheckIn: allowRetroactiveCheckIn,
                  ),
                  // 多选模式下，显示选择状态
                  if (isMultiSelectMode) Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white.withAlpha(80),
                          width: 2,
                        ),
                      ),
                      child: isSelected ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ) : null,
                    ),
                  ),
                  // 多选模式下，卡片添加轻微阴影效果
                  if (isMultiSelectMode) Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red.withAlpha(10) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        
        return slidableCard;
      },
      childCount: filteredHabits.length,
      addAutomaticKeepAlives: true,
    );

    // 构建内容
    return SliverList(
      delegate: listDelegate,
    );
  }
}



