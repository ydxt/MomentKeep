import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';

/// 待办事项详细信息页面
class TodoDetailPage extends ConsumerStatefulWidget {
  /// 待办事项
  final Todo todo;

  /// 构造函数
  const TodoDetailPage({super.key, required this.todo});

  @override
  ConsumerState<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends ConsumerState<TodoDetailPage> {
  /// 标题控制器
  late TextEditingController _titleController;
  
  /// 内容块列表
  late List<ContentBlock> _contentBlocks;
  
  /// 是否已修改
  bool _isModified = false;
  
  /// 开始时间
  late DateTime? _startTime;
  /// 结束时间
  late DateTime? _endTime;
  /// 当前优先级
  late TodoPriority _currentPriority;
  /// 当前分类
  late String _currentCategory;
  /// 当前完成状态
  late bool _currentIsCompleted;
  
  @override
  void initState() {
    super.initState();
    // 初始化控制器和状态
    _titleController = TextEditingController(text: widget.todo.title);
    _contentBlocks = List.from(widget.todo.content);
    _startTime = widget.todo.startDate;
    _endTime = widget.todo.date;
    _currentPriority = widget.todo.priority;
    _currentCategory = widget.todo.categoryId ?? '生活';
    _currentIsCompleted = widget.todo.isCompleted;
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
  
  /// 保存修改
  void _saveChanges() {
    final updatedTodo = Todo(
      id: widget.todo.id,
      title: _titleController.text,
      content: _contentBlocks,
      tags: widget.todo.tags,
      priority: _currentPriority,
      startDate: _startTime,
      date: _endTime,
      reminderTime: widget.todo.reminderTime,
      isCompleted: _currentIsCompleted,
      categoryId: _currentCategory,
      createdAt: widget.todo.createdAt,
      updatedAt: DateTime.now(),
    );
    
    // 发送更新事件
    context.read<TodoBloc>().add(UpdateTodo(updatedTodo));
    
    // 返回上一页
    Navigator.pop(context);
  }
  
  /// 显示时间选择器
  Future<void> _showTimePicker(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final currentDate = isStartTime ? _startTime : _endTime;
      final now = DateTime.now();
      final newTime = DateTime(
        currentDate?.year ?? now.year,
        currentDate?.month ?? now.month,
        currentDate?.day ?? now.day,
        picked.hour,
        picked.minute,
      );
      
      setState(() {
        if (isStartTime) {
          _startTime = newTime;
          // 如果结束时间早于开始时间，自动更新结束时间
          if (_endTime != null && _endTime!.isBefore(newTime)) {
            _endTime = newTime.add(const Duration(hours: 1));
          }
        } else {
          _endTime = newTime;
          // 如果结束时间早于开始时间，自动更新结束时间为开始时间+1小时
          if (_startTime != null && newTime.isBefore(_startTime!)) {
            _endTime = _startTime!.add(const Duration(hours: 1));
          }
        }
        _isModified = true;
      });
    }
  }
  
  /// 显示优先级选择器
  Future<void> _showPriorityPicker() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.surface,
          title: Text(
            '选择优先级',
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('高优先级'),
                leading: Icon(Icons.flag, color: const Color(0xFFFF4757)),
                onTap: () => Navigator.pop(context, 'high'),
              ),
              ListTile(
                title: Text('中优先级'),
                leading: Icon(Icons.flag, color: const Color(0xFFFFA502)),
                onTap: () => Navigator.pop(context, 'medium'),
              ),
              ListTile(
                title: Text('低优先级'),
                leading: Icon(Icons.flag, color: const Color(0xFF2ED573)),
                onTap: () => Navigator.pop(context, 'low'),
              ),
            ],
          ),
        );
      },
    );
    
    if (result != null) {
      setState(() {
        switch (result) {
          case 'high':
            _currentPriority = TodoPriority.high;
            break;
          case 'medium':
            _currentPriority = TodoPriority.medium;
            break;
          case 'low':
            _currentPriority = TodoPriority.low;
            break;
        }
        _isModified = true;
      });
    }
  }
  
  /// 显示分类选择器
  Future<void> _showCategoryPicker() async {
    // 从CategoryBloc获取分类列表
    final categoryBloc = context.read<CategoryBloc>();
    
    // 确保分类已加载
    if (categoryBloc.state is! CategoryLoaded) {
      categoryBloc.add(const LoadCategories(type: CategoryType.todo));
    }
    
    // 等待分类加载完成
    final categories = await _loadCategories();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.surface,
          title: Text(
            '选择分类',
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: categories.map((category) {
              return ListTile(
                title: Text(category.name),
                leading: Icon(Icons.category),
                onTap: () => Navigator.pop(context, category.name),
              );
            }).toList(),
          ),
        );
      },
    );
    
    if (result != null) {
      setState(() {
        _currentCategory = result;
        _isModified = true;
      });
    }
  }
  
  /// 加载分类列表
  Future<List<Category>> _loadCategories() async {
    final categoryBloc = context.read<CategoryBloc>();
    
    // 等待分类加载完成
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (categoryBloc.state is CategoryLoaded) {
      return (categoryBloc.state as CategoryLoaded).categories;
    }
    
    // 如果没有加载成功，返回默认分类
    return [
      Category(id: '1', name: '工作', type: CategoryType.todo, icon: 'work', color: 0xFF4285F4),
      Category(id: '2', name: '生活', type: CategoryType.todo, icon: 'home', color: 0xFF34A853),
      Category(id: '3', name: '学习', type: CategoryType.todo, icon: 'school', color: 0xFFFBBC05),
      Category(id: '4', name: '健康', type: CategoryType.todo, icon: 'fitness_center', color: 0xFFEA4335),
      Category(id: '5', name: '其他', type: CategoryType.todo, icon: 'more_horiz', color: 0xFF9AA0A6),
    ];
  }
  
  /// 切换任务状态
  void _toggleTaskStatus() {
    setState(() {
      _currentIsCompleted = !_currentIsCompleted;
      _isModified = true;
    });
  }
  
  /// 显示添加标签对话框
  Future<void> _showAddTagDialog(ThemeData theme) async {
    final TextEditingController tagController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          surfaceTintColor: theme.colorScheme.surface,
          title: Text(
            '添加标签',
            style: TextStyle(color: theme.colorScheme.onBackground),
          ),
          content: TextField(
            controller: tagController,
            decoration: InputDecoration(
              hintText: '输入标签名称',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            style: TextStyle(color: theme.colorScheme.onBackground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tagController.text.trim()),
              child: Text(
                '添加',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        widget.todo.tags.add(result);
        _isModified = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '任务详情',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // 只有当内容被修改时，才显示保存按钮
          if (_isModified)
            TextButton(
              onPressed: _saveChanges,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 任务标题（可编辑）
              TextField(
                controller: _titleController,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '输入任务标题',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onChanged: (text) {
                  setState(() {
                    _isModified = true;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // 任务元信息
              _buildMetaInfo(theme),
              const SizedBox(height: 24),
              
              // 任务状态
              _buildStatusSection(theme),
              const SizedBox(height: 24),
              
              // 详细内容
              _buildContentSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示日期选择器
  Future<void> _showDatePicker(bool isStartTime) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (_startTime ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final currentTime = (_startTime ?? DateTime.now());
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        currentTime.hour,
        currentTime.minute,
      );
      
      setState(() {
        if (isStartTime) {
          _startTime = newDateTime;
          // 如果结束时间早于开始时间，自动更新结束时间
          if (_endTime != null && _endTime!.isBefore(newDateTime)) {
            _endTime = newDateTime.add(const Duration(hours: 1));
          }
        } else {
          _endTime = newDateTime;
          // 如果结束时间早于开始时间，自动更新结束时间为开始时间+1小时
          if (_startTime != null && newDateTime.isBefore(_startTime!)) {
            _endTime = _startTime!.add(const Duration(hours: 1));
          }
        }
        _isModified = true;
      });
    }
  }
  
  /// 构建任务元信息
  Widget _buildMetaInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期和时间
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.schedule, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // 开始时间
                    InkWell(
                      onTap: () => _showDatePicker(true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _startTime != null
                                ? '${_startTime!.month}/${_startTime!.day}'
                                : '未设置日期',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showTimePicker(true),
                            child: Text(
                              _startTime != null
                                  ? '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                  : '未设置时间',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 连接符
                    Text(
                      '至',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    // 结束时间
                    InkWell(
                      onTap: () => _showDatePicker(false),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _endTime != null
                                ? '${_endTime!.month}/${_endTime!.day}'
                                : '未设置日期',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showTimePicker(false),
                            child: Text(
                              _endTime != null
                                  ? '${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                  : '未设置时间',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 优先级和分类在同一行
          Row(
            children: [
              // 优先级
              Expanded(
                child: GestureDetector(
                  onTap: _showPriorityPicker,
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: _getPriorityColor(_currentPriority)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getPriorityText(_currentPriority),
                          style: TextStyle(color: _getPriorityColor(_currentPriority)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              // 分类
              Expanded(
                child: GestureDetector(
                  onTap: _showCategoryPicker,
                  child: Row(
                    children: [
                      Icon(Icons.category, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentCategory,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 标签标题
                  Text(
                    '标签',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  // 标签列表
                  ...widget.todo.tags.map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline, width: 1),
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
                            style: TextStyle(color: theme.colorScheme.onBackground),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                widget.todo.tags.remove(tag);
                                _isModified = true;
                              });
                            },
                            child: Icon(
                              Icons.close, 
                              size: 16, 
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                  // 添加标签按钮
                  GestureDetector(
                    onTap: () {
                      _showAddTagDialog(theme);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 12,
                      ),
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

  /// 构建任务状态部分
  Widget _buildStatusSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '任务状态:',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleTaskStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _currentIsCompleted ? theme.colorScheme.secondary : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _currentIsCompleted ? '已完成' : '未完成',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内容部分
  Widget _buildContentSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '详细内容',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // 详细内容编辑器（可编辑模式）
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
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
            isQuestionBank: false,
          ),
        ),
      ],
    );
  }

  /// 获取优先级颜色
  Color _getPriorityColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return const Color(0xFFFF4757);
      case TodoPriority.medium:
        return const Color(0xFFFFA502);
      case TodoPriority.low:
        return const Color(0xFF2ED573);
    }
  }

  /// 获取优先级文本
  String _getPriorityText(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return '高优先级';
      case TodoPriority.medium:
        return '中优先级';
      case TodoPriority.low:
        return '低优先级';
    }
  }
}
