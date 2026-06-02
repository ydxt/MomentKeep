import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';
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
  final DateTime? date;

  const RecordHabitCompletion(this.habitId, this.score, this.comment, {this.date});

  @override
  List<Object> get props => [habitId, score, comment, if (date != null) date!];
}

/// 撤销习惯完成事件
class UndoHabitCompletion extends HabitEvent {
  final String habitId;
  final DateTime? date;

  const UndoHabitCompletion(this.habitId, {this.date});

  @override
  List<Object> get props => [habitId, if (date != null) date!];
}

/// 更新习惯顺序事件
class UpdateHabitOrder extends HabitEvent {
  final List<Habit> habits;

  const UpdateHabitOrder(this.habits);

  @override
  List<Object> get props => [habits];
}

/// 搜索习惯事件
class SearchHabits extends HabitEvent {
  final String query;

  const SearchHabits(this.query);

  @override
  List<Object> get props => [query];
}

/// 覆盖习惯事件（原子操作：删除旧记录 + 添加新记录）
class OverwriteHabit extends HabitEvent {
  final List<String> oldHabitIds;
  final Habit newHabit;

  const OverwriteHabit(this.oldHabitIds, this.newHabit);

  @override
  List<Object> get props => [oldHabitIds, newHabit];
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

/// 习惯搜索结果状态
class HabitSearchResult extends HabitState {
  final List<Habit> filteredHabits;
  final String query;

  const HabitSearchResult(this.filteredHabits, this.query);

  @override
  List<Object> get props => [filteredHabits, query];
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
    on<UndoHabitCompletion>(_onUndoHabitCompletion);
    on<UpdateHabitOrder>(_onUpdateHabitOrder);
    on<SearchHabits>(_onSearchHabits);
    on<OverwriteHabit>(_onOverwriteHabit);

    // 初始化习惯数据
    _habits = [];
  }

  /// 习惯数据
  late List<Habit> _habits;

  /// 保存习惯数据到数据库
  Future<void> _saveHabitsToStorage() async {
    try {
      final existingHabits = await _databaseService.getAllHabits();
      final existingIds = existingHabits.map((h) => h.id).toSet();

      for (final habit in _habits) {
        if (existingIds.contains(habit.id)) {
          await _databaseService.updateHabit(habit);
        } else {
          final newId = await _databaseService.insertHabit(habit);
          final index = _habits.indexWhere((h) => h.id == habit.id);
          if (index >= 0) {
            _habits[index] = habit.copyWith(id: newId.toString());
          }
        }
      }

      final currentIds = _habits.map((h) => h.id).toSet();
      for (final existing in existingHabits) {
        if (!currentIds.contains(existing.id)) {
          await _databaseService.deleteHabit(existing.id);
        }
      }
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

  /// 从数据库加载习惯数据
  Future<List<Habit>> _loadHabitsFromStorage() async {
    try {
      final habits = await _databaseService.getAllHabits();
      if (habits.isNotEmpty) {
        final updatedHabits = habits.map((habit) {
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

      final prefs = await SharedPreferences.getInstance();
      final habitsJson = prefs.getString('habits');
      if (habitsJson != null) {
        final List<dynamic> habitsList = jsonDecode(habitsJson);
        final loadedHabits = habitsList
            .map((habitJson) =>
                Habit.fromJson(habitJson as Map<String, dynamic>))
            .toList();
        for (final habit in loadedHabits) {
          await _databaseService.insertHabit(habit);
        }
        await prefs.remove('habits');
        return loadedHabits;
      }
    } catch (e) {
      print('加载习惯数据失败: $e');
    }
    return [];
  }

  List<Habit> _getDefaultHabits() {
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
      _habits = await _loadHabitsFromStorage();

      if (_habits.isEmpty) {
        _habits = _getDefaultHabits();
        await _saveHabitsToStorage();
      }

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

    // 保存到数据库
    await _saveHabitsToStorage();

    // 调度通知
    await _scheduleHabitNotification(event.habit);

    // 直接使用更新后的原始数据创建新状态
    emit(HabitLoaded(List.from(_habits)));
  }

  FutureOr<void> _onUpdateHabit(
      UpdateHabit event, Emitter<HabitState> emit) async {
    final isDuplicate = _habits.any((habit) =>
        habit.categoryId == event.habit.categoryId &&
        habit.name == event.habit.name &&
        habit.id != event.habit.id);

    if (isDuplicate) {
      emit(HabitError('同一分类中已存在同名习惯'));
      return;
    }

    final index = _habits.indexWhere((habit) => habit.id == event.habit.id);
    if (index != -1) {
      _habits[index] = event.habit;
    }

    await _saveHabitsToStorage();

    if (index != -1) {
      _habits[index] = event.habit;
    }

    await _cancelHabitNotification(event.habit.id);
    await _scheduleHabitNotification(event.habit);

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

      // 保存到数据库
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
    final sortedRecords = [...checkInRecords].where((r) => !r.id.startsWith('reward_')).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
    final targetDate = event.date ?? now;
    final isMakeupCheckIn = event.date != null;
    final today = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final todayStr = today.toIso8601String().split('T')[0];
    final isTodayChecked = habit.history.contains(todayStr);

    // --- 1. 计算当前周期的开始时间 (归一化为 00:00:00) ---
    DateTime cycleStart;
    int pointsAwarded = 0;
    DateTime? newLastRewardTime = habit.lastCycleRewardTime;

    if (habit.scoringMode == ScoringMode.daily) {
      cycleStart = today;
      pointsAwarded = event.score;
    } else if (habit.scoringMode == ScoringMode.checkInWithPenalty) {
      final createDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
      final daysSinceCreation = today.difference(createDate).inDays;
      if (daysSinceCreation < 0) {
        cycleStart = today;
      } else {
        final cycleIndex = daysSinceCreation ~/ habit.customCycleDays;
        cycleStart = createDate.add(Duration(days: cycleIndex * habit.customCycleDays));
      }
      cycleStart = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);

      pointsAwarded = habit.checkInPoints;

      final recordsInCycle = habit.checkInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_');
      }).length;
      final currentCycleCount = isTodayChecked ? recordsInCycle : recordsInCycle + 1;

      final cycleEnd = cycleStart.add(Duration(days: habit.customCycleDays));
      final isLastDayOfCycle = today.isAfter(cycleEnd.subtract(const Duration(days: 1))) || today.isAtSameMomentAs(cycleEnd.subtract(const Duration(days: 1)));

      bool penaltyAlreadyApplied = habit.checkInRecords.any((record) {
        if (!record.id.startsWith('penalty_')) return false;
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart) && rDate.isBefore(cycleEnd);
      });

      if (isLastDayOfCycle && currentCycleCount < habit.minCheckInDays && !penaltyAlreadyApplied) {
        final penalty = (habit.minCheckInDays - currentCycleCount) * habit.penaltyPoints;
        pointsAwarded -= penalty;
      }
    } else if (habit.scoringMode == ScoringMode.weeklyWithPenalty) {
      final weekday = targetDate.weekday;
      cycleStart = today.subtract(Duration(days: weekday - 1));
      cycleStart = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);

      pointsAwarded = habit.checkInPoints;

      final recordsInCycle = habit.checkInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_');
      }).length;
      final currentCycleCount = isTodayChecked ? recordsInCycle : recordsInCycle + 1;

      final cycleEnd = cycleStart.add(const Duration(days: 7));
      final isLastDayOfCycle = today.isAfter(cycleEnd.subtract(const Duration(days: 1))) || today.isAtSameMomentAs(cycleEnd.subtract(const Duration(days: 1)));

      bool penaltyAlreadyApplied = habit.checkInRecords.any((record) {
        if (!record.id.startsWith('penalty_')) return false;
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart) && rDate.isBefore(cycleEnd);
      });

      if (isLastDayOfCycle && currentCycleCount < habit.minCheckInDays && !penaltyAlreadyApplied) {
        final penalty = (habit.minCheckInDays - currentCycleCount) * habit.penaltyPoints;
        pointsAwarded -= penalty;
      }
    } else {
      // 周期模式（按周 或 自定义）
      if (habit.scoringMode == ScoringMode.weekly) {
        // 按周：周期从周一开始
        final weekday = targetDate.weekday; // 1 = Monday, 7 = Sunday
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
        return !rDate.isBefore(cycleStart) && !record.id.startsWith('reward_');
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

      pointsAwarded = event.score;
      if (targetReached && !cycleAlreadyRewarded) {
        pointsAwarded += habit.cycleRewardPoints;
        newLastRewardTime = now;
      }
    }

    // --- 4. 更新打卡记录 ---
    List<CheckInRecord> updatedCheckInRecords;
    final int recordScore;
    if (habit.scoringMode == ScoringMode.checkInWithPenalty || habit.scoringMode == ScoringMode.weeklyWithPenalty) {
      recordScore = habit.checkInPoints;
    } else {
      recordScore = event.score;
    }
    if (!isTodayChecked) {
      final checkInRecord = CheckInRecord(
        id: now.millisecondsSinceEpoch.toString(),
        habitId: event.habitId,
        score: recordScore,
        comment: event.comment,
        timestamp: DateTime(targetDate.year, targetDate.month, targetDate.day),
        checkedInAt: isMakeupCheckIn ? now : null,
        isNegative: habit.type == HabitType.negative,
      );
      updatedCheckInRecords = [...habit.checkInRecords, checkInRecord];

      if (habit.scoringMode != ScoringMode.daily && habit.scoringMode != ScoringMode.checkInWithPenalty && habit.scoringMode != ScoringMode.weeklyWithPenalty && pointsAwarded > 0) {
        final rewardRecord = CheckInRecord(
          id: 'reward_${now.millisecondsSinceEpoch}',
          habitId: event.habitId,
          score: habit.type == HabitType.negative ? -pointsAwarded : pointsAwarded,
          comment: [],
          timestamp: cycleStart,
          isNegative: habit.type == HabitType.negative,
        );
        updatedCheckInRecords = [...updatedCheckInRecords, rewardRecord];
      }

      if ((habit.scoringMode == ScoringMode.checkInWithPenalty || habit.scoringMode == ScoringMode.weeklyWithPenalty) && pointsAwarded < habit.checkInPoints) {
        final penaltyAmount = habit.checkInPoints - pointsAwarded;
        final penaltyRecord = CheckInRecord(
          id: 'penalty_${now.millisecondsSinceEpoch}',
          habitId: event.habitId,
          score: -penaltyAmount,
          comment: [],
          timestamp: cycleStart,
          isNegative: true,
        );
        updatedCheckInRecords = [...updatedCheckInRecords, penaltyRecord];
      }
    } else {
      updatedCheckInRecords = habit.checkInRecords.map((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        if (rDate.isAtSameMomentAs(today) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_')) {
          return CheckInRecord(
            id: now.millisecondsSinceEpoch.toString(),
            habitId: event.habitId,
            score: recordScore,
            comment: event.comment,
            timestamp: DateTime(targetDate.year, targetDate.month, targetDate.day),
            checkedInAt: isMakeupCheckIn ? now : null,
            isNegative: habit.type == HabitType.negative,
          );
        }
        return record;
      }).toList();
    }

    // --- 5. 计算统计数据 ---
    final currentStreak = _calculateCurrentStreak(updatedCheckInRecords);
    final totalCompletions = updatedCheckInRecords.where((r) => !r.id.startsWith('reward_') && !r.id.startsWith('penalty_')).length;
    int bestStreak = habit.bestStreak;
    if (currentStreak > bestStreak) bestStreak = currentStreak;

    final updatedHabit = habit.copyWith(
      currentStreak: currentStreak,
      totalCompletions: totalCompletions,
      bestStreak: bestStreak,
      history: isTodayChecked ? habit.history : [...habit.history, todayStr],
      checkInRecords: updatedCheckInRecords,
      updatedAt: targetDate,
      lastCycleRewardTime: newLastRewardTime,
    );

    _habits[index] = updatedHabit;

    // --- 6. 更新积分 ---
    if (pointsAwarded != 0) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(StorageKeys.userId) ?? 'default_user';
      final String habitTypeDesc = habit.type == HabitType.negative ? '减分项' : '加分项';
      
      final double finalPoints = habit.type == HabitType.negative 
          ? -pointsAwarded.toDouble() 
          : pointsAwarded.toDouble();

      final ruleSnapshot = jsonEncode({
        'fullStars': habit.fullStars,
        'cycleRewardPoints': habit.cycleRewardPoints,
        'scoringMode': habit.scoringMode.name,
        'score': event.score,
        'habitType': habit.type.name,
      });

      await _databaseService.updateUserPoints(
        userId,
        finalPoints,
        description: '习惯打卡($habitTypeDesc): ${habit.name}',
        transactionType: 'habit_completed',
        relatedId: event.habitId,
        ruleSnapshot: ruleSnapshot,
      );
    }

    await _saveHabitsToStorage();
    emit(HabitLoaded(List.from(_habits)));
  }

  /// 处理撤销习惯完成事件
  FutureOr<void> _onUndoHabitCompletion(
      UndoHabitCompletion event, Emitter<HabitState> emit) async {
    final index = _habits.indexWhere((habit) => habit.id == event.habitId);
    if (index == -1) return;

    final habit = _habits[index];
    final targetDate = event.date ?? DateTime.now();
    final today = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final todayStr = today.toIso8601String().split('T')[0];

    if (!habit.history.contains(todayStr)) return;

    final updatedHistory = habit.history.where((d) => d != todayStr).toList();

    List<CheckInRecord> updatedCheckInRecords = habit.checkInRecords.where((record) {
      final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      return !(rDate.isAtSameMomentAs(today) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_'));
    }).toList();

    int pointsToDeduct = 0;
    bool cycleRewardRevoked = false;

    if (habit.scoringMode == ScoringMode.daily) {
      final removedRecords = habit.checkInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return rDate.isAtSameMomentAs(today) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_');
      });
      for (final record in removedRecords) {
        pointsToDeduct += record.score;
      }
    } else if (habit.scoringMode == ScoringMode.checkInWithPenalty) {
      final removedRecords = habit.checkInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return rDate.isAtSameMomentAs(today) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_');
      });
      for (final record in removedRecords) {
        pointsToDeduct += record.score;
      }

      DateTime cycleStart;
      final createDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
      final daysSinceCreation = today.difference(createDate).inDays;
      if (daysSinceCreation < 0) {
        cycleStart = today;
      } else {
        final cycleIndex = daysSinceCreation ~/ habit.customCycleDays;
        cycleStart = createDate.add(Duration(days: cycleIndex * habit.customCycleDays));
      }
      cycleStart = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
      final cycleEnd = cycleStart.add(Duration(days: habit.customCycleDays));

      final penaltyRecordsInCycle = habit.checkInRecords.where((record) {
        if (!record.id.startsWith('penalty_')) return false;
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart) && rDate.isBefore(cycleEnd);
      });
      for (final record in penaltyRecordsInCycle) {
        pointsToDeduct += record.score;
      }

      updatedCheckInRecords = updatedCheckInRecords.where((record) {
        if (!record.id.startsWith('penalty_')) return true;
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return rDate.isBefore(cycleStart) || !rDate.isBefore(cycleEnd);
      }).toList();
    } else if (habit.scoringMode == ScoringMode.weeklyWithPenalty) {
      final removedRecords = habit.checkInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return rDate.isAtSameMomentAs(today) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_');
      });
      for (final record in removedRecords) {
        pointsToDeduct += record.score;
      }

      final weekday = targetDate.weekday;
      DateTime cycleStart = today.subtract(Duration(days: weekday - 1));
      cycleStart = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
      final cycleEnd = cycleStart.add(const Duration(days: 7));

      final penaltyRecordsInCycle = habit.checkInRecords.where((record) {
        if (!record.id.startsWith('penalty_')) return false;
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart) && rDate.isBefore(cycleEnd);
      });
      for (final record in penaltyRecordsInCycle) {
        pointsToDeduct += record.score;
      }

      updatedCheckInRecords = updatedCheckInRecords.where((record) {
        if (!record.id.startsWith('penalty_')) return true;
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return rDate.isBefore(cycleStart) || !rDate.isBefore(cycleEnd);
      }).toList();
    } else {
      final removedRecords = habit.checkInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return rDate.isAtSameMomentAs(today) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_');
      });
      for (final record in removedRecords) {
        pointsToDeduct += record.score;
      }

      DateTime cycleStart;
      if (habit.scoringMode == ScoringMode.weekly) {
        final weekday = targetDate.weekday;
        cycleStart = today.subtract(Duration(days: weekday - 1));
      } else {
        final createDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
        final daysSinceCreation = today.difference(createDate).inDays;
        if (daysSinceCreation < 0) {
          cycleStart = today;
        } else {
          final cycleIndex = daysSinceCreation ~/ habit.customCycleDays;
          cycleStart = createDate.add(Duration(days: cycleIndex * habit.customCycleDays));
        }
      }
      cycleStart = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);

      final recordsInCycleAfterUndo = updatedCheckInRecords.where((record) {
        final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        return !rDate.isBefore(cycleStart) && !record.id.startsWith('reward_') && !record.id.startsWith('penalty_');
      }).length;

      final bool wasRewarded = habit.lastCycleRewardTime != null &&
          !DateTime(habit.lastCycleRewardTime!.year, habit.lastCycleRewardTime!.month, habit.lastCycleRewardTime!.day).isBefore(cycleStart);

      if (wasRewarded && recordsInCycleAfterUndo < habit.targetDays) {
        pointsToDeduct += habit.type == HabitType.negative
            ? -habit.cycleRewardPoints
            : habit.cycleRewardPoints;
        cycleRewardRevoked = true;

        updatedCheckInRecords = updatedCheckInRecords.where((record) {
          final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
          return !(!rDate.isBefore(cycleStart) && record.id.startsWith('reward_'));
        }).toList();
      }
    }

    final currentStreak = _calculateCurrentStreak(updatedCheckInRecords);
    final totalCompletions = updatedCheckInRecords.where((r) => !r.id.startsWith('reward_') && !r.id.startsWith('penalty_')).length;
    int bestStreak = habit.bestStreak;
    if (currentStreak > bestStreak) bestStreak = currentStreak;

    DateTime? newLastRewardTime = habit.lastCycleRewardTime;
    if (cycleRewardRevoked) {
      newLastRewardTime = null;
    }

    final updatedHabit = habit.copyWith(
      currentStreak: currentStreak,
      totalCompletions: totalCompletions,
      bestStreak: bestStreak,
      history: updatedHistory,
      checkInRecords: updatedCheckInRecords,
      updatedAt: targetDate,
      lastCycleRewardTime: newLastRewardTime,
    );

    _habits[index] = updatedHabit;

    if (pointsToDeduct != 0) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(StorageKeys.userId) ?? 'default_user';
      final String habitTypeDesc = habit.type == HabitType.negative ? '减分项' : '加分项';

      final originalBillItem = await _databaseService.getBillItemByRelatedId(userId, event.habitId, 'habit_completed');
      double undoPoints;
      if (originalBillItem?.ruleSnapshot != null) {
        try {
          final snapshot = jsonDecode(originalBillItem!.ruleSnapshot!);
          undoPoints = -(snapshot['score'] ?? habit.fullStars).toDouble();
        } catch (_) {
          undoPoints = -pointsToDeduct.toDouble();
        }
      } else {
        undoPoints = -pointsToDeduct.toDouble();
      }

      await _databaseService.updateUserPoints(
        userId,
        undoPoints,
        description: '撤销打卡($habitTypeDesc): ${habit.name}',
        transactionType: 'habit_undo',
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

    // 保存到数据库
    await _saveHabitsToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(HabitLoaded(List.from(_habits)));
  }

  /// 处理覆盖习惯事件（原子操作）
  FutureOr<void> _onOverwriteHabit(OverwriteHabit event, Emitter<HabitState> emit) async {
    // 1. 取消旧习惯的通知
    for (final oldId in event.oldHabitIds) {
      await _cancelHabitNotification(oldId);
    }

    // 2. 从内存中删除旧记录
    _habits.removeWhere((habit) => event.oldHabitIds.contains(habit.id));

    // 3. 添加新记录
    _habits.add(event.newHabit);

    // 4. 一次性保存到数据库
    await _saveHabitsToStorage();

    // 5. 调度新习惯的通知
    await _scheduleHabitNotification(event.newHabit);

    // 6. 发出更新状态
    emit(HabitLoaded(List.from(_habits)));
  }

  /// 处理搜索习惯事件
  FutureOr<void> _onSearchHabits(
      SearchHabits event, Emitter<HabitState> emit) {
    if (state is HabitLoaded) {
      final allHabits = (state as HabitLoaded).habits;
      if (event.query.isEmpty) {
        emit(HabitSearchResult(List.from(allHabits), ''));
      } else {
        final lowerQuery = event.query.toLowerCase();
        final filtered = allHabits.where((habit) {
          return habit.name.toLowerCase().contains(lowerQuery) ||
              habit.notes.toLowerCase().contains(lowerQuery);
        }).toList();
        emit(HabitSearchResult(filtered, event.query));
      }
    } else if (state is HabitSearchResult) {
      final allHabits = _habits;
      if (event.query.isEmpty) {
        emit(HabitSearchResult(List.from(allHabits), ''));
      } else {
        final lowerQuery = event.query.toLowerCase();
        final filtered = allHabits.where((habit) {
          return habit.name.toLowerCase().contains(lowerQuery) ||
              habit.notes.toLowerCase().contains(lowerQuery);
        }).toList();
        emit(HabitSearchResult(filtered, event.query));
      }
    }
  }
}
