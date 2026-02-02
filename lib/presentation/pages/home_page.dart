import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/security.dart';
import 'package:moment_keep/presentation/pages/new_settings_page.dart';
import 'package:moment_keep/presentation/pages/diary_page.dart';
import 'package:moment_keep/presentation/pages/todo_page.dart';
import 'package:moment_keep/presentation/pages/habit_page.dart';
import 'package:moment_keep/presentation/pages/todo_detail_page.dart';
import 'package:moment_keep/presentation/pages/habit_detail_dialog.dart';
import 'package:moment_keep/presentation/components/navigation_provider.dart';
import 'package:moment_keep/presentation/components/minimal_journal_editor.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'client_message_center_page.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/blocs/diary_bloc.dart';
import 'package:moment_keep/presentation/pages/pomodoro_page.dart';
import 'package:moment_keep/presentation/pages/dashboard_page.dart';
import 'package:moment_keep/presentation/pages/star_exchange_page.dart';
import 'package:moment_keep/presentation/pages/recycle_bin_page.dart';

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

/// 主界面页面
class HomePage extends ConsumerStatefulWidget {
  /// 构造函数
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}



class _HomePageState extends ConsumerState<HomePage> {
  /// 当前时间
  late DateTime _currentTime;
  
  /// 通知服务实例
  final NotificationDatabaseService _notificationService = NotificationDatabaseService();
  
  /// 通知数量
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    // 初始化当前时间
    _currentTime = DateTime.now();
    // 加载未读消息数量
    _loadUnreadNotificationCount();
    // 加载待办事项、习惯和日记数据
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        context.read<TodoBloc>().add(LoadTodos());
        context.read<HabitBloc>().add(LoadHabits());
        context.read<DiaryBloc>().add(LoadDiaryEntries());
      }
    });
  }

  /// 加载未读消息数量
  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      setState(() {
        _notificationCount = count;
      });
    } catch (e) {
      print('加载未读消息数量失败: $e');
      // 出错时保持默认值0
    }
  }
  


  /// 格式化日期
  String _formatDate(DateTime date) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    return '${weekdays[date.weekday - 1]}，${months[date.month - 1]}${date.day}日';
  }

  /// 格式化问候语
  String _getGreeting(DateTime date) {
    final hour = date.hour;
    if (hour < 12) {
      return '早上好';
    } else if (hour < 18) {
      return '下午好';
    } else {
      return '晚上好';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      body: SafeArea(
        child: BlocBuilder<SecurityBloc, SecurityState>(
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
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(theme, user),
                  const SizedBox(height: 24),

                  // Stats Overview
                  _buildStatsOverview(theme),
                  const SizedBox(height: 24),

                  // Today's Focus (TODOs)
                  _buildTodayFocus(theme),
                  const SizedBox(height: 24),

                  // Habits
                  _buildHabits(theme),
                  const SizedBox(height: 24),

                  // Recent Memory
                  _buildRecentMemory(theme),
                  const SizedBox(height: 24),

                  // More Features
                  _buildMoreFeatures(theme),
                  const SizedBox(height: 60),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建Header
  Widget _buildHeader(ThemeData theme, UserAuth? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // 头像 - 可点击进入个人设置
            GestureDetector(
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
            ),
            const SizedBox(width: 12),
            // 日期和问候语
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(_currentTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_getGreeting(_currentTime)}, ${user?.username ?? '用户'}',
                  style: TextStyle(
                    fontSize: 20,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        // 通知按钮
        GestureDetector(
          onTap: () {
            // 导航到客户端消息中心页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ClientMessageCenterPage(),
              ),
            );
          },
          child: Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
              ),
              if (_notificationCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _notificationCount.toString(),
                      style: TextStyle(
                        color: theme.colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建Stats Overview
  Widget _buildStatsOverview(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Productivity Score
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.show_chart,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '效率',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '85%',
                          style: TextStyle(
                            fontSize: 32,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              color: theme.colorScheme.primary,
                              size: 16,
                            ),
                            Text(
                              '5%',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 0.85,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Focus Button
        GestureDetector(
          onTap: () {
            // 更新导航索引为番茄钟页面（索引为4）
            ref.read(navigationProvider.notifier).setIndex(4);
          },
          child: Container(
            width: 96,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '专注',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建Today's Focus (TODOs)
  Widget _buildTodayFocus(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '待办事项',
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            GestureDetector(
              onTap: () {
                // 导航到待办事项页面
                ref.read(navigationProvider.notifier).setIndex(1);
              },
              child: Text(
                '查看全部',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Task List - 从TodoBloc获取数据
        BlocBuilder<TodoBloc, TodoState>(
          builder: (context, todoState) {
            List<Todo> todos = [];
            if (todoState is TodoLoaded) {
              todos = todoState.todos;
            }
            
            // 限制显示前3个待办事项
            final displayTodos = todos.take(3).toList();
            
            return Column(
              children: List.generate(displayTodos.length, (index) {
                final todo = displayTodos[index];
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // 点击待办事项项，导航到待办事项详情页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TodoDetailPage(todo: todo),
                          ),
                        );
                      },
                      child: _buildTaskItem(
                        todo: todo,
                        onToggle: () {
                          // 使用TodoBloc切换待办事项完成状态
                          context.read<TodoBloc>().add(ToggleTodoCompletion(todo.id));
                        },
                        theme: theme,
                      ),
                    ),
                    if (index < displayTodos.length - 1)
                      const SizedBox(height: 12),
                  ],
                );
              }),
            );
          },
        ),
      ],
    );
  }

  /// 构建Task Item
  Widget _buildTaskItem({
    required Todo todo,
    required VoidCallback onToggle,
    required ThemeData theme,
  }) {
    // 获取优先级文本
    String priorityText = '中优先级';
    switch (todo.priority) {
      case TodoPriority.high:
        priorityText = '高优先级';
        break;
      case TodoPriority.medium:
        priorityText = '中优先级';
        break;
      case TodoPriority.low:
        priorityText = '低优先级';
        break;
    }
    
    // 获取时间文本
    String timeText = '未设置时间';
    if (todo.date != null) {
      timeText = '${todo.date!.month}/${todo.date!.day} ${todo.date!.hour}:${todo.date!.minute.toString().padLeft(2, '0')}';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: todo.isCompleted,
            onChanged: (value) => onToggle(),
            activeColor: theme.colorScheme.primary,
            checkColor: theme.colorScheme.onPrimary,
            side: BorderSide(
              color: theme.colorScheme.surfaceVariant,
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          // Task Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$priorityText • $timeText',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Progress Indicator
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: todo.isCompleted 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建Habits
  Widget _buildHabits(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '习惯',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                // 导航到习惯页面
                ref.read(navigationProvider.notifier).setIndex(2);
              },
              child: Text(
                '查看全部',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Habit List - 从HabitBloc获取数据
        BlocBuilder<HabitBloc, HabitState>(
          builder: (context, habitState) {
            List<Habit> habits = [];
            if (habitState is HabitLoaded) {
              habits = habitState.habits;
            }
            
            // 限制显示前3个习惯
            final displayHabits = habits.take(3).toList();
            
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(displayHabits.length, (index) {
                  final habit = displayHabits[index];
                  
                  // 尝试获取图标
                  IconData icon = Icons.water_drop;
                  try {
                    if (habit.icon != null && habit.icon!.isNotEmpty) {
                      icon = IconData(int.parse(habit.icon!), fontFamily: 'MaterialIcons');
                    }
                  } catch (e) {
                    // 如果图标解析失败，使用默认图标
                  }
                  
                  // 尝试获取颜色
                  Color color = const Color.fromARGB(255, 66, 135, 245);
                  try {
                    if (habit.color != null) {
                      color = Color(habit.color!);
                    }
                  } catch (e) {
                    // 如果颜色解析失败，使用默认颜色
                  }
                  
                  // 检查今天是否已经打卡
                  bool isCheckedInToday = _isHabitCheckedInToday(habit);
                  
                  // 根据打卡状态计算进度
                  double progress = isCheckedInToday ? 1.0 : 0.0;
                  
                  return SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        // 图标区域 - 点击进入详情页
                        GestureDetector(
                          onTap: () {
                            // 点击图标区域，导航到习惯详情页面
                            final categories = <Category>[Category(
                                id: habit.categoryId ?? '',
                                name: habit.category ?? '未分类',
                                type: CategoryType.habit,
                                color: habit.color ?? const Color.fromARGB(255, 66, 135, 245).value,
                                icon: Icons.fitness_center.codePoint.toString(),
                              ),
                            ];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HabitDetailDialog(
                                  habit: habit,
                                  categories: categories,
                                ),
                              ),
                            );
                          },
                          child: _buildHabitIcon(
                            icon: icon,
                            progress: progress,
                            color: color,
                            theme: theme,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          habit.name ?? '未命名习惯',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 打卡状态区域 - 点击进行打卡
                        GestureDetector(
                          onTap: () {
                            // 点击打卡状态区域，显示打卡对话框
                            _showCheckInDialog(context, habit);
                          },
                          child: Text(
                            isCheckedInToday ? '已打卡' : '未打卡',
                            style: TextStyle(
                              fontSize: 10,
                              color: isCheckedInToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建Habit Icon
  Widget _buildHabitIcon({
    required IconData icon,
    required double progress,
    required Color color,
    required ThemeData theme,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeCap: StrokeCap.round,
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ],
    );
  }

  /// 构建最新日记
  Widget _buildRecentMemory(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                  '最新日记',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            GestureDetector(
              onTap: () {
                // 导航到日记页面
                ref.read(navigationProvider.notifier).setIndex(4);
              },
              child: Text(
                '查看全部',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Memory Card - 从DiaryBloc获取数据
        BlocBuilder<DiaryBloc, DiaryState>(
          builder: (context, diaryState) {
            List<Journal> diaries = [];
            if (diaryState is DiaryLoaded) {
              diaries = diaryState.entries;
            }
            
            // 按日期排序，获取最新的日记
            diaries.sort((a, b) => b.date!.compareTo(a.date!));
            final latestDiary = diaries.isNotEmpty ? diaries.first : null;
            
            if (latestDiary == null) {
              // 如果没有日记，显示默认卡片
              return GestureDetector(
                onTap: () {
                  // 创建一个新日记
                  final journal = Journal(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    categoryId: '',
                    title: '新日记',
                    content: [
                      ContentBlock(
                        id: '1',
                        type: ContentBlockType.text,
                        data: jsonEncode([
                          {'insert': '开始写日记...\n'},
                        ]),
                        orderIndex: 0,
                        attributes: {'type': 'quill'},
                      ),
                    ],
                    tags: [],
                    date: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  
                  final category = Category(
                    id: '',
                    name: '未分类',
                    type: CategoryType.journal,
                    icon: Icons.note.codePoint.toString(),
                    color: const Color(0xFF4CAF50).value,
                    isExpanded: true,
                  );
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MinimalJournalEditor(
                        journal: journal,
                        category: category,
                        onSave: (updatedJournal) {
                          Navigator.pop(context);
                        },
                        onCancel: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      height: 192,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: theme.cardTheme.color,
                        image: const DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
                          fit: BoxFit.cover,
                          opacity: 0.7,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.9),
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit,
                          color: theme.colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '点击创建新日记',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '记录你的想法和感受...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // 有日记时，显示最新的日记
            return GestureDetector(
              onTap: () {
                // 导航到日记详情页面
                final category = Category(
                  id: latestDiary.categoryId ?? '',
                  name: latestDiary.tags.isNotEmpty ? latestDiary.tags[0] : '未分类',
                  type: CategoryType.journal,
                  icon: Icons.note.codePoint.toString(),
                  color: const Color(0xFF4CAF50).value,
                  isExpanded: true,
                );
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MinimalJournalEditor(
                      journal: latestDiary,
                      category: category,
                      onSave: (updatedJournal) {
                        Navigator.pop(context);
                      },
                      onCancel: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    height: 192,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: theme.cardTheme.color,
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
                        fit: BoxFit.cover,
                        opacity: 0.7,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.9),
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${latestDiary.date!.year}年${latestDiary.date!.month}月${latestDiary.date!.day}日 - ${latestDiary.title}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${latestDiary.content.isNotEmpty ? _getDiaryPreview(latestDiary.content) : '无内容'}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
  
  /// 获取日记预览内容
  String _getDiaryPreview(List<ContentBlock> content) {
    if (content.isEmpty) return '无内容';
    
    try {
      final firstBlock = content[0];
      if (firstBlock.type == ContentBlockType.text && firstBlock.data != null) {
        final data = jsonDecode(firstBlock.data!) as List;
        if (data.isNotEmpty && data[0] is Map && data[0].containsKey('insert')) {
          final text = data[0]['insert'] as String;
          return text.length > 50 ? '${text.substring(0, 50)}...' : text;
        }
      }
    } catch (e) {
      // 解析失败，返回默认值
    }
    
    return '查看日记内容...';
  }
  
  /// 检查习惯今天是否已经打卡
  bool _isHabitCheckedInToday(Habit habit) {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    
    // 检查 history 字段，与 RecordHabitCompletion 事件处理中的逻辑保持一致
    return habit.history.contains(today);
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

  /// 构建更多功能部分
  Widget _buildMoreFeatures(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '更多功能',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            // 番茄钟
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PomodoroPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.access_alarm,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '番茄钟',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '专注时间管理',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // 数据统计
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '数据统计',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '习惯和任务分析',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // 积分兑换
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StarExchangePage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_mall,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '积分兑换',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '用积分兑换奖励',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // 回收箱
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RecycleBinPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '回收箱',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '恢复已删除的内容',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建Bottom Navigation
  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.all(24),
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1a3524).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.dashboard,
            label: 'Home',
            isActive: true,
          ),
          _buildNavItem(
            icon: Icons.calendar_month,
            label: 'Plan',
            isActive: false,
          ),
          // Add Button
          Transform.translate(
            offset: const Offset(0, -20),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF13ec5b),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13ec5b).withOpacity(0.4),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
          _buildNavItem(
            icon: Icons.timer,
            label: 'Focus',
            isActive: false,
          ),
          _buildNavItem(
            icon: Icons.settings,
            label: 'Settings',
            isActive: false,
          ),
        ],
      ),
    );
  }

  /// 构建Nav Item
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? const Color(0xFF13ec5b) : Colors.grey,
          size: 26,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? const Color(0xFF13ec5b) : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
