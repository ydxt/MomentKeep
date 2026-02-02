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
import 'package:moment_keep/domain/entities/security.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/pages/add_todo_page.dart';
import 'package:moment_keep/presentation/pages/todo_detail_page.dart';
import 'package:moment_keep/presentation/pages/new_settings_page.dart';

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
  
  // 本地分类列表，从CategoryBloc获取后缓存
  List<Category> _categories = [];
  
  /// 是否处于多选模式
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
                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          MaterialPageRoute(builder: (context) => const NewSettingsPage()),
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

  // 控制是否显示删除按钮
  bool _showDeleteButtons = false;
  // 控制长按动画状态
  bool _isLongPressing = false;
  // 控制是否正在闪烁
  bool _isBlinking = false;

  /// 构建分类标题
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
      // 构建带有拖动功能的芯片
      Widget draggableChip = LongPressDraggable(
        data: index,
        delay: const Duration(milliseconds: 0), // 立即开始拖动，因为已经显示了删除按钮
        feedback: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          margin: const EdgeInsets.only(right: 12),
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
            // 提取chipContent内部的内容，去掉外层的GestureDetector和额外的Padding
            // 因为我们已经在外部处理了点击和删除逻辑
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

  /// 构建任务列表
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

        // 先根据搜索关键字过滤
        List<Todo> searchFilteredTodos = todos;
        if (_searchKeyword.isNotEmpty) {
          searchFilteredTodos = todos.where((todo) => 
            todo.title.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            todo.content.any((block) => 
              block.data.toLowerCase().contains(_searchKeyword.toLowerCase())
            )
          ).toList();
        }
        
        // 再根据筛选条件过滤
        List<Todo> filteredTodos = [];
        if (_selectedFilter == '全部') {
          filteredTodos = searchFilteredTodos;
        } else {
          filteredTodos = searchFilteredTodos.where((todo) => 
            todo.tags.contains(_selectedFilter)
          ).toList();
        }

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
                  color: todo.isCompleted ? Colors.transparent : theme.colorScheme.primary,
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
                          Text(
                            todo.title,
                            style: TextStyle(
                              color: todo.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                            ),
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
                                          todo.categoryId!,
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

  /// 构建优先级徽章
  Widget _buildPriorityBadge(TodoPriority priority) {
    Color color;
    String text;

    switch (priority) {
      case TodoPriority.high:
        color = theme.colorScheme.error;
        text = '高';
        break;
      case TodoPriority.medium:
        color = theme.colorScheme.secondary;
        text = '中';
        break;
      case TodoPriority.low:
        color = theme.colorScheme.tertiary;
        text = '低';
        break;
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
  
  /// 构建看板视图
  Widget _buildKanbanView() {
    return BlocBuilder<TodoBloc, TodoState>(
      buildWhen: (previous, current) {
        if (previous is TodoLoaded && current is TodoLoaded) {
          return previous.todos != current.todos;
        }
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, todoState) {
        if (todoState is TodoLoaded) {
          // 过滤任务
          List<Todo> searchFilteredTodos = todoState.todos;
          if (_searchKeyword.isNotEmpty) {
            searchFilteredTodos = todoState.todos.where((todo) => 
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
            filteredTodos = searchFilteredTodos.where((todo) => 
              todo.tags.contains(_selectedFilter)
            ).toList();
          }
          
          // 分组任务
          final todoList = filteredTodos.where((todo) => !todo.isCompleted).toList();
          final inProgressList = filteredTodos.where((todo) => todo.isCompleted).toList();
          
          return SliverToBoxAdapter(
            child: _KanbanViewContent(
              todoList: todoList,
              inProgressList: inProgressList,
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
          : allTodos.where((todo) => 
              todo.tags.contains(_selectedFilter)).toList();
              
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
  /// 当前显示的月份
  DateTime _currentMonth = DateTime.now();
  
  /// 今天的日期
  final DateTime _today = DateTime.now();
  
  /// 当前选中的日期
  DateTime? _selectedDate;
  
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
          // 月份导航
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
          const SizedBox(height: 16),
          
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
          
          // 日历网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.7,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
            ),
            itemCount: 7 * rows,
            itemBuilder: (context, index) {
              final dayIndex = index - (firstDayOfMonth - 1);
              final day = dayIndex + 1;
              
              if (dayIndex < 0 || day > daysInMonth) {
                return Container(); // 空白单元格
              }
              
              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                day,
              );
              
              final isToday = date.year == _today.year &&
                            date.month == _today.month &&
                            date.day == _today.day;
              
              final isSelected = _selectedDate != null &&
                                _selectedDate!.year == date.year &&
                                _selectedDate!.month == date.month &&
                                _selectedDate!.day == date.day;
              
              // 获取当天的任务
              final dayTasks = widget.todos.where((todo) {
                return _isTaskOnDay(todo, date);
              }).toList();
              
              // 任务排序：全天/跨天任务在上面，其他按开始时间排序
              List<Todo> sortedTasks = List.from(dayTasks);
              sortedTasks.sort((a, b) {
                // 确定是否为全天/跨天任务
                bool aIsAllDay = a.startDate != null && a.date != null && 
                    (a.startDate!.day != a.date!.day || a.startDate!.month != a.date!.month || a.startDate!.year != a.date!.year);
                bool bIsAllDay = b.startDate != null && b.date != null && 
                    (b.startDate!.day != b.date!.day || b.startDate!.month != b.date!.month || b.startDate!.year != b.date!.year);
                
                // 全天/跨天任务优先
                if (aIsAllDay && !bIsAllDay) return -1;
                if (!aIsAllDay && bIsAllDay) return 1;
                
                // 按开始时间排序
                DateTime? aStartTime = a.startDate ?? a.date;
                DateTime? bStartTime = b.startDate ?? b.date;
                
                if (aStartTime == null && bStartTime == null) return 0;
                if (aStartTime == null) return 1;
                if (bStartTime == null) return -1;
                
                return aStartTime.compareTo(bStartTime);
              });
              
              final hasTasks = dayTasks.isNotEmpty;
              
              // 获取当前日期的星期几（0=周一，6=周日）
              final weekday = date.weekday - 1;
              final currentDateOnly = DateTime(date.year, date.month, date.day);
              
              // 检查是否需要显示跨天任务的连接效果
              List<Widget> buildTaskWidgets() {
                List<Widget> widgets = [];
                for (int i = 0; i < sortedTasks.length && i < 3; i++) {
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
                  
                  widgets.add(
                    Container(
                      margin: isMultiDay 
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(vertical: 2),
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
                              top: BorderSide(
                                color: widget.theme.colorScheme.primary,
                                width: 3,
                              ),
                              bottom: BorderSide(
                                color: widget.theme.colorScheme.primary,
                                width: 3,
                              ),
                              left: isFirstDay ? BorderSide(
                                color: widget.theme.colorScheme.primary,
                                width: 3,
                              ) : BorderSide.none,
                              right: isLastDay ? BorderSide(
                                color: widget.theme.colorScheme.primary,
                                width: 3,
                              ) : BorderSide.none,
                            ) : Border.all(
                              color: widget.theme.colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 时间显示
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
                              // 任务标题
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
                return widgets;
              }
              
              return GestureDetector(
                onTap: () => _selectDate(day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.theme.colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: widget.theme.colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 日期部分
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isToday || hasTasks
                                  ? widget.theme.colorScheme.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                day.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: (isToday || hasTasks)
                                      ? widget.theme.colorScheme.onPrimary
                                      : widget.theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 任务列表
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...buildTaskWidgets(),
                              if (sortedTasks.length > 3)
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
                                                
                                                String durationText = '';
                                                if (todo.startDate != null && todo.date != null) {
                                                  final duration = todo.date!.difference(todo.startDate!);
                                                  if (duration.inDays > 0) {
                                                    durationText = '${duration.inDays}天';
                                                  } else if (duration.inHours > 0) {
                                                    durationText = '${duration.inHours}小时';
                                                  } else if (duration.inMinutes > 0) {
                                                    durationText = '${duration.inMinutes}分钟';
                                                  }
                                                }
                                                
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
                                                
                                                String priorityText = '';
                                                Color priorityColor = widget.theme.colorScheme.onBackground;
                                                switch (todo.priority) {
                                                  case TodoPriority.high:
                                                    priorityText = '高';
                                                    priorityColor = widget.theme.colorScheme.error;
                                                    break;
                                                  case TodoPriority.medium:
                                                    priorityText = '中';
                                                    priorityColor = widget.theme.colorScheme.secondary;
                                                    break;
                                                  case TodoPriority.low:
                                                    priorityText = '低';
                                                    priorityColor = widget.theme.colorScheme.tertiary;
                                                    break;
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
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.05),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                                          const SizedBox(height: 4),
                                                          if (durationText.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(left: 52),
                                                              child: Text(
                                                                durationText,
                                                                style: TextStyle(
                                                                  color: widget.theme.colorScheme.onSurfaceVariant,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                          const SizedBox(height: 4),
                                                          Padding(
                                                            padding: const EdgeInsets.only(left: 52),
                                                            child: Row(
                                                              children: [
                                                                Container(
                                                                  width: 6,
                                                                  height: 6,
                                                                  decoration: BoxDecoration(
                                                                    color: priorityColor,
                                                                    borderRadius: BorderRadius.circular(3),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  priorityText,
                                                                  style: TextStyle(
                                                                    color: priorityColor,
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
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
                                    '+${sortedTasks.length - 3}个任务',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: widget.theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          
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
                                            _buildPriorityBadge(todo.priority),
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
  
  /// 构建优先级徽章
  Widget _buildPriorityBadge(TodoPriority priority) {
    Color color;
    String text;
    
    switch (priority) {
      case TodoPriority.high:
        color = widget.theme.colorScheme.error;
        text = '高';
        break;
      case TodoPriority.medium:
        color = widget.theme.colorScheme.secondary;
        text = '中';
        break;
      case TodoPriority.low:
        color = widget.theme.colorScheme.tertiary;
        text = '低';
        break;
    }
    
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 看板列数据类
class KanbanColumn {
  final String id;
  final String title;
  final Color color;
  final List<Todo> todos;
  
  const KanbanColumn({
    required this.id,
    required this.title,
    required this.color,
    required this.todos,
  });
}

/// 看板视图内容组件
class _KanbanViewContent extends StatelessWidget {
  /// 构造函数
  const _KanbanViewContent({
    required this.todoList,
    required this.inProgressList,
    required this.theme,
  });
  
  /// 待办列表
  final List<Todo> todoList;
  
  /// 进行中列表
  final List<Todo> inProgressList;
  
  /// 主题
  final ThemeData theme;
  
  @override
  Widget build(BuildContext context) {
    // 创建看板列
    final columns = [
      KanbanColumn(
        id: '1',
        title: '待办',
        color: theme.colorScheme.primary,
        todos: todoList,
      ),
      KanbanColumn(
        id: '2',
        title: '进行中',
        color: theme.colorScheme.secondary,
        todos: inProgressList,
      ),
      KanbanColumn(
        id: '3',
        title: '已完成',
        color: theme.colorScheme.tertiary,
        todos: [],
      ),
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '看板视图',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // 看板列
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: columns.map((column) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildKanbanColumn(context, column),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建看板列
  Widget _buildKanbanColumn(BuildContext context, KanbanColumn column) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: column.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      column.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    column.todos.length.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tasks
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: column.todos.length,
                itemBuilder: (context, index) {
                  final todo = column.todos[index];
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                          color: theme.cardTheme.color,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todo.title,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Task Meta
                              Row(
                                children: [
                                  // Priority
                                  _buildPriorityBadge(todo.priority),
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建优先级徽章
  Widget _buildPriorityBadge(TodoPriority priority) {
    Color color;
    String text;
    
    switch (priority) {
      case TodoPriority.high:
        color = theme.colorScheme.error;
        text = '高';
        break;
      case TodoPriority.medium:
        color = theme.colorScheme.secondary;
        text = '中';
        break;
      case TodoPriority.low:
        color = theme.colorScheme.tertiary;
        text = '低';
        break;
    }
    
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}