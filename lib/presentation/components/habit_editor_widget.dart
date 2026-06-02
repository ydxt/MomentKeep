import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';

/// 习惯编辑器组件
class HabitEditorWidget extends StatefulWidget {
  /// 习惯实体
  final Habit? habit;

  /// 分类信息
  final Category category;

  /// 保存回调
  final Function(Habit) onSave;

  /// 取消回调
  final Function() onCancel;

  /// 构造函数
  const HabitEditorWidget({
    super.key,
    this.habit,
    required this.category,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<HabitEditorWidget> createState() => _HabitEditorWidgetState();
}

class _HabitEditorWidgetState extends State<HabitEditorWidget> {
  /// 名称控制器
  late TextEditingController _nameController;

  /// 内容块列表
  late List<ContentBlock> _contentBlocks;

  /// 标签列表
  late List<String> _tags;

  /// 图标
  late String _icon;

  /// 颜色
  late int _color;

  /// 频率
  late HabitFrequency _frequency;

  /// 提醒天数
  late List<int> _reminderDays;

  /// 提醒时间
  late DateTime? _reminderTime;

  /// 分类ID
  late String _categoryId;

  /// 满星数
  late int _fullStars;

  /// 自定义满星数输入控制器
  late TextEditingController _customFullStarsController;

  @override
  void initState() {
    super.initState();

    // 初始化控制器
    _nameController = TextEditingController(
      text: widget.habit?.name ?? '',
    );

    // 初始化内容块
    _contentBlocks = widget.habit?.content ?? [];

    // 初始化标签
    _tags = widget.habit?.tags ?? [];

    // 初始化图标
    _icon = widget.habit?.icon ?? 'book';

    // 初始化颜色
    _color = widget.habit?.color ?? 0xFF4CAF50;

    // 初始化频率
    _frequency = widget.habit?.frequency ?? HabitFrequency.daily;

    // 初始化提醒天数
    _reminderDays = widget.habit?.reminderDays ?? [];

    // 初始化提醒时间
    _reminderTime = widget.habit?.reminderTime;

    // 初始化分类ID
    _categoryId = widget.habit?.categoryId ?? widget.category.id;

    // 初始化满星数
    _fullStars = widget.habit?.fullStars ?? 5;

    // 初始化自定义满星数输入控制器
    _customFullStarsController =
        TextEditingController(text: _fullStars.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customFullStarsController.dispose();
    super.dispose();
  }

  /// 保存习惯
  void _saveHabit() {
    // 获取当前分类
    final currentCategory = context.read<CategoryBloc>().state is CategoryLoaded
        ? (context.read<CategoryBloc>().state as CategoryLoaded)
            .categories
            .firstWhere(
              (cat) => cat.id == _categoryId,
              orElse: () => widget.category,
            )
        : widget.category;

    final habit = Habit(
      id: widget.habit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      categoryId: _categoryId,
      category: currentCategory.name,
      name: _nameController.text,
      content: _contentBlocks,
      icon: _icon,
      color: _color,
      frequency: _frequency,
      reminderDays: _reminderDays,
      reminderTime: _reminderTime,
      currentStreak: widget.habit?.currentStreak ?? 0,
      bestStreak: widget.habit?.bestStreak ?? 0,
      totalCompletions: widget.habit?.totalCompletions ?? 0,
      history: widget.habit?.history ?? [],
      tags: _tags,
      createdAt: widget.habit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      fullStars: _fullStars,
    );

    widget.onSave(habit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑习惯'),
        backgroundColor: AppTheme.offWhite,
        foregroundColor: AppTheme.deepSpaceGray,
        actions: [
          TextButton(
            onPressed: _saveHabit,
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
            // 名称输入
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '习惯名称',
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                border: UnderlineInputBorder(),
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 分类选择
            BlocBuilder<CategoryBloc, CategoryState>(
              builder: (context, categoryState) {
                List<Category> categories = [];

                // 处理不同状态
                if (categoryState is CategoryLoaded) {
                  categories = categoryState.categories;
                } else if (categoryState is CategoryInitial) {
                  // 如果是初始状态，尝试加载分类数据
                  context
                      .read<CategoryBloc>()
                      .add(const LoadCategories(type: CategoryType.habit));
                }

                // 即使分类数据还没加载完成，也显示分类选择UI，使用默认分类
                return DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category.id,
                      child: Row(
                        children: [
                          Icon(
                            Icons.book, // 这里可以根据category.icon动态显示图标
                            color: Color(category.color),
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _categoryId = value!;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // 基本信息行
            Row(
              children: [
                // 频率选择
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<HabitFrequency>(
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      labelText: '频率',
                      border: OutlineInputBorder(),
                    ),
                    items: HabitFrequency.values.map((frequency) {
                      return DropdownMenuItem(
                        value: frequency,
                        child: Text(
                          frequency.toString().split('.').last,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _frequency = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 图标选择
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    initialValue: _icon,
                    decoration: const InputDecoration(
                      labelText: '图标',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      {'value': 'book', 'icon': Icons.book},
                      {'value': 'run', 'icon': Icons.directions_run},
                      {'value': 'code', 'icon': Icons.code},
                      {'value': 'meditate', 'icon': Icons.self_improvement},
                      {'value': 'work', 'icon': Icons.work},
                      {'value': 'home', 'icon': Icons.home},
                      {'value': 'school', 'icon': Icons.school},
                      {'value': 'shopping', 'icon': Icons.shopping_cart},
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
                      setState(() {
                        _icon = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 满星数选择
                Expanded(
                  flex: 1,
                  child: Stack(
                    children: [
                      // 当选择自定义时，显示TextField
                      if (_fullStars == 0 ||
                          ![5, 10, 15, 20, 50].contains(_fullStars))
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '满星数',
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.star, color: Color(0xFFFFD700)),
                          ),
                          controller: _customFullStarsController,
                          onChanged: (value) {
                            final int? customValue = int.tryParse(value);
                            if (customValue != null && customValue > 0) {
                              setState(() {
                                _fullStars = customValue;
                              });
                            }
                          },
                          autofocus: true,
                        ),
                      // 当选择预设值时，显示DropdownButtonFormField
                      if (_fullStars != 0 &&
                          [5, 10, 15, 20, 50].contains(_fullStars))
                        DropdownButtonFormField<int>(
                          value: _fullStars,
                          decoration: const InputDecoration(
                            labelText: '满星数',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            // 预设选项
                            for (int value in [5, 10, 15, 20, 50])
                              DropdownMenuItem<int>(
                                value: value,
                                child: Row(
                                  children: [
                                    Text('$value'),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.star,
                                        color: Color(0xFFFFD700), size: 16),
                                  ],
                                ),
                              ),
                            // 自定义选项
                            const DropdownMenuItem<int>(
                              value: 0,
                              child: Row(
                                children: [
                                  const Text('自定义'),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit,
                                      color: Color(0xFFFFD700), size: 16),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (int? value) {
                            setState(() {
                              if (value != null && value != 0) {
                                _fullStars = value;
                                _customFullStarsController.text =
                                    value.toString();
                              } else {
                                // 选择自定义选项时，将_fullStars设置为0，保持TextField显示
                                _fullStars = 0;
                                _customFullStarsController.text = '';
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 颜色选择
            Row(
              children: [
                const Text('颜色:'),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _buildColorOption(0xFF4CAF50),
                      _buildColorOption(0xFF2196F3),
                      _buildColorOption(0xFF9C27B0),
                      _buildColorOption(0xFFFF9800),
                      _buildColorOption(0xFFF44336),
                      _buildColorOption(0xFFE91E63),
                      _buildColorOption(0xFF009688),
                      _buildColorOption(0xFF673AB7),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 提醒设置
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '提醒设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 提醒时间选择
                    Row(
                      children: [
                        const Text('提醒时间:'),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: _reminderTime != null
                                  ? TimeOfDay.fromDateTime(_reminderTime!)
                                  : TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                _reminderTime = DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                  DateTime.now().day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          },
                          child: Text(
                            _reminderTime != null
                                ? '${_reminderTime!.hour}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                                : '选择时间',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 提醒天数选择
                if (_frequency == HabitFrequency.weekly) ...[
                  const Text('提醒天数:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildDayOption(0, '日'),
                      _buildDayOption(1, '一'),
                      _buildDayOption(2, '二'),
                      _buildDayOption(3, '三'),
                      _buildDayOption(4, '四'),
                      _buildDayOption(5, '五'),
                      _buildDayOption(6, '六'),
                    ],
                  ),
                ],
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

            // 使用通用富媒体编辑器
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

  /// 构建颜色选项
  Widget _buildColorOption(int colorValue) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _color = colorValue;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(20),
          border: _color == colorValue
              ? Border.all(color: AppTheme.primaryColor, width: 3)
              : null,
        ),
      ),
    );
  }

  /// 构建星期选项
  Widget _buildDayOption(int dayIndex, String dayName) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_reminderDays.contains(dayIndex)) {
            _reminderDays.remove(dayIndex);
          } else {
            _reminderDays.add(dayIndex);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _reminderDays.contains(dayIndex)
              ? AppTheme.primaryColor
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          dayName,
          style: TextStyle(
            color:
                _reminderDays.contains(dayIndex) ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
