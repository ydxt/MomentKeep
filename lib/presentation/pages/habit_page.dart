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
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/security.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/presentation/components/habit_editor_widget.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/presentation/pages/add_habit_page.dart';
import 'package:moment_keep/presentation/pages/habit_detail_dialog.dart';

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
    // 只在初始化时加载数据，避免重复加载
    context.read<HabitBloc>().add(LoadHabits());
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
class HabitView extends ConsumerWidget {
  /// 构造函数
  const HabitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

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
                return BlocBuilder<HabitBloc, HabitState>(
                  buildWhen: (previous, current) {
                    // 只有当习惯列表实际变化时才重建
                    if (previous is HabitLoaded && current is HabitLoaded) {
                      return previous.habits != current.habits;
                    }
                    // 状态类型变化时重建
                    return previous.runtimeType != current.runtimeType;
                  },
                  builder: (context, habitState) {
                    List<Habit> habits = [];
                    if (habitState is HabitLoaded) {
                      habits = habitState.habits;
                    }
                    return HabitContent(
                        habits: habits, 
                        categories: categoryState.categories,
                        user: user,
                        theme: theme);
                  },
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

  /// 显示添加习惯对话框
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

  /// 构造函数
  const HabitContent({
    super.key, 
    required this.habits, 
    required this.categories,
    required this.user,
    required this.theme,
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // 多选模式工具栏
          if (_isMultiSelectMode) SliverPersistentHeader(
            pinned: true,
            delegate: _MultiSelectToolbarDelegate(
              selectedCount: _selectedHabits.length,
              onSelectAll: _toggleSelectAll,
              onDelete: _deleteSelectedHabits,
              onCancel: _toggleMultiSelectMode,
            ),
          ),
          _buildHeader(),
          _buildGreeting(),
          _buildDateSelector(),
          _buildCategoriesHeader(),
          _buildCategoryTags(context),
          _buildHabitList(context),
        ],
      ),
    );
  }

  /// 构建顶部Header
  Widget _buildHeader() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(user: widget.user, theme: widget.theme),
    );
  }

  /// 构建问候语
  Widget _buildGreeting() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}, ${widget.user?.username ?? '用户'}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: widget.theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '你已经连续打卡5天了！继续保持。',
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
  
  /// 根据时间获取问候语
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return '凌晨好';
    } else if (hour < 12) {
      return '早上好';
    } else if (hour < 14) {
      return '中午好';
    } else if (hour < 18) {
      return '下午好';
    } else {
      return '晚上好';
    }
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
      backgroundColor = widget.theme.colorScheme.primary; // 选中日期使用主色调
    } else if (isToday) {
      backgroundColor = widget.theme.colorScheme.primary; // 今天使用主色调
    } else {
      backgroundColor = widget.theme.cardTheme.color ?? widget.theme.colorScheme.surface; // 其他天使用卡片背景色
    }
    
    // 确定文字颜色
    Color textColor = isSelected || isToday ? widget.theme.colorScheme.onPrimary : widget.theme.colorScheme.onSurface;
    Color dayNameColor = isSelected || isToday ? widget.theme.colorScheme.onPrimary : widget.theme.colorScheme.onSurfaceVariant;
    
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
                color: isSelected || isToday
                    ? Colors.transparent
                    : widget.theme.colorScheme.outline,
                width: 1,
              ),
              boxShadow: (isSelected || isToday)
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
          if (isChecked && !(isSelected || isToday))
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
  // 当前选中的日期
  DateTime? _selectedDate;

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
      // 构建带有拖动功能的芯片
      Widget draggableChip = LongPressDraggable(
        data: index,
        delay: const Duration(milliseconds: 0), // 立即开始拖动，因为已经显示了删除按钮
        feedback: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF13ec5b) : const Color.fromARGB(38, 255, 255, 255),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF13ec5b).withOpacity(0.3),
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
              color: isActive ? const Color(0xFF102216) : Colors.white,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        childWhenDragging: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(38, 255, 255, 255).withOpacity(0.5),
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
              top: -4, // 调整位置，确保完全显示
              right: -4, // 调整位置，确保完全显示
              child: GestureDetector(
                onTap: () {
                  // 调用CategoryBloc删除分类
                  context.read<CategoryBloc>().add(DeleteCategory(category.id));
                  // 如果删除的是当前选中的分类，切换到"全部"
                  if (_selectedCategoryId == category.name) {
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
  
  /// 构建习惯列表
  Widget _buildHabitList(BuildContext context) {
    // 根据选中的分类过滤习惯
    final filteredHabits = _selectedCategoryId == null
        ? widget.habits
        : widget.habits.where((habit) => habit.categoryId == _selectedCategoryId).toList();

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
    
    // 构建习惯列表
    final listDelegate = SliverChildBuilderDelegate(
      (context, index) {
        final habit = filteredHabits[index];
        
        // 检查习惯是否被选中
        final isSelected = _selectedHabits.contains(habit.id);
        
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
                if (_isMultiSelectMode) {
                  // 多选模式下，点击切换选择状态
                  _toggleEntrySelection(habit.id);
                } else {
                  // 非多选模式下，进入详情页
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HabitDetailDialog(
                        habit: habit,
                        categories: widget.categories,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () {
                // 长按进入多选模式
                if (!_isMultiSelectMode) {
                  _toggleMultiSelectMode();
                  _toggleEntrySelection(habit.id);
                }
              },
              child: Stack(
                children: [
                  HabitItem(
                    habit: habit,
                    selectedDate: _selectedDate,
                  ),
                  // 多选模式下，显示选择状态
                  if (_isMultiSelectMode) Positioned(
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
                  if (_isMultiSelectMode) Positioned.fill(
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

/// Header代理类
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  /// 用户信息
  final UserAuth? user;
  
  /// 主题数据
  final ThemeData theme;
  
  /// 构造函数
  const _HeaderDelegate({this.user, required this.theme});
  
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
      ),
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧：日期和标题
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getCurrentDate(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '我的习惯',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                )
              ),
            ],
          ),
          // 右侧：用户头像（垂直居中，占据整个右侧空间）
          _buildUserAvatar(),
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
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Center(
        child: user?.avatar != null && (user!.avatar?.isNotEmpty ?? false)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(user!.avatar!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(
                Icons.person,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  @override
  double get maxExtent => 77.0;

  @override
  double get minExtent => 77.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
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
  /// 习惯
  final Habit habit;
  
  /// 选中的日期
  final DateTime? selectedDate;

  /// 构造函数
  const HabitItem({super.key, required this.habit, this.selectedDate});

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
    
    // 检查该日期是否已经打卡
    final isChecked = habit.history.contains(checkDateString);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
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
                  color: _getIconBackgroundColor(habit),
                ),
                child: Center(
                  child: Icon(
                    _getIcon(habit),
                    color: _getIconColor(habit),
                    size: 24,
                  ),
                ),
              ),
              // 习惯信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
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
          _buildActionButton(habit, isChecked, context, isToday),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton(
      Habit habit, bool isChecked, BuildContext context, bool isToday) {
    final theme = Theme.of(context);
    // 处理特殊习惯名称的情况
    if (habit.name == 'Read Book' || habit.name == 'Morning Jog' || habit.name == 'Meditate') {
      // 对于这些特殊习惯，使用默认的打卡按钮逻辑
      return ElevatedButton(
        onPressed: () {
          // 只对当天的习惯显示打卡对话框，无论是否已经打卡
          // 对于非当天的习惯，不允许打卡或修改操作
          if (isToday) {
            _showCheckInDialog(context, habit);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          isChecked ? '已完成' : (isToday ? '打卡' : '补卡'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    // 默认打卡按钮
    return ElevatedButton(
      onPressed: () {
        // 只对当天的习惯显示打卡对话框，无论是否已经打卡
        // 对于非当天的习惯，不允许打卡或修改操作
        if (isToday) {
          _showCheckInDialog(context, habit);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      child: Text(
        isChecked ? '已完成' : (isToday ? '打卡' : '补卡'),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 获取图标
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

  /// 获取图标背景色
  Color _getIconBackgroundColor(Habit habit) {
    switch (habit.icon) {
      case 'water_drop':
        return const Color.fromARGB(48, 59, 130, 246); // 蓝色
      case 'menu_book':
        return const Color.fromARGB(48, 139, 92, 246); // 紫色
      case 'directions_run':
        return const Color.fromARGB(48, 249, 115, 22); // 橙色
      case 'self_improvement':
        return const Color.fromARGB(48, 236, 72, 153); // 粉色
      case 'mic':
        return const Color.fromARGB(48, 16, 185, 129); // 绿色
      default:
        return const Color.fromARGB(48, 59, 130, 246);
    }
  }

  /// 获取图标颜色
  Color _getIconColor(Habit habit) {
    switch (habit.icon) {
      case 'water_drop':
        return const Color(0xFF3b82f6); // 蓝色
      case 'menu_book':
        return const Color(0xFF8b5cf6); // 紫色
      case 'directions_run':
        return const Color(0xFFf97316); // 橙色
      case 'self_improvement':
        return const Color(0xFFec4899); // 粉色
      case 'mic':
        return const Color(0xFF10b981); // 绿色
      default:
        return const Color(0xFF3b82f6);
    }
  }

  /// 获取状态文本
  String _getStatusText(Habit habit, String checkDateString, bool isToday) {
    // 检查选中的日期是否已经打卡
    final isChecked = habit.history.contains(checkDateString);
    
    if (isChecked) {
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
  void _showCheckInDialog(BuildContext context, Habit habit) {
    // 计算默认得分：最高得分的80%，向上取整
    final defaultScore = (habit.fullStars * 0.8).ceil();
    
    showDialog(
      context: context,
      builder: (context) {
        return _CheckInDialog(
          habit: habit,
          defaultScore: defaultScore,
        );
      },
    );
  }
}

/// 打卡对话框组件
class _CheckInDialog extends StatefulWidget {
  final Habit habit;
  final int defaultScore;
  
  const _CheckInDialog({
    required this.habit,
    required this.defaultScore,
  });
  
  @override
  State<_CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<_CheckInDialog> {
  /// 得分控制器
  late TextEditingController _scoreController;
  
  /// 评论内容块列表
  late List<ContentBlock> _commentContent;
  
  @override
  void initState() {
    super.initState();
    
    // 检查当天是否已经有打卡记录
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    
    // 查找当天的打卡记录
    final todayRecord = widget.habit.checkInRecords.firstWhere(
      (record) {
        final recordDate = record.timestamp.toIso8601String().split('T')[0];
        return recordDate == today;
      },
      orElse: () => CheckInRecord(
        id: '',
        habitId: widget.habit.id,
        score: widget.defaultScore,
        comment: [],
        timestamp: now,
      ),
    );
    
    // 初始化得分控制器
    _scoreController = TextEditingController(
      text: todayRecord.score.toString(),
    );
    
    // 初始化评论内容
    _commentContent = todayRecord.comment;
  }
  
  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }
  
  /// 保存打卡记录
  void _saveCheckIn() {
    // 解析得分
    final int score = int.tryParse(_scoreController.text) ?? 0;
    
    // 检查得分是否在有效范围内
    if (score < 1 || score > widget.habit.fullStars) {
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('得分必须在1到${widget.habit.fullStars}之间'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 记录打卡完成事件
    context.read<HabitBloc>().add(RecordHabitCompletion(
          widget.habit.id,
          score,
          _commentContent,
        ));
    
    // 关闭对话框
    Navigator.pop(context);
    
    // 显示打卡成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.habit.name} 打卡成功！')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('打卡: ${widget.habit.name}'),
      backgroundColor: theme.colorScheme.surface,
      titleTextStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 得分输入
            Text(
              '今天的得分',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scoreController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '1-${widget.habit.fullStars}',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '/${widget.habit.fullStars}',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 评论输入
            Text(
              '写下你的感受',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: RichTextEditor(
                  initialContent: _commentContent,
                  onContentChanged: (content) {
                    setState(() {
                      _commentContent = content;
                    });
                  },
                  readOnly: false,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: _saveCheckIn,
          child: Text('保存', style: TextStyle(color: theme.colorScheme.primary)),
        ),
      ],
    );
  }
}
