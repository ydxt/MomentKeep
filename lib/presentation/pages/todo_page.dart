import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/kanban_column.dart';
import 'package:moment_keep/domain/entities/security.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/utils/priority_helper.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/pages/add_todo_page.dart';
import 'package:moment_keep/presentation/pages/todo_detail_page.dart';
import 'package:moment_keep/presentation/pages/settings_page.dart';

/// 待办事项页面
class TodoPage extends ConsumerStatefulWidget {
  /// 构造函数
  const TodoPage({super.key});

  @override
  TodoPageState createState() => TodoPageState();
}

/// 视图类型枚举
enum TodoViewType {
  /// 列表视图
  list,
  /// 日历视图
  calendar,
  /// 看板视图
  kanban
}

class TodoPageState extends ConsumerState<TodoPage> {
  // 跟踪当前选中的筛选条件
  String _selectedFilter = '全部';
  
  List<Category> _categories = [];
  
  Set<TodoPriority> _selectedPriorities = {};
  Set<String> _selectedCategoryIds = {};
  bool _filterCompleted = false;
  bool _filterIncomplete = false;
  String _sortBy = 'createdAt_desc';
  
  bool _isMultiSelectMode = false;
  
  /// 选中的任务ID集合
  Set<String> _selectedTodos = {};
  
  /// 搜索关键字
  String _searchKeyword = '';
  
  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();
  
  // 主题变量，在build方法中初始化
  late ThemeData theme;
  
  /// 当前视图类型
  TodoViewType _currentView = TodoViewType.list;
  


  @override
  void initState() {
    super.initState();
    // 只在初始化时加载数据，避免重复加载
    // 延迟加载数据，让页面先渲染，提高切换流畅度
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        context.read<TodoBloc>().add(LoadTodos());
        context
            .read<CategoryBloc>()
            .add(const LoadCategories(type: CategoryType.todo));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 从ref获取主题并赋值给类成员变量
    theme = ref.watch(currentThemeProvider);
    // 检查是否是桌面平台 (Windows, macOS, Linux)
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
          
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                // 多选模式工具栏
                if (_isMultiSelectMode) SliverPersistentHeader(
                  pinned: true,
                  delegate: _MultiSelectToolbarDelegate(
                    selectedCount: _selectedTodos.length,
                    onSelectAll: _toggleSelectAll,
                    onDelete: _deleteSelectedTodos,
                    onMarkAsCompleted: _markSelectedAsCompleted,
                    onMarkAsIncomplete: _markSelectedAsIncomplete,
                    onCancel: _toggleMultiSelectMode,
                  ),
                ),
                // Header Section
                SliverToBoxAdapter(
                  child: _buildHeader(user),
                ),
                // Date & Progress
                SliverToBoxAdapter(
                  child: BlocBuilder<TodoBloc, TodoState>(
                    builder: (context, todoState) {
                      int pendingCount = 0;
                      int totalCount = 0;
                      int completedCount = 0;
                      int highPriorityCount = 0;
                      int mediumPriorityCount = 0;
                      int lowPriorityCount = 0;
                      int todayCompletedCount = 0;
                      
                      if (todoState is TodoLoaded) {
                        // 过滤搜索结果
                        List<Todo> filteredTodos = todoState.todos;
                        if (_searchKeyword.isNotEmpty) {
                          filteredTodos = todoState.todos.where((todo) => 
                            todo.title.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
                            todo.content.any((block) => 
                              block.data.toLowerCase().contains(_searchKeyword.toLowerCase())
                            )
                          ).toList();
                        }
                        
                        totalCount = filteredTodos.length;
                        pendingCount = filteredTodos.where((todo) => !todo.isCompleted).length;
                        completedCount = totalCount - pendingCount;
                        
                        // 按优先级统计
                        highPriorityCount = filteredTodos.where((todo) => todo.priority == TodoPriority.high).length;
                        mediumPriorityCount = filteredTodos.where((todo) => todo.priority == TodoPriority.medium).length;
                        lowPriorityCount = filteredTodos.where((todo) => todo.priority == TodoPriority.low).length;
                        
                        // 统计今日完成的任务
                        final now = DateTime.now();
                        todayCompletedCount = filteredTodos.where((todo) => 
                          todo.isCompleted && 
                          todo.completedAt != null &&
                          todo.completedAt!.year == now.year &&
                          todo.completedAt!.month == now.month &&
                          todo.completedAt!.day == now.day
                        ).length;
                      }
                      return _buildDateAndProgress(
                        pendingCount: pendingCount,
                        totalCount: totalCount,
                        completedCount: completedCount,
                        highPriorityCount: highPriorityCount,
                        mediumPriorityCount: mediumPriorityCount,
                        lowPriorityCount: lowPriorityCount,
                        todayCompletedCount: todayCompletedCount
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchKeyword = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: '搜索任务...',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              suffixIcon: _searchKeyword.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _searchKeyword = '';
                                          _searchController.clear();
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            style: TextStyle(
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showFilterPanel(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _activeFilterCount > 0
                                  ? theme.colorScheme.primary.withOpacity(0.1)
                                  : theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: _activeFilterCount > 0
                                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Icon(
                                    Icons.filter_list,
                                    size: 20,
                                    color: _activeFilterCount > 0
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (_activeFilterCount > 0)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$_activeFilterCount',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Categories Header
                SliverToBoxAdapter(
                  child: _buildCategoriesHeader(),
                ),
                // Filter Chips
                SliverToBoxAdapter(
                  child: _buildFilterChips(),
                ),
                // View Toggle
                SliverToBoxAdapter(
                  child: _buildViewToggle(),
                ),
                // Task Content based on current view
                _buildTaskContent(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 构建头部
  Widget _buildHeader(UserAuth? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的工作区',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '今日任务',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          // User Avatar - Simplified with default avatar
          _buildDefaultAvatar(user),
        ],
      ),
    );
  }

  /// 构建默认头像
  Widget _buildDefaultAvatar(UserAuth? user) {
    return GestureDetector(
      onTap: () {
        // 导航到个人设置页面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
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

  /// 构建日期和进度部分
  Widget _buildDateAndProgress({
    required int pendingCount,
    required int totalCount,
    required int completedCount,
    required int highPriorityCount,
    required int mediumPriorityCount,
    required int lowPriorityCount,
    required int todayCompletedCount,
  }) {
    // 获取当前日期
    final now = DateTime.now();
    final weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final formattedDate = '${now.month}月${now.day}日, ${weekdays[now.weekday - 1]}';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Pending Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount 待办',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  bool _showDeleteButtons = false;
  bool _isLongPressing = false;
  bool _isBlinking = false;

  int get _activeFilterCount {
    int count = 0;
    count += _selectedPriorities.length;
    if (_filterCompleted) count++;
    if (_filterIncomplete) count++;
    count += _selectedCategoryIds.length;
    return count;
  }

  void _showFilterPanel() {
    Set<TodoPriority> tempPriorities = Set.from(_selectedPriorities);
    Set<String> tempCategoryIds = Set.from(_selectedCategoryIds);
    bool tempFilterCompleted = _filterCompleted;
    bool tempFilterIncomplete = _filterIncomplete;
    String tempSortBy = _sortBy;

    final sortOptions = [
      ('createdAt_desc', '创建时间↓'),
      ('createdAt_asc', '创建时间↑'),
      ('dueDate_asc', '结束时间↑'),
      ('dueDate_desc', '结束时间↓'),
      ('priority_desc', '优先级高→低'),
      ('priority_asc', '优先级低→高'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '筛选条件',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempPriorities.clear();
                              tempCategoryIds.clear();
                              tempFilterCompleted = false;
                              tempFilterIncomplete = false;
                              tempSortBy = 'createdAt_desc';
                            });
                          },
                          child: Text(
                            '重置',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      '优先级',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TodoPriority.values.map((priority) {
                        final isSelected = tempPriorities.contains(priority);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(PriorityHelper.getLabel(priority)),
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.onPrimary : PriorityHelper.getColor(priority),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          selectedColor: PriorityHelper.getColor(priority),
                          backgroundColor: PriorityHelper.getColor(priority).withOpacity(0.15),
                          side: BorderSide(
                            color: isSelected ? PriorityHelper.getColor(priority) : PriorityHelper.getColor(priority).withOpacity(0.3),
                          ),
                          checkmarkColor: theme.colorScheme.onPrimary,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                tempPriorities.add(priority);
                              } else {
                                tempPriorities.remove(priority);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      '完成状态',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          selected: tempFilterCompleted,
                          label: const Text('已完成'),
                          labelStyle: TextStyle(
                            color: tempFilterCompleted ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(
                            color: tempFilterCompleted ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                          checkmarkColor: theme.colorScheme.onPrimary,
                          onSelected: (selected) {
                            setModalState(() {
                              tempFilterCompleted = selected;
                            });
                          },
                        ),
                        FilterChip(
                          selected: tempFilterIncomplete,
                          label: const Text('未完成'),
                          labelStyle: TextStyle(
                            color: tempFilterIncomplete ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(
                            color: tempFilterIncomplete ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                          checkmarkColor: theme.colorScheme.onPrimary,
                          onSelected: (selected) {
                            setModalState(() {
                              tempFilterIncomplete = selected;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      '类别',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = tempCategoryIds.contains(category.id);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(category.name),
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                          checkmarkColor: theme.colorScheme.onPrimary,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                tempCategoryIds.add(category.id);
                              } else {
                                tempCategoryIds.remove(category.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    const Divider(),
                    const SizedBox(height: 16),

                    Text(
                      '排序方式',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortOptions.map((option) {
                        final isSelected = tempSortBy == option.$1;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempSortBy = option.$1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
                            ),
                            child: Text(
                              option.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPriorities = tempPriorities;
                            _selectedCategoryIds = tempCategoryIds;
                            _filterCompleted = tempFilterCompleted;
                            _filterIncomplete = tempFilterIncomplete;
                            _sortBy = tempSortBy;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '确认',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildCategoriesHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '分类',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建筛选芯片
  Widget _buildFilterChips() {
    return BlocBuilder<CategoryBloc, CategoryState>(
      buildWhen: (previous, current) {
        // 只有当分类列表实际变化时才重建
        if (previous is CategoryLoaded && current is CategoryLoaded) {
          return previous.categories != current.categories;
        }
        // 状态类型变化时重建
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, categoryState) {
        if (categoryState is CategoryLoaded) {
          // 更新本地分类列表，确保"全部"分类始终在第一位
          _categories = categoryState.categories;
        } else if (categoryState is CategoryLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: CircularProgressIndicator(),
          );
        } else if (categoryState is CategoryError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(categoryState.message, style: TextStyle(color: theme.colorScheme.error)),
          );
        }

        // 构建分类芯片列表，始终包含"全部"分类
        List<Widget> chipWidgets = [
          _buildAllCategoryChip(),
        ];

        // 添加用户定义的分类芯片
        for (int i = 0; i < _categories.length; i++) {
          chipWidgets.add(_buildDraggableFilterChip(i));
        }

        // 添加分类按钮 - 调整大小为"全部"按钮高度的一半
        chipWidgets.add(
          GestureDetector(
            onTap: () {
              _showAddCategoryDialog();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 24, // 调整为"全部"按钮高度的一半（24是垂直padding的两倍）
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add,
                color: theme.colorScheme.onSurfaceVariant,
                size: 12, // 调整图标大小
              ),
            ),
          ),
        );

        return Stack(
      children: [
        // 点击其他区域关闭删除按钮和闪烁效果
        if (_showDeleteButtons)
          GestureDetector(
            onTap: () {
              setState(() {
                _showDeleteButtons = false;
                _isLongPressing = false;
                _isBlinking = false;
              });
            },
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: 60, // 与筛选区域高度一致
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
              child: Row(children: chipWidgets),
            ),
          ),
        ),
      ],
    );
      },
    );
  }

  /// 构建"全部"分类芯片
  Widget _buildAllCategoryChip() {
    final isActive = _selectedFilter == '全部';
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = '全部';
            // 点击分类时隐藏删除按钮
            _showDeleteButtons = false;
            _isLongPressing = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
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
              color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建分类芯片内容
  Widget _buildCategoryChipContent(bool isActive, Category category, bool isAll, int index) {
    // 构建基础芯片内容
    Widget chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
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
          color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
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
            _selectedFilter = category.name;
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
          // 取消自动隐藏逻辑，让用户手动控制
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

  /// 构建可拖拽的筛选芯片
  Widget _buildDraggableFilterChip(int index) {
    final category = _categories[index];
    final isActive = _selectedFilter == category.name;

    // 构建分类芯片内容
    Widget chipContent = _buildCategoryChipContent(isActive, category, false, index);

    // 只有当显示删除按钮时，才允许拖动排序
    if (_showDeleteButtons) {
      Widget draggableChip = Draggable<int>(
        data: index,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              category.name,
              style: TextStyle(
                color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
        childWhenDragging: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
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
              top: -8, // 调整位置，确保完全显示
              right: -8, // 调整位置，确保完全显示
              child: GestureDetector(
                onTap: () {
                  // 调用CategoryBloc删除分类
                  context.read<CategoryBloc>().add(DeleteCategory(category.id));
                  // 如果删除的是当前选中的分类，切换到"全部"
                  if (_selectedFilter == category.name) {
                    setState(() {
                      _selectedFilter = '全部';
                    });
                  }
                  // 保持编辑状态，不隐藏删除按钮和闪烁动画
                },
                child: Container(
                  width: 24, // 增大尺寸，确保完全显示
                  height: 24, // 增大尺寸，确保完全显示
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: theme.colorScheme.onError,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    color: theme.colorScheme.onError,
                    size: 16, // 增大图标，确保清晰可见
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
      final element = _categories.removeAt(oldIndex);
      
      // 调整新索引，因为我们已经删除了一个元素
      int insertIndex = newIndex;
      if (newIndex > oldIndex) {
        insertIndex--;
      }
      
      _categories.insert(insertIndex, element);
      
      // 通过Bloc更新分类顺序，持久化保存
      context.read<CategoryBloc>().add(UpdateCategoryOrder(_categories));
    });
  }

  List<Todo> _applySorting(List<Todo> todos) {
    final sorted = List<Todo>.from(todos);
    switch (_sortBy) {
      case 'createdAt_asc':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'createdAt_desc':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'dueDate_asc':
        sorted.sort((a, b) {
          if (a.date == null && b.date == null) return 0;
          if (a.date == null) return 1;
          if (b.date == null) return -1;
          return a.date!.compareTo(b.date!);
        });
        break;
      case 'dueDate_desc':
        sorted.sort((a, b) {
          if (a.date == null && b.date == null) return 0;
          if (a.date == null) return 1;
          if (b.date == null) return -1;
          return b.date!.compareTo(a.date!);
        });
        break;
      case 'priority_desc':
        sorted.sort((a, b) {
          final priorityOrder = {TodoPriority.high: 0, TodoPriority.medium: 1, TodoPriority.low: 2};
          return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
        });
        break;
      case 'priority_asc':
        sorted.sort((a, b) {
          final priorityOrder = {TodoPriority.high: 2, TodoPriority.medium: 1, TodoPriority.low: 0};
          return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
        });
        break;
    }
    return sorted;
  }

  Widget _buildTaskList() {
    return BlocBuilder<TodoBloc, TodoState>(
      buildWhen: (previous, current) {
        // 只有当待办事项列表实际变化时才重建
        if (previous is TodoLoaded && current is TodoLoaded) {
          return previous.todos != current.todos;
        }
        // 状态类型变化时重建
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, todoState) {
        List<Todo> todos = [];
        if (todoState is TodoLoaded) {
          todos = todoState.todos;
        } else if (todoState is TodoLoading) {
          return const SliverToBoxAdapter(child: SizedBox.shrink()); // 加载中时显示空容器
        } else if (todoState is TodoError) {
          return const SliverToBoxAdapter(child: SizedBox.shrink()); // 错误时显示空容器
        }

        List<Todo> searchFilteredTodos = todos;
        if (_searchKeyword.isNotEmpty) {
          searchFilteredTodos = todos.where((todo) => 
            todo.title.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            todo.content.any((block) => 
              block.data.toLowerCase().contains(_searchKeyword.toLowerCase())
            )
          ).toList();
        }
        
        List<Todo> filteredTodos = [];
        if (_selectedFilter == '全部') {
          filteredTodos = searchFilteredTodos;
        } else {
          final matchCategory = _categories.where((cat) => cat.name == _selectedFilter).firstOrNull;
          if (matchCategory != null) {
            filteredTodos = searchFilteredTodos.where((todo) => 
              todo.categoryId == matchCategory.id
            ).toList();
          } else {
            filteredTodos = searchFilteredTodos;
          }
        }

        if (_selectedPriorities.isNotEmpty) {
          filteredTodos = filteredTodos.where((todo) => 
            _selectedPriorities.contains(todo.priority)
          ).toList();
        }

        if (_filterCompleted && !_filterIncomplete) {
          filteredTodos = filteredTodos.where((todo) => todo.isCompleted).toList();
        } else if (_filterIncomplete && !_filterCompleted) {
          filteredTodos = filteredTodos.where((todo) => !todo.isCompleted).toList();
        } else if (_filterCompleted && _filterIncomplete) {
          // both selected means no filter on completion status
        }

        if (_selectedCategoryIds.isNotEmpty) {
          filteredTodos = filteredTodos.where((todo) => 
            _selectedCategoryIds.contains(todo.categoryId)
          ).toList();
        }

        filteredTodos = _applySorting(filteredTodos);

        // 如果没有任务，显示空状态
        if (filteredTodos.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无任务',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加新任务',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverReorderableList(
          itemCount: filteredTodos.length,
          itemBuilder: (context, index) {
            final todo = filteredTodos[index];
            return Padding(
              key: ValueKey(todo.id),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              child: Column(
                children: [
                  _buildTaskItem(context, todo),
                  const SizedBox(height: 12), // 任务项之间的垂直间距
                ],
              ),
            );
          },
          onReorder: (oldIndex, newIndex) {
            // 调整新索引，因为我们已经删除了一个元素
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            
            // 重新排序任务
            setState(() {
              final Todo movedTodo = filteredTodos.removeAt(oldIndex);
              filteredTodos.insert(newIndex, movedTodo);
            });
            
            // 通过Bloc更新任务顺序，持久化保存
            context.read<TodoBloc>().add(UpdateTodoOrder(filteredTodos));
          },
        );
      },
    );
  }

  /// 构建任务项
  Widget _buildTaskItem(BuildContext context, Todo todo) {
    // 检查任务是否被选中
    final isSelected = _selectedTodos.contains(todo.id);
    
    // 显示删除确认对话框
    void showDeleteDialog() {
      // 检查任务是否是重复任务
      if (todo.repeatType != RepeatType.none) {
        // 显示重复任务删除确认对话框
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surfaceVariant,
              title: Text(
                '删除任务',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: Text(
                '确定要删除任务 "${todo.title}" 吗？',
                style: TextStyle(color: theme.colorScheme.onSurface),
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
                    // 仅删除选中的一个待办事项
                    // 这里我们需要修改任务的重复类型为none，而不是直接删除
                    // 因为如果直接删除，所有重复任务都会被删除
                    final updatedTodo = todo.copyWith(
                      repeatType: RepeatType.none,
                      repeatInterval: 1,
                      repeatEndDate: null,
                      lastRepeatDate: null,
                    );
                    context.read<TodoBloc>().add(UpdateTodo(updatedTodo));
                    Navigator.pop(context);
                  },
                  child: Text('仅删除次项'),
                ),
                TextButton(
                  onPressed: () {
                    // 删除所有重复的待办事项
                    context.read<TodoBloc>().add(DeleteTodo(todo.id));
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: Text('删除所有重复项'),
                ),
              ],
            );
          },
        );
      } else {
        // 显示普通删除确认对话框
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surfaceVariant,
              title: Text(
                '删除任务',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: Text(
                '确定要删除任务 "${todo.title}" 吗？',
                style: TextStyle(color: theme.colorScheme.onSurface),
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
                    context.read<TodoBloc>().add(DeleteTodo(todo.id));
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: Text('删除'),
                ),
              ],
            );
          },
        );
      }
    }
    
    return Slidable(
      // 配置滑动方向和动画
      key: ValueKey(todo.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) => showDeleteDialog(),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
            label: '删除',
          ),
        ],
      ),
      // 主内容区域
      child: GestureDetector(
        onTap: () {
          if (_isMultiSelectMode) {
            // 多选模式下，点击切换选择状态
            _toggleEntrySelection(todo.id);
          } else {
            // 非多选模式下，进入详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TodoDetailPage(todo: todo),
              ),
            );
          }
        },
        onLongPress: () {
          // 长按进入多选模式
          if (!_isMultiSelectMode) {
            _toggleMultiSelectMode();
            _toggleEntrySelection(todo.id);
          }
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(
                  color: todo.isCompleted ? Colors.transparent : PriorityHelper.getColor(todo.priority),
                  width: 4,
                )),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Checkbox
                    Checkbox(
                      value: todo.isCompleted,
                      onChanged: (value) {
                        context.read<TodoBloc>().add(ToggleTodoCompletion(todo.id));
                      },
                      activeColor: theme.colorScheme.primary,
                      checkColor: theme.colorScheme.onPrimary,
                      side: BorderSide(color: theme.colorScheme.outline, width: 2),
                    ),
                    const SizedBox(width: 12),
                    // Task Content - Clickable to show details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!todo.isCompleted)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: PriorityHelper.getColor(todo.priority),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  todo.title,
                                  style: TextStyle(
                                    color: todo.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Task Meta
                          Row(
                            children: [
                              // Time
                              Icon(
                                Icons.schedule,
                                color: todo.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                todo.date != null
                                    ? '${todo.date!.month}/${todo.date!.day} ${todo.date!.hour}:${todo.date!.minute.toString().padLeft(2, '0')}'
                                    : '未设置时间',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Category
                              if (todo.categoryId != null && todo.categoryId!.isNotEmpty)
                                ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.category, 
                                          size: 14, 
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _categories.firstWhere(
                                            (cat) => cat.id == todo.categoryId,
                                            orElse: () => Category(id: '', name: todo.categoryId ?? '', type: CategoryType.todo, icon: '', color: 0),
                                          ).name,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              // Tags
                              if (todo.tags.isNotEmpty)
                                ...[
                                  const SizedBox(width: 8),
                                  ...todo.tags.map((tag) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.tag, 
                                            size: 14, 
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            tag,
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                                ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // More Options
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showEditTodoDialog(context, todo);
                            break;
                          case 'delete':
                            showDeleteDialog();
                            break;
                        }
                      },
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      color: theme.colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: theme.colorScheme.onSurface, size: 16),
                              const SizedBox(width: 8),
                              Text('编辑', style: TextStyle(color: theme.colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: theme.colorScheme.error, size: 16),
                              const SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: theme.colorScheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 多选模式下，显示选择状态
            if (_isMultiSelectMode) Positioned(
              top: 12,
              left: 12,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.error : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.onError : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isSelected ? Icon(
                  Icons.check,
                  size: 16,
                  color: theme.colorScheme.onError,
                ) : null,
              ),
            ),
            // 多选模式下，卡片添加轻微阴影效果
            if (_isMultiSelectMode) Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.error.withAlpha(10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示添加分类对话框
  void _showAddCategoryDialog() {
    final categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceVariant,
        title: Text('添加分类', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: TextField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: '分类名称',
            labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary),
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          style: TextStyle(color: theme.colorScheme.onSurface),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              if (categoryController.text.isNotEmpty) {
                // 通过CategoryBloc添加新分类
                final newCategory = Category(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: categoryController.text,
                  type: CategoryType.todo,
                  color: theme.colorScheme.primary.value,
                  icon: Icons.category.codePoint.toString(),
                );
                
                context.read<CategoryBloc>().add(AddCategory(newCategory));
                
                setState(() {
                  // 添加成功后隐藏删除按钮
                  _showDeleteButtons = false;
                });
                
                Navigator.pop(context);
              }
            },
            child: Text('添加'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示删除分类对话框
  void _showDeleteCategoryDialog() {
    // 这里应该显示现有分类列表，让用户选择要删除的分类
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceVariant,
        title: Text('删除分类', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('选择要删除的分类', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              // 这里应该调用分类管理的Bloc来删除分类
              Navigator.pop(context);
            },
            child: Text('删除'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建视图切换按钮
  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 列表视图按钮
            _buildViewButton(Icons.list, '列表', TodoViewType.list, _currentView == TodoViewType.list),
            // 日历视图按钮
            _buildViewButton(Icons.calendar_today, '日历', TodoViewType.calendar, _currentView == TodoViewType.calendar),
            // 看板视图按钮
            _buildViewButton(Icons.view_column, '看板', TodoViewType.kanban, _currentView == TodoViewType.kanban),
          ],
        ),
      ),
    );
  }
  
  /// 构建单个视图按钮
  Widget _buildViewButton(IconData icon, String label, TodoViewType viewType, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentView = viewType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 根据当前视图构建任务内容
  Widget _buildTaskContent() {
    switch (_currentView) {
      case TodoViewType.list:
        return _buildTaskList();
      case TodoViewType.calendar:
        return _buildCalendarView();
      case TodoViewType.kanban:
        return _buildKanbanView();
    }
  }
  
  /// 构建日历视图
  Widget _buildCalendarView() {
    return BlocBuilder<TodoBloc, TodoState>(
      buildWhen: (previous, current) {
        if (previous is TodoLoaded && current is TodoLoaded) {
          return previous.todos != current.todos;
        }
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, todoState) {
        if (todoState is TodoLoaded) {
          return SliverToBoxAdapter(
            child: _CalendarViewContent(
              todos: todoState.todos,
              theme: theme,
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }
  
  Widget _buildKanbanView() {
    return BlocBuilder<TodoBloc, TodoState>(
      buildWhen: (previous, current) {
        if (previous is TodoLoaded && current is TodoLoaded) {
          return previous.todos != current.todos || previous.kanbanColumns != current.kanbanColumns;
        }
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, todoState) {
        if (todoState is TodoLoaded) {
          List<Todo> filteredTodos = todoState.todos;
          if (_searchKeyword.isNotEmpty) {
            filteredTodos = filteredTodos.where((todo) => 
              todo.title.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
              todo.content.any((block) => 
                block.data.toLowerCase().contains(_searchKeyword.toLowerCase())
              )
            ).toList();
          }
          if (_selectedPriorities.isNotEmpty) {
            filteredTodos = filteredTodos.where((todo) => 
              _selectedPriorities.contains(todo.priority)
            ).toList();
          }
          if (_filterCompleted && !_filterIncomplete) {
            filteredTodos = filteredTodos.where((todo) => todo.isCompleted).toList();
          } else if (_filterIncomplete && !_filterCompleted) {
            filteredTodos = filteredTodos.where((todo) => !todo.isCompleted).toList();
          }
          if (_selectedCategoryIds.isNotEmpty) {
            filteredTodos = filteredTodos.where((todo) => 
              _selectedCategoryIds.contains(todo.categoryId)
            ).toList();
          }
          filteredTodos = _applySorting(filteredTodos);
          
          return SliverToBoxAdapter(
            child: _KanbanViewContent(
              columns: todoState.kanbanColumns,
              todos: filteredTodos,
              theme: theme,
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  /// 构建悬浮按钮
  Widget _buildFloatingActionButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () {
          // 导航到添加待办事项页面
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTodoPage()),
          );
        },
        icon: Icon(
          Icons.add,
          color: theme.colorScheme.onPrimary,
          size: 32,
        ),
      ),
    );
  }

  /// 显示编辑待办事项对话框
  void _showEditTodoDialog(BuildContext context, Todo todo) {
    // 直接导航到 AddTodoPage，并传递待办事项数据，实现编辑功能
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTodoPage(todo: todo),
      ),
    );
  }


  
  /// 切换多选模式
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedTodos.clear();
      }
    });
  }
  
  /// 切换任务选中状态
  void _toggleEntrySelection(String todoId) {
    setState(() {
      if (_selectedTodos.contains(todoId)) {
        _selectedTodos.remove(todoId);
      } else {
        _selectedTodos.add(todoId);
      }
    });
  }
  
  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      // 从上下文获取 TodoBloc 状态
      final todoBloc = BlocProvider.of<TodoBloc>(context);
      final todoState = todoBloc.state;
      List<Todo> allTodos = [];
      
      if (todoState is TodoLoaded) {
        allTodos = todoState.todos;
      }
      
      final filteredTodos = _selectedFilter == '全部'
          ? allTodos
          : allTodos.where((todo) {
              final matchCategory = _categories.where((cat) => cat.name == _selectedFilter).firstOrNull;
              if (matchCategory != null) {
                return todo.categoryId == matchCategory.id;
              }
              return true;
            }).toList();
              
      if (_selectedTodos.length == filteredTodos.length) {
        _selectedTodos.clear();
      } else {
        _selectedTodos = filteredTodos.map((todo) => todo.id).toSet();
      }
    });
  }
  
  /// 删除选中的任务
  void _deleteSelectedTodos() {
    if (_selectedTodos.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.mediumSurfaceGray,
          title: const Text(
            '删除任务',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '确定要删除选中的 ${_selectedTodos.length} 个任务吗？',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                '取消',
                style: TextStyle(color: AppTheme.lightSurfaceGray),
              ),
            ),
            TextButton(
              onPressed: () {
                // 删除选中的任务
                for (final todoId in _selectedTodos) {
                  context.read<TodoBloc>().add(DeleteTodo(todoId));
                }
                // 退出多选模式
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedTodos.clear();
                });
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
  
  /// 将选中的任务标记为完成
  void _markSelectedAsCompleted() {
    if (_selectedTodos.isEmpty) return;
    
    // 批量标记为完成
    for (final todoId in _selectedTodos) {
      context.read<TodoBloc>().add(ToggleTodoCompletion(todoId));
    }
    
    // 退出多选模式
    setState(() {
      _isMultiSelectMode = false;
      _selectedTodos.clear();
    });
  }
  
  /// 将选中的任务标记为未完成
  void _markSelectedAsIncomplete() {
    if (_selectedTodos.isEmpty) return;
    
    // 批量标记为未完成
    for (final todoId in _selectedTodos) {
      context.read<TodoBloc>().add(ToggleTodoCompletion(todoId));
    }
    
    // 退出多选模式
    setState(() {
      _isMultiSelectMode = false;
      _selectedTodos.clear();
    });
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
  
  /// 标记为完成回调
  final VoidCallback onMarkAsCompleted;
  
  /// 标记为未完成回调
  final VoidCallback onMarkAsIncomplete;
  
  /// 取消多选模式回调
  final VoidCallback onCancel;
  
  /// 构造函数
  const _MultiSelectToolbarDelegate({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onDelete,
    required this.onMarkAsCompleted,
    required this.onMarkAsIncomplete,
    required this.onCancel,
  });
  
  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mediumSurfaceGray,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.darkSurfaceGray,
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
                child: const Text('全选'),
              ),
            ],
          ),
          // 右侧：批量操作按钮
          Row(
            children: [
              ElevatedButton(
                onPressed: onMarkAsCompleted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('标记完成'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onMarkAsIncomplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('标记未完成'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text('删除'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text('取消'),
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

/// 日历视图内容组件
class _CalendarViewContent extends StatefulWidget {
  /// 构造函数
  const _CalendarViewContent({
    required this.todos,
    required this.theme,
  });
  
  /// 待办事项列表
  final List<Todo> todos;
  
  /// 主题
  final ThemeData theme;
  
  @override
  State<_CalendarViewContent> createState() => _CalendarViewContentState();
}

class _CalendarViewContentState extends State<_CalendarViewContent> {
  DateTime _currentMonth = DateTime.now();
  final DateTime _today = DateTime.now();
  DateTime? _selectedDate;
  bool _isCalendarCollapsed = false;
  
  @override
  void initState() {
    super.initState();
    // 默认选中今天的日期
    _selectedDate = _today;
  }
  
  /// 获取当前月份的天数
  int get _daysInMonth {
    return DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
  }
  
  /// 获取当前月份第一天是星期几（调整为周一作为第一天，1=周一，7=周日）
  int get _firstDayOfMonth {
    final firstDay = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday;
    // 将周一作为第一天，所以如果是周日（7），则返回0
    return firstDay == 7 ? 0 : firstDay;
  }
  
  /// 上一个月
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
        1,
      );
    });
  }
  
  /// 下一个月
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        1,
      );
    });
  }
  
  /// 切换到今天
  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
  }
  
  /// 选择日期
  void _selectDate(int day) {
    setState(() {
      _selectedDate = DateTime(
        _currentMonth.year,
        _currentMonth.month,
        day,
      );
    });
  }
  
  /// 检查任务是否应该出现在某一天
  bool _isTaskOnDay(Todo todo, DateTime date) {
    if (todo.date == null) return false;
    
    // 检查是否是跨天任务
    if (todo.startDate != null) {
      // 为了比较日期，创建只包含年月日的DateTime对象
      final startDateOnly = DateTime(todo.startDate!.year, todo.startDate!.month, todo.startDate!.day);
      final endDateOnly = DateTime(todo.date!.year, todo.date!.month, todo.date!.day);
      final targetDateOnly = DateTime(date.year, date.month, date.day);
      
      // 检查目标日期是否在开始日期和结束日期之间（包括开始和结束日期）
      final isBetween = targetDateOnly.isAfter(startDateOnly.subtract(const Duration(days: 1))) &&
          targetDateOnly.isBefore(endDateOnly.add(const Duration(days: 1)));
      
      if (isBetween) {
        return true;
      }
    }
    
    // 首先检查任务的原始日期是否与目标日期相同
    if (todo.date!.year == date.year &&
        todo.date!.month == date.month &&
        todo.date!.day == date.day) {
      return true;
    }
    
    // 如果任务不是重复任务，直接返回false
    if (todo.repeatType == RepeatType.none) {
      return false;
    }
    
    // 检查目标日期是否在重复范围内
    if (date.isBefore(todo.date!)) {
      return false;
    }
    if (todo.repeatEndDate != null && date.isAfter(todo.repeatEndDate!)) {
      return false;
    }
    
    // 根据重复类型计算任务是否应该出现在目标日期
    switch (todo.repeatType) {
      case RepeatType.daily:
        return _isDailyTaskOnDay(todo, date);
      case RepeatType.weekly:
        return _isWeeklyTaskOnDay(todo, date);
      case RepeatType.monthly:
        return _isMonthlyTaskOnDay(todo, date);
      case RepeatType.yearly:
        return _isYearlyTaskOnDay(todo, date);
      case RepeatType.custom:
        // 自定义重复类型暂时不支持
        return false;
      default:
        return false;
    }
  }
  
  /// 检查每日重复任务是否应该出现在某一天
  bool _isDailyTaskOnDay(Todo todo, DateTime date) {
    final daysSinceStart = date.difference(todo.date!).inDays;
    return daysSinceStart % todo.repeatInterval == 0;
  }
  
  /// 检查每周重复任务是否应该出现在某一天
  bool _isWeeklyTaskOnDay(Todo todo, DateTime date) {
    final weeksSinceStart = date.difference(todo.date!).inDays ~/ 7;
    if (weeksSinceStart % todo.repeatInterval != 0) {
      return false;
    }
    
    // 检查目标日期的星期几是否与任务的原始日期的星期几相同
    return date.weekday == todo.date!.weekday;
  }
  
  /// 检查每月重复任务是否应该出现在某一天
  bool _isMonthlyTaskOnDay(Todo todo, DateTime date) {
    // 计算目标日期与原始日期之间的月数差
    int monthsSinceStart = (date.year - todo.date!.year) * 12 + (date.month - todo.date!.month);
    if (monthsSinceStart % todo.repeatInterval != 0) {
      return false;
    }
    
    // 检查目标日期的天数是否与任务的原始日期的天数相同
    return date.day == todo.date!.day;
  }
  
  /// 检查每年重复任务是否应该出现在某一天
  bool _isYearlyTaskOnDay(Todo todo, DateTime date) {
    // 计算目标日期与原始日期之间的年数差
    int yearsSinceStart = date.year - todo.date!.year;
    if (yearsSinceStart % todo.repeatInterval != 0) {
      return false;
    }
    
    // 检查目标日期的月和日是否与任务的原始日期的月和日相同
    return date.month == todo.date!.month && date.day == todo.date!.day;
  }
  
  /// 获取某天的任务
  List<Todo> _getTasksForDay(DateTime? date) {
    if (date == null) return [];
    
    return widget.todos.where((todo) {
      return _isTaskOnDay(todo, date);
    }).toList();
  }

  Widget _buildCalendarDayCell(DateTime date, bool isToday, bool isSelected, List<Todo> sortedTasks, bool hasTasks, {bool compact = false}) {
    final currentDateOnly = DateTime(date.year, date.month, date.day);
    final maxTasks = compact ? 1 : 2;

    List<Widget> buildTaskWidgets() {
      List<Widget> widgets = [];
      for (int i = 0; i < sortedTasks.length && i < maxTasks; i++) {
        final task = sortedTasks[i];
        bool isMultiDay = task.startDate != null && task.date != null &&
            (task.startDate!.day != task.date!.day ||
             task.startDate!.month != task.date!.month ||
             task.startDate!.year != task.date!.year);

        BorderRadius borderRadius = BorderRadius.circular(8);
        String statusText = '';
        bool isFirstDay = false;
        bool isLastDay = false;

        if (isMultiDay) {
          final startDateOnly = DateTime(task.startDate!.year, task.startDate!.month, task.startDate!.day);
          final endDateOnly = DateTime(task.date!.year, task.date!.month, task.date!.day);

          isFirstDay = currentDateOnly.isAtSameMomentAs(startDateOnly);
          isLastDay = currentDateOnly.isAtSameMomentAs(endDateOnly);

          if (isFirstDay && isLastDay) {
            borderRadius = BorderRadius.circular(8);
          } else if (isFirstDay) {
            borderRadius = const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
              topRight: Radius.zero,
              bottomRight: Radius.zero,
            );
          } else if (isLastDay) {
            borderRadius = const BorderRadius.only(
              topLeft: Radius.zero,
              bottomLeft: Radius.zero,
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            );
          } else {
            borderRadius = BorderRadius.zero;
          }

          if (isFirstDay) {
            statusText = '开始';
          } else if (isLastDay) {
            statusText = '结束';
          } else {
            statusText = '进行中';
          }
        }

        if (compact) {
          widgets.add(
            Container(
              margin: isMultiDay ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 1),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TodoDetailPage(todo: task),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMultiDay
                        ? widget.theme.colorScheme.primary.withOpacity(0.2)
                        : widget.theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: borderRadius,
                    border: isMultiDay ? Border(
                      top: BorderSide(color: widget.theme.colorScheme.primary, width: 2),
                      bottom: BorderSide(color: widget.theme.colorScheme.primary, width: 2),
                      left: isFirstDay ? BorderSide(color: widget.theme.colorScheme.primary, width: 2) : BorderSide.none,
                      right: isLastDay ? BorderSide(color: widget.theme.colorScheme.primary, width: 2) : BorderSide.none,
                    ) : Border.all(
                      color: widget.theme.colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isMultiDay ? '$statusText ${task.title}' : task.title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          widgets.add(
            Container(
              margin: isMultiDay ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 2),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TodoDetailPage(todo: task),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMultiDay
                        ? widget.theme.colorScheme.primary.withOpacity(0.2)
                        : widget.theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: borderRadius,
                    border: isMultiDay ? Border(
                      top: BorderSide(color: widget.theme.colorScheme.primary, width: 3),
                      bottom: BorderSide(color: widget.theme.colorScheme.primary, width: 3),
                      left: isFirstDay ? BorderSide(color: widget.theme.colorScheme.primary, width: 3) : BorderSide.none,
                      right: isLastDay ? BorderSide(color: widget.theme.colorScheme.primary, width: 3) : BorderSide.none,
                    ) : Border.all(
                      color: widget.theme.colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isMultiDay
                          ? statusText
                          : (task.startDate != null
                              ? '${task.startDate!.hour.toString().padLeft(2, '0')}:${task.startDate!.minute.toString().padLeft(2, '0')}'
                              : (task.date != null
                                  ? '${task.date!.hour.toString().padLeft(2, '0')}:${task.date!.minute.toString().padLeft(2, '0')}'
                                  : '')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              overflow: TextOverflow.ellipsis,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
      return widgets;
    }

    return GestureDetector(
      onTap: () => _selectDate(date.day),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? widget.theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: widget.theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: compact ? 28 : 32,
                  height: compact ? 28 : 32,
                  decoration: BoxDecoration(
                    color: isToday
                        ? widget.theme.colorScheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: !isToday && hasTasks
                        ? Border.all(color: widget.theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? widget.theme.colorScheme.onPrimary
                            : hasTasks
                                ? widget.theme.colorScheme.primary
                                : widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Expanded(
                child: ClipRect(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...buildTaskWidgets(),
                    if (sortedTasks.length > maxTasks)
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                backgroundColor: widget.theme.colorScheme.background,
                                surfaceTintColor: widget.theme.colorScheme.surface,
                                title: Text(
                                  '${date.year}年${date.month}月${date.day}日的所有任务',
                                  style: TextStyle(color: widget.theme.colorScheme.onBackground),
                                ),
                                content: SizedBox(
                                  width: 400,
                                  height: 500,
                                  child: ListView.builder(
                                    itemCount: sortedTasks.length,
                                    itemBuilder: (context, index) {
                                      final todo = sortedTasks[index];
                                      String timeText = '';
                                      bool isAllDay = todo.startDate != null && todo.date != null &&
                                          (todo.startDate!.day != todo.date!.day ||
                                           todo.startDate!.month != todo.date!.month ||
                                           todo.startDate!.year != todo.date!.year);
                                      if (isAllDay) {
                                        timeText = '全天';
                                      } else if (todo.startDate != null) {
                                        timeText = '${todo.startDate!.hour.toString().padLeft(2, '0')}:${todo.startDate!.minute.toString().padLeft(2, '0')}';
                                      } else if (todo.date != null) {
                                        timeText = '${todo.date!.hour.toString().padLeft(2, '0')}:${todo.date!.minute.toString().padLeft(2, '0')}';
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => TodoDetailPage(todo: todo),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: widget.theme.colorScheme.surfaceVariant,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  timeText,
                                                  style: TextStyle(
                                                    color: widget.theme.colorScheme.primary,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    todo.title,
                                                    style: TextStyle(
                                                      color: widget.theme.colorScheme.onBackground,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Text(
                          compact ? '+${sortedTasks.length - maxTasks}' : '+${sortedTasks.length - maxTasks}个任务',
                          style: TextStyle(
                            fontSize: compact ? 10 : 12,
                            fontWeight: FontWeight.w500,
                            color: widget.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Todo> _getSortedTasksForDate(DateTime date) {
    final dayTasks = widget.todos.where((todo) {
      return _isTaskOnDay(todo, date);
    }).toList();

    List<Todo> sortedTasks = List.from(dayTasks);
    sortedTasks.sort((a, b) {
      bool aIsAllDay = a.startDate != null && a.date != null &&
          (a.startDate!.day != a.date!.day || a.startDate!.month != a.date!.month || a.startDate!.year != a.date!.year);
      bool bIsAllDay = b.startDate != null && b.date != null &&
          (b.startDate!.day != b.date!.day || b.startDate!.month != b.date!.month || b.startDate!.year != b.date!.year);
      if (aIsAllDay && !bIsAllDay) return -1;
      if (!aIsAllDay && bIsAllDay) return 1;
      DateTime? aStartTime = a.startDate ?? a.date;
      DateTime? bStartTime = b.startDate ?? b.date;
      if (aStartTime == null && bStartTime == null) return 0;
      if (aStartTime == null) return 1;
      if (bStartTime == null) return -1;
      return aStartTime.compareTo(bStartTime);
    });
    return sortedTasks;
  }

  Widget _buildFullCalendarGrid(int firstDayOfMonth, int daysInMonth, int rows, List<String> weekdays) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
      ),
      itemCount: 7 * rows,
      itemBuilder: (context, index) {
        final dayIndex = index - (firstDayOfMonth - 1);
        final day = dayIndex + 1;

        if (dayIndex < 0 || day > daysInMonth) {
          return Container();
        }

        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final isToday = date.year == _today.year && date.month == _today.month && date.day == _today.day;
        final isSelected = _selectedDate != null && _selectedDate!.year == date.year && _selectedDate!.month == date.month && _selectedDate!.day == date.day;
        final sortedTasks = _getSortedTasksForDate(date);
        final hasTasks = sortedTasks.isNotEmpty;

        return _buildCalendarDayCell(date, isToday, isSelected, sortedTasks, hasTasks);
      },
    );
  }

  Widget _buildCollapsedCalendarGrid(int firstDayOfMonth, int daysInMonth) {
    final todayRowStartOffset = firstDayOfMonth - 1;
    final todayDayIndex = _today.day + todayRowStartOffset - 1;
    final todayRowIndex = todayDayIndex ~/ 7;
    final startItemIndex = todayRowIndex * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.7,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
      ),
      itemCount: 7,
      itemBuilder: (context, index) {
        final absoluteIndex = startItemIndex + index;
        final dayIndex = absoluteIndex - (firstDayOfMonth - 1);
        final day = dayIndex + 1;

        if (dayIndex < 0 || day > daysInMonth) {
          return Container();
        }

        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final isToday = date.year == _today.year && date.month == _today.month && date.day == _today.day;
        final isSelected = _selectedDate != null && _selectedDate!.year == date.year && _selectedDate!.month == date.month && _selectedDate!.day == date.day;
        final sortedTasks = _getSortedTasksForDate(date);
        final hasTasks = sortedTasks.isNotEmpty;

        return _buildCalendarDayCell(date, isToday, isSelected, sortedTasks, hasTasks, compact: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final daysInMonth = _daysInMonth;
    final firstDayOfMonth = _firstDayOfMonth;
    
    // 计算需要显示的行数
    final rows = ((daysInMonth + firstDayOfMonth - 1) / 7).ceil();
    
    // 获取选中日期的任务
    final selectedDateTasks = _getTasksForDay(_selectedDate);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isCalendarCollapsed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: Icon(
                      Icons.chevron_left,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${_currentMonth.year}年${_currentMonth.month}月',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _goToToday,
                        child: Text(
                          '今天',
                          style: TextStyle(
                            color: widget.theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: Icon(
                          Icons.chevron_right,
                          color: widget.theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_isCalendarCollapsed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_today.month}月${_today.day}日',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: _goToToday,
                    icon: Text(
                      '今天',
                      style: TextStyle(
                        color: widget.theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isCalendarCollapsed = !_isCalendarCollapsed;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isCalendarCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 18,
                        color: widget.theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isCalendarCollapsed ? '展开日历' : '折叠日历',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _isCalendarCollapsed ? const SizedBox(height: 4) : const SizedBox(height: 8),
          
          // 星期标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekdays[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          
          AnimatedCrossFade(
            firstChild: _buildFullCalendarGrid(firstDayOfMonth, daysInMonth, rows, weekdays),
            secondChild: _buildCollapsedCalendarGrid(firstDayOfMonth, daysInMonth),
            crossFadeState: _isCalendarCollapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          _isCalendarCollapsed ? const SizedBox(height: 8) : const SizedBox(height: 24),
          
          // 选中日期的任务列表
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate != null
                        ? '${_selectedDate!.month}月${_selectedDate!.day}日的任务'
                        : '今天的任务',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                  // 添加待办事项按钮
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddTodoPage(date: _selectedDate),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                            color: widget.theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '添加任务',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (selectedDateTasks.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: widget.theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无任务',
                        style: TextStyle(
                          color: widget.theme.colorScheme.onSurfaceVariant,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 添加待办事项按钮
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddTodoPage(date: _selectedDate),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: widget.theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '添加第一个任务',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: widget.theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedDateTasks.length,
                  itemBuilder: (context, index) {
                    final todo = selectedDateTasks[index];
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Slidable(
                        // 配置滑动方向和动画
                        key: ValueKey(todo.id),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.25,
                          children: [
                            SlidableAction(
                              onPressed: (context) {
                                // 检查任务是否是重复任务
                                if (todo.repeatType != RepeatType.none) {
                                  // 显示重复任务删除确认对话框
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        backgroundColor: widget.theme.colorScheme.surfaceVariant,
                                        title: Text(
                                          '删除任务',
                                          style: TextStyle(color: widget.theme.colorScheme.onSurface),
                                        ),
                                        content: Text(
                                          '确定要删除任务 "${todo.title}" 吗？',
                                          style: TextStyle(color: widget.theme.colorScheme.onSurface),
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
                                              // 仅删除选中的一个待办事项
                                              // 这里我们需要修改任务的重复类型为none，而不是直接删除
                                              // 因为如果直接删除，所有重复任务都会被删除
                                              final updatedTodo = todo.copyWith(
                                                repeatType: RepeatType.none,
                                                repeatInterval: 1,
                                                repeatEndDate: null,
                                                lastRepeatDate: null,
                                              );
                                              context.read<TodoBloc>().add(UpdateTodo(updatedTodo));
                                              Navigator.pop(context);
                                            },
                                            child: Text('仅删除此项'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              // 删除所有重复的待办事项
                                              context.read<TodoBloc>().add(DeleteTodo(todo.id));
                                              Navigator.pop(context);
                                            },
                                            style: TextButton.styleFrom(foregroundColor: widget.theme.colorScheme.error),
                                            child: Text('删除所有重复项'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  // 显示普通删除确认对话框
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        backgroundColor: widget.theme.colorScheme.surfaceVariant,
                                        title: Text(
                                          '删除任务',
                                          style: TextStyle(color: widget.theme.colorScheme.onSurface),
                                        ),
                                        content: Text(
                                          '确定要删除任务 "${todo.title}" 吗？',
                                          style: TextStyle(color: widget.theme.colorScheme.onSurface),
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
                                              context.read<TodoBloc>().add(DeleteTodo(todo.id));
                                              Navigator.pop(context);
                                            },
                                            style: TextButton.styleFrom(foregroundColor: widget.theme.colorScheme.error),
                                            child: Text('删除'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              },
                              backgroundColor: widget.theme.colorScheme.error,
                              foregroundColor: widget.theme.colorScheme.onError,
                              icon: Icons.delete,
                              label: '删除',
                            ),
                          ],
                        ),
                        // 主内容区域
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TodoDetailPage(todo: todo),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: todo.isCompleted,
                                    onChanged: (value) {
                                      context.read<TodoBloc>().add(
                                            ToggleTodoCompletion(todo.id),
                                          );
                                    },
                                    activeColor: widget.theme.colorScheme.primary,
                                    checkColor: widget.theme.colorScheme.onPrimary,
                                    side: BorderSide(
                                      color: widget.theme.colorScheme.outline,
                                      width: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Task Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          todo.title,
                                          style: TextStyle(
                                            color: todo.isCompleted
                                                ? widget.theme.colorScheme.onSurfaceVariant
                                                : widget.theme.colorScheme.onSurface,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: todo.isCompleted
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Task Meta
                                        Row(
                                          children: [
                                            // Priority
                                            PriorityHelper.buildBadge(todo.priority),
                                            // Tags
                                            if (todo.tags.isNotEmpty)
                                              ...[
                                                const SizedBox(width: 8),
                                                ...todo.tags.map((tag) => Padding(
                                                      padding: const EdgeInsets.only(right: 8),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: widget.theme.colorScheme.surface,
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(
                                                            color: widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.tag, 
                                                              size: 14, 
                                                              color: widget.theme.colorScheme.primary,
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              tag,
                                                              style: TextStyle(
                                                                color: widget.theme.colorScheme.onSurfaceVariant,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )),
                                              ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KanbanViewContent extends StatefulWidget {
  final List<KanbanColumnEntity> columns;
  final List<Todo> todos;
  final ThemeData theme;

  const _KanbanViewContent({
    required this.columns,
    required this.todos,
    required this.theme,
  });

  @override
  State<_KanbanViewContent> createState() => _KanbanViewContentState();
}

class _KanbanViewContentState extends State<_KanbanViewContent> {
  final ScrollController _scrollController = ScrollController();
  String? _draggingTodoId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Todo> _getTodosForColumn(String columnId) {
    final columnIds = widget.columns.map((c) => c.id).toSet();
    final defaultColumnId = columnIds.contains('todo') ? 'todo' : (widget.columns.isNotEmpty ? widget.columns.first.id : null);
    final result = widget.todos.where((todo) {
      final kid = todo.kanbanColumnId;
      if (kid == null || kid.isEmpty) {
        return columnId == defaultColumnId;
      }
      if (!columnIds.contains(kid)) {
        return columnId == defaultColumnId;
      }
      return kid == columnId;
    }).toList();
    print('[Kanban] 列$columnId: ${result.length}个待办 (总${widget.todos.length}个, 列IDs=$columnIds, defaultCol=$defaultColumnId)');
    return result;
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.columns.map((column) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildKanbanColumn(column),
            )),
            _buildAddColumnCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(KanbanColumnEntity column) {
    final columnTodos = _getTodosForColumn(column.id);
    final completedCount = columnTodos.where((t) => t.isCompleted).length;
    final progress = columnTodos.isEmpty ? 0.0 : completedCount / columnTodos.length;
    final columnColor = _parseColor(column.color);

    return SizedBox(
      width: 280,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          return true;
        },
        onAcceptWithDetails: (details) {
          context.read<TodoBloc>().add(MoveTodoToColumn(
            todoId: details.data,
            targetColumnId: column.id,
          ));
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              color: isHovering 
                ? widget.theme.colorScheme.surfaceVariant.withOpacity(0.5)
                : widget.theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: isHovering 
                ? Border.all(color: widget.theme.colorScheme.primary, width: 2)
                : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _KanbanColumnHeader(
                  column: column,
                  todosCount: columnTodos.length,
                  progress: progress,
                  columnColor: columnColor,
                  theme: widget.theme,
                  onRename: (newTitle) {
                    context.read<TodoBloc>().add(RenameKanbanColumn(
                      columnId: column.id,
                      newTitle: newTitle,
                    ));
                  },
                  onDelete: (deleteTodos) {
                    context.read<TodoBloc>().add(DeleteKanbanColumn(
                      columnId: column.id,
                      deleteTodos: deleteTodos,
                      moveToColumnId: deleteTodos ? null : 'todo',
                    ));
                  },
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height - 350,
                  ),
                  child: columnTodos.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Center(
                          child: Text('暂无任务', style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            fontSize: 14,
                          )),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: columnTodos.asMap().entries.map((entry) {
                            final index = entry.key;
                            final todo = entry.value;
                            return Padding(
                              padding: EdgeInsets.only(bottom: index < columnTodos.length - 1 ? 8 : 0),
                              child: _KanbanCard(
                                todo: todo,
                                theme: widget.theme,
                                isDragging: _draggingTodoId == todo.id,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: GestureDetector(
                    onTap: () => _showAddTodoToColumnDialog(column.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.theme.colorScheme.outline.withOpacity(0.2),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 18, color: widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text('添加任务', style: TextStyle(
                            fontSize: 13,
                            color: widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddColumnCard() {
    return SizedBox(
      width: 280,
      child: GestureDetector(
        onTap: () => _showAddColumnDialog(),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.theme.colorScheme.outline.withOpacity(0.3),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 32, color: widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text('添加新列', style: TextStyle(
                  color: widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  fontSize: 14,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTodoToColumnDialog(String columnId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('添加任务到列', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: widget.theme.colorScheme.onSurface,
              )),
            ),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: widget.theme.colorScheme.primary),
              title: const Text('创建新待办'),
              subtitle: const Text('创建一个新的待办事项并添加到此列'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTodoPage(kanbanColumnId: columnId),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.assignment, color: widget.theme.colorScheme.primary),
              title: const Text('从已有待办添加'),
              subtitle: const Text('选择一个已有的待办事项添加到此列'),
              onTap: () {
                Navigator.pop(ctx);
                _showSelectTodoForColumn(columnId);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSelectTodoForColumn(String columnId) {
    final todoState = context.read<TodoBloc>().state;
    final allTodos = todoState is TodoLoaded ? todoState.todos : <Todo>[];
    final columnTodoIds = _getTodosForColumn(columnId).map((t) => t.id).toSet();
    final availableTodos = allTodos.where((t) => !columnTodoIds.contains(t.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择待办事项', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: widget.theme.colorScheme.onSurface,
              )),
            ),
            Expanded(
              child: availableTodos.isEmpty
                ? Center(
                    child: Text('没有可添加的待办事项', style: TextStyle(
                      color: widget.theme.colorScheme.onSurfaceVariant,
                    )),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: availableTodos.length,
                    itemBuilder: (ctx, index) {
                      final todo = availableTodos[index];
                      return ListTile(
                        leading: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: PriorityHelper.getColor(todo.priority),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(todo.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: todo.date != null
                          ? Text('${todo.date!.year}/${todo.date!.month}/${todo.date!.day}',
                              style: TextStyle(fontSize: 12, color: widget.theme.colorScheme.onSurfaceVariant))
                          : null,
                        trailing: todo.kanbanColumnId != null && todo.kanbanColumnId!.isNotEmpty
                          ? Chip(
                              label: Text(_getColumnTitle(todo.kanbanColumnId!), style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                        onTap: () {
                          context.read<TodoBloc>().add(MoveTodoToColumn(
                            todoId: todo.id,
                            targetColumnId: columnId,
                          ));
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _getColumnTitle(String columnId) {
    final column = widget.columns.where((c) => c.id == columnId).firstOrNull;
    return column?.title ?? columnId;
  }

  void _showAddColumnDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加新列'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入列名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<TodoBloc>().add(AddKanbanColumn(
                  title: controller.text.trim(),
                  color: '#6750A4',
                ));
                Navigator.pop(ctx);
                _scrollToEnd();
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return widget.theme.colorScheme.primary;
    }
  }
}

class _KanbanColumnHeader extends StatefulWidget {
  final KanbanColumnEntity column;
  final int todosCount;
  final double progress;
  final Color columnColor;
  final ThemeData theme;
  final Function(String) onRename;
  final Function(bool) onDelete;

  const _KanbanColumnHeader({
    required this.column,
    required this.todosCount,
    required this.progress,
    required this.columnColor,
    required this.theme,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_KanbanColumnHeader> createState() => _KanbanColumnHeaderState();
}

class _KanbanColumnHeaderState extends State<_KanbanColumnHeader> {
  bool _isEditing = false;
  late TextEditingController _editController;
  late FocusNode _editFocusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.column.title);
    _editFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.column.title;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _editFocusNode.requestFocus();
    });
  }

  void _saveEdit() {
    final newTitle = _editController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.column.title) {
      widget.onRename(newTitle);
    }
    setState(() { _isEditing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: widget.columnColor, borderRadius: BorderRadius.circular(6)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _isEditing
                  ? TextField(
                      controller: _editController,
                      focusNode: _editFocusNode,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => _saveEdit(),
                    )
                  : GestureDetector(
                      onDoubleTap: _startEditing,
                      child: Text(widget.column.title, style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: widget.theme.colorScheme.onSurface,
                      )),
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.surface, borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${widget.todosCount}', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: widget.theme.colorScheme.onSurfaceVariant,
                )),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: widget.theme.colorScheme.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'rename') _startEditing();
                  if (value == 'delete') _showDeleteDialog(context);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  const PopupMenuItem(value: 'delete', child: Text('删除列')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.progress,
              backgroundColor: widget.theme.colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(widget.columnColor),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除列'),
        content: Text('确定要删除「${widget.column.title}」列吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { widget.onDelete(true); Navigator.pop(ctx); },
            child: const Text('删除列和任务', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () { widget.onDelete(false); Navigator.pop(ctx); },
            child: const Text('转移到待办列'),
          ),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final Todo todo;
  final ThemeData theme;
  final bool isDragging;

  const _KanbanCard({
    required this.todo,
    required this.theme,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: todo.id,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 256,
          child: _buildCardContent(context),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCard(context),
      ),
      onDragStarted: () {
        final state = context.findAncestorStateOfType<_KanbanViewContentState>();
        state?.setState(() { state._draggingTodoId = todo.id; });
      },
      onDragEnd: (details) {
        final state = context.findAncestorStateOfType<_KanbanViewContentState>();
        state?.setState(() { state._draggingTodoId = null; });
      },
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => TodoDetailPage(todo: todo),
        ));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: todo.isCompleted 
            ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
            : theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildCardContent(context),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final priorityColor = PriorityHelper.getColor(todo.priority);
    final isOverdue = todo.date != null && todo.date!.isBefore(DateTime.now()) && !todo.isCompleted;
    final completedSubtasks = todo.subtasks.where((s) => s.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  PriorityHelper.getLabel(todo.priority),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: priorityColor),
                ),
              ),
              const Spacer(),
              if (todo.date != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 13, color: isOverdue ? Colors.red : theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      '${todo.date!.month}/${todo.date!.day}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue ? Colors.red : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            todo.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: todo.isCompleted 
                ? theme.colorScheme.onSurfaceVariant 
                : theme.colorScheme.onSurface,
              decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          if (todo.subtasks.isNotEmpty || true)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  if (todo.subtasks.isNotEmpty) ...[
                    Icon(Icons.checklist, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '$completedSubtasks/${todo.subtasks.length}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      context.read<TodoBloc>().add(ToggleTodoCompletion(todo.id));
                    },
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: todo.isCompleted ? theme.colorScheme.primary : Colors.transparent,
                        border: todo.isCompleted 
                          ? null 
                          : Border.all(color: theme.colorScheme.onSurfaceVariant, width: 1.5),
                      ),
                      child: todo.isCompleted 
                        ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary)
                        : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

