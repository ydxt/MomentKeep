import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/services/countdown_service.dart';
import 'dart:async';
import 'dart:convert';

/// 习惯事件
abstract class HabitEvent extends Equatable {
  const HabitEvent();

  @override
  List<Object> get props => [];
}

/// 加载习惯事件
class LoadHabits extends HabitEvent {}

/// 添加习惯事件
class AddHabit extends HabitEvent {
  final Habit habit;

  const AddHabit(this.habit);

  @override
  List<Object> get props => [habit];
}

/// 更新习惯事件
class UpdateHabit extends HabitEvent {
  final Habit habit;

  const UpdateHabit(this.habit);

  @override
  List<Object> get props => [habit];
}

/// 删除习惯事件
class DeleteHabit extends HabitEvent {
  final String habitId;

  const DeleteHabit(this.habitId);

  @override
  List<Object> get props => [habitId];
}

/// 记录习惯完成事件
class RecordHabitCompletion extends HabitEvent {
  final String habitId;
  final int score;
  final List<ContentBlock> comment;

  const RecordHabitCompletion(this.habitId, this.score, this.comment);

  @override
  List<Object> get props => [habitId, score, comment];
}

/// 更新习惯顺序事件
class UpdateHabitOrder extends HabitEvent {
  final List<Habit> habits;

  const UpdateHabitOrder(this.habits);

  @override
  List<Object> get props => [habits];
}

/// 习惯状态
abstract class HabitState extends Equatable {
  const HabitState();

  @override
  List<Object> get props => [];
}

/// 习惯初始状态
class HabitInitial extends HabitState {}

/// 习惯加载中状态
class HabitLoading extends HabitState {}

/// 习惯加载完成状态
class HabitLoaded extends HabitState {
  final List<Habit> habits;

  const HabitLoaded(this.habits);

  @override
  List<Object> get props => [habits];
}

/// 习惯操作失败状态
class HabitError extends HabitState {
  final String message;

  const HabitError(this.message);

  @override
  List<Object> get props => [message];
}

/// 习惯BLoC
class HabitBloc extends Bloc<HabitEvent, HabitState> {
  /// 回收箱BLoC
  final RecycleBinBloc recycleBinBloc;

  /// 数据库服务
  final DatabaseService _databaseService;

  /// 倒计时服务（用于通知调度）
  final CountdownService _countdownService = CountdownService();

  HabitBloc(this.recycleBinBloc) :
        _databaseService = DatabaseService(),
        super(HabitInitial()) {
    on<LoadHabits>(_onLoadHabits);
    on<AddHabit>(_onAddHabit);
    on<UpdateHabit>(_onUpdateHabit);
    on<DeleteHabit>(_onDeleteHabit);
    on<RecordHabitCompletion>(_onRecordHabitCompletion);
    on<UpdateHabitOrder>(_onUpdateHabitOrder);

    // 初始化习惯数据
    _habits = [];
  }

  /// 习惯数据
  late List<Habit> _habits;

  /// 保存习惯数据到SharedPreferences
  Future<void> _saveHabitsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitsJson =
          jsonEncode(_habits.map((habit) => habit.toJson()).toList());
      await prefs.setString('habits', habitsJson);
    } catch (e) {
      print('保存习惯数据失败: $e');
    }
  }

  /// 为习惯调度通知
  Future<void> _scheduleHabitNotification(Habit habit) async {
    try {
      // 检查是否有提醒时间
      if (habit.reminderTime != null) {
        final time = habit.reminderTime!;
        final habitId = int.tryParse(habit.id) ?? habit.id.hashCode;
        
        await _countdownService.setHabitReminder(
          habitId: habitId,
          habitName: habit.name,
          hour: time.hour,
          minute: time.minute,
          daysOfWeek: habit.reminderDays.isNotEmpty 
              ? habit.reminderDays 
              : null, // null 表示每天
        );
        print('习惯提醒已设置: ${habit.name} at ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
      }
    } catch (e) {
      print('设置习惯提醒失败: $e');
    }
  }

  /// 取消习惯通知
  Future<void> _cancelHabitNotification(String habitId) async {
    try {
      final id = int.tryParse(habitId) ?? habitId.hashCode;
      await _countdownService.cancelHabitReminder(id);
      print('习惯提醒已取消: $habitId');
    } catch (e) {
      print('取消习惯提醒失败: $e');
    }
  }

  /// 从SharedPreferences加载习惯数据
  Future<List<Habit>> _loadHabitsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitsJson = prefs.getString('habits');
      if (habitsJson != null) {
        final List<dynamic> habitsList = jsonDecode(habitsJson);
        final loadedHabits = habitsList
            .map((habitJson) =>
                Habit.fromJson(habitJson as Map<String, dynamic>))
            .toList();
        
        // 确保每个习惯的currentStreak计算正确
        final updatedHabits = loadedHabits.map((habit) {
          final currentStreak = _calculateCurrentStreak(habit.checkInRecords);
          final totalCompletions = habit.checkInRecords.length;
          int bestStreak = habit.bestStreak;
          if (currentStreak > bestStreak) {
            bestStreak = currentStreak;
          }
          
          return habit.copyWith(
            currentStreak: currentStreak,
            totalCompletions: totalCompletions,
            bestStreak: bestStreak,
          );
        }).toList();
        
        return updatedHabits;
      }
    } catch (e) {
      print('加载习惯数据失败: $e');
    }
    // 如果没有数据或加载失败，返回默认的习惯数据
    return [
      Habit(
        id: '1',
        name: '喝水',
        categoryId: '1',
        category: '健康',
        icon: 'water_drop',
        color: 0xFF3b82f6,
        frequency: HabitFrequency.daily,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
        history: [],
        checkInRecords: [],
        currentStreak: 0,
        bestStreak: 0,
        totalCompletions: 0,
        notes: '每天喝8杯水',
      ),
      Habit(
        id: '2',
        name: '阅读',
        categoryId: '1',
        category: '学习',
        icon: 'menu_book',
        color: 0xFF8b5cf6,
        frequency: HabitFrequency.daily,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
        history: [],
        checkInRecords: [],
        currentStreak: 0,
        bestStreak: 0,
        totalCompletions: 0,
        notes: '每天阅读30分钟',
      ),
      Habit(
        id: '3',
        name: '晨跑',
        categoryId: '2',
        category: '运动',
        icon: 'directions_run',
        color: 0xFFf97316,
        frequency: HabitFrequency.daily,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now(),
        history: [],
        checkInRecords: [],
        currentStreak: 0,
        bestStreak: 0,
        totalCompletions: 0,
        notes: '每天早上跑步5公里',
      ),
    ];
  }

  /// 处理加载习惯事件
  FutureOr<void> _onLoadHabits(
      LoadHabits event, Emitter<HabitState> emit) async {
    emit(HabitLoading());
    try {
      // 从SharedPreferences加载习惯数据
      _habits = await _loadHabitsFromStorage();
      
      // 为所有有提醒时间的习惯重新调度通知
      for (final habit in _habits) {
        if (habit.reminderTime != null) {
          await _scheduleHabitNotification(habit);
        }
      }
      
      emit(HabitLoaded(List.from(_habits)));
    } catch (e) {
      emit(HabitError('加载习惯失败'));
    }
  }

  /// 处理添加习惯事件
  FutureOr<void> _onAddHabit(AddHabit event, Emitter<HabitState> emit) async {
    // 检查同一分类中是否已经存在同名习惯
    final isDuplicate = _habits.any((habit) =>
        habit.categoryId == event.habit.categoryId &&
        habit.name == event.habit.name &&
        habit.id != event.habit.id);

    if (isDuplicate) {
      // 如果存在同名习惯，发出错误状态
      emit(HabitError('同一分类中已存在同名习惯'));
      return;
    }

    // 更新原始数据
    _habits.add(event.habit);

    // 保存到SharedPreferences
    await _saveHabitsToStorage();

    // 调度通知
    await _scheduleHabitNotification(event.habit);

    // 直接使用更新后的原始数据创建新状态
    emit(HabitLoaded(List.from(_habits)));
  }

  /// 处理更新习惯事件
  FutureOr<void> _onUpdateHabit(
      UpdateHabit event, Emitter<HabitState> emit) async {
    // 检查同一分类中是否已经存在同名习惯（排除当前习惯）
    final isDuplicate = _habits.any((habit) =>
        habit.categoryId == event.habit.categoryId &&
        habit.name == event.habit.name &&
        habit.id != event.habit.id);

    if (isDuplicate) {
      // 如果存在同名习惯，发出错误状态
      emit(HabitError('同一分类中已存在同名习惯'));
      return;
    }

    // 更新原始数据
    final index = _habits.indexWhere((habit) => habit.id == event.habit.id);
    if (index != -1) {
      _habits[index] = event.habit;
    }

    // 保存到SharedPreferences
    await _saveHabitsToStorage();

    // 重新调度通知
    await _cancelHabitNotification(event.habit.id);
    await _scheduleHabitNotification(event.habit);

    // 直接使用更新后的原始数据创建新状态
    emit(HabitLoaded(List.from(_habits)));
  }

  /// 处理删除习惯事件
  FutureOr<void> _onDeleteHabit(
      DeleteHabit event, Emitter<HabitState> emit) async {
    // 查找要删除的习惯
    final habitIndex = _habits.indexWhere((habit) => habit.id == event.habitId);
    if (habitIndex != -1) {
      final deletedHabit = _habits[habitIndex];

      // 将删除的习惯添加到回收箱
      final recycleBinItem = RecycleBinItem(
        id: deletedHabit.id,
        type: 'habit',
        name: deletedHabit.name,
        data: deletedHabit.toJson(),
        deletedAt: DateTime.now(),
      );
      recycleBinBloc.add(AddToRecycleBin(recycleBinItem));

      // 取消通知
      await _cancelHabitNotification(event.habitId);

      // 更新原始数据
      _habits.removeAt(habitIndex);

      // 保存到SharedPreferences
      await _saveHabitsToStorage();

      // 直接使用更新后的原始数据创建新状态
      emit(HabitLoaded(List.from(_habits)));
    }
  }

  /// 计算连续打卡天数
  int _calculateCurrentStreak(List<CheckInRecord> checkInRecords) {
    if (checkInRecords.isEmpty) {
      return 0;
    }

    // 按时间戳排序，最新的在前
    final sortedRecords = [...checkInRecords]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    int streak = 0;
    final now = DateTime.now();
    DateTime currentDate = DateTime(now.year, now.month, now.day);

    // 检查今天是否有打卡记录
    final todayStr = currentDate.toIso8601String().split('T')[0];
    final hasTodayCheckIn = sortedRecords.any((record) {
      return record.timestamp.toIso8601String().split('T')[0] == todayStr;
    });

    if (!hasTodayCheckIn) {
      // 如果今天没有打卡，检查昨天是否有打卡记录
      currentDate = currentDate.subtract(const Duration(days: 1));
      final yesterdayStr = currentDate.toIso8601String().split('T')[0];
      final hasYesterdayCheckIn = sortedRecords.any((record) {
        return record.timestamp.toIso8601String().split('T')[0] == yesterdayStr;
      });

      if (!hasYesterdayCheckIn) {
        // 如果昨天也没有打卡，连续天数为0
        return 0;
      }
    }

    // 计算连续打卡天数
    for (final record in sortedRecords) {
      final recordDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      final recordDateStr = recordDate.toIso8601String().split('T')[0];
      final currentDateStr = currentDate.toIso8601String().split('T')[0];

      if (recordDateStr == currentDateStr) {
        // 今天有打卡记录，连续天数加1
        streak++;
        // 检查前一天
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else if (recordDate.isBefore(currentDate)) {
        // 跳过不是当前检查日期的记录
        continue;
      } else {
        // 遇到不连续的记录，停止计算
        break;
      }
    }

    return streak;
  }

  /// 处理记录习惯完成事件
  FutureOr<void> _onRecordHabitCompletion(
      RecordHabitCompletion event, Emitter<HabitState> emit) async {
    final index = _habits.indexWhere((habit) => habit.id == event.habitId);
    if (index == -1) return;

    final habit = _habits[index];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // 归一化到今天 00:00:00
    final todayStr = today.toIso8601String().split('T')[0];
    final isTodayChecked = habit.history.contains(todayStr);

    // --- 1. 计算当前周期的开始时间 (归一化为 00:00:00) ---
    DateTime cycleStart;
    int pointsAwarded = 0;
    DateTime? newLastRewardTime = habit.lastCycleRewardTime;

    if (habit.scoringMode == ScoringMode.daily) {
      cycleStart = today;
      pointsAwarded = event.score; // 每天模式：直接得分为用户选择的星星数
    } else {
      // 周期模式（按周 或 自定义）
      if (habit.scoringMode == ScoringMode.weekly) {
        // 按周：周期从周一开始
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday
        cycleStart = today.subtract(Duration(days: weekday - 1));
      } else {
        // 自定义周期：从 createdAt 日期开始推算
        final createDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
        final daysSinceCreation = today.difference(createDate).inDays;
        // 如果创建时间在未来（异常数据），fallback 到今天
        if (daysSinceCreation < 0) {
          cycleStart = today;
        } else {
          final cycleIndex = daysSinceCreation ~/ habit.customCycleDays;
          cycleStart = createDate.add(Duration(days: cycleIndex * habit.customCycleDays));
        }
      }

      // 强制归一化周期开始时间为 00:00:00
      cycleStart = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);

      // --- 2. 统计周期内打卡次数 ---
      // 使用归一化的日期进行比较，避免时分秒导致的边界错误
      final recordsInCycle = habit.checkInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart);
      }).length;

      // 如果今天还没打卡，本次打卡会使计数 +1
      final currentCycleCount = isTodayChecked ? recordsInCycle : recordsInCycle + 1;

      // --- 3. 判定是否达标 & 防刷 ---
      final bool targetReached = currentCycleCount >= habit.targetDays;
      
      // 检查本周期是否已发过奖
      // 逻辑：如果上次发奖时间 >= 当前周期开始时间，说明本周期已处理过
      bool cycleAlreadyRewarded = false;
      if (habit.lastCycleRewardTime != null) {
        final lastRewardDate = DateTime(habit.lastCycleRewardTime!.year, habit.lastCycleRewardTime!.month, habit.lastCycleRewardTime!.day);
        if (!lastRewardDate.isBefore(cycleStart)) {
          cycleAlreadyRewarded = true;
        }
      }

      if (targetReached && !cycleAlreadyRewarded) {
        pointsAwarded = habit.cycleRewardPoints;
        newLastRewardTime = now; // 记录发奖时间
      } else {
        pointsAwarded = 0;
      }
    }

    // --- 4. 更新打卡记录 ---
    List<CheckInRecord> updatedCheckInRecords;
    if (!isTodayChecked) {
      // 新增打卡
      final checkInRecord = CheckInRecord(
        id: now.millisecondsSinceEpoch.toString(),
        habitId: event.habitId,
        score: event.score, // 记录始终保存用户的主观评分（星星数）
        comment: event.comment,
        timestamp: now,
        isNegative: habit.type == HabitType.negative,
      );
      updatedCheckInRecords = [...habit.checkInRecords, checkInRecord];
    } else {
      // 更新今日打卡
      updatedCheckInRecords = habit.checkInRecords.map((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        if (rDate.isAtSameMomentAs(today)) {
          return CheckInRecord(
            id: now.millisecondsSinceEpoch.toString(),
            habitId: event.habitId,
            score: event.score,
            comment: event.comment,
            timestamp: now,
            isNegative: habit.type == HabitType.negative,
          );
        }
        return record;
      }).toList();
    }

    // --- 5. 计算统计数据 ---
    final currentStreak = _calculateCurrentStreak(updatedCheckInRecords);
    final totalCompletions = updatedCheckInRecords.length;
    int bestStreak = habit.bestStreak;
    if (currentStreak > bestStreak) bestStreak = currentStreak;

    final updatedHabit = habit.copyWith(
      currentStreak: currentStreak,
      totalCompletions: totalCompletions,
      bestStreak: bestStreak,
      history: isTodayChecked ? habit.history : [...habit.history, todayStr],
      checkInRecords: updatedCheckInRecords,
      updatedAt: now,
      lastCycleRewardTime: newLastRewardTime,
    );

    _habits[index] = updatedHabit;

    // --- 6. 更新积分 ---
    if (pointsAwarded != 0) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'default_user';
      final String habitTypeDesc = habit.type == HabitType.negative ? '减分项' : '加分项';
      
      // 减分项扣除分数，加分项增加分数
      final double finalPoints = habit.type == HabitType.negative 
          ? -pointsAwarded.toDouble() 
          : pointsAwarded.toDouble();

      await _databaseService.updateUserPoints(
        userId,
        finalPoints,
        description: '习惯打卡($habitTypeDesc): ${habit.name}',
        transactionType: 'habit_completed',
        relatedId: event.habitId,
      );
    }

    await _saveHabitsToStorage();
    emit(HabitLoaded(List.from(_habits)));
  }

  /// 处理更新习惯顺序事件
  FutureOr<void> _onUpdateHabitOrder(
      UpdateHabitOrder event, Emitter<HabitState> emit) async {
    // 更新原始数据
    _habits = event.habits;

    // 保存到SharedPreferences
    await _saveHabitsToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(HabitLoaded(List.from(_habits)));
  }
}
