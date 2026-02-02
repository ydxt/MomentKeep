import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 添加习惯页面
class AddHabitPage extends StatelessWidget {
  /// 要编辑的习惯（可选）
  final Habit? habit;
  
  /// 构造函数
  const AddHabitPage({super.key, this.habit});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, categoryState) {
        if (categoryState is CategoryLoaded) {
          return AddHabitView(categories: categoryState.categories, habit: habit);
        } else if (categoryState is CategoryInitial) {
          // 如果是初始状态，尝试加载分类数据
          context.read<CategoryBloc>().add(const LoadCategories(type: CategoryType.habit));
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(child: Text('加载分类失败'));
      },
    );
  }
}

/// 添加习惯视图
class AddHabitView extends ConsumerStatefulWidget {
  /// 分类列表
  final List<Category> categories;
  
  /// 要编辑的习惯（可选）
  final Habit? habit;

  /// 构造函数
  const AddHabitView({super.key, required this.categories, this.habit});

  @override
  ConsumerState<AddHabitView> createState() => _AddHabitViewState();
}

class _AddHabitViewState extends ConsumerState<AddHabitView> {
  /// 习惯名称控制器
  late TextEditingController _nameController;
  
  /// 内容块列表
  late List<ContentBlock> _contentBlocks;
  
  /// 重复周期
  late HabitFrequency _frequency;
  
  /// 每周选择的天数
  late List<int> _selectedDays;
  
  /// 满星数
  late int _fullStars;
  
  /// 提醒开关
  late bool _isReminderEnabled;
  
  /// 提醒时间
  late TimeOfDay _reminderTime;
  
  /// 选中的分类ID
  late String? _selectedCategoryId;
  
  /// 卡片主题色
  late int _cardColor;
  
  /// 选中的图标
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    
    // 检查是否是编辑模式
    if (widget.habit != null) {
      // 编辑模式：使用现有习惯数据初始化
      final habit = widget.habit!;
      
      _nameController = TextEditingController(text: habit.name);
      _contentBlocks = List.from(habit.content);
      _frequency = habit.frequency;
      _selectedDays = List.from(habit.reminderDays);
      _fullStars = habit.fullStars;
      _isReminderEnabled = habit.reminderTime != null;
      _reminderTime = habit.reminderTime != null 
          ? TimeOfDay.fromDateTime(habit.reminderTime!) 
          : const TimeOfDay(hour: 7, minute: 0);
      _selectedCategoryId = habit.categoryId;
      _cardColor = habit.color;
      _selectedIcon = _getValidIconValue(habit.icon);
    } else {
      // 添加模式：使用默认值初始化
      _nameController = TextEditingController();
      _contentBlocks = [];
      _frequency = HabitFrequency.weekly;
      _selectedDays = [1, 3, 5, 6]; // 默认选择二、四、五、六
      _fullStars = 5; // 默认5颗星
      _isReminderEnabled = true;
      _reminderTime = const TimeOfDay(hour: 7, minute: 0);
      _selectedCategoryId = widget.categories.isNotEmpty ? widget.categories.first.id : null;
      _cardColor = 0xFF13ec5b;
      if (widget.categories.isNotEmpty) {
        _selectedIcon = _getValidIconValue(widget.categories.first.icon);
      } else {
        _selectedIcon = Icons.fitness_center.codePoint.toString();
      }
    }
  }

  /// 获取有效的图标值
  String _getValidIconValue(String iconValue) {
    try {
      int.parse(iconValue);
      return iconValue;
    } catch (e) {
      return Icons.fitness_center.codePoint.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 显示图标选择对话框
  void _showIconPickerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        
        // 常用图标列表，包含图标和对应的颜色
        final iconItems = [
          {'icon': Icons.fitness_center, 'color': Colors.blue},
          {'icon': Icons.book, 'color': Colors.green},
          {'icon': Icons.music_note, 'color': Colors.purple},
          {'icon': Icons.palette, 'color': Colors.orange},
          {'icon': Icons.code, 'color': Colors.indigo},
          {'icon': Icons.camera, 'color': Colors.red},
          {'icon': Icons.restaurant, 'color': Colors.pink},
          {'icon': Icons.water_drop, 'color': Colors.cyan},
          {'icon': Icons.bed, 'color': Colors.teal},
          {'icon': Icons.star, 'color': Colors.yellow},
          {'icon': Icons.favorite, 'color': Colors.red},
          {'icon': Icons.directions_run, 'color': Colors.green},
          {'icon': Icons.bike_scooter, 'color': Colors.blue},
          {'icon': Icons.directions_boat, 'color': Colors.indigo},
          {'icon': Icons.skateboarding, 'color': Colors.purple},
          {'icon': Icons.music_note, 'color': Colors.pink},
          {'icon': Icons.sports_soccer, 'color': Colors.green},
          {'icon': Icons.sports_basketball, 'color': Colors.orange},
          {'icon': Icons.sports_tennis, 'color': Colors.yellow},
          {'icon': Icons.sports_golf, 'color': Colors.blue},
          {'icon': Icons.read_more, 'color': Colors.brown},
          {'icon': Icons.library_books, 'color': Colors.green},
          {'icon': Icons.school, 'color': Colors.blue},
          {'icon': Icons.lightbulb, 'color': Colors.yellow},
          {'icon': Icons.self_improvement, 'color': Colors.purple},
          {'icon': Icons.spa, 'color': Colors.pink},
          {'icon': Icons.psychology, 'color': Colors.indigo},
          {'icon': Icons.face, 'color': Colors.orange},
        ];
        
        return AlertDialog(
          title: const Text('选择图标'),
          backgroundColor: theme.colorScheme.surface,
          titleTextStyle: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 300),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: iconItems.length,
              itemBuilder: (context, index) {
                final item = iconItems[index];
                final icon = item['icon'] as IconData;
                final color = item['color'] as Color;
                final isSelected = _selectedIcon == icon.codePoint.toString();
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon.codePoint.toString();
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: theme.colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? theme.colorScheme.onPrimary : color,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 保存习惯
  void _saveHabit() {
    if (_nameController.text.isEmpty) {
      return;
    }
    
    // 找到选中的分类
    final selectedCategory = widget.categories.firstWhere(
      (cat) => cat.id == _selectedCategoryId,
      orElse: () => Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '默认分类',
        type: CategoryType.habit,
        icon: 'book',
        color: 0xFF13ec5b,
        isExpanded: true,
      ),
    );
    
    final now = DateTime.now();
    
    // 创建或更新习惯
    final habit = widget.habit != null 
        ? widget.habit!.copyWith(
            name: _nameController.text,
            content: _contentBlocks,
            categoryId: selectedCategory.id,
            category: selectedCategory.name,
            icon: _selectedIcon,
            color: _cardColor,
            frequency: _frequency,
            reminderDays: _selectedDays,
            reminderTime: _isReminderEnabled 
                ? DateTime(
                    now.year,
                    now.month,
                    now.day,
                    _reminderTime.hour,
                    _reminderTime.minute,
                  )
                : null,
            fullStars: _fullStars,
            updatedAt: now,
          )
        : Habit(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            categoryId: selectedCategory.id,
            category: selectedCategory.name,
            name: _nameController.text,
            content: _contentBlocks,
            icon: _selectedIcon,
            color: _cardColor,
            frequency: _frequency,
            reminderDays: _selectedDays,
            reminderTime: _isReminderEnabled 
                ? DateTime(
                    now.year,
                    now.month,
                    now.day,
                    _reminderTime.hour,
                    _reminderTime.minute,
                  )
                : null,
            currentStreak: 0,
            bestStreak: 0,
            totalCompletions: 0,
            history: [],
            checkInRecords: [],
            tags: [],
            createdAt: now,
            updatedAt: now,
            fullStars: _fullStars,
            notes: '',
          );
    
    // 根据是否是编辑模式发送不同的事件
    if (widget.habit != null) {
      // 编辑模式：发送更新习惯事件
      context.read<HabitBloc>().add(UpdateHabit(habit));
    } else {
      // 添加模式：发送添加习惯事件
      context.read<HabitBloc>().add(AddHabit(habit));
    }
    
    // 返回上一页
    Navigator.pop(context);
  }

  /// 显示添加分类对话框
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建分类'),
          backgroundColor: const Color(0xFF102216),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '分类名称',
              labelStyle: TextStyle(color: Colors.grey),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF13ec5b)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final newCategory = Category(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: CategoryType.habit,
                    icon: 'book',
                    color: 0xFF13ec5b,
                    isExpanded: true,
                  );
                  context.read<CategoryBloc>().add(AddCategory(newCategory));
                  Navigator.pop(context);
                }
              },
              child: const Text('添加', style: TextStyle(color: Color(0xFF13ec5b))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.colorScheme.onBackground,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onBackground),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            widget.habit != null ? '编辑习惯' : '添加习惯',
            style: TextStyle(
              color: theme.colorScheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: theme.colorScheme.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          actions: [
            TextButton(
              onPressed: _saveHabit,
              child: Text(
                '保存',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 习惯名称和动力输入
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // 习惯名称
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: '晨跑',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onBackground,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onBackground,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 动力或计划
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: RichTextEditor(
                      initialContent: _contentBlocks,
                      onContentChanged: (content) {
                        setState(() {
                          _contentBlocks = content;
                        });
                      },
                      readOnly: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 重复周期
            Text(
              '重复周期',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFrequencyButton('每日', HabitFrequency.daily, theme),
                  _buildFrequencyButton('每周', HabitFrequency.weekly, theme),
                  _buildFrequencyButton('每月', HabitFrequency.monthly, theme),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // 每周天数选择
            if (_frequency == HabitFrequency.weekly) 
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDayButton(-1, '一', theme),
                  _buildDayButton(1, '二', theme),
                  _buildDayButton(2, '三', theme),
                  _buildDayButton(3, '四', theme),
                  _buildDayButton(4, '五', theme),
                  _buildDayButton(5, '六', theme),
                  _buildDayButton(0, '日', theme),
                ],
              ),
            const SizedBox(height: 24),
            
            // 满星数设置
            Container(
              padding: const EdgeInsets.all(16.0),
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surfaceVariant,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.star,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '满星数',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '设置最高可获得星星数量',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildTargetButton('-', () {
                        setState(() {
                          if (_fullStars > 1) {
                            _fullStars--;
                          }
                        });
                      }, theme),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Text(
                            '$_fullStars',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      _buildTargetButton('+', () {
                        setState(() {
                          _fullStars++;
                        });
                      }, theme),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 提醒设置
            Container(
              padding: const EdgeInsets.all(16.0),
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surfaceVariant,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.notifications,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '提醒',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} AM',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _isReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isReminderEnabled = value;
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.surfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 分类选择
            Container(
              padding: const EdgeInsets.all(16.0),
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surfaceVariant,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.category,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Text(
                        '分类',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 分类标签
                      for (var category in widget.categories.take(3)) 
                        _buildCategoryTag(category, theme),
                      // 新建分类按钮
                      GestureDetector(
                        onTap: _showAddCategoryDialog,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '+ 新建',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 图标选择
            Container(
              padding: const EdgeInsets.all(16.0),
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.surfaceVariant,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.fitness_center,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '图标',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '选择习惯的图标',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showIconPickerDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          _getIconData(_selectedIcon),
                          color: theme.colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 卡片主题色
            const Text(
              '卡片主题色',
              style: TextStyle(
                color: Color.fromARGB(255, 164, 175, 166),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildColorOption(0xFF13ec5b),
                _buildColorOption(0xFFe53935),
                _buildColorOption(0xFF1e88e5),
                _buildColorOption(0xFF8d6e63),
                _buildColorOption(0xFF6a1b9a),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建频率选择按钮
  Widget _buildFrequencyButton(String label, HabitFrequency frequency, ThemeData theme) {
    final isSelected = _frequency == frequency;
    return GestureDetector(
      onTap: () {
        setState(() {
          _frequency = frequency;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onBackground,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 构建星期按钮
  Widget _buildDayButton(int dayIndex, String dayName, ThemeData theme) {
    final isSelected = _selectedDays.contains(dayIndex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(dayIndex);
          } else {
            _selectedDays.add(dayIndex);
          }
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.transparent : theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            dayName,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onBackground,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建目标增减按钮
  Widget _buildTargetButton(String label, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primary,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建分类标签
  Widget _buildCategoryTag(Category category, ThemeData theme) {
    final isSelected = _selectedCategoryId == category.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = category.id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        ),
        child: Text(
          category.name,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onBackground,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 构建颜色选项
  Widget _buildColorOption(int colorValue) {
    final isSelected = _cardColor == colorValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _cardColor = colorValue;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : null,
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  /// 获取图标数据，包含错误处理
  IconData _getIconData(String iconValue) {
    try {
      return IconData(int.parse(iconValue), fontFamily: 'MaterialIcons');
    } catch (e) {
      // 如果图标解析失败，返回默认图标
      return Icons.fitness_center;
    }
  }
}
