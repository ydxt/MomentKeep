import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/blocs/diary_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';

/// 回收箱页面
class RecycleBinPage extends StatelessWidget {
  /// 构造函数
  const RecycleBinPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 确保回收箱数据已加载
    context.read<RecycleBinBloc>().add(LoadRecycleBin());
    return const RecycleBinView();
  }
}

/// 回收箱视图
class RecycleBinView extends ConsumerWidget {
  /// 构造函数
  const RecycleBinView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收箱'),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          TextButton(
            onPressed: () {
              _showClearConfirmationDialog(context);
            },
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor), // 使用主题主色
            child: const Text('清空'),
          ),
        ],
      ),
      body: BlocBuilder<RecycleBinBloc, RecycleBinState>(
        builder: (context, state) {
          if (state is RecycleBinLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is RecycleBinError) {
            return Center(child: Text(state.message));
          } else if (state is RecycleBinLoaded) {
            return _buildRecycleBinList(state.items);
          }
          return const Center(child: Text('暂无数据'));
        },
      ),
    );
  }

  /// 显示清空回收箱确认对话框
  void _showClearConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空回收箱'),
          content: const Text('确定要清空回收箱吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final recycleBinBloc = context.read<RecycleBinBloc>();
                final state = recycleBinBloc.state;
                
                if (state is RecycleBinLoaded) {
                  final databaseService = DatabaseService();
                  
                  // 永久删除所有项目的媒体文件
                  for (final item in state.items) {
                    switch (item.type) {
                      case 'diary':
                        final journal = Journal.fromJson(item.data);
                        await databaseService.permanentDeleteJournal(journal);
                        break;
                      case 'habit':
                        final habit = Habit.fromJson(item.data);
                        await databaseService.permanentDeleteHabit(habit);
                        break;
                      case 'todo':
                        final todo = Todo.fromJson(item.data);
                        await databaseService.permanentDeleteTodo(todo);
                        break;
                      default:
                        break;
                    }
                  }
                }
                
                recycleBinBloc.add(ClearRecycleBin());
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
  }

  /// 构建回收箱列表
  Widget _buildRecycleBinList(List<RecycleBinItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('回收箱为空'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return RecycleBinItemWidget(item: item);
      },
    );
  }
}

/// 回收箱项组件
class RecycleBinItemWidget extends StatelessWidget {
  /// 回收箱项
  final RecycleBinItem item;

  /// 构造函数
  const RecycleBinItemWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Slidable(
      // 滑动方向
      direction: Axis.horizontal,
      // 左侧滑动动作（恢复）- 按住项向右滑动显示
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              _restoreItem(context, item);
            },
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
            icon: Icons.restore,
            label: '恢复',
          ),
        ],
      ),
      // 右侧滑动动作（删除）- 按住项向左滑动显示
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              _deleteItem(context, item.id);
            },
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            icon: Icons.delete_forever,
            label: '删除',
          ),
        ],
      ),
      // 回收箱项卡片
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: ListTile(
          leading: _getItemIcon(item.type),
          title: Text(item.name),
          subtitle: Text(
            '删除于: ${_formatDate(item.deletedAt)}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: Text(
            _getItemTypeText(item.type),
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 获取项类型对应的图标
  Widget _getItemIcon(String type) {
    switch (type) {
      case 'todo':
        return const Icon(Icons.checklist, color: Colors.blue);
      case 'habit':
        return Icon(Icons.track_changes, color: AppTheme.secondaryColor);
      case 'category':
        return Icon(Icons.category, color: AppTheme.accentColor);
      case 'plan':
        return Icon(Icons.event_note, color: AppTheme.accentColor);
      case 'diary':
        return Icon(Icons.book, color: AppTheme.primaryColor);
      default:
        return const Icon(Icons.delete, color: Colors.grey);
    }
  }

  /// 获取项类型对应的文本
  String _getItemTypeText(String type) {
    switch (type) {
      case 'todo':
        return '待办事项';
      case 'habit':
        return '习惯';
      case 'category':
        return '分类';
      case 'plan':
        return '计划';
      case 'diary':
        return '日记';
      default:
        return '其他';
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 恢复项
  void _restoreItem(BuildContext context, RecycleBinItem item) {
    // 根据item.type恢复对应的实体
    switch (item.type) {
      case 'todo':
        final todo = Todo.fromJson(item.data);
        context.read<TodoBloc>().add(AddTodo(todo));
        break;
      case 'habit':
        final habit = Habit.fromJson(item.data);
        context.read<HabitBloc>().add(AddHabit(habit));
        break;
      case 'diary':
        final diary = Journal.fromJson(item.data);
        context.read<DiaryBloc>().add(AddDiaryEntry(diary));
        break;
      case 'category':
        final category = Category.fromJson(item.data);
        context.read<CategoryBloc>().add(AddCategory(category));
        break;
      default:
        break;
    }
    // 从回收箱中移除项目
    context.read<RecycleBinBloc>().add(RestoreFromRecycleBin(item.id));
  }

  /// 删除项
  void _deleteItem(BuildContext context, String itemId) {
    final recycleBinBloc = context.read<RecycleBinBloc>();
    final state = recycleBinBloc.state;
    
    if (state is RecycleBinLoaded) {
      final item = state.items.firstWhere((i) => i.id == itemId, orElse: () => throw Exception('Item not found'));
      
      // 根据item.type执行对应的永久删除操作
      final databaseService = DatabaseService();
      switch (item.type) {
        case 'diary':
          final journal = Journal.fromJson(item.data);
          databaseService.permanentDeleteJournal(journal);
          break;
        case 'habit':
          final habit = Habit.fromJson(item.data);
          databaseService.permanentDeleteHabit(habit);
          break;
        case 'todo':
          final todo = Todo.fromJson(item.data);
          databaseService.permanentDeleteTodo(todo);
          break;
        default:
          break;
      }
    }
    
    // 从回收箱中移除项目
    recycleBinBloc.add(DeleteFromRecycleBin(itemId));
  }
}
