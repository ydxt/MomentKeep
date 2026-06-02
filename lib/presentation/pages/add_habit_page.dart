import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/core/utils/icon_helper.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  /// 名称输入框焦点
  final FocusNode _nameFocusNode = FocusNode();
  
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

  /// 图片选择器实例
  final ImagePicker _imagePicker = ImagePicker();

  /// 习惯类型
  late HabitType _habitType;

  // 计分周期规则
  late ScoringMode _scoringMode;       // 计分模式（按天/按周/自定义）
  late int _targetDays;                // 周期内目标打卡天数
  late int _customCycleDays;           // 自定义周期天数
  late int _cycleRewardPoints;         // 周期达标奖励积分
  late int _minCheckInDays;            // 打卡+扣分模式：周期内最小打卡天数
  late int _checkInPoints;             // 打卡+扣分模式：每次打卡得分
  late int _penaltyPoints;             // 打卡+扣分模式：不足最小天数每次扣分

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
      // 兼容旧数据：将 0 或 -1 (周日) 修正为 7
      _selectedDays = habit.reminderDays.map((d) => (d == 0 || d == -1) ? 7 : d).toList();
      _fullStars = habit.fullStars;
      _isReminderEnabled = habit.reminderTime != null;
      _reminderTime = habit.reminderTime != null 
          ? TimeOfDay.fromDateTime(habit.reminderTime!) 
          : const TimeOfDay(hour: 7, minute: 0);
      _selectedCategoryId = habit.categoryId;
      _cardColor = habit.color;
      _selectedIcon = _getValidIconValue(habit.icon);
      _habitType = habit.type;

      // 初始化计分周期
      _scoringMode = habit.scoringMode;
      _targetDays = habit.targetDays;
      _customCycleDays = habit.customCycleDays;
      // 如果奖励分是 0（旧数据），则使用 fullStars
      _cycleRewardPoints = habit.cycleRewardPoints > 0 ? habit.cycleRewardPoints : habit.fullStars;
      _minCheckInDays = habit.minCheckInDays;
      _checkInPoints = habit.checkInPoints;
      _penaltyPoints = habit.penaltyPoints;
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
      _habitType = HabitType.positive;

      // 初始化计分周期默认值
      _scoringMode = ScoringMode.daily; // 默认每天计分
      _targetDays = 1;
      _customCycleDays = 7;
      _cycleRewardPoints = _fullStars; // 默认奖励分等于满星数
      _minCheckInDays = 0;
      _checkInPoints = 0;
      _penaltyPoints = 0;
    }
  }

  /// 获取有效的图标值
  String _getValidIconValue(String iconValue) {
    if (iconValue.isEmpty) {
      return Icons.fitness_center.codePoint.toString();
    }
    return iconValue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// 常用 Emoji 列表
  static const List<String> _commonEmojis = [
    '😊', '🏃', '📚', '🎵', '💪', '🎨', '💻', '📷',
    '🍽️', '💧', '🛏️', '⭐', '❤️', '🧘', '🎯', '🌟',
    '🔥', '📝', '🎸', '🏀', '⚽', '🎮', '✈️', '🌱',
    '💰', '🧠', '☕', '🐾', '🏠', '🚗',
  ];

  /// 从相册选择图片作为图标
  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 200,
        maxHeight: 200,
      );
      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        String storagePath = prefs.getString(StorageKeys.storagePath) ?? '';
        if (storagePath.isEmpty) {
          if (Platform.isWindows) {
            storagePath = '${Platform.environment['USERPROFILE']}${Platform.pathSeparator}Documents${Platform.pathSeparator}MomentKeep';
          } else {
            final documentsDir = await getApplicationDocumentsDirectory();
            storagePath = '${documentsDir.path}${Platform.pathSeparator}MomentKeep';
          }
        }
        final userId = prefs.getString(StorageKeys.userId) ?? 'default';
        final iconsDir = Directory('$storagePath${Platform.pathSeparator}$userId${Platform.pathSeparator}habit_icons');
        if (!await iconsDir.exists()) {
          await iconsDir.create(recursive: true);
        }
        final fileName = 'icon_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedPath = '${iconsDir.path}${Platform.pathSeparator}$fileName';
        await File(pickedFile.path).copy(savedPath);
        setState(() {
          _selectedIcon = IconHelper.toFileUri(savedPath);
        });
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择图片失败')),
        );
      }
    }
  }

  /// 显示图标选择对话框
  void _showIconPickerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);

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

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final customEmojiController = TextEditingController();
            final customTextController = TextEditingController();

            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                title: const Text('选择图标'),
                backgroundColor: theme.colorScheme.surface,
                titleTextStyle: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TabBar(
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        indicatorColor: theme.colorScheme.primary,
                        tabs: const [
                          Tab(text: '内置图标'),
                          Tab(text: '自定义'),
                        ],
                      ),
                      SizedBox(
                        height: 320,
                        child: TabBarView(
                          children: [
                            GridView.builder(
                              padding: const EdgeInsets.only(top: 12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: iconItems.length,
                              itemBuilder: (context, index) {
                                final item = iconItems[index];
                                final icon = item['icon'] as IconData;
                                final color = item['color'] as Color;
                                final isSelected =
                                    _selectedIcon == icon.codePoint.toString();

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIcon =
                                          icon.codePoint.toString();
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: theme.colorScheme.primary,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Icon(
                                      icon,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimary
                                          : color,
                                      size: 24,
                                    ),
                                  ),
                                );
                              },
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '常用 Emoji',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _commonEmojis.map((emoji) {
                                      final isSelected = _selectedIcon == emoji;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedIcon = emoji;
                                          });
                                          Navigator.pop(context);
                                        },
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: isSelected
                                                ? Border.all(
                                                    color: theme
                                                        .colorScheme.primary,
                                                    width: 2,
                                                  )
                                                : null,
                                          ),
                                          child: Center(
                                            child: Text(
                                              emoji,
                                              style:
                                                  const TextStyle(fontSize: 22),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '输入 Emoji',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: customEmojiController,
                                    decoration: InputDecoration(
                                      hintText: '输入单个 Emoji 表情',
                                      hintStyle: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.check),
                                        onPressed: () {
                                          final text =
                                              customEmojiController.text.trim();
                                          if (text.isNotEmpty) {
                                            setState(() {
                                              _selectedIcon = text;
                                            });
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 24),
                                    textAlign: TextAlign.center,
                                    maxLength: 2,
                                    buildCounter: (
                                      context, {
                                      currentLength = 0,
                                      isFocused = false,
                                      maxLength,
                                    }) =>
                                        null,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '文字符号',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: customTextController,
                                    decoration: InputDecoration(
                                      hintText: '输入符号，如 ✓ ★ ♥',
                                      hintStyle: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.check),
                                        onPressed: () {
                                          final text =
                                              customTextController.text.trim();
                                          if (text.isNotEmpty) {
                                            setState(() {
                                              _selectedIcon = text;
                                            });
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 20),
                                    textAlign: TextAlign.center,
                                    maxLength: 2,
                                    buildCounter: (
                                      context, {
                                      currentLength = 0,
                                      isFocused = false,
                                      maxLength,
                                    }) =>
                                        null,
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _pickImageFromGallery();
                                      },
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('从相册选择'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 保存习惯
  Future<void> _saveHabit() async {
    if (_nameController.text.isEmpty) {
      return;
    }

    if (_scoringMode == ScoringMode.weekly || _scoringMode == ScoringMode.custom) {
      _cycleRewardPoints = _fullStars;
    }

    List<String> existingHabitIds = [];

    final currentName = _nameController.text.trim();
    final isNameChanged = widget.habit == null ||
        widget.habit!.name.trim().toLowerCase() != currentName.toLowerCase();

    if (isNameChanged) {
      final habitState = context.read<HabitBloc>().state;
      final existingHabits = habitState is HabitLoaded
          ? habitState.habits.where((h) => h.name.trim().toLowerCase() == currentName.toLowerCase()).toList()
          : <Habit>[];

      if (existingHabits.isNotEmpty) {
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final theme = ref.read(currentThemeProvider);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text(
                '重复标题',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: Text(
                '已存在相同标题的习惯：$currentName',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'modify'),
                  child: const Text('修改标题'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'overwrite'),
                  child: const Text('覆盖已有记录'),
                ),
              ],
            );
          },
        );

        if (action == 'overwrite') {
          existingHabitIds = existingHabits.map((h) => h.id).toList();
        } else {
          _nameFocusNode.requestFocus();
          _nameController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _nameController.text.length,
          );
          return;
        }
      }
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
            type: _habitType,
            scoringMode: _scoringMode,
            targetDays: _targetDays,
            customCycleDays: _customCycleDays,
            cycleRewardPoints: _cycleRewardPoints,
            minCheckInDays: _minCheckInDays,
            checkInPoints: _checkInPoints,
            penaltyPoints: _penaltyPoints,
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
            type: _habitType,
            scoringMode: _scoringMode,
            targetDays: _targetDays,
            customCycleDays: _customCycleDays,
            cycleRewardPoints: _cycleRewardPoints,
            minCheckInDays: _minCheckInDays,
            checkInPoints: _checkInPoints,
            penaltyPoints: _penaltyPoints,
          );
    
    // 根据是否是编辑模式发送不同的事件
    if (widget.habit != null) {
      context.read<HabitBloc>().add(UpdateHabit(habit));
    } else {
      if (existingHabitIds.isNotEmpty) {
        context.read<HabitBloc>().add(OverwriteHabit(existingHabitIds, habit));
      } else {
        context.read<HabitBloc>().add(AddHabit(habit));
      }
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
                    focusNode: _nameFocusNode,
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
                  _buildDayButton(1, '一', theme),
                  _buildDayButton(2, '二', theme),
                  _buildDayButton(3, '三', theme),
                  _buildDayButton(4, '四', theme),
                  _buildDayButton(5, '五', theme),
                  _buildDayButton(6, '六', theme),
                  _buildDayButton(7, '日', theme),
                ],
              ),
            const SizedBox(height: 24),
            
            // 积分设置
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            Icons.bolt,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Text(
                        '积分设置',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Text(
                        '习惯类型：',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground,
                          fontSize: 14,
                        ),
                      ),
                      _buildTypeButton(HabitType.positive, theme),
                      const SizedBox(width: 12),
                      _buildTypeButton(HabitType.negative, theme),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Text(
                        '计分规则：',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ScoringMode>(
                              isExpanded: true,
                              value: _scoringMode,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _scoringMode = value;
                                    if (value == ScoringMode.daily) {
                                      _targetDays = 1;
                                    }
                                    if (value == ScoringMode.checkInWithPenalty || value == ScoringMode.weeklyWithPenalty) {
                                      if (_checkInPoints == 0) _checkInPoints = _fullStars;
                                      if (_penaltyPoints == 0) _penaltyPoints = _fullStars;
                                    }
                                  });
                                }
                              },
                              items: ScoringMode.values.map((mode) {
                                return DropdownMenuItem(
                                  value: mode,
                                  child: Text(mode.displayName),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_scoringMode == ScoringMode.daily) ...[
                    const SizedBox(height: 12),
                    _buildScoreRow(theme, label: _habitType == HabitType.negative ? '最大扣分/天' : '最大得分/天'),
                  ],

                  if (_scoringMode == ScoringMode.weekly) ...[
                    const SizedBox(height: 12),
                    _buildNumberButtonRow('达标天数', _targetDays, (val) {
                      setState(() { _targetDays = val; });
                    }, '天', theme),
                    const SizedBox(height: 12),
                    _buildScoreRow(theme, label: _habitType == HabitType.negative ? '最大扣分/周' : '最大得分/周'),
                  ],

                  if (_scoringMode == ScoringMode.custom) ...[
                    const SizedBox(height: 12),
                    _buildNumberButtonRow('周期天数', _customCycleDays, (val) {
                      setState(() { _customCycleDays = val; });
                    }, '天', theme),
                    const SizedBox(height: 12),
                    _buildNumberButtonRow('达标天数', _targetDays, (val) {
                      setState(() { _targetDays = val; });
                    }, '天', theme),
                    const SizedBox(height: 12),
                    _buildScoreRow(theme, label: _habitType == HabitType.negative ? '最大扣分/周' : '最大得分/周'),
                  ],

                  if (_scoringMode == ScoringMode.checkInWithPenalty) ...[
                    const SizedBox(height: 12),
                    _buildNumberButtonRow('周期天数', _customCycleDays, (val) {
                      setState(() { _customCycleDays = val; });
                    }, '天', theme),
                    const SizedBox(height: 12),
                    _buildNumberButtonRow('最小打卡天数', _minCheckInDays, (val) {
                      setState(() { _minCheckInDays = val; });
                    }, '天', theme, min: 0),
                    const SizedBox(height: 12),
                    _buildCheckInScoreRow(theme),
                    const SizedBox(height: 12),
                    _buildPenaltyScoreRow(theme),
                  ],

                  if (_scoringMode == ScoringMode.weeklyWithPenalty) ...[
                    const SizedBox(height: 12),
                    _buildNumberButtonRow('最小打卡天数', _minCheckInDays, (val) {
                      setState(() { _minCheckInDays = val; });
                    }, '天', theme, min: 0),
                    const SizedBox(height: 12),
                    _buildCheckInScoreRow(theme),
                    const SizedBox(height: 12),
                    _buildPenaltyScoreRow(theme),
                  ],
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
                        child: IconHelper.buildIconWidget(
                          _selectedIcon,
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
  Widget _buildScoreRow(ThemeData theme, {String? label}) {
    final isNegative = _habitType == HabitType.negative;
    final scoreColor = isNegative ? Colors.red : Colors.green;
    final prefix = isNegative ? '-' : '+';
    final displayLabel = label ?? (isNegative ? '最大扣分' : '最大得分');

    return Row(
      children: [
        Text('$displayLabel：', style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14)),
        _buildTargetButton('-', () {
          setState(() { if (_fullStars > 1) _fullStars--; });
        }, theme),
        const SizedBox(width: 12),
        Text(prefix, style: TextStyle(color: scoreColor, fontSize: 16, fontWeight: FontWeight.bold)),
        Text('$_fullStars', style: TextStyle(color: scoreColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('分', style: TextStyle(color: scoreColor.withOpacity(0.7), fontSize: 14)),
        const SizedBox(width: 12),
        _buildTargetButton('+', () {
          setState(() { _fullStars++; });
        }, theme),
      ],
    );
  }

  Widget _buildCheckInScoreRow(ThemeData theme) {
    return Row(
      children: [
        Text('打卡得分/天：', style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14)),
        _buildTargetButton('-', () {
          setState(() { if (_checkInPoints > 1) _checkInPoints--; });
        }, theme),
        const SizedBox(width: 12),
        Text('+', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
        Text('$_checkInPoints', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('分', style: TextStyle(color: Colors.green.withOpacity(0.7), fontSize: 14)),
        const SizedBox(width: 12),
        _buildTargetButton('+', () {
          setState(() { _checkInPoints++; });
        }, theme),
      ],
    );
  }

  Widget _buildPenaltyScoreRow(ThemeData theme) {
    return Row(
      children: [
        Text('不足扣分/天：', style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14)),
        _buildTargetButton('-', () {
          setState(() { if (_penaltyPoints > 1) _penaltyPoints--; });
        }, theme),
        const SizedBox(width: 12),
        Text('-', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
        Text('$_penaltyPoints', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('分', style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 14)),
        const SizedBox(width: 12),
        _buildTargetButton('+', () {
          setState(() { _penaltyPoints++; });
        }, theme),
      ],
    );
  }

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

  Widget _buildNumberButtonRow(String label, int value, Function(int) onChanged, String suffix, ThemeData theme, {int min = 1}) {
    return Row(
      children: [
        Text('$label：', style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14)),
        _buildTargetButton('-', () {
          setState(() { if (value > min) onChanged(value - 1); });
        }, theme),
        const SizedBox(width: 12),
        Text('$value', style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(suffix, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
        const SizedBox(width: 12),
        _buildTargetButton('+', () {
          setState(() { onChanged(value + 1); });
        }, theme),
      ],
    );
  }

  /// 构建类型选择按钮
  Widget _buildTypeButton(HabitType type, ThemeData theme) {
    final isSelected = _habitType == type;
    final buttonColor = type == HabitType.positive 
        ? theme.colorScheme.primary 
        : theme.colorScheme.error;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _habitType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? buttonColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? buttonColor
                  : theme.colorScheme.outline,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                type == HabitType.positive ? Icons.add_circle : Icons.remove_circle,
                color: buttonColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                type == HabitType.positive ? '加分项' : '减分项',
                style: TextStyle(
                  color: buttonColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
