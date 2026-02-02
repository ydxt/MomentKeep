import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' as foundation show kIsWeb, Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moment_keep/core/utils/image_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/diary_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/category.dart' as AppCategory;
import 'package:moment_keep/presentation/components/minimal_journal_editor.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';


/// 日记页面
class DiaryPage extends StatefulWidget {
  /// 构造函数
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  @override
  void initState() {
    super.initState();
    // 只在初始化时加载数据，避免重复加载
    context.read<DiaryBloc>().add(LoadDiaryEntries());
    context
        .read<CategoryBloc>()
        .add(const LoadCategories(type: AppCategory.CategoryType.journal));
  }

  @override
  Widget build(BuildContext context) {
    return const DiaryView();
  }
}

/// 日记视图
class DiaryView extends ConsumerStatefulWidget {
  /// 构造函数
  const DiaryView({super.key});

  @override
  DiaryViewState createState() => DiaryViewState();
}

class DiaryViewState extends ConsumerState<DiaryView> {
  /// 当前日期视图类型
  DateViewType currentViewType = DateViewType.all;
  
  /// 日期范围的开始日期
  DateTime? startDate;
  
  /// 日期范围的结束日期
  DateTime? endDate;
  
  // 主题变量，在build方法中初始化
  late ThemeData theme;
  
  @override
  Widget build(BuildContext context) {
    // 从ref获取主题并赋值给类成员变量
    theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // 移除传统AppBar，使用CustomScrollView+SliverPersistentHeader实现
      body: BlocBuilder<CategoryBloc, CategoryState>(
        buildWhen: (previous, current) {
          if (previous is CategoryLoaded && current is CategoryLoaded) {
            return previous.categories != current.categories;
          }
          return previous.runtimeType != current.runtimeType;
        },
        builder: (context, categoryState) {
          if (categoryState is CategoryLoaded) {
            return BlocBuilder<DiaryBloc, DiaryState>(
              buildWhen: (previous, current) {
                if (previous is DiaryLoaded && current is DiaryLoaded) {
                  return previous.entries != current.entries;
                }
                return previous.runtimeType != current.runtimeType;
              },
              builder: (context, diaryState) {
                List<Journal> entries = [];
                if (diaryState is DiaryLoaded) {
                  // 按日期倒序排列日记
                  entries = List.from(diaryState.entries)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                }
                return DiaryContent(
                      entries: entries,
                      categories: categoryState.categories,
                      theme: theme,
                      startDate: startDate,
                      endDate: endDate,
                      onDateFilterPressed: () => _showDateSelectorDialog(context),
                    );
              },
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      // 在所有平台上显示浮动操作按钮，类似习惯页
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showAddDiaryDialog(context);
          },
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 8,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 28),
        ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// 获取当前星期几
  String _getCurrentWeekday() {
    final now = DateTime.now();
    final weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[now.weekday - 1];
  }

  /// 获取当前日期
  String _getCurrentDate() {
    final now = DateTime.now();
    final months = ['一月', '二月', '三月', '四月', '五月', '六月', 
                  '七月', '八月', '九月', '十月', '十一月', '十二月'];
    return '${months[now.month - 1]}${now.day}日';
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15231B).withAlpha(90),
        border: Border(
          top: BorderSide(
            color: Colors.white.withAlpha(5),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF13ec5b),
        unselectedItemColor: Colors.grey,
        currentIndex: 2, // 日记页面是第三个选项
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: '待办',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.autorenew),
            label: '习惯',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: '日记',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            label: '专注',
          ),
        ],
        onTap: (index) {
          // 处理导航栏点击事件
          switch (index) {
            case 0: // 待办
              Navigator.pushNamed(context, '/todo');
              break;
            case 1: // 习惯
              Navigator.pushNamed(context, '/habit');
              break;
            case 2: // 日记
              // 已经在日记页面，不需要导航
              break;
            case 3: // 专注
              Navigator.pushNamed(context, '/pomodoro');
              break;
          }
        },
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),
    );
  }
  
  /// 显示日期选择器对话框
  void _showDateSelectorDialog(BuildContext context) {
    // 在对话框外部保存临时日期，避免上下文问题
    DateTime? tempStartDate = startDate;
    DateTime? tempEndDate = endDate;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        // 使用ValueNotifier来管理日期状态，确保UI能够正确更新
        final startDateNotifier = ValueNotifier<DateTime?>(tempStartDate);
        final endDateNotifier = ValueNotifier<DateTime?>(tempEndDate);
        
        return Dialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  '选择日期范围',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 开始日期选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '开始日期',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: startDateNotifier,
                      builder: (context, value, child) {
                        return GestureDetector(
                          onTap: () {
                            showDatePicker(
                              context: dialogContext,
                              initialDate: value ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: theme.copyWith(
                                    colorScheme: theme.colorScheme,
                                  ),
                                  child: child!,
                                );
                              },
                            ).then((pickedDate) {
                              if (pickedDate != null) {
                                startDateNotifier.value = pickedDate;
                                tempStartDate = pickedDate;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outline),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  value != null
                                      ? '${value.year}年${value.month}月${value.day}日'
                                      : '选择开始日期',
                                  style: TextStyle(
                                    color: value != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 16,
                                  ),
                                ),
                                Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 结束日期选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '结束日期',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: endDateNotifier,
                      builder: (context, value, child) {
                        return GestureDetector(
                          onTap: () {
                            showDatePicker(
                              context: dialogContext,
                              initialDate: value ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: theme.copyWith(
                                    colorScheme: theme.colorScheme,
                                  ),
                                  child: child!,
                                );
                              },
                            ).then((pickedDate) {
                              if (pickedDate != null) {
                                endDateNotifier.value = pickedDate;
                                tempEndDate = pickedDate;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outline),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  value != null
                                      ? '${value.year}年${value.month}月${value.day}日'
                                      : '选择结束日期',
                                  style: TextStyle(
                                    color: value != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 16,
                                  ),
                                ),
                                Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 按钮组
                Row(
                  children: [
                    // 重置按钮
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          startDateNotifier.value = null;
                          endDateNotifier.value = null;
                          tempStartDate = null;
                          tempEndDate = null;
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(color: theme.colorScheme.outline),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          '重置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 确认按钮
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // 更新页面状态
                          setState(() {
                            startDate = tempStartDate;
                            endDate = tempEndDate;
                          });
                          // 关闭对话框
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          '确定',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  

  
  /// 判断是否同一天
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
  
  /// 显示日期选择器
  void _showDatePicker(
    BuildContext context,
    DateTime initialDate,
    void Function(DateTime) onDateSelected,
  ) {
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme,
          ),
          child: child!,
        );
      },
    ).then((pickedDate) {
      if (pickedDate != null) {
        onDateSelected(pickedDate);
      }
    });
  }


  

  
  /// 显示添加日记编辑器
  void _showAddDiaryDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocBuilder<CategoryBloc, CategoryState>(
          builder: (context, categoryState) {
            if (categoryState is CategoryLoaded) {
              final categories = categoryState.categories;

              // 如果没有分类，先提示用户添加分类
              if (categories.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('添加日记')),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('请先添加分类'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddCategoryDialog(context);
                          },
                          child: const Text('添加分类'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 默认选择第一个分类
              final defaultCategory = categories.first;

              return MinimalJournalEditor(
                category: defaultCategory,
                onSave: (newJournal) {
                  // 添加日记
                  context.read<DiaryBloc>().add(AddDiaryEntry(newJournal));
                  Navigator.pop(context);
                },
                onCancel: () {
                  Navigator.pop(context);
                },
              );
            }
            return Scaffold(
              appBar: AppBar(title: const Text('添加日记')),
              body: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  /// 显示添加分类对话框
  void _showAddCategoryDialog(BuildContext context) {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    String icon = 'note';
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
                    {'value': 'note', 'icon': Icons.note},
                    {'value': 'book', 'icon': Icons.book},
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
                  final newCategory = AppCategory.Category(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: AppCategory.CategoryType.journal,
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
}

/// 日期视图类型 - 简化为单一类型，用于日期范围筛选
enum DateViewType {
  all,
}

/// 日记内容组件
class DiaryContent extends StatefulWidget {
  /// 日记列表
  final List<Journal> entries;

  /// 分类列表
  final List<AppCategory.Category> categories;

  /// 主题
  final ThemeData theme;
  
  /// 开始日期
  final DateTime? startDate;
  
  /// 结束日期
  final DateTime? endDate;
  
  /// 日期筛选按钮点击回调
  final VoidCallback onDateFilterPressed;

  /// 构造函数
  const DiaryContent(
      {super.key, 
      required this.entries, 
      required this.categories, 
      required this.theme,
      this.startDate,
      this.endDate,
      required this.onDateFilterPressed});

  @override
  State<DiaryContent> createState() => _DiaryContentState();
}

/// 日记页面Header代理类
class _DiaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// 日期筛选按钮点击回调
  final VoidCallback onDateFilterPressed;
  
  /// 开始日期
  final DateTime? startDate;
  
  /// 结束日期
  final DateTime? endDate;
  
  /// 主题数据
  final ThemeData theme;
  
  /// 构造函数
  const _DiaryHeaderDelegate({
    required this.onDateFilterPressed,
    this.startDate,
    this.endDate,
    required this.theme,
  });
  
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
                '我的日记',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                )
              ),
            ],
          ),
          // 右侧：日期筛选按钮
          _buildDateFilterButton(),
        ],
      ),
    );
  }
  
  /// 构建日期筛选按钮
  Widget _buildDateFilterButton() {
    // 格式化显示选择的日期范围
    String dateText = '';
    if (startDate != null && endDate != null) {
      if (startDate!.year == endDate!.year && startDate!.month == endDate!.month && startDate!.day == endDate!.day) {
        // 同一天
        dateText = '${startDate!.year}年${startDate!.month}月${startDate!.day}日';
      } else {
        // 日期范围
        dateText = '${startDate!.year}年${startDate!.month}月${startDate!.day}日 - ${endDate!.year}年${endDate!.month}月${endDate!.day}日';
      }
    } else if (startDate != null) {
      // 只有开始日期
      dateText = '从 ${startDate!.year}年${startDate!.month}月${startDate!.day}日';
    } else if (endDate != null) {
      // 只有结束日期
      dateText = '到 ${endDate!.year}年${endDate!.month}月${endDate!.day}日';
    }
    
    return GestureDetector(
      onTap: onDateFilterPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: theme.colorScheme.onSurface, size: 18),
            if (dateText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                dateText,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
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

class _DiaryContentState extends State<DiaryContent> {
  /// 当前选中的分类
  String? _selectedCategory;
  
  /// 当前选中的标签
  String? _selectedTag;
  
  /// 是否处于多选模式
  bool _isMultiSelectMode = false;
  
  /// 选中的日记条目ID集合
  Set<String> _selectedEntries = {};
  
  // 控制是否显示删除按钮
  bool _showDeleteButtons = false;
  // 控制长按动画状态
  bool _isLongPressing = false;
  // 控制是否正在闪烁
  bool _isBlinking = false;
  
  /// 切换多选模式
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedEntries.clear();
      }
    });
  }
  
  /// 切换条目选中状态
  void _toggleEntrySelection(String entryId) {
    setState(() {
      if (_selectedEntries.contains(entryId)) {
        _selectedEntries.remove(entryId);
      } else {
        _selectedEntries.add(entryId);
      }
    });
  }
  
  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (_selectedEntries.length == widget.entries.length) {
        _selectedEntries.clear();
      } else {
        _selectedEntries = widget.entries.map((entry) => entry.id).toSet();
      }
    });
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
  
  /// 显示添加分类对话框
  void _showAddCategoryDialog(BuildContext context) {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    String icon = 'note';
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
                    {'value': 'note', 'icon': Icons.note},
                    {'value': 'book', 'icon': Icons.book},
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
                  dropdownColor: theme.colorScheme.surfaceVariant,
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
                  dropdownColor: theme.colorScheme.surfaceVariant,
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
                  final newCategory = AppCategory.Category(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: AppCategory.CategoryType.journal,
                    icon: icon,
                    color: color,
                    isExpanded: true,
                  );
                  
                  context.read<CategoryBloc>().add(AddCategory(newCategory));
                  
                  setState(() {
                    // 添加成功后隐藏删除按钮
                    _showDeleteButtons = false;
                  });
                  
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
  
  /// 重新排序分类
  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      final List<AppCategory.Category> categories = List.from(widget.categories);
      final AppCategory.Category element = categories.removeAt(oldIndex);
      
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
  
  /// 删除选中的日记
  void _deleteSelectedEntries() {
    if (_selectedEntries.isEmpty) return;
    
    _showBatchDeleteConfirmationDialog(context);
  }
  
  /// 从内容块中提取图片URL，包括从Quill Delta格式中提取
  List<String> _getImageUrls(Journal entry) {
    if (entry.content == null || entry.content.isEmpty) {
      print('日记内容为空');
      return [];
    }
    
    final List<String> imageUrls = [];
    
    for (var block in entry.content) {
      print('内容块类型: ${block.type}, 数据: ${block.data}');
      // 处理单独的图像内容块
      if (block.type == ContentBlockType.image) {
        final imageUrl = block.data;
        print('找到图像内容块，URL: $imageUrl');
        // 接受所有图片URL，包括本地和网络URL
        imageUrls.add(imageUrl);
      }
      // 处理文本内容块中的Quill Delta格式图像
      else if (block.type == ContentBlockType.text) {
        try {
          final List<dynamic> delta = jsonDecode(block.data);
          for (var op in delta) {
            if (op is Map<String, dynamic>) {
              if (op.containsKey('insert')) {
                final insert = op['insert'];
                if (insert is Map<String, dynamic>) {
                  // 检查是否有image键
                  if (insert.containsKey('image')) {
                    final imageUrl = insert['image'];
                    if (imageUrl is String) {
                      print('找到Quill Delta图像，URL: $imageUrl');
                      // 接受所有图片URL，包括本地和网络URL
                      imageUrls.add(imageUrl);
                    }
                  }
                  // 检查是否有file键，可能是另一种格式
                  else if (insert.containsKey('file')) {
                    final fileData = insert['file'];
                    if (fileData is Map<String, dynamic> && fileData.containsKey('url')) {
                      final url = fileData['url'];
                      if (url is String && (url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.gif'))) {
                        print('找到Quill Delta文件图像，URL: $url');
                        // 接受所有图片URL，包括本地和网络URL
                        imageUrls.add(url);
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          // 忽略解析错误
          print('解析Quill Delta错误: $e');
        }
      }
    }
    
    print('提取到的图片URLs: $imageUrls');
    return imageUrls;
  }
  
  /// 从内容块中提取音频URL，包括从Quill Delta格式中提取
  List<String> _getAudioUrls(Journal entry) {
    if (entry.content == null || entry.content.isEmpty) {
      return [];
    }
    
    final List<String> audioUrls = [];
    
    for (var block in entry.content) {
      // 处理单独的音频内容块
      if (block.type == ContentBlockType.audio) {
        // 接受所有音频URL，包括本地和网络URL
        audioUrls.add(block.data);
      }
      // 处理文本内容块中的Quill Delta格式音频
      else if (block.type == ContentBlockType.text) {
        try {
          final List<dynamic> delta = jsonDecode(block.data);
          for (var op in delta) {
            if (op is Map<String, dynamic>) {
              if (op.containsKey('insert')) {
                final insert = op['insert'];
                if (insert is Map<String, dynamic>) {
                  // 检查是否有audio键
                  if (insert.containsKey('audio')) {
                    final audioUrl = insert['audio'];
                    if (audioUrl is String) {
                      // 接受所有音频URL，包括本地和网络URL
                      audioUrls.add(audioUrl);
                    }
                  }
                  // 检查是否有file键，可能是另一种格式
                  else if (insert.containsKey('file')) {
                    final fileData = insert['file'];
                    if (fileData is Map<String, dynamic> && fileData.containsKey('url')) {
                      final url = fileData['url'];
                      if (url is String && (url.endsWith('.mp3') || url.endsWith('.wav') || url.endsWith('.ogg'))) {
                        // 接受所有音频URL，包括本地和网络URL
                        audioUrls.add(url);
                      }
                    }
                  }
                  // 检查是否有custom键，处理自定义嵌入
                  else if (insert.containsKey('custom')) {
                    final customData = insert['custom'];
                    Map<String, dynamic> embedData;
                    
                    if (customData is String) {
                      try {
                        embedData = jsonDecode(customData);
                      } catch (e) {
                        debugPrint('Error parsing custom audio data: $e');
                        continue;
                      }
                    } else if (customData is Map<String, dynamic>) {
                      embedData = customData;
                    } else {
                      continue;
                    }
                    
                    // 处理自定义音频嵌入
                    if (embedData.containsKey('audio')) {
                      final audioInfo = embedData['audio'];
                      if (audioInfo is String) {
                        try {
                          final audioMap = jsonDecode(audioInfo);
                          if (audioMap is Map && audioMap.containsKey('path')) {
                            audioUrls.add(audioMap['path']);
                          } else {
                            audioUrls.add(audioInfo);
                          }
                        } catch (e) {
                          audioUrls.add(audioInfo);
                        }
                      } else if (audioInfo is Map && audioInfo.containsKey('path')) {
                        audioUrls.add(audioInfo['path']);
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          // 忽略解析错误
          debugPrint('Error parsing audio delta: $e');
        }
      }
    }
    
    debugPrint('Extracted audio URLs: $audioUrls');
    return audioUrls;
  }
  
  /// 从内容块中提取视频URL，包括从Quill Delta格式中提取
  List<String> _getVideoUrls(Journal entry) {
    if (entry.content == null || entry.content.isEmpty) {
      return [];
    }
    
    final List<String> videoUrls = [];
    
    for (var block in entry.content) {
      // 处理单独的视频内容块
      if (block.type == ContentBlockType.video) {
        // 接受所有视频URL，包括本地和网络URL
        videoUrls.add(block.data);
      }
      // 处理文本内容块中的Quill Delta格式视频
      else if (block.type == ContentBlockType.text) {
        try {
          final List<dynamic> delta = jsonDecode(block.data);
          for (var op in delta) {
            if (op is Map<String, dynamic>) {
              if (op.containsKey('insert')) {
                final insert = op['insert'];
                if (insert is Map<String, dynamic>) {
                  // 检查是否有video键
                  if (insert.containsKey('video')) {
                    final videoUrl = insert['video'];
                    if (videoUrl is String) {
                      // 接受所有视频URL，包括本地和网络URL
                      videoUrls.add(videoUrl);
                    }
                  }
                  // 检查是否有file键，可能是另一种格式
                  else if (insert.containsKey('file')) {
                    final fileData = insert['file'];
                    if (fileData is Map<String, dynamic> && fileData.containsKey('url')) {
                      final url = fileData['url'];
                      if (url is String && (url.endsWith('.mp4') || url.endsWith('.webm') || url.endsWith('.mov'))) {
                        // 接受所有视频URL，包括本地和网络URL
                        videoUrls.add(url);
                      }
                    }
                  }
                  // 检查是否有custom键，处理自定义嵌入
                  else if (insert.containsKey('custom')) {
                    final customData = insert['custom'];
                    Map<String, dynamic> embedData;
                    
                    if (customData is String) {
                      try {
                        embedData = jsonDecode(customData);
                      } catch (e) {
                        debugPrint('Error parsing custom video data: $e');
                        continue;
                      }
                    } else if (customData is Map<String, dynamic>) {
                      embedData = customData;
                    } else {
                      continue;
                    }
                    
                    // 处理自定义视频嵌入
                    if (embedData.containsKey('video')) {
                      final videoInfo = embedData['video'];
                      if (videoInfo is String) {
                        try {
                          final videoMap = jsonDecode(videoInfo);
                          if (videoMap is Map && videoMap.containsKey('path')) {
                            videoUrls.add(videoMap['path']);
                          } else {
                            videoUrls.add(videoInfo);
                          }
                        } catch (e) {
                          videoUrls.add(videoInfo);
                        }
                      } else if (videoInfo is Map && videoInfo.containsKey('path')) {
                        videoUrls.add(videoInfo['path']);
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          // 忽略解析错误
          debugPrint('Error parsing video delta: $e');
        }
      }
    }
    
    debugPrint('Extracted video URLs: $videoUrls');
    return videoUrls;
  }
  
  /// 从内容块中提取复选框内容，从Quill Delta格式中提取
  List<Map<String, dynamic>> _getCheckboxes(Journal entry) {
    if (entry.content == null || entry.content.isEmpty) {
      return [];
    }
    
    final List<Map<String, dynamic>> checkboxes = [];
    
    for (var block in entry.content) {
      if (block.type == ContentBlockType.text) {
        try {
          final List<dynamic> delta = jsonDecode(block.data);
          for (var op in delta) {
            if (op is Map<String, dynamic>) {
              if (op.containsKey('insert')) {
                final insert = op['insert'];
                if (insert is Map<String, dynamic> && insert.containsKey('custom')) {
                  final customData = insert['custom'];
                  if (customData is Map<String, dynamic> && customData.containsKey('checkbox')) {
                    checkboxes.add({
                      'id': customData['id'] as String? ?? '',
                      'checked': customData['checked'] as bool? ?? false,
                    });
                  }
                }
              }
            }
          }
        } catch (e) {
          // 忽略解析错误
        }
      }
    }
    
    return checkboxes;
  }
  
  /// 从内容块中提取文本内容
  String _getTextContent(Journal entry) {
    if (entry.content == null || entry.content.isEmpty) {
      return '';
    }
    
    // 处理Quill Delta格式的文本内容
    String text = '';
    
    for (var block in entry.content) {
      if (block.type == ContentBlockType.text) {
        try {
          // 尝试解析Quill Delta格式
          final List<dynamic> delta = jsonDecode(block.data);
          for (var op in delta) {
            if (op is Map<String, dynamic>) {
              if (op.containsKey('insert')) {
                final insert = op['insert'];
                if (insert is String) {
                  text += insert;
                } else if (insert is Map<String, dynamic>) {
                  // 只处理复选框，跳过其他嵌入内容
                  if (insert.containsKey('custom')) {
                    final customData = insert['custom'];
                    if (customData is Map<String, dynamic> && customData.containsKey('checkbox')) {
                      // 处理复选框
                      final checked = customData['checked'] ?? false;
                      text += checked ? '[✓] ' : '[ ] ';
                    }
                    // 跳过其他自定义组件
                  }
                  // 跳过其他嵌入内容（如图片、音频、视频）
                }
              }
            }
          }
        } catch (e) {
          // 如果不是有效的JSON，直接使用原始数据
          text += block.data;
        }
      }
    }
    
    return text;
  }

  @override
  Widget build(BuildContext context) {
    // 使用与习惯页完全一致的布局结构，添加SafeArea
    return SafeArea(
      child: GestureDetector(
        // 点击任何位置恢复正常状态
        onTap: () {
          if (_showDeleteButtons) {
            setState(() {
              _showDeleteButtons = false;
            });
          }
        },
        child: CustomScrollView(
          slivers: [
            // 多选模式工具栏
            if (_isMultiSelectMode)
              SliverPersistentHeader(
                pinned: true,
                delegate: _MultiSelectToolbarDelegate(
                  selectedCount: _selectedEntries.length,
                  onSelectAll: _toggleSelectAll,
                  onDelete: _deleteSelectedEntries,
                  onCancel: _toggleMultiSelectMode,
                ),
              ),
            // 固定顶部Header，与习惯页样式一致
            SliverPersistentHeader(
              pinned: true,
              delegate: _DiaryHeaderDelegate(
                onDateFilterPressed: widget.onDateFilterPressed,
                startDate: widget.startDate,
                endDate: widget.endDate,
                theme: widget.theme,
              ),
            ),
            // 分类标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
                child: Text(
                  '分类',
                  style: TextStyle(
                    color: widget.theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            // 顶部横向滚动筛选栏 - 调整为与习惯页相同的左对齐样式
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
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
                    padding: EdgeInsets.zero,
                    child: GestureDetector(
                      // 筛选栏内部点击事件，不做特殊处理
                      onTapDown: (TapDownDetails details) {
                        // 内部点击事件已处理，无需额外操作
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 全部筛选按钮 - 直接与分类标题对齐
                          _buildFilterButton(
                            '全部', 
                            Icons.check_circle, 
                            isActive: _selectedCategory == null && _selectedTag == null,
                            onTap: () {
                              setState(() {
                                _selectedCategory = null;
                                _selectedTag = null;
                              });
                            },
                            onLongPress: () {
                              if (!_showDeleteButtons) {
                                setState(() {
                                  _showDeleteButtons = true;
                                });
                                _startBlinkingAnimation();
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          // 分类筛选按钮，使用DragTarget接收拖动的分类
                          ...widget.categories.asMap().entries.map((entry) {
                            final index = entry.key;
                            final category = entry.value;
                            return [
                              DragTarget<AppCategory.Category>(
                                onAccept: (draggedCategory) {
                                  // 当拖动的分类被放置到当前位置时，更新分类顺序
                                  if (draggedCategory.id != category.id) {
                                    _reorderCategories(
                                      widget.categories.indexOf(draggedCategory),
                                      index
                                    );
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  // 只有在编辑模式下才显示Draggable组件
                                  if (_showDeleteButtons) {
                                    return Draggable<AppCategory.Category>(
                                      data: category,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: _buildFilterButton(
                                          category.name,
                                          Icons.compost,
                                          color: Color(category.color),
                                          isActive: _selectedCategory == category.id,
                                          onTap: () {},
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.5,
                                        child: _buildFilterButton(
                                          category.name,
                                          Icons.compost,
                                          color: Color(category.color),
                                          isActive: _selectedCategory == category.id,
                                          onTap: () {
                                            setState(() {
                                              _selectedCategory = category.id;
                                              _selectedTag = null;
                                            });
                                          },
                                          showDelete: _showDeleteButtons,
                                          isBlinking: _isLongPressing,
                                          onDelete: () {
                                            context.read<CategoryBloc>().add(DeleteCategory(category.id));
                                            setState(() {
                                              _showDeleteButtons = false;
                                            });
                                          },
                                          onLongPress: () {
                                            if (!_showDeleteButtons) {
                                              setState(() {
                                                _showDeleteButtons = true;
                                              });
                                              _startBlinkingAnimation();
                                            }
                                          },
                                        ),
                                      ),
                                      child: _buildFilterButton(
                                        category.name,
                                        Icons.compost,
                                        color: Color(category.color),
                                        isActive: _selectedCategory == category.id,
                                        onTap: () {
                                          setState(() {
                                            _selectedCategory = category.id;
                                            _selectedTag = null;
                                          });
                                        },
                                        showDelete: _showDeleteButtons,
                                        isBlinking: _isLongPressing,
                                        onDelete: () {
                                          context.read<CategoryBloc>().add(DeleteCategory(category.id));
                                          setState(() {
                                            _showDeleteButtons = false;
                                          });
                                        },
                                        onLongPress: () {
                                          if (!_showDeleteButtons) {
                                            setState(() {
                                              _showDeleteButtons = true;
                                            });
                                            _startBlinkingAnimation();
                                          }
                                        },
                                      ),
                                    );
                                  } else {
                                    // 非编辑模式下，只显示普通按钮
                                    return _buildFilterButton(
                                      category.name,
                                      Icons.compost,
                                      color: Color(category.color),
                                      isActive: _selectedCategory == category.id,
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = category.id;
                                          _selectedTag = null;
                                        });
                                      },
                                      onLongPress: () {
                                        if (!_showDeleteButtons) {
                                          setState(() {
                                            _showDeleteButtons = true;
                                          });
                                          _startBlinkingAnimation();
                                        }
                                      },
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                            ];
                          }).expand((widgets) => widgets),
                          // 添加分类按钮
                          _buildFilterButton(
                            '+',
                            Icons.add,
                            onTap: () {
                              _showAddCategoryDialog(context);
                            },
                          ),
                          // 标签筛选按钮（如果有标签）
                          if (widget.entries.isNotEmpty)
                            ...(() {
                              final allTags = <String>{};
                              for (final entry in widget.entries) {
                                allTags.addAll(entry.tags);
                              }
                              return allTags.isNotEmpty ? [
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: Colors.white.withAlpha(10),
                                ),
                                const SizedBox(width: 12),
                                ...allTags.map((tag) => [
                                  _buildFilterButton(
                                    tag,
                                    Icons.tag,
                                    color: Colors.blue,
                                    isActive: _selectedTag == tag,
                                    onTap: () {
                                      setState(() {
                                        _selectedTag = tag;
                                        _selectedCategory = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                ]).expand((widgets) => widgets)
                              ] : [];
                            })(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // 分隔线
            const SliverToBoxAdapter(
              child: Divider(
                height: 1,
                color: Color.fromARGB(10, 255, 255, 255),
              ),
            ),
            
            // 日记列表 - 直接使用SliverList，与习惯页保持一致
            _buildDiaryList(),
          ],
        ),
      ),
    );
  }

  /// 获取分类名称
  String _getCategoryName(String categoryId) {
    final category = widget.categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => AppCategory.Category(
        id: '',
        name: '未分类',
        type: AppCategory.CategoryType.journal,
        icon: 'note',
        color: 0xFF4CAF50,
        isExpanded: true,
      ),
    );
    return category.name;
  }
  
  /// 格式化短日期时间
  String _formatDateTimeShort(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} • ${dateTime.month}月${dateTime.day}日';
  }
  
  /// 构建筛选按钮
  Widget _buildFilterButton(String label, IconData icon, {int? count, Color? color, bool isActive = false, VoidCallback? onTap, bool showDelete = false, bool isBlinking = false, VoidCallback? onDelete, VoidCallback? onLongPress}) {
    // 针对加号按钮的特殊样式处理，与待办事项页保持一致
    final bool isAddButton = label == '+';
    
    // 如果是加号按钮，使用特殊样式，进一步减小尺寸
    if (isAddButton) {
      return GestureDetector(
        onTap: onTap,
        // 添加悬停效果
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 24, // 更小的宽度
            height: 24, // 更小的高度
            decoration: BoxDecoration(
              color: widget.theme.colorScheme.surfaceVariant, // 使用主题颜色
              borderRadius: BorderRadius.circular(12), // 更小的圆角
              border: Border.all(
                color: widget.theme.colorScheme.primary, // 使用主题主色
                width: 2, // 保持边框宽度
              ),
            ),
            child: Icon(
              Icons.add,
              color: widget.theme.colorScheme.primary, // 使用主题主色，让+号更明显
              size: 14, // 更小的图标大小
            ),
          ),
        ),
      );
    }
    
    // 普通筛选按钮样式
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      // 添加悬停效果
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedOpacity(
          opacity: isBlinking ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: isActive
                      ? widget.theme.colorScheme.primary
                      : color != null
                          ? color.withAlpha(10)
                          : widget.theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                  border: color != null
                      ? Border.all(color: color.withAlpha(20))
                      : Border.all(color: widget.theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    if (color != null && !isActive)
                      Icon(icon, size: 18, color: color),
                    if (isActive)
                      Text(
                        label,
                        style: TextStyle(
                          color: widget.theme.colorScheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (!isActive && color == null)
                      Text(
                        label,
                        style: TextStyle(
                          color: widget.theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (!isActive && color != null)
                      const SizedBox(width: 6),
                    if (!isActive && color != null)
                      Text(
                        label,
                        style: TextStyle(
                          color: widget.theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (count != null)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 删除按钮，仅当 showDelete 为 true 且不是 "全部" 标签时显示
              if (showDelete && label != '全部')
                Positioned(
                  top: 0, // 调整位置，避免被截断
                  right: 0,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 16, // 稍微小一点，避免被截断
                      height: 16,
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        size: 10, // 更小的图标
                        color: widget.theme.colorScheme.onError,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建日记列表
  Widget _buildDiaryList() {
    // 根据筛选条件过滤日记
    final filteredEntries = _filterDiaryEntries();

    if (filteredEntries.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.book,
                size: 64,
                color: widget.theme.colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 16),
              Text(
                '没有找到符合条件的日记',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 构建日记列表
    final listDelegate = SliverChildBuilderDelegate(
      (context, index) {
        final entry = filteredEntries[index];
        final imageUrls = _getImageUrls(entry);
        final audioUrls = _getAudioUrls(entry);
        final videoUrls = _getVideoUrls(entry);
        
        // 根据日记类型构建不同的卡片
        final diaryCard = imageUrls.isNotEmpty
            ? _buildImageDiaryCard(context, entry)
            : audioUrls.isNotEmpty
                ? _buildAudioDiaryCard(context, entry)
                : videoUrls.isNotEmpty
                    ? _buildVideoDiaryCard(context, entry)
                    : _buildTextDiaryCard(context, entry);
        
        // 检查条目是否被选中
        final isSelected = _selectedEntries.contains(entry.id);
        
        // 左滑删除功能
        final slidableCard = Slidable(
          // 配置滑动方向和动画
          key: ValueKey(entry.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (context) {
                  _showDeleteDiaryDialog(context, entry);
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
                  _toggleEntrySelection(entry.id);
                } else {
                  // 非多选模式下，进入编辑页（使用添加日记的界面）
                  _showEditDiaryDialog(context, entry);
                }
              },
              onLongPress: () {
                // 长按进入多选模式
                if (!_isMultiSelectMode) {
                  _toggleMultiSelectMode();
                  _toggleEntrySelection(entry.id);
                }
              },
              child: Stack(
                children: [
                  diaryCard,
                  // 多选模式下，显示选择状态
                  if (_isMultiSelectMode) Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.errorColor : Colors.transparent,
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
      childCount: filteredEntries.length,
      addAutomaticKeepAlives: true,
    );
    
    // 构建内容
    return SliverList(
      delegate: listDelegate,
    );
  }
  
  /// 过滤日记条目
  List<Journal> _filterDiaryEntries() {
    return widget.entries.where((entry) {
      // 分类过滤
      if (_selectedCategory != null && entry.categoryId != _selectedCategory) {
        return false;
      }
      
      // 标签过滤
      if (_selectedTag != null && !entry.tags.contains(_selectedTag)) {
        return false;
      }
      
      // 日期范围过滤
      bool inDateRange = true;
      if (widget.startDate != null) {
        inDateRange = inDateRange && entry.createdAt.isAfter(widget.startDate!.subtract(const Duration(seconds: 1)));
      }
      if (widget.endDate != null) {
        inDateRange = inDateRange && entry.createdAt.isBefore(widget.endDate!.add(const Duration(days: 1)));
      }
      
      return inDateRange;
    }).toList();
  }
  
  /// 判断是否同一天
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  /// 根据URL类型返回合适的ImageProvider，带有错误处理
  ImageProvider _getImageProvider(String url) {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return NetworkImage(url);
      } else {
        // 处理本地文件路径
        String filePath;
        if (url.startsWith('file://')) {
          filePath = url.replaceFirst('file://', '');
        } else {
          // 尝试多种路径格式
          filePath = url;
          
          // 检查原始路径是否存在
          if (!File(filePath).existsSync()) {
            // 尝试常见的存储路径格式
            // 1. 直接使用图片名称（假设当前目录是存储目录）
            final fileName = path.basename(url);
            final currentDirPath = Directory.current.path;
            
            // 2. 尝试存储路径 + 图片路径
            final possibleBasePaths = [
              // 应用文档目录
              path.join(currentDirPath, 'MomentKeep', 'images'),
              path.join(currentDirPath, 'images'),
              // 添加用户目录前缀
              path.join(currentDirPath, 'user', 'MomentKeep', 'images'),
              path.join(currentDirPath, 'user', 'images'),
              // 默认存储路径
              path.join(currentDirPath, 'default', 'MomentKeep', 'images'),
              path.join(currentDirPath, 'default', 'images'),
              // 自定义存储路径的常见位置
              path.join('D:', 'momentkeep', 'images'),
              path.join('E:', 'momentkeep', 'images'),
              path.join('C:', 'Users', 'User', 'Documents', 'momentkeep', 'images'),
            ];
            
            // 尝试所有可能的路径组合
            for (final basePath in possibleBasePaths) {
              final possiblePath = path.join(basePath, fileName);
              if (File(possiblePath).existsSync()) {
                filePath = possiblePath;
                break;
              }
            }
          }
        }
        
        final file = File(filePath);
        // 检查文件是否存在
        if (file.existsSync()) {
          return FileImage(file);
        } else {
          // 文件不存在，返回一个占位符图片
          return NetworkImage('https://picsum.photos/800/400?random=$url');
        }
      }
    } catch (e) {
      // 发生任何错误，返回一个占位符图片
      return NetworkImage('https://picsum.photos/800/400?random=$url');
    }
  }
  
  /// 异步获取图片提供者，使用ImageHelper处理正确的路径
  Future<ImageProvider> _getImageProviderAsync(String url) async {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return NetworkImage(url);
      } else {
        // 处理本地文件路径
        String relativePath = url.startsWith('file://') ? url.replaceFirst('file://', '') : url;
        final fileName = path.basename(relativePath);
        
        // 1. 尝试直接获取绝对路径
        try {
          final absolutePath = await ImageHelper.getAbsolutePath(relativePath);
          final file = File(absolutePath);
          if (await file.exists()) {
            return FileImage(file);
          }
        } catch (e) {
          debugPrint('直接获取绝对路径失败: $e');
        }
        
        // 2. 获取应用文档目录
        final basePath = await ImageHelper.getApplicationDocumentsDirectoryPath();
        final storageDir = Directory(path.join(basePath, 'MomentKeep'));
        
        // 收集所有可能的路径
        final List<String> possiblePaths = [];
        
        // 3. 旧路径：直接在storage目录下
        possiblePaths.add(path.join(storageDir.path, relativePath));
        possiblePaths.add(path.join(storageDir.path, 'images', fileName));
        
        // 4. 新路径：带有用户ID的目录结构
        if (await storageDir.exists()) {
          try {
            // 列出storageDir下的所有子目录（用户ID目录）
            final userDirs = storageDir.listSync().where((entity) => entity is Directory).toList();
            for (final userDir in userDirs) {
              final userDirPath = (userDir as Directory).path;
              
              // 尝试用户目录下的images目录
              possiblePaths.add(path.join(userDirPath, 'images', fileName));
              
              // 尝试直接在用户目录下
              possiblePaths.add(path.join(userDirPath, fileName));
            }
          } catch (e) {
            debugPrint('列出用户目录失败: $e');
          }
        }
        
        // 调试信息：打印所有可能的路径
        debugPrint('Checking diary item image paths: $possiblePaths');
        
        // 5. 尝试所有可能的路径
        for (final possiblePath in possiblePaths) {
          final possibleFile = File(possiblePath);
          if (await possibleFile.exists()) {
            debugPrint('Found diary item image at: $possiblePath');
            return FileImage(possibleFile);
          }
        }
        
        // 所有路径都不存在，返回占位符
        debugPrint('Diary item image not found: $url');
        return NetworkImage('https://picsum.photos/800/400?random=$url');
      }
    } catch (e) {
      // 发生错误，返回占位符
      debugPrint('Error loading diary item image: $e');
      return NetworkImage('https://picsum.photos/800/400?random=$url');
    }
  }

  /// 构建图片日记卡片
  Widget _buildImageDiaryCard(BuildContext context, Journal entry) {
    final imageUrls = _getImageUrls(entry);
    final textContent = _getTextContent(entry);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片区域
          Stack(
            children: [
              FutureBuilder<ImageProvider>(
                future: _getImageProviderAsync(imageUrls.first),
                builder: (context, snapshot) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      color: widget.theme.colorScheme.surfaceVariant,
                      image: DecorationImage(
                        image: snapshot.data ?? NetworkImage('https://picsum.photos/800/400'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      widget.theme.cardTheme.color ?? widget.theme.scaffoldBackgroundColor,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // 标签
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(90),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.compost, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _getCategoryName(entry.categoryId),
                        style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              // 标题和时间
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isNotEmpty ? entry.title : '无标题',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTimeShort(entry.createdAt),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 211, 211, 211),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 内容和标签
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textContent,
                  style: TextStyle(
                    color: Color.fromARGB(255, 211, 211, 211),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (entry.tags.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.label, color: Color.fromARGB(255, 158, 158, 158), size: 16),
                      const SizedBox(width: 6),
                      Wrap(
                        spacing: 8,
                        children: entry.tags.map((tag) => Text(
                          '#$tag',
                          style: TextStyle(color: Color.fromARGB(255, 158, 158, 158), fontSize: 12, fontWeight: FontWeight.w500),
                        )).toList(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化时长为 mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  /// 获取真实的音频时长
  Future<Duration> _getRealAudioDuration(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        debugPrint('Audio file not found: $audioPath');
        return Duration(seconds: 5);
      }
      
      final player = AudioPlayer();
      await player.setSource(DeviceFileSource(audioPath));
      final duration = await player.getDuration() ?? Duration(seconds: 5);
      await player.dispose();
      return duration;
    } catch (e) {
      debugPrint('Error getting real audio duration: $e');
      // 出错时返回估算值
      final file = File(audioPath);
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        final estimatedSeconds = (fileSize / 16384).ceil();
        return Duration(seconds: estimatedSeconds > 0 ? estimatedSeconds : 5);
      }
      return Duration(seconds: 5);
    }
  }
  
  /// 估算音频时长（备用方法）
  Duration _estimateAudioDuration(String audioPath) {
    try {
      final file = File(audioPath);
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        // 假设平均比特率为128kbps，1秒约16KB
        final estimatedSeconds = (fileSize / 16384).ceil();
        return Duration(seconds: estimatedSeconds > 0 ? estimatedSeconds : 5);
      }
    } catch (e) {
      debugPrint('Error estimating audio duration: $e');
    }
    return Duration(seconds: 5);
  }
  
  /// 视频缩略图小部件，显示视频文件的真实缩略图并保持宽高比
  Widget _videoThumbnailWidget(String videoPath) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _buildRealVideoThumbnail(videoPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF13ec5b)),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data!['widget'] != null) {
          // 使用固定高度200像素，与图片日记保持一致
          return Container(
            height: 200,
            width: double.infinity,
            child: snapshot.data!['widget'] as Widget,
          );
        }
        
        return _getDefaultVideoThumbnail();
      },
    );
  }
  
  /// 构建真实的视频缩略图，返回包含宽高比和widget的map
  Future<Map<String, dynamic>> _buildRealVideoThumbnail(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!file.existsSync()) {
        debugPrint('Video file not found: $videoPath');
        return {
          'aspectRatio': 16/9,
          'widget': _getDefaultVideoThumbnail()
        };
      }
      
      // 使用VideoPlayerController显示视频的第一帧作为缩略图
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.pause();
      
      // 获取视频的宽高比
      final aspectRatio = controller.value.aspectRatio;
      
      // 使用固定高度200像素，与图片日记保持一致
      final thumbnailWidget = Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey[800],
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      );
      
      // 不立即dispose，让VideoPlayer组件保持显示
      // 注意：在实际应用中，应该管理controller的生命周期
      return {
        'aspectRatio': aspectRatio,
        'widget': thumbnailWidget
      };
    } catch (e) {
      debugPrint('Error building real video thumbnail: $e');
      return {
        'aspectRatio': 16/9,
        'widget': _getDefaultVideoThumbnail()
      };
    }
  }
  
  /// 获取默认视频缩略图
  Widget _getDefaultVideoThumbnail() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: Colors.grey[800],
        image: const DecorationImage(
          image: NetworkImage('https://picsum.photos/id/1074/800/400'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
  
  /// 获取视频缩略图
  Future<ImageProvider> _getVideoThumbnail(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!file.existsSync()) {
        debugPrint('Video file not found: $videoPath');
        return const NetworkImage('https://picsum.photos/id/1074/800/400');
      }
      
      // 使用video_player获取视频信息和缩略图
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.pause();
      
      // 直接使用视频文件路径作为缩略图，系统会自动处理
      // 注意：在实际应用中，可能需要使用更复杂的方法来生成高质量的缩略图
      final imageProvider = FileImage(file);
      await controller.dispose();
      return imageProvider;
    } catch (e) {
      debugPrint('Error getting video thumbnail: $e');
      // 出错时返回默认图片
      return const NetworkImage('https://picsum.photos/id/1074/800/400');
    }
  }
  
  /// 生成真实的音频波形数据
  List<double> _generateAudioWaveformData() {
    // 生成更真实的音频波形数据
    // 模拟真实音频频谱的起伏
    final List<double> waveform = [];
    final random = Random();
    
    // 生成50个波形点，更密集更真实
    for (int i = 0; i < 50; i++) {
      // 使用正弦函数生成基础波形，模拟音频的周期性
      final baseHeight = 10.0 + 8.0 * sin(i * 0.3);
      // 添加随机变化，模拟音频的不规则性
      final randomVariation = random.nextDouble() * 6.0 - 3.0;
      // 确保波形高度在合理范围内
      final height = max(2.0, min(20.0, baseHeight + randomVariation));
      waveform.add(height);
    }
    
    return waveform;
  }
  
  /// 构建音频日记卡片
  Widget _buildAudioDiaryCard(BuildContext context, Journal entry) {
    final textContent = _getTextContent(entry);
    final audioUrls = _getAudioUrls(entry);
    
    String audioFileName = '';
    if (audioUrls.isNotEmpty) {
      audioFileName = path.basename(audioUrls.first);
    }
    
    // 生成真实的音频波形数据
    final waveformData = _generateAudioWaveformData();
    
    // 异步获取真实音频时长
    Future<Duration> _getAudioData() async {
      if (audioUrls.isEmpty) {
        return Duration.zero;
      }
      return await _getRealAudioDuration(audioUrls.first);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(Icons.mic, color: widget.theme.colorScheme.secondary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.title.isNotEmpty ? entry.title : '无标题',
                              style: TextStyle(color: widget.theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.theme.colorScheme.secondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _getCategoryName(entry.categoryId),
                                style: TextStyle(color: widget.theme.colorScheme.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTimeShort(entry.createdAt),
                          style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.more_horiz, color: widget.theme.colorScheme.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 内容预览
            Text(
              textContent,
              style: TextStyle(
                color: widget.theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // 音频播放器样式显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 音频文件名
                  if (audioFileName.isNotEmpty) ...[
                    Text(
                      audioFileName,
                      style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 12, fontFamily: 'Monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 音频播放控制和波形
                  Row(
                    children: [
                      // 播放按钮
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(Icons.play_arrow, color: widget.theme.colorScheme.onPrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      // 音频波形图
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(waveformData.length, (index) {
                              final height = waveformData[index];
                              return Container(
                                width: 2.0,
                                height: height,
                                decoration: BoxDecoration(
                                  color: widget.theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 真实音频时长
                      FutureBuilder<Duration>(
                        future: _getAudioData(),
                        builder: (context, snapshot) {
                          final duration = snapshot.data ?? Duration(seconds: 0);
                          return Text(
                            _formatDuration(duration),
                            style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 12, fontFamily: 'Monospace'),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 标签
            if (entry.tags.isNotEmpty) ...[
              Wrap(
                spacing: 12,
                children: entry.tags.map((tag) => Text(
                  '#$tag',
                  style: TextStyle(color: widget.theme.colorScheme.primary, fontSize: 12),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 获取真实的视频时长
  Future<Duration> _getRealVideoDuration(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!file.existsSync()) {
        debugPrint('Video file not found: $videoPath');
        return Duration(seconds: 10);
      }
      
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      return duration;
    } catch (e) {
      debugPrint('Error getting real video duration: $e');
      // 出错时返回估算值
      final file = File(videoPath);
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        final estimatedSeconds = (fileSize / 192000).ceil();
        return Duration(seconds: estimatedSeconds > 0 ? estimatedSeconds : 10);
      }
      return Duration(seconds: 10);
    }
  }
  
  /// 估算视频时长（备用方法）
  Duration _estimateVideoDuration(String videoPath) {
    try {
      final file = File(videoPath);
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        // 假设平均比特率为1.5Mbps，1秒约187.5KB
        final estimatedSeconds = (fileSize / 192000).ceil();
        return Duration(seconds: estimatedSeconds > 0 ? estimatedSeconds : 10);
      }
    } catch (e) {
      debugPrint('Error estimating video duration: $e');
    }
    return Duration(seconds: 10);
  }
  
  /// 构建视频日记卡片
  Widget _buildVideoDiaryCard(BuildContext context, Journal entry) {
    final videoUrls = _getVideoUrls(entry);
    final textContent = _getTextContent(entry);
    
    // 异步获取真实视频时长
    Future<Duration> _getVideoData() async {
      if (videoUrls.isEmpty) {
        return Duration.zero;
      }
      return await _getRealVideoDuration(videoUrls.first);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频预览 - 固定高度200像素，与图片日记保持一致
          Container(
            height: 200,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  if (videoUrls.isNotEmpty) 
                    _videoThumbnailWidget(videoUrls.first)
                  else
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surfaceVariant,
                        image: const DecorationImage(
                          image: NetworkImage('https://picsum.photos/id/1074/800/400'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  // 播放按钮
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.theme.colorScheme.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: widget.theme.colorScheme.onPrimary.withOpacity(0.4), width: 2),
                        ),
                        child: Icon(Icons.play_arrow, color: widget.theme.colorScheme.onPrimary, size: 32),
                      ),
                    ),
                  ),
                  // 类别标签 - 右上角
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.movie, color: widget.theme.colorScheme.onSecondary, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _getCategoryName(entry.categoryId),
                            style: TextStyle(color: widget.theme.colorScheme.onSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 真实时长 - 右下角
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FutureBuilder<Duration>(
                      future: _getVideoData(),
                      builder: (context, snapshot) {
                        final videoDuration = snapshot.data ?? Duration.zero;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.theme.colorScheme.surface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatDuration(videoDuration),
                            style: TextStyle(color: widget.theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 内容和标签
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.title.isNotEmpty ? entry.title : '无标题',
                      style: TextStyle(color: widget.theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDateTimeShort(entry.createdAt),
                      style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  textContent,
                  style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (entry.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    children: entry.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建文本日记卡片
  Widget _buildTextDiaryCard(BuildContext context, Journal entry) {
    final textContent = _getTextContent(entry);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.title.isNotEmpty ? entry.title : '无标题',
                          style: TextStyle(color: widget.theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.theme.colorScheme.secondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(Icons.work, color: widget.theme.colorScheme.secondary, size: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTimeShort(entry.createdAt),
                      style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
                Icon(Icons.edit_note, color: widget.theme.colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            // 内容
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: widget.theme.colorScheme.primary, width: 2)),
              ),
              child: Text(
                textContent,
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.6,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            // 标签
            if (entry.tags.isNotEmpty) ...[
              Wrap(
                spacing: 12,
                children: entry.tags.map((tag) => Text(
                  '#$tag',
                  style: TextStyle(color: widget.theme.colorScheme.onSurfaceVariant, fontSize: 12),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 显示修改日记对话框
  void _showEditDiaryDialog(BuildContext context, Journal entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocBuilder<CategoryBloc, CategoryState>(
          builder: (context, categoryState) {
            if (categoryState is CategoryLoaded) {
              // 找到对应的分类
              final category = categoryState.categories.firstWhere(
                (cat) => cat.id == entry.categoryId,
                orElse: () => categoryState.categories.first,
              );

              return MinimalJournalEditor(
                journal: entry,
                category: category,
                onSave: (updatedJournal) {
                  // 更新日记
                  context
                      .read<DiaryBloc>()
                      .add(UpdateDiaryEntry(updatedJournal));
                  Navigator.pop(context);
                },
                onCancel: () {
                  Navigator.pop(context);
                },
              );
            }
            return Scaffold(
              body: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  /// 显示日记详情
  void _showDiaryDetail(BuildContext context, Journal entry) {
    final textContent = _getTextContent(entry);
    final imageUrls = _getImageUrls(entry);
    final audioUrls = _getAudioUrls(entry);
    final videoUrls = _getVideoUrls(entry);
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(entry.title.isNotEmpty ? entry.title : '日记详情'),
            backgroundColor: const Color(0xFF102216),
          ),
          backgroundColor: const Color(0xFF102216),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日期时间
                Text(
                  _formatDateTime(entry.createdAt),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 内容
                Text(
                  textContent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                
                // 图片内容
                if (imageUrls.isNotEmpty) ...[
                  const Text('图片', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...imageUrls.map((imageUrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image(
                      image: _getImageProvider(imageUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )),
                ],
                
                // 音频内容
                if (audioUrls.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('音频', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...audioUrls.map((audioUrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // 播放按钮
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF13ec5b),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.black, size: 24),
                          ),
                          const SizedBox(width: 12),
                          // 音频波形
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(20, (index) {
                                  final height = [3, 5, 8, 6, 4, 3, 2, 5, 7, 4, 3, 5, 3, 2, 5, 7, 4, 3, 5, 3][index];
                                  return Container(
                                    width: 3,
                                    height: height.toDouble(),
                                    decoration: BoxDecoration(
                                      color: index < 5 ? const Color(0xFF13ec5b) : Colors.grey[400]!, 
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 时长占位符
                          Text('0:00', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'Monospace')),
                        ],
                      ),
                    ),
                  )),
                ],
                
                // 视频内容
                if (videoUrls.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('视频', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...videoUrls.map((videoUrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AspectRatio(
                      aspectRatio: 16/9,
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              // 使用默认图片作为视频缩略图，避免直接加载视频文件
                              image: const DecorationImage(
                                image: NetworkImage('https://picsum.photos/id/1074/800/400'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // 播放按钮
                          Positioned.fill(
                            child: Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(color: Colors.white.withAlpha(40), width: 2),
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
                
                // 标签
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 12),
                      ),
                    )).toList(),
                  ),
                ],
                
                // 操作按钮
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _showEditDiaryDialog(context, entry);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13ec5b),
                        foregroundColor: const Color(0xFF102216),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showDeleteDiaryDialog(context, entry);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('删除'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  /// 显示删除日记对话框
  void _showDeleteDiaryDialog(BuildContext context, Journal entry) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: Text(
              '确定要删除日记 "${entry.title.isNotEmpty ? entry.title : '无标题'}" 吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                context.read<DiaryBloc>().add(DeleteDiaryEntry(entry.id));
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
  
  /// 显示批量删除确认对话框
  void _showBatchDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('批量删除日记'),
          content: Text(
              '确定要删除选中的 ${_selectedEntries.length} 篇日记吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 批量删除选中的日记
                for (final entryId in _selectedEntries) {
                  context.read<DiaryBloc>().add(DeleteDiaryEntry(entryId));
                }
                // 退出多选模式
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedEntries.clear();
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
}
