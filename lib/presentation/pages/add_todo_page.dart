import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';
import 'package:moment_keep/core/services/location_service.dart';
import 'package:moment_keep/presentation/pages/map_select_page.dart';

/// 添加待办事项页面
class AddTodoPage extends ConsumerStatefulWidget {
  /// 待办事项（用于编辑模式）
  final Todo? todo;
  
  /// 预定义日期（用于从日历视图添加任务）
  final DateTime? date;

  /// 构造函数
  const AddTodoPage({super.key, this.todo, this.date});

  @override
  ConsumerState<AddTodoPage> createState() => _AddTodoPageState();
}

class _AddTodoPageState extends ConsumerState<AddTodoPage> {
  // 任务标题控制器
  final TextEditingController _titleController = TextEditingController();
  
  // 内容块列表
  List<ContentBlock> _contentBlocks = [];
  
  // 选择的分类
  String _selectedCategory = '生活';
  // 日期
  String _date = '今天';
  String _endDate = '今天';
  // 时间
  String _startTime = '全天';
  String _endTime = '';
  // 时间输入控制器
  late TextEditingController _startDateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _endDateController;
  // 是否全天
  bool _isAllDay = false;
  // 提醒时间
  String _reminderTime = '不提醒';
  // 重复类型
  String _repeatType = '不重复';
  // 重复间隔
  int _repeatInterval = 1;
  // 重复单位
  String _repeatUnit = '周'; // 选项：天、周、月、年
  // 选中的星期
  List<int> _selectedWeekdays = [1]; // 0-6 表示周一到周日
  // 月重复类型
  String _monthRepeatType = 'date'; // 选项：date, nth_weekday, last_weekday
  // 年重复类型
  String _yearRepeatType = 'date'; // 选项：date, nth_weekday, last_weekday
  // 重复结束日期
  String _repeatEndDate = '无结束日期';
  // 优先级
  String _priority = '中';
  // 位置提醒开关
  bool _locationReminder = false;
  // 位置信息
  double? _latitude;
  double? _longitude;
  String? _locationName;
  // 地理围栏半径
  double _radius = 100.0;
  
  // 分类列表
  List<Category> _categories = [];
  
  // 标签列表
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    // 加载分类数据
    context.read<CategoryBloc>().add(const LoadCategories(type: CategoryType.todo));
    
    // 如果是编辑模式，初始化标题、内容、日期时间和优先级
    if (widget.todo != null) {
      _titleController.text = widget.todo!.title;
      _contentBlocks = List.from(widget.todo!.content);
      
      // 设置日期和时间
      if (widget.todo!.date != null) {
        // 设置结束日期
        _endDate = '${widget.todo!.date!.year}/${widget.todo!.date!.month.toString().padLeft(2, '0')}/${widget.todo!.date!.day.toString().padLeft(2, '0')}';
        _endTime = '${widget.todo!.date!.hour}:${widget.todo!.date!.minute.toString().padLeft(2, '0')}';
        
        // 设置开始日期和时间
        if (widget.todo!.startDate != null) {
          _date = '${widget.todo!.startDate!.year}/${widget.todo!.startDate!.month.toString().padLeft(2, '0')}/${widget.todo!.startDate!.day.toString().padLeft(2, '0')}';
          _startTime = '${widget.todo!.startDate!.hour}:${widget.todo!.startDate!.minute.toString().padLeft(2, '0')}';
        } else {
          _date = _endDate;
          _startTime = _endTime;
        }
        
        // 判断是否为全天任务
        _isAllDay = false;
      }
      
      // 设置提醒时间
      if (widget.todo!.reminderTime != null) {
        _reminderTime = '${widget.todo!.reminderTime!.hour}:${widget.todo!.reminderTime!.minute.toString().padLeft(2, '0')}';
      }
      
      // 设置优先级
      switch (widget.todo!.priority) {
        case TodoPriority.high:
          _priority = '高';
          break;
        case TodoPriority.medium:
          _priority = '中';
          break;
        case TodoPriority.low:
          _priority = '低';
          break;
      }
      
      // 设置重复任务
      switch (widget.todo!.repeatType) {
        case RepeatType.none:
          _repeatType = '不重复';
          break;
        case RepeatType.daily:
          _repeatType = '每天';
          break;
        case RepeatType.weekly:
          _repeatType = '每周';
          break;
        case RepeatType.monthly:
          _repeatType = '每月';
          break;
        case RepeatType.yearly:
          _repeatType = '每年';
          break;
        case RepeatType.custom:
          _repeatType = '自定义';
          break;
      }
      
      // 设置重复间隔
      _repeatInterval = widget.todo!.repeatInterval;
      
      // 设置重复结束日期
      if (widget.todo!.repeatEndDate != null) {
        _repeatEndDate = '${widget.todo!.repeatEndDate!.year}/${widget.todo!.repeatEndDate!.month.toString().padLeft(2, '0')}/${widget.todo!.repeatEndDate!.day.toString().padLeft(2, '0')}';
      } else {
        _repeatEndDate = '无结束日期';
      }
      
      // 设置位置提醒
      _locationReminder = widget.todo!.isLocationReminderEnabled;
      _latitude = widget.todo!.latitude;
      _longitude = widget.todo!.longitude;
      _locationName = widget.todo!.locationName;
      _radius = widget.todo!.radius ?? 100.0;
      
      // 设置标签
      _tags = List.from(widget.todo!.tags);
    } 
    // 如果从日历视图过来，设置默认日期
    else if (widget.date != null) {
      _date = '${widget.date!.year}/${widget.date!.month.toString().padLeft(2, '0')}/${widget.date!.day.toString().padLeft(2, '0')}';
      _endDate = '${widget.date!.year}/${widget.date!.month.toString().padLeft(2, '0')}/${widget.date!.day.toString().padLeft(2, '0')}';
      // 设置默认时间为当前时间
      final now = DateTime.now();
      _startTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      // 设置默认结束时间为当前时间+1小时
      final endTime = now.add(const Duration(hours: 1));
      _endTime = '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}';
    }
    // 默认情况
    else {
      final now = DateTime.now();
      _date = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
      _endDate = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
      // 设置默认时间为当前时间
      _startTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      // 设置默认结束时间为当前时间+1小时
      final endTime = now.add(const Duration(hours: 1));
      _endTime = '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}';
    }
    
    // 初始化时间输入控制器
    _startDateController = TextEditingController(text: _date);
    _startTimeController = TextEditingController(text: _startTime);
    _endTimeController = TextEditingController(text: _endTime);
    _endDateController = TextEditingController(text: _endDate);
  }

  // 显示日期选择器
  Future<void> _showDatePicker(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
      final formattedDate = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
      if (isStartDate) {
        setState(() {
          _date = formattedDate;
          _startDateController.text = formattedDate;
          // 如果结束日期早于开始日期，自动更新结束日期
          if (_endDate.isNotEmpty) {
            final endDateParts = _endDate.split('/');
            final startDateParts = formattedDate.split('/');
            final endDate = DateTime(
              int.parse(endDateParts[0]),
              int.parse(endDateParts[1]),
              int.parse(endDateParts[2]),
            );
            final startDate = DateTime(
              int.parse(startDateParts[0]),
              int.parse(startDateParts[1]),
              int.parse(startDateParts[2]),
            );
            if (endDate.isBefore(startDate)) {
              _endDate = formattedDate;
              _endDateController.text = formattedDate;
            }
          }
        });
      } else {
        setState(() {
          // 确保结束日期不早于开始日期
          final startDateParts = _date.split('/');
          final startDate = DateTime(
            int.parse(startDateParts[0]),
            int.parse(startDateParts[1]),
            int.parse(startDateParts[2]),
          );
          final endDate = picked;
          
          if (endDate.isBefore(startDate)) {
            _endDate = _date;
            _endDateController.text = _date;
          } else {
            _endDate = formattedDate;
            _endDateController.text = formattedDate;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, categoryState) {
        // 无论分类状态如何，都构建完整UI
        if (categoryState is CategoryLoaded) {
          _categories = categoryState.categories;
          
          // 如果是编辑模式，且分类数据已加载完成，查找并设置分类
          if (widget.todo != null) {
            final category = _categories.firstWhere(
              (cat) => cat.id == widget.todo!.categoryId,
              orElse: () => Category(
                id: 'default',
                name: '默认分类',
                type: CategoryType.todo,
                color: AppTheme.primaryColor.value,
                icon: Icons.category.codePoint.toString(),
              ),
            );
            
            // 使用SchedulerBinding延迟执行状态更新，避免在构建过程中调用setState()
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedCategory = category.name;
                });
              }
            });
          }
        } else if (categoryState is CategoryLoading) {
          // 加载中状态，使用空分类列表
          _categories = [];
        } else if (categoryState is CategoryError) {
          // 错误状态，使用空分类列表
          _categories = [];
        }

        final theme = ref.watch(currentThemeProvider);
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close, color: theme.colorScheme.onBackground),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              title: Text(
                widget.todo != null ? '编辑待办' : '添加待办',
                style: TextStyle(color: theme.colorScheme.onBackground, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            actions: [
              TextButton(
                onPressed: () {
                  _saveTodo();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
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
                  // 准备做什么？
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: '准备做什么？',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 18),
                    cursorColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  
                  // 详细描述编辑区
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
                        });
                      },
                      readOnly: false,
                      isQuestionBank: false,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 分类
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '分类',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: () {
                          // 编辑分类逻辑
                        },
                        child: Text(
                          '编辑',
                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 分类标签
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 动态生成分类标签
                        for (var category in _categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildCategoryTag(
                              category.name,
                              _selectedCategory == category.name,
                              Icons.category,
                              theme,
                            ),
                          ),
                        // 添加分类按钮
                        GestureDetector(
                          onTap: () {
                            _showAddCategoryDialog();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.colorScheme.outline, width: 1),
                            ),
                            child: Icon(Icons.add, color: theme.colorScheme.onBackground, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 标签显示区域
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
                          ..._tags.map((tag) => Padding(
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
                                        _tags.remove(tag);
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
                              _showAddTagDialog();
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
                  const SizedBox(height: 24),
                  
                  // 时间与提醒
                  Text(
                    '时间与提醒',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  
                  // 左右分栏布局
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // 左侧：日期时间选择区
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 第一行：开始日期、开始时间、全天开关
                              Row(
                                children: [
                                  // 开始日期输入
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: theme.colorScheme.outline),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: '2026/01/26',
                                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                            controller: _startDateController,
                                            onChanged: (value) {
                                              setState(() {
                                                _date = value;
                                                // 验证日期格式和逻辑
                                                if (value.isNotEmpty && _endDate.isNotEmpty) {
                                                  try {
                                                    final startDateParts = value.split('/');
                                                    final endDateParts = _endDate.split('/');
                                                    if (startDateParts.length == 3 && endDateParts.length == 3) {
                                                      final startDate = DateTime(
                                                        int.parse(startDateParts[0]),
                                                        int.parse(startDateParts[1]),
                                                        int.parse(startDateParts[2]),
                                                      );
                                                      final endDate = DateTime(
                                                        int.parse(endDateParts[0]),
                                                        int.parse(endDateParts[1]),
                                                        int.parse(endDateParts[2]),
                                                      );
                                                      if (endDate.isBefore(startDate)) {
                                                        _endDate = value;
                                                        _endDateController.text = value;
                                                      }
                                                    }
                                                  } catch (e) {
                                                    // 日期格式错误，忽略验证
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.calendar_today, color: theme.colorScheme.onSurfaceVariant, size: 18),
                                          onPressed: () {
                                            _showDatePicker(true);
                                          },
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 开始时间输入
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: theme.colorScheme.outline),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: '18:53',
                                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                            controller: _startTimeController,
                                            onChanged: (value) {
                                              setState(() {
                                                _startTime = value;
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.access_time, color: theme.colorScheme.onSurfaceVariant, size: 18),
                                          onPressed: () async {
                                            // 显示时间选择器
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
                                              setState(() {
                                                _startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                _startTimeController.text = _startTime;
                                              });
                                            }
                                          },
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 全天开关
                                  Row(
                                    children: [
                                      Switch(
                                            value: _isAllDay,
                                            onChanged: (value) {
                                              setState(() {
                                                _isAllDay = value;
                                                if (_isAllDay) {
                                                  // 切换到全天状态，设置开始时间为00:00，结束时间为23:59
                                                  _startTime = '00:00';
                                                  _endTime = '23:59';
                                                  _startTimeController.text = _startTime;
                                                  _endTimeController.text = _endTime;
                                                } else {
                                                  // 切换到非全天状态，设置默认时间
                                                  final now = DateTime.now();
                                                  _startTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                                                  final endTime = now.add(const Duration(hours: 1));
                                                  _endTime = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
                                                  _startTimeController.text = _startTime;
                                                  _endTimeController.text = _endTime;
                                                }
                                              });
                                            },
                                            activeColor: theme.colorScheme.primary,
                                            inactiveTrackColor: theme.colorScheme.surfaceVariant,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                      Text(
                                        '全天',
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 第二行：结束日期、结束时间
                              Row(
                                children: [
                                  // 结束日期输入
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: theme.colorScheme.outline),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: '2026/01/26',
                                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                            controller: _endDateController,
                                            onChanged: (value) {
                                              setState(() {
                                                _endDate = value;
                                                // 验证日期格式和逻辑
                                                if (value.isNotEmpty && _date.isNotEmpty) {
                                                  try {
                                                    final startDateParts = _date.split('/');
                                                    final endDateParts = value.split('/');
                                                    if (startDateParts.length == 3 && endDateParts.length == 3) {
                                                      final startDate = DateTime(
                                                        int.parse(startDateParts[0]),
                                                        int.parse(startDateParts[1]),
                                                        int.parse(startDateParts[2]),
                                                      );
                                                      final endDate = DateTime(
                                                        int.parse(endDateParts[0]),
                                                        int.parse(endDateParts[1]),
                                                        int.parse(endDateParts[2]),
                                                      );
                                                      if (endDate.isBefore(startDate)) {
                                                        _endDate = _date;
                                                        _endDateController.text = _date;
                                                      }
                                                    }
                                                  } catch (e) {
                                                    // 日期格式错误，忽略验证
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.calendar_today, color: theme.colorScheme.onSurfaceVariant, size: 18),
                                          onPressed: () {
                                            _showDatePicker(false);
                                          },
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 结束时间输入
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: theme.colorScheme.outline),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: '19:53',
                                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                            controller: _endTimeController,
                                            onChanged: (value) {
                                              setState(() {
                                                _endTime = value;
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.access_time, color: theme.colorScheme.onSurfaceVariant, size: 18),
                                          onPressed: () async {
                                            // 显示时间选择器
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
                                              setState(() {
                                                _endTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                _endTimeController.text = _endTime;
                                              });
                                            }
                                          },
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 右侧：提醒时间和重复类型
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 提醒时间
                              GestureDetector(
                                onTapDown: (details) {
                                  _showReminderTimeSelector(details.globalPosition);
                                },
                                child: Container(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.alarm, color: Colors.green, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        '提醒时间',
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _reminderTime,
                                        style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              // 分隔线
                              Divider(color: theme.colorScheme.outline, height: 1),
                              // 重复类型
                              GestureDetector(
                                onTapDown: (details) {
                                  _showRepeatTypeSelector(details.globalPosition);
                                },
                                child: Container(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.repeat, color: Colors.orange, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        '重复类型',
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _repeatType,
                                        style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                  // 重复设置（仅当重复类型不是"不重复"时显示）
                  if (_repeatType != '不重复')
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        // 根据重复类型显示不同的设置界面
                        if (_repeatType == '自定义')
                          // 自定义重复设置UI
                          Column(
                            children: [
                              // 重复间隔
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.countertops, color: Colors.teal, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          '重复间隔',
                                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        // 间隔数字输入
                                        Container(
                                          width: 50,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.background,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: theme.colorScheme.outline),
                                          ),
                                          child: TextField(
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            ),
                                            style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                            keyboardType: TextInputType.number,
                                            controller: TextEditingController(text: '$_repeatInterval'),
                                            onChanged: (value) {
                                              if (value.isNotEmpty) {
                                                setState(() {
                                                  _repeatInterval = int.parse(value);
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // 间隔单位选择
                                        GestureDetector(
                                          onTap: () {
                                            _showRepeatUnitSelector();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.background,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: theme.colorScheme.outline),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  _repeatUnit,
                                                  style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.arrow_drop_down,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 星期选择（仅当重复单位为周时显示）
                              if (_repeatUnit == '周')
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      for (int i = 0; i < 7; i++)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (_selectedWeekdays.contains(i)) {
                                                _selectedWeekdays.remove(i);
                                              } else {
                                                _selectedWeekdays.add(i);
                                              }
                                            });
                                          },
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: _selectedWeekdays.contains(i)
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.background,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: theme.colorScheme.outline),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              ['一', '二', '三', '四', '五', '六', '日'][i],
                                              style: TextStyle(
                                                color: _selectedWeekdays.contains(i)
                                                    ? theme.colorScheme.onPrimary
                                                    : theme.colorScheme.onBackground,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              // 月重复类型选择（仅当重复单位为月时显示）
                              if (_repeatUnit == '月')
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 在当前日期选项
                                      RadioListTile(
                                        title: Text('在${_date.split('/').last}日'),
                                        value: 'date',
                                        groupValue: _monthRepeatType,
                                        onChanged: (value) {
                                          setState(() {
                                            _monthRepeatType = value as String;
                                          });
                                        },
                                        activeColor: theme.colorScheme.primary,
                                      ),
                                      // 在第几个星期几选项
                                      RadioListTile(
                                        title: Text('在${_getNthWeekday()}个星期${_getWeekdayFromDate()}'),
                                        value: 'nth_weekday',
                                        groupValue: _monthRepeatType,
                                        onChanged: (value) {
                                          setState(() {
                                            _monthRepeatType = value as String;
                                          });
                                        },
                                        activeColor: theme.colorScheme.primary,
                                      ),
                                      // 只有当当前日期是当月的最后一个星期几时，才显示"在最后一个星期几"选项
                                      if (_isLastWeekday())
                                        RadioListTile(
                                          title: Text('在最后一个星期${_getWeekdayFromDate()}'),
                                          value: 'last_weekday',
                                          groupValue: _monthRepeatType,
                                          onChanged: (value) {
                                            setState(() {
                                              _monthRepeatType = value as String;
                                            });
                                          },
                                          activeColor: theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              // 年重复类型选择（仅当重复单位为年时显示）
                              if (_repeatUnit == '年')
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 在当前月日选项
                                      RadioListTile(
                                        title: Text('在${_date.split('/')[1]}月${_date.split('/')[2]}日'),
                                        value: 'date',
                                        groupValue: _yearRepeatType,
                                        onChanged: (value) {
                                          setState(() {
                                            _yearRepeatType = value as String;
                                          });
                                        },
                                        activeColor: theme.colorScheme.primary,
                                      ),
                                      // 在当前月的第几个星期几选项
                                      RadioListTile(
                                        title: Text('在${_date.split('/')[1]}月的${_getNthWeekday()}个星期${_getWeekdayFromDate()}'),
                                        value: 'nth_weekday',
                                        groupValue: _yearRepeatType,
                                        onChanged: (value) {
                                          setState(() {
                                            _yearRepeatType = value as String;
                                          });
                                        },
                                        activeColor: theme.colorScheme.primary,
                                      ),
                                      // 只有当当前日期是当月的最后一个星期几时，才显示"在最后一个星期几"选项
                                      if (_isLastWeekday())
                                        RadioListTile(
                                          title: Text('在${_date.split('/')[1]}月的最后一个星期${_getWeekdayFromDate()}'),
                                          value: 'last_weekday',
                                          groupValue: _yearRepeatType,
                                          onChanged: (value) {
                                            setState(() {
                                              _yearRepeatType = value as String;
                                            });
                                          },
                                          activeColor: theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              // 重复规则描述
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 规则描述和日期选择在同一行
                                    Container(
                                      width: double.infinity,
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            // 动态生成的规则描述文本
                                            TextSpan(
                                              text: _generateRuleDescription(),
                                              style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                            ),
                                            // 日期显示和选择
                                            WidgetSpan(
                                              child: GestureDetector(
                                                onTap: () async {
                                                  // 显示日期选择器
                                                  final DateTime? picked = await showDatePicker(
                                                    context: context,
                                                    initialDate: DateTime.now(),
                                                    firstDate: DateTime.now(),
                                                    lastDate: DateTime(2101),
                                                    builder: (BuildContext context, Widget? child) {
                                                      return Theme(
                                                        data: ThemeData.light().copyWith(
                                                          colorScheme: theme.colorScheme,
                                                        ),
                                                        child: child!,
                                                      );
                                                    },
                                                  );
                                                  
                                                  if (picked != null) {
                                                    setState(() {
                                                      _repeatEndDate = '${picked.year}年${picked.month}月${picked.day}日';
                                                    });
                                                  }
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(width: 4),
                                                    Text(
                                                      _repeatEndDate == '无结束日期' ? '2026年7月13日' : _repeatEndDate,
                                                      style: TextStyle(
                                                        color: theme.colorScheme.primary,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Icon(
                                                      Icons.arrow_drop_down,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // 删除结束日期链接
                                            WidgetSpan(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '删除结束日期',
                                                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        overflow: TextOverflow.visible,
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          // 普通重复设置（非自定义）
                          Column(
                            children: [
                              // 根据重复类型显示不同的设置
                              if (_repeatType == '每天')
                                Column(
                                  children: [
                                    // 规则描述
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 规则描述和日期选择在同一行
                                          Container(
                                            width: double.infinity,
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  // 动态生成的规则描述文本
                                                  TextSpan(
                                                    text: '每天发生一次，直到',
                                                    style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                                  ),
                                                  // 日期显示和选择
                                                  WidgetSpan(
                                                    child: GestureDetector(
                                                      onTap: () async {
                                                        // 显示日期选择器
                                                        final DateTime? picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: DateTime.now(),
                                                          firstDate: DateTime.now(),
                                                          lastDate: DateTime(2101),
                                                          builder: (BuildContext context, Widget? child) {
                                                            return Theme(
                                                              data: ThemeData.light().copyWith(
                                                                colorScheme: theme.colorScheme,
                                                              ),
                                                              child: child!,
                                                            );
                                                          },
                                                        );
                                                        
                                                        if (picked != null) {
                                                          setState(() {
                                                            _repeatEndDate = '${picked.year}年${picked.month}月${picked.day}日';
                                                          });
                                                        }
                                                      },
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          SizedBox(width: 4),
                                                          Text(
                                                            _repeatEndDate == '无结束日期' ? '2026年4月27日' : _repeatEndDate,
                                                            style: TextStyle(
                                                              color: theme.colorScheme.primary,
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          SizedBox(width: 4),
                                                          Icon(
                                                            Icons.arrow_drop_down,
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            size: 16,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  // 删除结束日期链接
                                                  WidgetSpan(
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(width: 8),
                                                        Text(
                                                          '删除结束日期',
                                                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 14),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              overflow: TextOverflow.visible,
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              // 每周重复
                              if (_repeatType == '每周')
                                Column(
                                  children: [
                                    // 星期选择
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          for (int i = 0; i < 7; i++)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (_selectedWeekdays.contains(i)) {
                                                    _selectedWeekdays.remove(i);
                                                  } else {
                                                    _selectedWeekdays.add(i);
                                                  }
                                                });
                                              },
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: _selectedWeekdays.contains(i)
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.background,
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: theme.colorScheme.outline),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  ['一', '二', '三', '四', '五', '六', '日'][i],
                                                  style: TextStyle(
                                                    color: _selectedWeekdays.contains(i)
                                                        ? theme.colorScheme.onPrimary
                                                        : theme.colorScheme.onBackground,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // 规则描述
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 规则描述和日期选择在同一行
                                          Container(
                                            width: double.infinity,
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  // 动态生成的规则描述文本
                                                  TextSpan(
                                                    text: _generateRuleDescription(),
                                                    style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                                  ),
                                                  // 日期显示和选择
                                                  WidgetSpan(
                                                    child: GestureDetector(
                                                      onTap: () async {
                                                        // 显示日期选择器
                                                        final DateTime? picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: DateTime.now(),
                                                          firstDate: DateTime.now(),
                                                          lastDate: DateTime(2101),
                                                          builder: (BuildContext context, Widget? child) {
                                                            return Theme(
                                                              data: ThemeData.light().copyWith(
                                                                colorScheme: theme.colorScheme,
                                                              ),
                                                              child: child!,
                                                            );
                                                          },
                                                        );
                                                        
                                                        if (picked != null) {
                                                          setState(() {
                                                            _repeatEndDate = '${picked.year}年${picked.month}月${picked.day}日';
                                                          });
                                                        }
                                                      },
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          SizedBox(width: 4),
                                                          Text(
                                                            _repeatEndDate == '无结束日期' ? '2026年4月27日' : _repeatEndDate,
                                                            style: TextStyle(
                                                              color: theme.colorScheme.primary,
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          SizedBox(width: 4),
                                                          Icon(
                                                            Icons.arrow_drop_down,
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            size: 16,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  // 删除结束日期链接
                                                  WidgetSpan(
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(width: 8),
                                                        Text(
                                                          '删除结束日期',
                                                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 14),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              overflow: TextOverflow.visible,
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              // 每月重复
                              if (_repeatType == '每月')
                                Column(
                                  children: [
                                    // 月重复类型选择
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 在当前日期选项
                                          RadioListTile(
                                            title: Text('在${_date.split('/').last}日'),
                                            value: 'date',
                                            groupValue: _monthRepeatType,
                                            onChanged: (value) {
                                              setState(() {
                                                _monthRepeatType = value as String;
                                              });
                                            },
                                            activeColor: theme.colorScheme.primary,
                                          ),
                                          // 在第几个星期几选项
                                          RadioListTile(
                                            title: Text('在${_getNthWeekday()}个星期${_getWeekdayFromDate()}'),
                                            value: 'nth_weekday',
                                            groupValue: _monthRepeatType,
                                            onChanged: (value) {
                                              setState(() {
                                                _monthRepeatType = value as String;
                                              });
                                            },
                                            activeColor: theme.colorScheme.primary,
                                          ),
                                          // 只有当当前日期是当月的最后一个星期几时，才显示"在最后一个星期几"选项
                                          if (_isLastWeekday())
                                            RadioListTile(
                                              title: Text('在最后一个星期${_getWeekdayFromDate()}'),
                                              value: 'last_weekday',
                                              groupValue: _monthRepeatType,
                                              onChanged: (value) {
                                                setState(() {
                                                  _monthRepeatType = value as String;
                                                });
                                              },
                                              activeColor: theme.colorScheme.primary,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // 规则描述
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 规则描述和日期选择在同一行
                                          Container(
                                            width: double.infinity,
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  // 动态生成的规则描述文本
                                                  TextSpan(
                                                    text: _generateRuleDescription(),
                                                    style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                                  ),
                                                  // 日期显示和选择
                                                  WidgetSpan(
                                                    child: GestureDetector(
                                                      onTap: () async {
                                                        // 显示日期选择器
                                                        final DateTime? picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: DateTime.now(),
                                                          firstDate: DateTime.now(),
                                                          lastDate: DateTime(2101),
                                                          builder: (BuildContext context, Widget? child) {
                                                            return Theme(
                                                              data: ThemeData.light().copyWith(
                                                                colorScheme: theme.colorScheme,
                                                              ),
                                                              child: child!,
                                                            );
                                                          },
                                                        );
                                                        
                                                        if (picked != null) {
                                                          setState(() {
                                                            _repeatEndDate = '${picked.year}年${picked.month}月${picked.day}日';
                                                          });
                                                        }
                                                      },
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          SizedBox(width: 4),
                                                          Text(
                                                            _repeatEndDate == '无结束日期' ? '2027年1月27日' : _repeatEndDate,
                                                            style: TextStyle(
                                                              color: theme.colorScheme.primary,
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          SizedBox(width: 4),
                                                          Icon(
                                                            Icons.arrow_drop_down,
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            size: 16,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  // 删除结束日期链接
                                                  WidgetSpan(
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(width: 8),
                                                        Text(
                                                          '删除结束日期',
                                                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 14),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              overflow: TextOverflow.visible,
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              // 每年重复
                              if (_repeatType == '每年')
                                Column(
                                  children: [
                                    // 年重复类型选择
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 在当前月日选项
                                          RadioListTile(
                                            title: Text('在${_date.split('/')[1]}月${_date.split('/')[2]}日'),
                                            value: 'date',
                                            groupValue: _yearRepeatType,
                                            onChanged: (value) {
                                              setState(() {
                                                _yearRepeatType = value as String;
                                              });
                                            },
                                            activeColor: theme.colorScheme.primary,
                                          ),
                                          // 在当前月的第几个星期几选项
                                          RadioListTile(
                                            title: Text('在${_date.split('/')[1]}月的${_getNthWeekday()}个星期${_getWeekdayFromDate()}'),
                                            value: 'nth_weekday',
                                            groupValue: _yearRepeatType,
                                            onChanged: (value) {
                                              setState(() {
                                                _yearRepeatType = value as String;
                                              });
                                            },
                                            activeColor: theme.colorScheme.primary,
                                          ),
                                          // 只有当当前日期是当月的最后一个星期几时，才显示"在最后一个星期几"选项
                                          if (_isLastWeekday())
                                            RadioListTile(
                                              title: Text('在${_date.split('/')[1]}月的最后一个星期${_getWeekdayFromDate()}'),
                                              value: 'last_weekday',
                                              groupValue: _yearRepeatType,
                                              onChanged: (value) {
                                                setState(() {
                                                  _yearRepeatType = value as String;
                                                });
                                              },
                                              activeColor: theme.colorScheme.primary,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // 规则描述
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 规则描述和日期选择在同一行
                                          Container(
                                            width: double.infinity,
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  // 动态生成的规则描述文本
                                                  TextSpan(
                                                    text: _generateRuleDescription(),
                                                    style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14),
                                                  ),
                                                  // 日期显示和选择
                                                  WidgetSpan(
                                                    child: GestureDetector(
                                                      onTap: () async {
                                                        // 显示日期选择器
                                                        final DateTime? picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: DateTime.now(),
                                                          firstDate: DateTime.now(),
                                                          lastDate: DateTime(2101),
                                                          builder: (BuildContext context, Widget? child) {
                                                            return Theme(
                                                              data: ThemeData.light().copyWith(
                                                                colorScheme: theme.colorScheme,
                                                              ),
                                                              child: child!,
                                                            );
                                                          },
                                                        );
                                                        
                                                        if (picked != null) {
                                                          setState(() {
                                                            _repeatEndDate = '${picked.year}年${picked.month}月${picked.day}日';
                                                          });
                                                        }
                                                      },
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          SizedBox(width: 4),
                                                          Text(
                                                            _repeatEndDate == '无结束日期' ? '2027年1月27日' : _repeatEndDate,
                                                            style: TextStyle(
                                                              color: theme.colorScheme.primary,
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          SizedBox(width: 4),
                                                          Icon(
                                                            Icons.arrow_drop_down,
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            size: 16,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  // 删除结束日期链接
                                                  WidgetSpan(
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(width: 8),
                                                        Text(
                                                          '删除结束日期',
                                                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 14),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              overflow: TextOverflow.visible,
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  
                  // 其他设置
                  Text(
                    '其他设置',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  
                  // 优先级
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text('优先级', style: TextStyle(color: theme.colorScheme.onBackground)),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _buildPriorityButton('低', _priority == '低', theme),
                          const SizedBox(width: 8),
                          _buildPriorityButton('中', _priority == '中', theme),
                          const SizedBox(width: 8),
                          _buildPriorityButton('高', _priority == '高', theme),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // 位置提醒
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.pink),
                          const SizedBox(width: 8),
                          Text('位置提醒', style: TextStyle(color: theme.colorScheme.onBackground)),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: _locationReminder,
                        onChanged: (value) {
                          setState(() {
                            _locationReminder = value;
                          });
                        },
                        activeColor: theme.colorScheme.primary,
                        inactiveTrackColor: theme.colorScheme.surfaceVariant,
                      ),
                    ],
                  ),
                  
                  // 位置选择和半径设置（仅当位置提醒开启时显示）
                  if (_locationReminder)
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        // 选择位置
                        InkWell(
                          onTap: () {
                            _selectLocation();
                          },
                          borderRadius: BorderRadius.circular(12),
                          splashColor: theme.colorScheme.primary.withOpacity(0.1),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_searching, color: theme.colorScheme.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '选择位置',
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _locationName ?? '点击选择位置',
                                        style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 半径设置
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '提醒范围',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: '输入提醒范围 (50-500米)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: theme.colorScheme.primary),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        fillColor: theme.colorScheme.background,
                                        filled: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      controller: TextEditingController(text: _radius.toInt().toString())..selection = TextSelection.collapsed(offset: _radius.toInt().toString().length),
                                      onSubmitted: (value) {
                                        _updateRadiusFromInput(value);
                                      },
                                      onChanged: (value) {
                                        // 实时更新，但只在输入有效数字时更新
                                        if (RegExp(r'^\d*$').hasMatch(value)) {
                                          // 这里可以添加实时更新逻辑，但为了避免频繁更新，我们只在提交时更新
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '米',
                                    style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  
                  // 底部操作栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: Icon(Icons.alternate_email, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.tag, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _showAddTagDialog();
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.link, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_upward, color: theme.colorScheme.primary),
                        onPressed: () {
                          _saveTodo();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建分类标签
  Widget _buildCategoryTag(String name, bool isSelected, IconData icon, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = name;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onBackground, size: 14),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onBackground,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 解析时间字符串为DateTime对象
  DateTime _parseTime(String timeString) {
    if (timeString == '全天') {
      return DateTime(2000, 1, 1, 0, 0);
    }
    List<String> parts = timeString.split(':');
    if (parts.length != 2) {
      return DateTime(2000, 1, 1, 0, 0);
    }
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  /// 构建优先级按钮
  Widget _buildPriorityButton(String label, bool isSelected, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _priority = label;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onBackground,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 显示添加分类对话框
  void _showAddCategoryDialog() {
    final categoryController = TextEditingController();
    final theme = ref.read(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceVariant,
        title: Text('添加分类', style: TextStyle(color: theme.colorScheme.onBackground)),
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
            fillColor: theme.colorScheme.surfaceVariant,
          ),
          style: TextStyle(color: theme.colorScheme.onBackground),
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
                
                Navigator.pop(context);
              }
            },
            child: Text('添加', style: TextStyle(color: theme.colorScheme.onPrimary)),
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
  
  /// 显示添加标签对话框
  Future<void> _showAddTagDialog() async {
    final TextEditingController tagController = TextEditingController();
    final theme = ref.read(currentThemeProvider);
    
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
        _tags.add(result);
      });
    }
  }
  
  /// 选择位置
  Future<void> _selectLocation() async {
    try {
      // 导航到地图选择页面
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapSelectPage(
            initialLocation: _latitude != null && _longitude != null
                ? LatLng(_latitude!, _longitude!)
                : null,
          ),
        ),
      );
      
      // 处理返回结果
      if (result != null) {
        setState(() {
          _latitude = result['latitude'];
          _longitude = result['longitude'];
          _locationName = result['locationName'];
        });
      }
    } catch (e) {
      debugPrint('选择位置失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('选择位置失败，请重试'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
  
  /// 从输入更新半径值
  void _updateRadiusFromInput(String value) {
    try {
      int radius = int.parse(value);
      // 确保半径在50-500米范围内
      if (radius < 50) {
        radius = 50;
      } else if (radius > 500) {
        radius = 500;
      }
      setState(() {
        _radius = radius.toDouble();
      });
    } catch (e) {
      // 输入无效，设置默认值50
      setState(() {
        _radius = 50.0;
      });
    }
  }

  /// 显示重复类型选择器
  void _showRepeatTypeSelector(Offset position) {
    final theme = ref.read(currentThemeProvider);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: [
        for (var type in ['不重复', '每天', '每周', '每月', '每年']) 
          PopupMenuItem(
            value: type,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    type,
                    style: TextStyle(
                      color: _repeatType == type 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.onBackground,
                    ),
                  ),
                ),
                if (_repeatType == type)
                  Icon(Icons.check, color: theme.colorScheme.primary, size: 16),
              ],
            ),
          ),
        PopupMenuItem(
          value: '自定义',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '自定义',
                  style: TextStyle(
                    color: _repeatType == '自定义' 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.onBackground,
                  ),
                ),
              ),
              if (_repeatType == '自定义')
                Icon(Icons.check, color: theme.colorScheme.primary, size: 16),
            ],
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ).then((value) {
      if (value != null) {
        final selectedType = value as String;
        setState(() {
          _repeatType = selectedType;
        });
      }
    });
  }



  /// 显示提醒时间选择器
  void _showReminderTimeSelector(Offset position) {
    final theme = ref.read(currentThemeProvider);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: [
        for (var time in ['不提醒', '5分钟前', '15分钟前', '30分钟前', '1小时前', '自定义时间']) 
          PopupMenuItem(
            value: time,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    time,
                    style: TextStyle(
                      color: _reminderTime == time 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.onBackground,
                    ),
                  ),
                ),
                if (_reminderTime == time)
                  Icon(Icons.check, color: theme.colorScheme.primary, size: 16),
              ],
            ),
          ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ).then((value) {
      if (value != null) {
        final selectedTime = value as String;
        if (selectedTime == '自定义时间') {
          _showCustomReminderTimePicker();
        } else {
          setState(() {
            _reminderTime = selectedTime;
          });
        }
      }
    });
  }

  /// 显示自定义提醒时间选择器
  void _showCustomReminderTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        final theme = ref.read(currentThemeProvider);
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: theme.colorScheme,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _reminderTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  /// 显示重复单位选择器
  void _showRepeatUnitSelector() {
    final theme = ref.read(currentThemeProvider);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        200,
        0,
        0,
      ),
      items: [
        for (var unit in ['天', '周', '月', '年']) 
          PopupMenuItem(
            value: unit,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: _repeatUnit == unit 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.onBackground,
                    ),
                  ),
                ),
                if (_repeatUnit == unit)
                  Icon(Icons.check, color: theme.colorScheme.primary, size: 16),
              ],
            ),
          ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ).then((value) {
      if (value != null) {
        setState(() {
          _repeatUnit = value as String;
        });
      }
    });
  }

  /// 获取日期对应的星期几
  String _getWeekdayFromDate() {
    final dateParts = _date.split('/');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    final dateTime = DateTime(year, month, day);
    
    // 获取星期几（1-7，星期一为1）
    final weekday = dateTime.weekday;
    // 转换为中文星期几
    return ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
  }

  /// 获取日期是当月的第几个星期几
  String _getNthWeekday() {
    final dateParts = _date.split('/');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    final dateTime = DateTime(year, month, day);
    
    // 计算是当月的第几个星期几
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysSinceFirst = dateTime.difference(firstDayOfMonth).inDays;
    final nthWeekday = (daysSinceFirst ~/ 7) + 1;
    
    return ['第一', '第二', '第三', '第四', '第五'][nthWeekday - 1];
  }

  /// 判断当前日期是否是当月的最后一个星期几
  bool _isLastWeekday() {
    final dateParts = _date.split('/');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    final dateTime = DateTime(year, month, day);
    
    // 获取当前星期几
    final weekday = dateTime.weekday;
    
    // 获取下个月的第一天
    final nextMonth = DateTime(year, month + 1, 1);
    
    // 向前遍历，找到本月的最后一个相同星期几
    DateTime lastWeekday = nextMonth.subtract(const Duration(days: 1));
    while (lastWeekday.weekday != weekday) {
      lastWeekday = lastWeekday.subtract(const Duration(days: 1));
    }
    
    // 判断当前日期是否是最后一个星期几
    return dateTime.day == lastWeekday.day;
  }

  /// 生成规则描述文本
  String _generateRuleDescription() {
    if (_repeatUnit == '天') {
      return '每${_repeatInterval}天发生一次，直到';
    } else if (_repeatUnit == '周') {
      if (_selectedWeekdays.isEmpty) {
        return '每${_repeatInterval}周发生一次，直到';
      } else if (_selectedWeekdays.length == 7) {
        // 如果选中了所有7天，显示每天发生一次
        return '每天发生一次，直到';
      } else if (_selectedWeekdays.length == 1) {
        final weekday = ['一', '二', '三', '四', '五', '六', '日'][_selectedWeekdays[0]];
        return '每个星期${weekday}发生一次，直到';
      } else {
        _selectedWeekdays.sort();
        final weekdays = _selectedWeekdays.map((i) => ['一', '二', '三', '四', '五', '六', '日'][i]).join('、');
        return '每${_repeatInterval}周的星期${weekdays}发生一次，直到';
      }
    } else if (_repeatUnit == '月') {
      final weekday = _getWeekdayFromDate();
      
      if (_monthRepeatType == 'date') {
        return '在${_date.split('/').last}日发生一次，直到';
      } else if (_monthRepeatType == 'nth_weekday') {
        final nthWeekday = _getNthWeekday();
        return '在${nthWeekday}个星期${weekday}发生一次，直到';
      } else if (_monthRepeatType == 'last_weekday') {
        return '在最后一个星期${weekday}发生一次，直到';
      }
    } else if (_repeatUnit == '年') {
      final dateParts = _date.split('/');
      final month = dateParts[1];
      final day = dateParts[2];
      final weekday = _getWeekdayFromDate();
      
      if (_yearRepeatType == 'date') {
        return '每年${month}月${day}日发生一次，直到';
      } else if (_yearRepeatType == 'nth_weekday') {
        final nthWeekday = _getNthWeekday();
        return '每年${month}月的${nthWeekday}个星期${weekday}发生一次，直到';
      } else if (_yearRepeatType == 'last_weekday') {
        return '每年${month}月的最后一个星期${weekday}发生一次，直到';
      }
    }
    return '每${_repeatInterval}${_repeatUnit}发生一次，直到';
  }

  /// 保存待办事项
  void _saveTodo() {
    if (_titleController.text.isEmpty) {
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入任务标题'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // 转换优先级
    TodoPriority priority;
    switch (_priority) {
      case '高':
        priority = TodoPriority.high;
        break;
      case '中':
        priority = TodoPriority.medium;
        break;
      case '低':
        priority = TodoPriority.low;
        break;
      default:
        priority = TodoPriority.medium;
    }

    // 查找选中分类的ID
    String categoryId = '';
    for (var category in _categories) {
      if (category.name == _selectedCategory) {
        categoryId = category.id;
        break;
      }
    }

    // 解析开始日期
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day);
    if (_date != '今天') {
      List<String> dateParts = _date.split('/');
      if (dateParts.length == 3) {
        int year = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int day = int.parse(dateParts[2]);
        startDate = DateTime(year, month, day);
      } else if (dateParts.length == 2) {
        int month = int.parse(dateParts[0]);
        int day = int.parse(dateParts[1]);
        startDate = DateTime(now.year, month, day);
      }
    }

    // 解析结束日期
    DateTime endDate = startDate;
    if (_endDate != '今天') {
      List<String> dateParts = _endDate.split('/');
      if (dateParts.length == 3) {
        int year = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int day = int.parse(dateParts[2]);
        endDate = DateTime(year, month, day);
      } else if (dateParts.length == 2) {
        int month = int.parse(dateParts[0]);
        int day = int.parse(dateParts[1]);
        endDate = DateTime(now.year, month, day);
      }
    }

    // 解析开始时间和结束时间
    DateTime? startTime;
    DateTime? endTime;
    
    if (_isAllDay) {
      // 全天任务：设置开始和结束日期
      startTime = startDate;
      endTime = endDate;
    } else {
      // 非全天任务：设置具体的开始和结束时间
      if (_startTime != '全天') {
        List<String> timeParts = _startTime.split(':');
        if (timeParts.length == 2) {
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          startTime = DateTime(startDate.year, startDate.month, startDate.day, hour, minute);
        }
      }
      
      if (_endTime.isNotEmpty && _endTime != '全天') {
        List<String> timeParts = _endTime.split(':');
        if (timeParts.length == 2) {
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          endTime = DateTime(endDate.year, endDate.month, endDate.day, hour, minute);
        }
      }
    }

    // 计算提醒时间
    DateTime? reminderTime;
    if (_reminderTime != '不提醒') {
      if (_reminderTime.contains('分钟前') || _reminderTime.contains('小时前')) {
        // 相对时间提醒（如5分钟前）
        final baseDate = startTime ?? startDate;
        if (_reminderTime == '5分钟前') {
          reminderTime = baseDate.subtract(const Duration(minutes: 5));
        } else if (_reminderTime == '15分钟前') {
          reminderTime = baseDate.subtract(const Duration(minutes: 15));
        } else if (_reminderTime == '30分钟前') {
          reminderTime = baseDate.subtract(const Duration(minutes: 30));
        } else if (_reminderTime == '1小时前') {
          reminderTime = baseDate.subtract(const Duration(hours: 1));
        }
      } else {
        // 自定义时间提醒（如14:30）
        List<String> timeParts = _reminderTime.split(':');
        if (timeParts.length == 2) {
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          reminderTime = DateTime(startDate.year, startDate.month, startDate.day, hour, minute);
        }
      }
    }
    
    // 处理重复任务
    RepeatType repeatType;
    switch (_repeatType) {
      case '不重复':
        repeatType = RepeatType.none;
        break;
      case '每天':
        repeatType = RepeatType.daily;
        break;
      case '每周':
        repeatType = RepeatType.weekly;
        break;
      case '每月':
        repeatType = RepeatType.monthly;
        break;
      case '每年':
        repeatType = RepeatType.yearly;
        break;
      case '自定义':
        repeatType = RepeatType.custom;
        break;
      default:
        repeatType = RepeatType.none;
    }
    
    // 处理重复结束日期
    DateTime? repeatEndDate;
    if (_repeatEndDate != '无结束日期') {
      List<String> dateParts = _repeatEndDate.split('/');
      if (dateParts.length == 3) {
        int month = int.parse(dateParts[0]);
        int day = int.parse(dateParts[1]);
        int year = int.parse(dateParts[2]);
        repeatEndDate = DateTime(year, month, day);
      }
    }

    // 根据是否是编辑模式执行不同的保存逻辑
    if (widget.todo != null) {
      // 编辑模式：更新待办事项
  final updatedTodo = widget.todo!.copyWith(
    title: _titleController.text,
    content: _contentBlocks,
    categoryId: categoryId,
    tags: _tags.isNotEmpty ? _tags : [_selectedCategory],
    priority: priority,
        date: endTime ?? endDate,
        startDate: startTime ?? startDate,
        reminderTime: reminderTime,
        repeatType: repeatType,
        repeatInterval: _repeatInterval,
        repeatEndDate: repeatEndDate,
        lastRepeatDate: repeatType == RepeatType.none ? null : DateTime.now(),
        updatedAt: DateTime.now(),
        // 位置提醒相关字段
        isLocationReminderEnabled: _locationReminder,
        latitude: _locationReminder ? _latitude : null,
        longitude: _locationReminder ? _longitude : null,
        radius: _locationReminder ? _radius : null,
        locationName: _locationReminder ? _locationName : null,
      );
      
      // 通过Bloc更新待办事项
      context.read<TodoBloc>().add(UpdateTodo(updatedTodo));
    } else {
      // 添加模式：创建新待办事项
  final newTodo = Todo(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    categoryId: categoryId,
    title: _titleController.text,
    content: _contentBlocks,
    isCompleted: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    date: endTime ?? endDate,
    startDate: startTime ?? startDate,
    reminderTime: reminderTime,
    priority: priority,
    tags: _tags.isNotEmpty ? _tags : [_selectedCategory],
        repeatType: repeatType,
        repeatInterval: _repeatInterval,
        repeatEndDate: repeatEndDate,
        lastRepeatDate: repeatType == RepeatType.none ? null : DateTime.now(),
        // 位置提醒相关字段
        isLocationReminderEnabled: _locationReminder,
        latitude: _locationReminder ? _latitude : null,
        longitude: _locationReminder ? _longitude : null,
        radius: _locationReminder ? _radius : null,
        locationName: _locationReminder ? _locationName : null,
      );
      
      // 通过Bloc添加待办事项
      context.read<TodoBloc>().add(AddTodo(newTodo));
    }

    // 返回上一页
    Navigator.pop(context);
  }
}