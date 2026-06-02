import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';

/// 待办事项编辑器组件
class TodoEditorWidget extends StatefulWidget {
  /// 待办事项实体
  final Todo? todo;

  /// 分类信息
  final Category category;

  /// 保存回调
  final Function(Todo) onSave;

  /// 取消回调
  final Function() onCancel;

  /// 构造函数
  const TodoEditorWidget({
    super.key,
    this.todo,
    required this.category,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<TodoEditorWidget> createState() => _TodoEditorWidgetState();
}

class _TodoEditorWidgetState extends State<TodoEditorWidget> {
  /// 标题控制器
  late TextEditingController _titleController;

  /// 内容块列表
  late List<ContentBlock> _contentBlocks;

  /// 标签列表
  late List<String> _tags;

  /// 优先级
  late TodoPriority _priority;

  /// 截止日期
  late DateTime? _dueDate;

  /// 开始日期
  late DateTime? _startDate;

  /// 提醒时间
  late DateTime? _reminderTime;

  /// 是否完成
  late bool _isCompleted;

  /// 分类ID
  late String _categoryId;

  @override
  void initState() {
    super.initState();
    // 初始化控制器和状态
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _contentBlocks = widget.todo?.content ?? [];
    _tags = widget.todo?.tags ?? [];
    _priority = widget.todo?.priority ?? TodoPriority.medium;
    _dueDate = widget.todo?.date;
    _startDate = widget.todo?.startDate;
    _reminderTime = widget.todo?.reminderTime;
    _isCompleted = widget.todo?.isCompleted ?? false;
    _categoryId = widget.todo?.categoryId ?? widget.category.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// 保存待办事项
  void _saveTodo() {
    final todo = Todo(
      id: widget.todo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      content: _contentBlocks,
      tags: _tags,
      priority: _priority,
      startDate: _startDate,
      date: _dueDate,
      reminderTime: _reminderTime,
      isCompleted: _isCompleted,
      categoryId: _categoryId,
      createdAt: widget.todo?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(todo);
  }

  /// 显示添加分类对话框
  Future<bool?> _showAddCategoryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String icon = 'work';
    int color = 0xFF4CAF50;

    return showDialog<bool>(
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
                    {'value': 'work', 'icon': Icons.work},
                    {'value': 'home', 'icon': Icons.home},
                    {'value': 'school', 'icon': Icons.school},
                    {'value': 'shopping', 'icon': Icons.shopping_cart},
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
                    DropdownMenuItem(
                        value: 0xFF4CAF50, child: const Text('绿色')),
                    DropdownMenuItem(
                        value: 0xFF2196F3, child: const Text('蓝色')),
                    DropdownMenuItem(
                        value: 0xFF9C27B0, child: const Text('紫色')),
                    DropdownMenuItem(
                        value: 0xFFFF9800, child: const Text('橙色')),
                    DropdownMenuItem(
                        value: 0xFFF44336, child: const Text('红色')),
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
                Navigator.pop(context, false); // 返回false表示取消
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final newCategory = Category(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: CategoryType.todo,
                    icon: icon,
                    color: color,
                    isExpanded: true,
                  );
                  context.read<CategoryBloc>().add(AddCategory(newCategory));
                  // 设置新分类为当前选择的分类
                  setState(() {
                    _categoryId = newCategory.id;
                  });
                  Navigator.pop(context, true); // 返回true表示成功添加
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑待办事项'),
        backgroundColor: AppTheme.offWhite,
        foregroundColor: AppTheme.deepSpaceGray,
        actions: [
          TextButton(
            onPressed: _saveTodo,
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.deepSpaceGray),
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题输入
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                border: UnderlineInputBorder(),
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 分类、优先级和完成状态行
            Row(
              children: [
                // 分类选择
                Expanded(
                  child: BlocBuilder<CategoryBloc, CategoryState>(
                    builder: (context, state) {
                      List<Category> categories = [];

                      // 处理不同状态
                      if (state is CategoryLoaded) {
                        categories = state.categories;
                      } else if (state is CategoryInitial) {
                        // 如果是初始状态，尝试加载分类数据
                        context
                            .read<CategoryBloc>()
                            .add(const LoadCategories(type: CategoryType.todo));
                      }

                      // 即使分类数据还没加载完成，也显示分类选择UI，使用默认分类
                      // 添加"新建"选项到分类列表
                      final dropdownItems = <DropdownMenuItem<String>>[
                        ...categories.map((category) {
                          return DropdownMenuItem(
                            value: category.id,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.work, // 这里可以根据category.icon动态显示图标
                                  color: Color(category.color),
                                ),
                                const SizedBox(width: 8),
                                Text(category.name),
                              ],
                            ),
                          );
                        }).toList(),
                        // 添加"新建"选项
                        const DropdownMenuItem(
                          value: 'new_category',
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('新建分类'),
                            ],
                          ),
                        ),
                      ];

                      return DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        value: _categoryId,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          border: OutlineInputBorder(),
                        ),
                        items: dropdownItems,
                        onChanged: (value) async {
                          if (value == 'new_category') {
                            // 保存当前分类ID
                            final originalCategoryId = _categoryId;
                            // 调用新建分类对话框并等待结果
                            final result =
                                await _showAddCategoryDialog(context);
                            // 如果用户取消了对话框，重置为原始分类ID
                            if (result == null) {
                              setState(() {
                                _categoryId = originalCategoryId;
                              });
                            }
                          } else {
                            setState(() {
                              _categoryId = value!;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 优先级选择
                Expanded(
                  child: DropdownButtonFormField<TodoPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: '优先级',
                      border: OutlineInputBorder(),
                    ),
                    items: TodoPriority.values.map((priority) {
                      String priorityText;
                      switch (priority) {
                        case TodoPriority.high:
                          priorityText = '高';
                          break;
                        case TodoPriority.medium:
                          priorityText = '中';
                          break;
                        case TodoPriority.low:
                          priorityText = '低';
                          break;
                      }
                      return DropdownMenuItem(
                        value: priority,
                        child: Text(priorityText),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _priority = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 完成状态
                Row(
                  children: [
                    const Text('已完成:'),
                    Switch(
                      value: _isCompleted,
                      onChanged: (value) {
                        setState(() {
                          _isCompleted = value;
                        });
                      },
                      activeThumbColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 日期时间选择
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 开始日期选择 - 标签和选择按钮在同一行
                Row(
                  children: [
                    const Text('开始日期:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _startDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                _startDate?.hour ?? DateTime.now().hour,
                                _startDate?.minute ?? DateTime.now().minute,
                              );
                            });
                          }
                        },
                        child: Text(
                          _startDate != null
                              ? '${_startDate!.year}-${_startDate!.month}-${_startDate!.day}'
                              : '选择日期',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: _startDate != null
                                ? TimeOfDay.fromDateTime(_startDate!)
                                : TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _startDate = DateTime(
                                _startDate?.year ?? DateTime.now().year,
                                _startDate?.month ?? DateTime.now().month,
                                _startDate?.day ?? DateTime.now().day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        },
                        child: Text(
                          _startDate != null
                              ? '${_startDate!.hour}:${_startDate!.minute.toString().padLeft(2, '0')}'
                              : '选择时间',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 截止日期选择 - 标签和选择按钮在同一行
                Row(
                  children: [
                    const Text('截止日期:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _dueDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                _dueDate?.hour ?? DateTime.now().hour,
                                _dueDate?.minute ?? DateTime.now().minute,
                              );
                            });
                          }
                        },
                        child: Text(
                          _dueDate != null
                              ? '${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}'
                              : '选择日期',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: _dueDate != null
                                ? TimeOfDay.fromDateTime(_dueDate!)
                                : TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _dueDate = DateTime(
                                _dueDate?.year ?? DateTime.now().year,
                                _dueDate?.month ?? DateTime.now().month,
                                _dueDate?.day ?? DateTime.now().day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        },
                        child: Text(
                          _dueDate != null
                              ? '${_dueDate!.hour}:${_dueDate!.minute.toString().padLeft(2, '0')}'
                              : '选择时间',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 内容编辑区标题
            const Text(
              '详情',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 内容编辑区
            RichTextEditor(
              initialContent: _contentBlocks,
              onContentChanged: (content) {
                setState(() {
                  _contentBlocks = content;
                });
              },
              readOnly: false,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
