import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/blocs/pomodoro_bloc.dart';
import 'package:moment_keep/services/database_service.dart';

import 'package:moment_keep/core/theme/theme_provider.dart';

/// 番茄钟页面
class PomodoroPage extends StatelessWidget {
  /// 构造函数
  const PomodoroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PomodoroBloc(),
      child: const PomodoroView(),
    );
  }
}

/// 番茄钟视图
class PomodoroView extends ConsumerStatefulWidget {
  /// 构造函数
  const PomodoroView({super.key});

  @override
  ConsumerState<PomodoroView> createState() => _PomodoroViewState();
}

class _PomodoroViewState extends ConsumerState<PomodoroView> {
  bool _showMiddleCircle = true;
  bool _showInnerCircle = true;
  bool _isVibrationEnabled = true; // 震动反馈状态
  bool _isAudioEnabled = true; // 音频反馈状态
  bool _isRandomAudioEnabled = true; // 随机音频状态，默认启用
  bool _isAudioSelectionEnabled = false; // 音频选择状态
  String _selectedAudio = 'default'; // 选中的音频
  bool _isStatsExpanded = false;
  bool _isFocusMode = true; // 波动开关：true=专注模式，false=休息模式
  int _duration = 25; // 合并的时长设置
  int _focusDuration = 25; // 默认25分钟专注
  int _restDuration = 5; // 默认5分钟休息
  int _focusSeconds = 0; // 默认0秒专注
  int _restSeconds = 0; // 默认0秒休息
  bool _isInterruptionDialogVisible = false; // 控制中断记录弹窗显示
  bool _isFullScreen = false; // 控制是否全屏显示
  final TextEditingController _interruptionController =
      TextEditingController(); // 中断原因输入控制器
  
  // 时间编辑相关状态
  bool _isEditingMinutes = false; // 是否正在编辑分钟
  bool _isEditingSeconds = false; // 是否正在编辑秒
  final TextEditingController _minutesController = TextEditingController(); // 分钟输入控制器
  final TextEditingController _secondsController = TextEditingController(); // 秒输入控制器

  // 统计数据状态
  Map<String, dynamic> _todayFocusStats = {
    'count': 0,
    'duration': 0,
    'averageDuration': 0,
    'interruptions': 0,
  };
  Map<String, dynamic> _todayRestStats = {
    'count': 0,
    'duration': 0,
    'averageDuration': 0,
    'interruptions': 0,
  };
  Map<String, dynamic> _yesterdayFocusStats = {
    'count': 0,
    'duration': 0,
    'averageDuration': 0,
    'interruptions': 0,
  };
  Map<String, dynamic> _yesterdayRestStats = {
    'count': 0,
    'duration': 0,
    'averageDuration': 0,
    'interruptions': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _loadPomodoroStats();
  }

  /// 加载保存的设置
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _showMiddleCircle = prefs.getBool('showMiddleCircle') ?? true;
        _showInnerCircle = prefs.getBool('showInnerCircle') ?? true;
        _isVibrationEnabled = prefs.getBool('isVibrationEnabled') ?? true;
        _isAudioEnabled = prefs.getBool('isAudioEnabled') ?? true;
        _isRandomAudioEnabled = prefs.getBool('isRandomAudioEnabled') ?? true;
        _isAudioSelectionEnabled = prefs.getBool('isAudioSelectionEnabled') ?? false;
        _selectedAudio = prefs.getString('selectedAudio') ?? 'default';
      });
      
      print('Settings loaded successfully');
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('showMiddleCircle', _showMiddleCircle);
      await prefs.setBool('showInnerCircle', _showInnerCircle);
      await prefs.setBool('isVibrationEnabled', _isVibrationEnabled);
      await prefs.setBool('isAudioEnabled', _isAudioEnabled);
      await prefs.setBool('isRandomAudioEnabled', _isRandomAudioEnabled);
      await prefs.setBool('isAudioSelectionEnabled', _isAudioSelectionEnabled);
      await prefs.setString('selectedAudio', _selectedAudio);
      
      print('Settings saved successfully');
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  /// 加载番茄钟统计数据
  Future<void> _loadPomodoroStats() async {
    try {
      final dbService = DatabaseService();
      final db = await dbService.database;

      // 获取今天和昨天的日期范围
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      // 今天的开始和结束时间戳
      final todayStart = today.millisecondsSinceEpoch;
      final todayEnd = tomorrow.millisecondsSinceEpoch - 1;

      // 昨天的开始和结束时间戳
      final yesterdayStart = yesterday.millisecondsSinceEpoch;
      final yesterdayEnd = todayStart - 1;

      // 查询今天的专注时钟数据
      final todayFocusResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(duration_minutes * 60) as duration,
          AVG(duration_minutes * 60) as averageDuration,
          SUM(CASE WHEN notes = '暂停' THEN 1 ELSE 0 END) as interruptions
        FROM pomodoro_records 
        WHERE start_time >= ? AND start_time <= ? 
          AND state = 'focusing' 
          AND is_completed = 1
      ''', [todayStart, todayEnd]);

      if (todayFocusResult.isNotEmpty) {
        _todayFocusStats = {
          'count': todayFocusResult[0]['count'] ?? 0,
          'duration': todayFocusResult[0]['duration'] ?? 0,
          'averageDuration': todayFocusResult[0]['averageDuration'] ?? 0,
          'interruptions': todayFocusResult[0]['interruptions'] ?? 0,
        };
      }

      // 查询今天的休息时钟数据
      final todayRestResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(duration_minutes * 60) as duration,
          AVG(duration_minutes * 60) as averageDuration,
          SUM(CASE WHEN notes = '暂停' THEN 1 ELSE 0 END) as interruptions
        FROM pomodoro_records 
        WHERE start_time >= ? AND start_time <= ? 
          AND state = 'resting' 
          AND is_completed = 1
      ''', [todayStart, todayEnd]);

      if (todayRestResult.isNotEmpty) {
        _todayRestStats = {
          'count': todayRestResult[0]['count'] ?? 0,
          'duration': todayRestResult[0]['duration'] ?? 0,
          'averageDuration': todayRestResult[0]['averageDuration'] ?? 0,
          'interruptions': todayRestResult[0]['interruptions'] ?? 0,
        };
      }

      // 查询昨天的专注时钟数据
      final yesterdayFocusResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(duration_minutes * 60) as duration,
          AVG(duration_minutes * 60) as averageDuration,
          SUM(CASE WHEN notes = '暂停' THEN 1 ELSE 0 END) as interruptions
        FROM pomodoro_records 
        WHERE start_time >= ? AND start_time <= ? 
          AND state = 'focusing' 
          AND is_completed = 1
      ''', [yesterdayStart, yesterdayEnd]);

      if (yesterdayFocusResult.isNotEmpty) {
        _yesterdayFocusStats = {
          'count': yesterdayFocusResult[0]['count'] ?? 0,
          'duration': yesterdayFocusResult[0]['duration'] ?? 0,
          'averageDuration': yesterdayFocusResult[0]['averageDuration'] ?? 0,
          'interruptions': yesterdayFocusResult[0]['interruptions'] ?? 0,
        };
      }

      // 查询昨天的休息时钟数据
      final yesterdayRestResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(duration_minutes * 60) as duration,
          AVG(duration_minutes * 60) as averageDuration,
          SUM(CASE WHEN notes = '暂停' THEN 1 ELSE 0 END) as interruptions
        FROM pomodoro_records 
        WHERE start_time >= ? AND start_time <= ? 
          AND state = 'resting' 
          AND is_completed = 1
      ''', [yesterdayStart, yesterdayEnd]);

      if (yesterdayRestResult.isNotEmpty) {
        _yesterdayRestStats = {
          'count': yesterdayRestResult[0]['count'] ?? 0,
          'duration': yesterdayRestResult[0]['duration'] ?? 0,
          'averageDuration': yesterdayRestResult[0]['averageDuration'] ?? 0,
          'interruptions': yesterdayRestResult[0]['interruptions'] ?? 0,
        };
      }

      setState(() {});
    } catch (e) {
      print('Error loading pomodoro stats: $e');
    }
  }

  /// 格式化时长为时分格式
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours h ${minutes}m';
    } else {
      return '$minutes m';
    }
  }

  /// 格式化平均时长
  String _formatAverageDuration(num seconds) {
    final minutes = (seconds / 60).round();
    return '$minutes m';
  }

  /// 显示音频选择对话框
  void _showAudioSelectionDialog(BuildContext context) {
    // 可用的音频列表（包含所有在pubspec.yaml中列出的音频文件）
    final audioOptions = [
      {'value': 'default', 'label': '默认音频'},
      {'value': 'bell', 'label': '铃声'},
      {'value': 'chime', 'label': '风铃'},
      {'value': 'notification', 'label': '通知音'},
      {'value': 'alarm', 'label': '闹钟'},
      {'value': 'BELLLrg_Church bell', 'label': '教堂钟声'},
      {'value': 'Ba', 'label': 'Ba音效'},
      {'value': 'BellNotification', 'label': '通知铃声'},
      {'value': 'BellRing', 'label': '铃响'},
      {'value': 'Deng', 'label': '登声'},
      {'value': 'Ding', 'label': '叮声'},
      {'value': 'DingEnd', 'label': '结束叮声'},
      {'value': 'KeTingEnd', 'label': '课堂结束'},
      {'value': 'Livechat', 'label': '聊天提示'},
      {'value': 'Notification', 'label': '通知'},
      {'value': 'Notification2', 'label': '通知2'},
      {'value': 'Notification3', 'label': '通知3'},
      {'value': 'Piano', 'label': '钢琴'},
      {'value': 'Rock', 'label': '摇滚'},
      {'value': 'cute_notification_sounds', 'label': '可爱通知音'},
      {'value': 'silence', 'label': '静音'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        // 使用局部变量来跟踪当前选择
        String selectedAudio = _selectedAudio;
        
        return AlertDialog(
          title: const Text('选择音频'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: audioOptions.map((audio) {
                    return RadioListTile<String>(
                      title: Text(audio['label']!),
                      value: audio['value']!,
                      groupValue: selectedAudio,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedAudio = value;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 点击确定时更新全局状态
                setState(() {
                  _selectedAudio = selectedAudio;
                });
                Navigator.of(context).pop();
                _saveSettings();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _interruptionController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  /// 显示时间选择对话框
  void _showTimePicker(BuildContext context, {bool selectMinutes = false, bool selectSeconds = false}) {
    // 确定当前模式（专注或休息）
    final isFocusMode = _isFocusMode;
    
    // 获取当前设置的时间
    int currentMinutes = isFocusMode ? _focusDuration : _restDuration;
    int currentSeconds = 0; // 默认秒为0

    // 如果是选择分钟或秒，显示相应的选择器
    if (selectMinutes || selectSeconds) {
      // 这里可以实现更复杂的时间选择逻辑
      // 为了简单起见，我们使用 showDialog 来显示一个简单的时间选择界面
      showDialog(
        context: context,
        builder: (context) {
          int selectedValue = selectMinutes ? currentMinutes : currentSeconds;
          int maxValue = selectMinutes ? 60 : 59;
          String title = selectMinutes ? '设置分钟' : '设置秒';

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 使用滑块选择时间
                Slider(
                  value: selectedValue.toDouble(),
                  min: 0,
                  max: maxValue.toDouble(),
                  divisions: maxValue,
                  label: '$selectedValue',
                  onChanged: (value) {
                    selectedValue = value.toInt();
                  },
                ),
                // 显示当前选择的值
                Text(
                  selectMinutes ? '$selectedValue 分钟' : '$selectedValue 秒',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (selectMinutes) {
                      if (isFocusMode) {
                        _focusDuration = selectedValue;
                      } else {
                        _restDuration = selectedValue;
                      }
                    } else {
                      // 秒的设置可以根据需要实现
                    }
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    } else {
      // 显示完整的时间选择器
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(isFocusMode ? '设置专注时长' : '设置休息时长'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 分钟设置
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('分钟:'),
                    DropdownButton<int>(
                      value: currentMinutes,
                      items: List.generate(61, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text('$index'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            currentMinutes = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 秒设置
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('秒:'),
                    DropdownButton<int>(
                      value: currentSeconds,
                      items: List.generate(60, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text('$index'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            currentSeconds = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (isFocusMode) {
                      _focusDuration = currentMinutes;
                    } else {
                      _restDuration = currentMinutes;
                    }
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      // 使用透明AppBar，实现沉浸式设计
      // 全屏模式下隐藏AppBar
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: const Text('番茄钟'),
              centerTitle: true,
              backgroundColor: theme.appBarTheme.backgroundColor,
              foregroundColor: theme.appBarTheme.foregroundColor,
              elevation: theme.appBarTheme.elevation,
              actions: [
                // 设置菜单
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      switch (value) {
                        case 'showMiddleCircle':
                          _showMiddleCircle = !_showMiddleCircle;
                          break;
                        case 'showInnerCircle':
                          _showInnerCircle = !_showInnerCircle;
                          break;
                        case 'toggleVibration':
                          _isVibrationEnabled = !_isVibrationEnabled;
                          context.read<PomodoroBloc>().add(ToggleVibration());
                          break;
                        case 'toggleAudio':
                          _isAudioEnabled = !_isAudioEnabled;
                          context.read<PomodoroBloc>().add(ToggleAudio());
                          
                          // 如果音频反馈被启用，确保至少有一个音频模式被选中
                          if (_isAudioEnabled && !_isRandomAudioEnabled && !_isAudioSelectionEnabled) {
                            _isRandomAudioEnabled = true;
                          }
                          break;
                        case 'toggleRandomAudio':
                          _isRandomAudioEnabled = !_isRandomAudioEnabled;
                          if (_isRandomAudioEnabled) {
                            _isAudioSelectionEnabled = false;
                          }
                          break;
                        case 'toggleAudioSelection':
                          _isAudioSelectionEnabled = !_isAudioSelectionEnabled;
                          if (_isAudioSelectionEnabled) {
                            _isRandomAudioEnabled = false;
                          }
                          // 打开音频选择对话框
                          _showAudioSelectionDialog(context);
                          break;
                      }
                    });
                    
                    // 保存设置
                    _saveSettings();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'showMiddleCircle',
                      child: Row(
                        children: [
                          Checkbox(
                            value: _showMiddleCircle,
                            onChanged: (value) {
                              setState(() {
                                _showMiddleCircle = value ?? true;
                              });
                              Navigator.pop(context);
                              _saveSettings();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('显示中间圈'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'showInnerCircle',
                      child: Row(
                        children: [
                          Checkbox(
                            value: _showInnerCircle,
                            onChanged: (value) {
                              setState(() {
                                _showInnerCircle = value ?? true;
                              });
                              Navigator.pop(context);
                              _saveSettings();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('显示内圈'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'toggleVibration',
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isVibrationEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isVibrationEnabled = value ?? true;
                                context
                                    .read<PomodoroBloc>()
                                    .add(ToggleVibration());
                              });
                              Navigator.pop(context);
                              _saveSettings();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('震动反馈'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggleAudio',
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isAudioEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isAudioEnabled = value ?? true;
                                context.read<PomodoroBloc>().add(ToggleAudio());
                                
                                // 如果音频反馈被启用，确保至少有一个音频模式被选中
                                if (_isAudioEnabled && !_isRandomAudioEnabled && !_isAudioSelectionEnabled) {
                                  _isRandomAudioEnabled = true;
                                }
                              });
                              Navigator.pop(context);
                              _saveSettings();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('音频反馈'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggleRandomAudio',
                      child: Row(
                        children: [
                          SizedBox(width: 24), // 添加缩进
                          Radio<bool>(
                            value: true,
                            groupValue: _isRandomAudioEnabled,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _isRandomAudioEnabled = true;
                                  _isAudioSelectionEnabled = false;
                                });
                                Navigator.pop(context);
                                _saveSettings();
                              }
                            },
                          ),
                          const Text('随机音频'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggleAudioSelection',
                      child: Row(
                        children: [
                          SizedBox(width: 24), // 添加缩进
                          Radio<bool>(
                            value: true,
                            groupValue: _isAudioSelectionEnabled,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _isAudioSelectionEnabled = true;
                                  _isRandomAudioEnabled = false;
                                });
                                Navigator.pop(context);
                                _showAudioSelectionDialog(context);
                                _saveSettings();
                              }
                            },
                          ),
                          const Text('音频选择'),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 原有内容
          BlocBuilder<PomodoroBloc, PomodoroBlocState>(
            builder: (context, state) {
              // 获取当前状态信息
              String statusText = '准备开始';
              Color statusColor = theme.colorScheme.primary;
              int remainingTime =
                  _isFocusMode ? _focusDuration * 60 + _focusSeconds : _restDuration * 60 + _restSeconds;
              int totalTime =
                  _isFocusMode ? _focusDuration * 60 + _focusSeconds : _restDuration * 60 + _restSeconds;

              bool isRunning = false;

              if (state is PomodoroRunning) {
                isRunning = true;
                if (state.session.state == PomodoroState.focusing) {
                  statusText = '专注中';
                  statusColor = theme.colorScheme.primary;
                } else {
                  statusText = '休息中';
                  statusColor = theme.colorScheme.secondary;
                }
                remainingTime = state.session.remainingTime;
                totalTime = state.session.totalTime;
              } else if (state is PomodoroPaused) {
                isRunning = true;
                statusText = '已暂停';
                statusColor = theme.colorScheme.tertiary;
                remainingTime = state.session.remainingTime;
                totalTime = state.session.totalTime;
              } else if (state is PomodoroCompleted) {
                isRunning = false;
                statusText = '完成';
                statusColor = theme.colorScheme.primary;
                remainingTime = 0;
                totalTime = state.session.totalTime;
              }

              final minutes = (remainingTime ~/ 60).toString().padLeft(2, '0');
              final seconds = (remainingTime % 60).toString().padLeft(2, '0');

              // 计算三个圆环的进度
              // 最外圈：从0开始递增到100%
              final elapsedTime = totalTime - remainingTime;
              final totalProgress = elapsedTime / totalTime;

              // 中间圈：分钟进度（1分钟一圈）
              final minuteProgress = (remainingTime % 60) / 60;

              // 内圈：秒进度（1秒一圈）
              final secondProgress =
                  1.0 - (seconds == '00' ? 1.0 : int.parse(seconds) / 60);

              // 根据全屏状态决定显示内容
              if (_isFullScreen) {
                // 全屏模式：只显示核心内容，占据整个屏幕
                return SizedBox.expand(
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 状态显示
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              )
                                  .animate()
                                  .fadeIn(
                                      duration:
                                          const Duration(milliseconds: 500))
                                  .scale(
                                      duration:
                                          const Duration(milliseconds: 300)),

                              const SizedBox(height: 40),

                              // 三圈番茄钟设计
                              LayoutBuilder(builder: (context, constraints) {
                                // 使用相对宽度，适配不同屏幕
                                final clockSize =
                                    constraints.maxWidth * 0.7; // 时钟大小为屏幕宽度的70%
                                final maxClockSize = 400.0; // 最大不超过400px
                                final finalClockSize = clockSize > maxClockSize
                                    ? maxClockSize
                                    : clockSize;

                                return SizedBox(
                                  width: finalClockSize,
                                  height: finalClockSize,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // 最外圈：总时间进度（从0开始递增）
                                      SizedBox(
                                        width: finalClockSize,
                                        height: finalClockSize,
                                        child: CircularProgressIndicator(
                                          value: totalProgress,
                                          strokeWidth: finalClockSize *
                                              0.04, // 相对宽度，占时钟的4%
                                          backgroundColor: theme.colorScheme
                                              .surfaceContainerHighest,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  statusColor),
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),

                                      // 中间圈：分钟进度（1分钟一圈）
                                      if (_showMiddleCircle)
                                        SizedBox(
                                          width:
                                              finalClockSize * 0.833, // 250/300
                                          height: finalClockSize * 0.833,
                                          child: CircularProgressIndicator(
                                            value: minuteProgress,
                                            strokeWidth:
                                                finalClockSize * 0.027, // 8/300
                                            backgroundColor: theme.colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.7),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    statusColor.withValues(
                                                        alpha: 0.7)),
                                            strokeCap: StrokeCap.round,
                                          ),
                                        ),

                                      // 内圈：秒进度（1秒一圈）
                                      if (_showInnerCircle)
                                        SizedBox(
                                          width:
                                              finalClockSize * 0.667, // 200/300
                                          height: finalClockSize * 0.667,
                                          child: CircularProgressIndicator(
                                            value: secondProgress,
                                            strokeWidth:
                                                finalClockSize * 0.02, // 6/300
                                            backgroundColor: theme.colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    statusColor.withValues(
                                                        alpha: 0.5)),
                                            strokeCap: StrokeCap.round,
                                          ),
                                        ),

                                      // 中心时间显示
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // 可点击的时间显示
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // 分钟部分
                                              GestureDetector(
                                                onTap: () {
                                                  // 只有在初始状态或完成状态才能设置时间
                                                  if (state is PomodoroInitial || state is PomodoroCompleted) {
                                                    setState(() {
                                                      _isEditingMinutes = true;
                                                      _isEditingSeconds = false;
                                                      _minutesController.text = minutes;
                                                    });
                                                  }
                                                },
                                                child: _isEditingMinutes
                                                    ? Container(
                                                        width: finalClockSize * 0.25,
                                                        height: finalClockSize * 0.3,
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.surface,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: theme.colorScheme.primary,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: TextField(
                                                          controller: _minutesController,
                                                          keyboardType: TextInputType.number,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: finalClockSize * 0.25,
                                                            fontWeight: FontWeight.w700,
                                                            color: theme.colorScheme.onSurface,
                                                          ),
                                                          decoration: const InputDecoration(
                                                            border: InputBorder.none,
                                                            contentPadding: EdgeInsets.zero,
                                                          ),
                                                          onSubmitted: (value) {
                                                            // 提交分钟输入
                                                            int newMinutes = int.tryParse(value) ?? 0;
                                                            newMinutes = newMinutes.clamp(0, 99);
                                                            setState(() {
                                                              if (_isFocusMode) {
                                                                _focusDuration = newMinutes;
                                                              } else {
                                                                _restDuration = newMinutes;
                                                              }
                                                              _isEditingMinutes = false;
                                                            });
                                                          },
                                                          onTapOutside: (event) {
                                                            // 点击外部关闭编辑
                                                            int newMinutes = int.tryParse(_minutesController.text) ?? 0;
                                                            newMinutes = newMinutes.clamp(0, 99);
                                                            setState(() {
                                                              if (_isFocusMode) {
                                                                _focusDuration = newMinutes;
                                                              } else {
                                                                _restDuration = newMinutes;
                                                              }
                                                              _isEditingMinutes = false;
                                                            });
                                                          },
                                                        ),
                                                      )
                                                    : Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: finalClockSize * 0.02,
                                                          vertical: finalClockSize * 0.01,
                                                        ),
                                                        child: Text(
                                                          minutes,
                                                          style: TextStyle(
                                                            fontSize: finalClockSize * 0.25,
                                                            fontWeight: FontWeight.w700,
                                                            color:
                                                                theme.colorScheme.onSurface,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              Text(
                                                ':',
                                                style: TextStyle(
                                                  fontSize: finalClockSize * 0.25,
                                                  fontWeight: FontWeight.w700,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),
                                              // 秒部分
                                              GestureDetector(
                                                onTap: () {
                                                  // 只有在初始状态或完成状态才能设置时间
                                                  if (state is PomodoroInitial || state is PomodoroCompleted) {
                                                    setState(() {
                                                      _isEditingSeconds = true;
                                                      _isEditingMinutes = false;
                                                      _secondsController.text = seconds;
                                                    });
                                                  }
                                                },
                                                child: _isEditingSeconds
                                                    ? Container(
                                                        width: finalClockSize * 0.25,
                                                        height: finalClockSize * 0.3,
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.surface,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: theme.colorScheme.primary,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: TextField(
                                                          controller: _secondsController,
                                                          keyboardType: TextInputType.number,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: finalClockSize * 0.25,
                                                            fontWeight: FontWeight.w700,
                                                            color: theme.colorScheme.onSurface,
                                                          ),
                                                          decoration: const InputDecoration(
                                                            border: InputBorder.none,
                                                            contentPadding: EdgeInsets.zero,
                                                          ),
                                                          onSubmitted: (value) {
                                                            // 提交秒输入
                                                            int newSeconds = int.tryParse(value) ?? 0;
                                                            newSeconds = newSeconds.clamp(0, 59);
                                                            setState(() {
                                                              if (_isFocusMode) {
                                                                _focusSeconds = newSeconds;
                                                              } else {
                                                                _restSeconds = newSeconds;
                                                              }
                                                              _isEditingSeconds = false;
                                                            });
                                                          },
                                                          onTapOutside: (event) {
                                                            // 点击外部关闭编辑
                                                            int newSeconds = int.tryParse(_secondsController.text) ?? 0;
                                                            newSeconds = newSeconds.clamp(0, 59);
                                                            setState(() {
                                                              if (_isFocusMode) {
                                                                _focusSeconds = newSeconds;
                                                              } else {
                                                                _restSeconds = newSeconds;
                                                              }
                                                              _isEditingSeconds = false;
                                                            });
                                                          },
                                                        ),
                                                      )
                                                    : Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: finalClockSize * 0.02,
                                                          vertical: finalClockSize * 0.01,
                                                        ),
                                                        child: Text(
                                                          seconds,
                                                          style: TextStyle(
                                                            fontSize: finalClockSize * 0.25,
                                                            fontWeight: FontWeight.w700,
                                                            color: theme.colorScheme.onSurface,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ],
                                          ).animate().fadeIn(
                                              duration: const Duration(
                                                  milliseconds: 500)),
                                          SizedBox(
                                              height: finalClockSize *
                                                  0.027), // 8/300
                                          Text(
                                            '${totalTime ~/ 60} 分钟',
                                            style: TextStyle(
                                              fontSize: finalClockSize *
                                                  0.08, // 增大字体大小
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              })
                                  .animate()
                                  .fadeIn(
                                      duration:
                                          const Duration(milliseconds: 500))
                                  .scale(
                                      duration:
                                          const Duration(milliseconds: 300)),

                              const SizedBox(height: 40),

                              // 控制按钮区域：开始/重置 + 全屏退出按钮
                              LayoutBuilder(builder: (context, constraints) {
                                final screenWidth = constraints.maxWidth;

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 顶部：开始/暂停按钮 + 重置按钮
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // 开始/暂停/停止按钮
                                    ElevatedButton(
                                      onPressed: () {
                                        if (state is PomodoroInitial) {
                                          // 初始状态，开始番茄钟
                                          context.read<PomodoroBloc>().add(
                                                StartPomodoro(
                                                  duration: _isFocusMode
                                                      ? _focusDuration * 60 + _focusSeconds
                                                      : _restDuration * 60 + _restSeconds,
                                                  restDuration: _isFocusMode
                                                      ? _restDuration * 60 + _restSeconds
                                                      : _focusDuration * 60 + _focusSeconds,
                                                  initialState: _isFocusMode
                                                      ? PomodoroState.focusing
                                                      : PomodoroState.resting,
                                                  isVibrationEnabled:
                                                      _isVibrationEnabled,
                                                  isAudioEnabled:
                                                      _isAudioEnabled,
                                                  isRandomAudioEnabled:
                                                      _isRandomAudioEnabled,
                                                  isAudioSelectionEnabled:
                                                      _isAudioSelectionEnabled,
                                                  selectedAudio:
                                                      _selectedAudio,
                                                ),
                                              );
                                        } else if (state is PomodoroRunning) {
                                          // 运行状态，暂停番茄钟
                                          context
                                              .read<PomodoroBloc>()
                                              .add(PausePomodoro());
                                        } else if (state is PomodoroPaused) {
                                          // 暂停状态，恢复番茄钟
                                          context.read<PomodoroBloc>().add(
                                                StartPomodoro(
                                                  duration: state.session.totalTime,
                                                  restDuration: _isFocusMode
                                                      ? _restDuration * 60
                                                      : _focusDuration * 60,
                                                  initialState: state.session
                                                      .state, // 使用当前会话的状态
                                                  isVibrationEnabled:
                                                      _isVibrationEnabled,
                                                  isAudioEnabled:
                                                      _isAudioEnabled,
                                                ),
                                              );
                                        } else if (state is PomodoroCompleted) {
                                          // 完成状态，停止铃声/震动，重置番茄钟
                                          context
                                              .read<PomodoroBloc>()
                                              .add(ResetPomodoro());
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: state is PomodoroCompleted
                                            ? Colors.red // 完成状态显示红色
                                            : statusColor,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth *
                                              0.035, // 减小水平内边距
                                          vertical: screenWidth *
                                              0.015, // 减小垂直内边距
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              screenWidth * 0.03), // 减小圆角
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: screenWidth *
                                              0.018, // 减小字体大小
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: Text(
                                        state is PomodoroRunning
                                            ? '暂停'
                                            : state is PomodoroCompleted
                                                ? '停止'
                                                : '开始',
                                      ),
                                    )
                                            .animate()
                                            .fadeIn(
                                                duration: const Duration(
                                                    milliseconds: 500))
                                            .scale(
                                                duration: const Duration(
                                                    milliseconds: 300)),

                                        SizedBox(
                                            width:
                                                screenWidth * 0.015), // 减小按钮间距

                                        // 重置按钮
                                        ElevatedButton(
                                          onPressed: () {
                                            context
                                                .read<PomodoroBloc>()
                                                .add(ResetPomodoro());
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            foregroundColor: Colors.black87,
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  screenWidth * 0.03, // 减小水平内边距
                                              vertical: screenWidth *
                                                  0.015, // 减小垂直内边距
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      screenWidth *
                                                          0.03), // 减小圆角
                                            ),
                                            textStyle: TextStyle(
                                              fontSize:
                                                  screenWidth * 0.018, // 减小字体大小
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: const Text('重置'),
                                        )
                                            .animate()
                                            .fadeIn(
                                                duration: const Duration(
                                                    milliseconds: 500),
                                                delay: const Duration(
                                                    milliseconds: 100))
                                            .scale(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                delay: const Duration(
                                                    milliseconds: 100)),
                                      ],
                                    ),

                                    SizedBox(
                                        height: screenWidth * 0.02), // 减小按钮间距

                                    // 底部：记录中断按钮 + 退出全屏按钮
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // 记录中断按钮
                                        ElevatedButton(
                                          onPressed: () {
                                            // 显示中断记录弹窗
                                            setState(() {
                                              _interruptionController.clear();
                                              _isInterruptionDialogVisible =
                                                  true;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.orange.shade400,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: screenWidth *
                                                  0.035, // 减小水平内边距
                                              vertical: screenWidth *
                                                  0.015, // 减小垂直内边距
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      screenWidth *
                                                          0.03), // 减小圆角
                                            ),
                                            textStyle: TextStyle(
                                              fontSize:
                                                  screenWidth * 0.018, // 减小字体大小
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          child: const Text('记录中断'),
                                        )
                                            .animate()
                                            .fadeIn(
                                                duration: const Duration(
                                                    milliseconds: 500),
                                                delay: const Duration(
                                                    milliseconds: 200))
                                            .scale(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                delay: const Duration(
                                                    milliseconds: 200)),

                                        SizedBox(
                                            width:
                                                screenWidth * 0.015), // 减小按钮间距

                                        // 退出全屏按钮
                                        ElevatedButton(
                                          onPressed: () async {
                                            setState(() {
                                              _isFullScreen = false;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            foregroundColor: Colors.black87,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: screenWidth *
                                                  0.035, // 减小水平内边距
                                              vertical: screenWidth *
                                                  0.015, // 减小垂直内边距
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      screenWidth *
                                                          0.03), // 减小圆角
                                            ),
                                            textStyle: TextStyle(
                                              fontSize:
                                                  screenWidth * 0.018, // 减小字体大小
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: const Text('退出全屏'),
                                        )
                                            .animate()
                                            .fadeIn(
                                                duration: const Duration(
                                                    milliseconds: 500),
                                                delay: const Duration(
                                                    milliseconds: 300))
                                            .scale(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                delay: const Duration(
                                                    milliseconds: 300)),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // 普通模式：显示完整内容
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 状态显示
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 500))
                          .scale(duration: const Duration(milliseconds: 300)),

                      const SizedBox(height: 40),

                      // 三圈番茄钟设计
                      LayoutBuilder(builder: (context, constraints) {
                        // 使用相对宽度，适配不同屏幕
                        final clockSize =
                            constraints.maxWidth * 0.7; // 时钟大小为屏幕宽度的70%
                        final maxClockSize = 300.0; // 最大不超过300px
                        final finalClockSize =
                            clockSize > maxClockSize ? maxClockSize : clockSize;

                        return SizedBox(
                          width: finalClockSize,
                          height: finalClockSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 最外圈：总时间进度（从0开始递增）
                              SizedBox(
                                width: finalClockSize,
                                height: finalClockSize,
                                child: CircularProgressIndicator(
                                  value: totalProgress,
                                  strokeWidth:
                                      finalClockSize * 0.04, // 相对宽度，占时钟的4%
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      statusColor),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),

                              // 中间圈：分钟进度（1分钟一圈）
                              if (_showMiddleCircle)
                                SizedBox(
                                  width: finalClockSize * 0.833, // 250/300
                                  height: finalClockSize * 0.833,
                                  child: CircularProgressIndicator(
                                    value: minuteProgress,
                                    strokeWidth:
                                        finalClockSize * 0.027, // 8/300
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.7),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        statusColor.withValues(alpha: 0.7)),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),

                              // 内圈：秒进度（1秒一圈）
                              if (_showInnerCircle)
                                SizedBox(
                                  width: finalClockSize * 0.667, // 200/300
                                  height: finalClockSize * 0.667,
                                  child: CircularProgressIndicator(
                                    value: secondProgress,
                                    strokeWidth: finalClockSize * 0.02, // 6/300
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        statusColor.withValues(alpha: 0.5)),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),

                              // 中心时间显示
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 可点击的时间显示
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 分钟部分
                                      GestureDetector(
                                        onTap: () {
                                          // 只有在初始状态或完成状态才能设置时间
                                          if (state is PomodoroInitial || state is PomodoroCompleted) {
                                            setState(() {
                                              _isEditingMinutes = true;
                                              _isEditingSeconds = false;
                                              _minutesController.text = minutes;
                                            });
                                          }
                                        },
                                        child: _isEditingMinutes
                                            ? Container(
                                                width: finalClockSize * 0.25,
                                                height: finalClockSize * 0.3,
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surface,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: theme.colorScheme.primary,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller: _minutesController,
                                                  keyboardType: TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: finalClockSize * 0.213,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                  onSubmitted: (value) {
                                                    // 提交分钟输入
                                                    int newMinutes = int.tryParse(value) ?? 0;
                                                    newMinutes = newMinutes.clamp(0, 99);
                                                    setState(() {
                                                      if (_isFocusMode) {
                                                        _focusDuration = newMinutes;
                                                      } else {
                                                        _restDuration = newMinutes;
                                                      }
                                                      _isEditingMinutes = false;
                                                    });
                                                  },
                                                  onTapOutside: (event) {
                                                    // 点击外部关闭编辑
                                                    int newMinutes = int.tryParse(_minutesController.text) ?? 0;
                                                    newMinutes = newMinutes.clamp(0, 99);
                                                    setState(() {
                                                      if (_isFocusMode) {
                                                        _focusDuration = newMinutes;
                                                      } else {
                                                        _restDuration = newMinutes;
                                                      }
                                                      _isEditingMinutes = false;
                                                    });
                                                  },
                                                ),
                                              )
                                            : Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: finalClockSize * 0.02,
                                                  vertical: finalClockSize * 0.01,
                                                ),
                                                child: Text(
                                                  minutes,
                                                  style: TextStyle(
                                                    fontSize: finalClockSize * 0.213,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: finalClockSize * 0.213,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      // 秒部分
                                      GestureDetector(
                                        onTap: () {
                                          // 只有在初始状态或完成状态才能设置时间
                                          if (state is PomodoroInitial || state is PomodoroCompleted) {
                                            setState(() {
                                              _isEditingSeconds = true;
                                              _isEditingMinutes = false;
                                              _secondsController.text = seconds;
                                            });
                                          }
                                        },
                                        child: _isEditingSeconds
                                            ? Container(
                                                width: finalClockSize * 0.25,
                                                height: finalClockSize * 0.3,
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surface,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: theme.colorScheme.primary,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller: _secondsController,
                                                  keyboardType: TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: finalClockSize * 0.213,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                  onSubmitted: (value) {
                                                    // 提交秒输入
                                                    int newSeconds = int.tryParse(value) ?? 0;
                                                    newSeconds = newSeconds.clamp(0, 59);
                                                    setState(() {
                                                      if (_isFocusMode) {
                                                        _focusSeconds = newSeconds;
                                                      } else {
                                                        _restSeconds = newSeconds;
                                                      }
                                                      _isEditingSeconds = false;
                                                    });
                                                  },
                                                  onTapOutside: (event) {
                                                    // 点击外部关闭编辑
                                                    int newSeconds = int.tryParse(_secondsController.text) ?? 0;
                                                    newSeconds = newSeconds.clamp(0, 59);
                                                    setState(() {
                                                      if (_isFocusMode) {
                                                        _focusSeconds = newSeconds;
                                                      } else {
                                                        _restSeconds = newSeconds;
                                                      }
                                                      _isEditingSeconds = false;
                                                    });
                                                  },
                                                ),
                                              )
                                            : Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: finalClockSize * 0.02,
                                                  vertical: finalClockSize * 0.01,
                                                ),
                                                child: Text(
                                                  seconds,
                                                  style: TextStyle(
                                                    fontSize: finalClockSize * 0.213,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ).animate().fadeIn(
                                      duration: const Duration(
                                          milliseconds: 500)),
                                  SizedBox(
                                      height: finalClockSize * 0.027), // 8/300
                                  Text(
                                    '${totalTime ~/ 60} 分钟',
                                    style: TextStyle(
                                      fontSize: finalClockSize * 0.06, // 18/300
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      })
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 500))
                          .scale(duration: const Duration(milliseconds: 300)),

                      const SizedBox(height: 40),

                      // 控制按钮区域：开始/重置 + 波动开关（时钟正下方）
                      LayoutBuilder(builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 左侧：开始/重置按钮 + 记录中断按钮（时钟正下方）
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 顶部：开始/暂停按钮 + 重置按钮 + 全屏按钮
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 开始/暂停/停止按钮
                                    ElevatedButton(
                                      onPressed: () {
                                        if (state is PomodoroInitial) {
                                          // 初始状态，开始番茄钟
                                          context.read<PomodoroBloc>().add(
                                                StartPomodoro(
                                                  duration: _isFocusMode
                                                      ? _focusDuration * 60 + _focusSeconds
                                                      : _restDuration * 60 + _restSeconds,
                                                  restDuration: _isFocusMode
                                                      ? _restDuration * 60 + _restSeconds
                                                      : _focusDuration * 60 + _focusSeconds,
                                                  initialState: _isFocusMode
                                                      ? PomodoroState.focusing
                                                      : PomodoroState.resting,
                                                  isVibrationEnabled:
                                                      _isVibrationEnabled,
                                                  isAudioEnabled:
                                                      _isAudioEnabled,
                                                ),
                                              );
                                        } else if (state is PomodoroRunning) {
                                          // 运行状态，暂停番茄钟
                                          context
                                              .read<PomodoroBloc>()
                                              .add(PausePomodoro());
                                        } else if (state is PomodoroPaused) {
                                          // 暂停状态，恢复番茄钟
                                          context.read<PomodoroBloc>().add(
                                                StartPomodoro(
                                                  duration:
                                                      state.session.totalTime,
                                                  restDuration: _isFocusMode
                                                      ? _restDuration * 60
                                                      : _focusDuration * 60,
                                                  initialState: state.session
                                                      .state, // 使用当前会话的状态
                                                  isVibrationEnabled:
                                                      _isVibrationEnabled,
                                                  isAudioEnabled:
                                                      _isAudioEnabled,
                                                  isRandomAudioEnabled:
                                                      _isRandomAudioEnabled,
                                                  isAudioSelectionEnabled:
                                                      _isAudioSelectionEnabled,
                                                  selectedAudio:
                                                      _selectedAudio,
                                                ),
                                              );
                                        } else if (state is PomodoroCompleted) {
                                          // 完成状态，停止铃声/震动，重置番茄钟
                                          context
                                              .read<PomodoroBloc>()
                                              .add(ResetPomodoro());
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: state is PomodoroCompleted
                                            ? Colors.red // 完成状态显示红色
                                            : statusColor,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              screenWidth * 0.035, // 减小水平内边距
                                          vertical:
                                              screenWidth * 0.015, // 减小垂直内边距
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              screenWidth * 0.03), // 减小圆角
                                        ),
                                        textStyle: TextStyle(
                                          fontSize:
                                              screenWidth * 0.018, // 减小字体大小
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: Text(
                                        state is PomodoroRunning
                                            ? '暂停'
                                            : state is PomodoroCompleted
                                                ? '停止'
                                                : '开始',
                                      ),
                                    )
                                        .animate()
                                        .fadeIn(
                                            duration: const Duration(
                                                milliseconds: 500))
                                        .scale(
                                            duration: const Duration(
                                                milliseconds: 300)),

                                    SizedBox(
                                        width: screenWidth * 0.015), // 减小按钮间距

                                    // 重置按钮
                                    ElevatedButton(
                                      onPressed: () {
                                        context
                                            .read<PomodoroBloc>()
                                            .add(ResetPomodoro());
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        foregroundColor: Colors.black87,
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              screenWidth * 0.03, // 减小水平内边距
                                          vertical:
                                              screenWidth * 0.015, // 减小垂直内边距
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              screenWidth * 0.03), // 减小圆角
                                        ),
                                        textStyle: TextStyle(
                                          fontSize:
                                              screenWidth * 0.018, // 减小字体大小
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: const Text('重置'),
                                    )
                                        .animate()
                                        .fadeIn(
                                            duration: const Duration(
                                                milliseconds: 500),
                                            delay: const Duration(
                                                milliseconds: 100))
                                        .scale(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            delay: const Duration(
                                                milliseconds: 100)),
                                  ],
                                ),

                                SizedBox(height: screenWidth * 0.03), // 增大按钮间距

                                // 底部：记录中断按钮 + 全屏按钮
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 记录中断按钮
                                    ElevatedButton(
                                      onPressed: () {
                                        // 显示中断记录弹窗
                                        setState(() {
                                          _interruptionController.clear();
                                          _isInterruptionDialogVisible = true;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade400,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              screenWidth * 0.035, // 减小水平内边距
                                          vertical:
                                              screenWidth * 0.015, // 减小垂直内边距
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              screenWidth * 0.03), // 减小圆角
                                        ),
                                        textStyle: TextStyle(
                                          fontSize:
                                              screenWidth * 0.018, // 减小字体大小
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      child: const Text('记录中断'),
                                    )
                                        .animate()
                                        .fadeIn(
                                            duration: const Duration(
                                                milliseconds: 500),
                                            delay: const Duration(
                                                milliseconds: 200))
                                        .scale(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            delay: const Duration(
                                                milliseconds: 200)),

                                    SizedBox(
                                        width: screenWidth * 0.015), // 减小按钮间距

                                    // 全屏按钮
                                    ElevatedButton(
                                      onPressed: () async {
                                        setState(() {
                                          _isFullScreen = true;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        foregroundColor: Colors.black87,
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              screenWidth * 0.03, // 减小水平内边距
                                          vertical:
                                              screenWidth * 0.015, // 减小垂直内边距
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              screenWidth * 0.03), // 减小圆角
                                        ),
                                        textStyle: TextStyle(
                                          fontSize:
                                              screenWidth * 0.018, // 减小字体大小
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.fullscreen,
                                        size: screenWidth * 0.025, // 减小图标大小
                                      ),
                                    )
                                        .animate()
                                        .fadeIn(
                                            duration: const Duration(
                                                milliseconds: 500),
                                            delay: const Duration(
                                                milliseconds: 300))
                                        .scale(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            delay: const Duration(
                                                milliseconds: 300)),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(width: screenWidth * 0.04), // 间距

                            // 右侧：波动开关：专注/休息模式切换
                            SizedBox(
                              width: screenWidth * 0.12, // 缩小宽度到屏幕12%
                              child: Row(
                                children: [
                                  // 专注模式
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (!isRunning) {
                                          setState(() {
                                            _isFocusMode = true;
                                            _duration = _focusDuration;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical:
                                              screenWidth * 0.008, // 减小垂直内边距
                                          horizontal:
                                              screenWidth * 0.01, // 减小水平内边距
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isFocusMode
                                              ? const Color(0xFFE76F51)
                                              : Colors.grey.shade200,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(6), // 减小圆角
                                            bottomLeft: Radius.circular(6),
                                          ),
                                        ),
                                        child: Text(
                                          '专注',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize:
                                                screenWidth * 0.015, // 减小字体大小
                                            fontWeight: FontWeight.w600,
                                            color: _isFocusMode
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 休息模式
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (!isRunning) {
                                          setState(() {
                                            _isFocusMode = false;
                                            _duration = _restDuration;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical:
                                              screenWidth * 0.008, // 减小垂直内边距
                                          horizontal:
                                              screenWidth * 0.01, // 减小水平内边距
                                        ),
                                        decoration: BoxDecoration(
                                          color: !_isFocusMode
                                              ? const Color(0xFF2A9D8F)
                                              : Colors.grey.shade200,
                                          borderRadius: const BorderRadius.only(
                                            topRight:
                                                Radius.circular(6), // 减小圆角
                                            bottomRight: Radius.circular(6),
                                          ),
                                        ),
                                        child: Text(
                                          '休息',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize:
                                                screenWidth * 0.015, // 减小字体大小
                                            fontWeight: FontWeight.w600,
                                            color: !_isFocusMode
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),



                      // 统计信息（折叠面板）
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ExpansionTile(
                          title: const Text(
                            '统计信息',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            _isStatsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.grey.shade600,
                          ),
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isStatsExpanded = expanded;
                            });
                          },
                          children: [
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final screenWidth = constraints.maxWidth;

                                  return Table(
                                    border: TableBorder.all(
                                        color: Colors.grey.shade200),
                                    columnWidths: {
                                      0: FixedColumnWidth(screenWidth * 0.25),
                                      1: FixedColumnWidth(screenWidth * 0.2),
                                      2: FixedColumnWidth(screenWidth * 0.2),
                                      3: FixedColumnWidth(screenWidth * 0.2),
                                      4: FixedColumnWidth(screenWidth * 0.15),
                                    },
                                    children: [
                                      // 表头
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                        ),
                                        children: [
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '类型',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '完成番茄钟数',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '持续时长',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '平均持续时长',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '中断次数',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 今日专注时钟行 - 红色背景
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE76F51)
                                              .withValues(alpha: 0.1),
                                        ),
                                        children: [
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '今日专注时钟',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xFFE76F51),
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_todayFocusStats['count']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatDuration(_todayFocusStats['duration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatAverageDuration(_todayFocusStats['averageDuration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_todayFocusStats['interruptions']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 今日休息时钟行 - 绿色背景
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A9D8F)
                                              .withValues(alpha: 0.1),
                                        ),
                                        children: [
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '今日休息时钟',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xFF2A9D8F),
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_todayRestStats['count']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatDuration(_todayRestStats['duration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatAverageDuration(_todayRestStats['averageDuration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_todayRestStats['interruptions']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 今日总计行
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Colors.blue
                                              .withValues(alpha: 0.1),
                                        ),
                                        children: [
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '今日总计',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${(int.tryParse(_todayFocusStats['count'].toString()) ?? 0) + (int.tryParse(_todayRestStats['count'].toString()) ?? 0)}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatDuration((_todayFocusStats['duration'] ?? 0) + (_todayRestStats['duration'] ?? 0)),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatAverageDuration(
                                                  ((_todayFocusStats['averageDuration'] ?? 0) * (int.tryParse(_todayFocusStats['count'].toString()) ?? 0) + 
                                                   (_todayRestStats['averageDuration'] ?? 0) * (int.tryParse(_todayRestStats['count'].toString()) ?? 0)) / 
                                                   ((int.tryParse(_todayFocusStats['count'].toString()) ?? 0) + (int.tryParse(_todayRestStats['count'].toString()) ?? 0) > 0 ? 
                                                    (int.tryParse(_todayFocusStats['count'].toString()) ?? 0) + (int.tryParse(_todayRestStats['count'].toString()) ?? 0) : 1)
                                                ),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${(int.tryParse(_todayFocusStats['interruptions'].toString()) ?? 0) + (int.tryParse(_todayRestStats['interruptions'].toString()) ?? 0)}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 昨日专注时钟行 - 灰色背景
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.1),
                                        ),
                                        children: [
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '昨日专注时钟',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_yesterdayFocusStats['count']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatDuration(_yesterdayFocusStats['duration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatAverageDuration(_yesterdayFocusStats['averageDuration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_yesterdayFocusStats['interruptions']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 昨日休息时钟行 - 灰色背景
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.1),
                                        ),
                                        children: [
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '昨日休息时钟',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_yesterdayRestStats['count']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatDuration(_yesterdayRestStats['duration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatAverageDuration(_yesterdayRestStats['averageDuration'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${_yesterdayRestStats['interruptions']}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 昨日总计行
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Colors.blue
                                              .withValues(alpha: 0.1),
                                        ),
                                        children: [
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '昨日总计',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${(int.tryParse(_yesterdayFocusStats['count'].toString()) ?? 0) + (int.tryParse(_yesterdayRestStats['count'].toString()) ?? 0)}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatDuration((_yesterdayFocusStats['duration'] ?? 0) + (_yesterdayRestStats['duration'] ?? 0)),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                _formatAverageDuration(
                                                  ((_yesterdayFocusStats['averageDuration'] ?? 0) * (int.tryParse(_yesterdayFocusStats['count'].toString()) ?? 0) + 
                                                   (_yesterdayRestStats['averageDuration'] ?? 0) * (int.tryParse(_yesterdayRestStats['count'].toString()) ?? 0)) / 
                                                   ((int.tryParse(_yesterdayFocusStats['count'].toString()) ?? 0) + (int.tryParse(_yesterdayRestStats['count'].toString()) ?? 0) > 0 ? 
                                                    (int.tryParse(_yesterdayFocusStats['count'].toString()) ?? 0) + (int.tryParse(_yesterdayRestStats['count'].toString()) ?? 0) : 1)
                                                ),
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TableCell(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: screenWidth * 0.015,
                                                  horizontal:
                                                      screenWidth * 0.01),
                                              child: Text(
                                                '${(int.tryParse(_yesterdayFocusStats['interruptions'].toString()) ?? 0) + (int.tryParse(_yesterdayRestStats['interruptions'].toString()) ?? 0)}',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.02,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                              duration: const Duration(milliseconds: 500),
                              delay: const Duration(milliseconds: 200))
                          .slideY(
                              begin: 20,
                              duration: const Duration(milliseconds: 300),
                              delay: const Duration(milliseconds: 200)),
                    ],
                  ),
                );
              }
            },
          ),
          // 中断记录弹窗
          if (_isInterruptionDialogVisible)
            Container(
              color: Colors.black.withValues(alpha: 0.5), // 半透明背景
              alignment: Alignment.center,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 弹窗标题
                      const Text(
                        '记录中断原因',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 中断原因输入框
                      TextField(
                        controller: _interruptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: '请输入中断原因...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 操作按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 取消按钮
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isInterruptionDialogVisible = false;
                              });
                            },
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 12),
                          // 保存按钮
                          ElevatedButton(
                            onPressed: () {
                              // 保存中断原因
                              final reason =
                                  _interruptionController.text.trim();
                              if (reason.isNotEmpty) {
                                // 发送中断记录事件到Bloc
                                context
                                    .read<PomodoroBloc>()
                                    .add(RecordInterruption(reason));
                                // 关闭弹窗
                                setState(() {
                                  _isInterruptionDialogVisible = false;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade400,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
