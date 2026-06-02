import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/dashboard.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/core/services/mood_statistics_service.dart';
import 'dart:async';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/diary_bloc.dart';

/// 数据看板事件
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object> get props => [];
}

/// 加载数据看板事件
class LoadDashboard extends DashboardEvent {
  /// 时间范围（日、周、月、年、自定义）
  final String timeRange;

  /// 习惯筛选条件
  final String habitFilter;

  /// 开始日期（自定义时间范围时使用）
  final DateTime? startDate;

  /// 结束日期（自定义时间范围时使用）
  final DateTime? endDate;

  /// 构造函数
  const LoadDashboard({this.timeRange = '月', this.habitFilter = '全部', this.startDate, this.endDate});

  @override
  List<Object> get props => [timeRange, habitFilter, startDate ?? DateTime.now(), endDate ?? DateTime.now()];
}

/// 刷新数据看板事件
class RefreshDashboard extends DashboardEvent {
  /// 时间范围（日、周、月、年、自定义）
  final String timeRange;

  /// 习惯筛选条件
  final String habitFilter;

  /// 开始日期（自定义时间范围时使用）
  final DateTime? startDate;

  /// 结束日期（自定义时间范围时使用）
  final DateTime? endDate;

  /// 构造函数
  const RefreshDashboard({this.timeRange = '月', this.habitFilter = '全部', this.startDate, this.endDate});

  @override
  List<Object> get props => [timeRange, habitFilter, startDate ?? DateTime.now(), endDate ?? DateTime.now()];
}

/// 数据看板状态
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object> get props => [];
}

/// 数据看板初始状态
class DashboardInitial extends DashboardState {}

/// 数据看板加载中状态
class DashboardLoading extends DashboardState {}

/// 数据看板加载完成状态
class DashboardLoaded extends DashboardState {
  final Dashboard dashboard;

  const DashboardLoaded(this.dashboard);

  @override
  List<Object> get props => [dashboard];
}

/// 数据看板操作失败状态
class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}

/// 数据看板BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final HabitBloc? habitBloc;
  final TodoBloc? todoBloc;
  final DiaryBloc? diaryBloc;
  bool isRefreshing = false;

  Dashboard? _cachedDashboard;
  String? _cachedTimeRange;
  String? _cachedHabitFilter;

  DashboardBloc([this.habitBloc, this.todoBloc, this.diaryBloc])
      : super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<RefreshDashboard>(_onRefreshDashboard);
  }

  void _invalidateCache() {
    _cachedDashboard = null;
    _cachedTimeRange = null;
    _cachedHabitFilter = null;
  }

  Future<void> _waitForBlocState<BlocType extends BlocBase<StateType>, StateType>(
    BlocType? bloc,
    bool Function(StateType) isTargetState,
  ) async {
    if (bloc == null) return;
    if (isTargetState(bloc.state)) return;
    try {
      await bloc.stream
          .firstWhere(isTargetState, orElse: () => bloc.state)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // proceed with whatever state is available
    }
  }

  /// 从习惯数据计算仪表板数据
  Dashboard _calculateDashboardData(String timeRange,
      {String habitFilter = '全部', DateTime? startDate, DateTime? endDate}) {
    // 获取习惯列表
    final List<Habit> habits = habitBloc?.state is HabitLoaded
        ? (habitBloc!.state as HabitLoaded).habits
        : [];

    // 根据习惯筛选条件过滤习惯列表
    final filteredHabits = habitFilter == '全部'
        ? habits
        : habits.where((habit) => habit.name == habitFilter).toList();

    // 获取待办列表
    final List<Todo> todos = todoBloc?.state is TodoLoaded
        ? (todoBloc!.state as TodoLoaded).todos
        : [];

    // 获取日记列表
    final List<Journal> diaries = diaryBloc?.state is DiaryLoaded
        ? (diaryBloc!.state as DiaryLoaded).entries
        : [];

    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    // 获取今天的开始时间（00:00:00）
    final todayStart = DateTime(now.year, now.month, now.day);

    // 根据时间范围计算起始日期
    DateTime startTime;
    DateTime endTime = now;
    
    if (timeRange == '自定义' && startDate != null && endDate != null) {
      // 自定义时间范围
      startTime = startDate;
      endTime = endDate;
    } else {
      // 预设时间范围
      switch (timeRange) {
        case '日':
        case '最近7天':
        case '最近一周':
          // 最近7天：从今天开始往前推7天，包括今天
          startTime = todayStart.subtract(Duration(days: 6));
          break;
        case '周':
        case '最近30天':
          // 最近30天：从今天开始往前推30天，包括今天
          startTime = todayStart.subtract(Duration(days: 29));
          break;
        case '月':
        case '全部时间':
          // 全部时间：默认显示一年的数据，从今天开始往前推365天
          startTime = todayStart.subtract(Duration(days: 364));
          break;
        case '年':
          // 年：从今天开始往前推365天
          startTime = todayStart.subtract(Duration(days: 364));
          break;
        default: // 自定义，默认使用月
          startTime = todayStart.subtract(Duration(days: 29));
      }
    }

    // 计算所选时间范围内的打卡记录
    final List<CheckInRecord> timeRangeCheckIns = [];
    final Set<String> checkInHistory = {};
    for (final habit in filteredHabits) {
      for (final record in habit.checkInRecords) {
        if (record.timestamp
            .isAfter(startTime.subtract(const Duration(seconds: 1))) &&
            record.timestamp
            .isBefore(endTime.add(const Duration(days: 1)))) {
          timeRangeCheckIns.add(record);
          final dateStr = record.timestamp.toIso8601String().split('T')[0];
          checkInHistory.add(dateStr);
        }
      }
    }

    // 计算总习惯数 and 已完成习惯数（今天）
    final int totalHabits = filteredHabits.length;
    final completedHabits = filteredHabits.where((habit) {
      return habit.checkInRecords.any((record) {
        final recordDateStr = record.timestamp.toIso8601String().split('T')[0];
        return recordDateStr == todayStr;
      });
    }).length;

    // 计算完成率
    final double completionRate =
        totalHabits > 0 ? completedHabits / totalHabits : 0.0;

    // 计算一个日期列表，包含从startTime到endTime的所有日期
    final List<String> dateRangeList = [];
    DateTime tempDate = startTime;
    while (tempDate.isBefore(endTime.add(Duration(days: 1)))) {
      dateRangeList.add(tempDate.toIso8601String().split('T')[0]);
      tempDate = tempDate.add(Duration(days: 1));
      if (tempDate.toIso8601String().split('T')[0] ==
          endTime.add(Duration(days: 1)).toIso8601String().split('T')[0]) break;
    }

    // 计算本周和本月完成天数（无论时间范围如何，都计算这两个值用于默认显示）
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final completedDaysThisWeek = filteredHabits
        .expand((habit) => habit.checkInRecords)
        .where((record) {
          return record.timestamp
              .isAfter(weekStart.subtract(const Duration(seconds: 1)));
        })
        .map((record) => record.timestamp.toIso8601String().split('T')[0])
        .toSet()
        .length;

    final completedDaysThisMonth = filteredHabits
        .expand((habit) => habit.checkInRecords)
        .where((record) {
          return record.timestamp
              .isAfter(monthStart.subtract(const Duration(seconds: 1)));
        })
        .map((record) => record.timestamp.toIso8601String().split('T')[0])
        .toSet()
        .length;

    // 计算所选时间范围内的总打卡次数和最长连续打卡天数
    int totalCheckIns = timeRangeCheckIns.length;
    int maxStreak = 0;

    for (final habit in filteredHabits) {
      if (habit.bestStreak > maxStreak) {
        maxStreak = habit.bestStreak;
      }
    }

    // 计算每日活跃时段数据
    final Map<int, int> dailyActivityData = {};
    for (final record in timeRangeCheckIns) {
      final hour = record.timestamp.hour;
      dailyActivityData[hour] = (dailyActivityData[hour] ?? 0) + 1;
    }

    // 计算分类完成率（时间范围内）
    final Map<String, int> categoryCounts = {};
    final Map<String, int> categoryCompletedCounts = {};

    for (final habit in filteredHabits) {
      // 统计分类总数
      categoryCounts[habit.category] =
          (categoryCounts[habit.category] ?? 0) + 1;

      // 统计分类完成数（时间范围内）
      final hasCheckInInRange = habit.checkInRecords.any((record) {
        return record.timestamp
            .isAfter(startTime.subtract(const Duration(seconds: 1)));
      });
      if (hasCheckInInRange) {
        categoryCompletedCounts[habit.category] =
            (categoryCompletedCounts[habit.category] ?? 0) + 1;
      }
    }

    // 计算分类完成率
    final Map<String, double> categoryCompletionRates = {};
    for (final category in categoryCounts.keys) {
      final total = categoryCounts[category] ?? 0;
      final completed = categoryCompletedCounts[category] ?? 0;
      categoryCompletionRates[category] = total > 0 ? completed / total : 0.0;
    }

    // 计算分数趋势数据
    final Map<String, List<double>> dailyScores = {};
    // 初始化每日积分为0
    for (final dateStr in dateRangeList) {
      dailyScores[dateStr] = [];
    }

    // 计算每个习惯的分数趋势数据
    final Map<String, Map<String, double>> habitScoreTrendData = {};

    for (final habit in filteredHabits) {
      habitScoreTrendData[habit.id] = {};
      // 初始化每个习惯的每日积分为0
      for (final dateStr in dateRangeList) {
        habitScoreTrendData[habit.id]![dateStr] = 0.0;
      }
    }

    for (final record in timeRangeCheckIns) {
      if (record.id.startsWith('reward_')) continue;
      final dateStr = record.timestamp.toIso8601String().split('T')[0];
      final actualScore = record.score.toDouble();
      if (dailyScores.containsKey(dateStr) && actualScore != 0) {
        dailyScores[dateStr]!.add(actualScore);
      }

      if (habitScoreTrendData.containsKey(record.habitId) &&
          habitScoreTrendData[record.habitId]!.containsKey(dateStr)) {
        habitScoreTrendData[record.habitId]![dateStr] =
            (habitScoreTrendData[record.habitId]![dateStr] ?? 0) + actualScore;
      }
    }

    // 计算每日平均分数
    final Map<String, double> scoreTrendData = {};
    for (final dateStr in dateRangeList) {
      final scores = dailyScores[dateStr] ?? [];
      if (scores.isEmpty) {
        scoreTrendData[dateStr] = 0.0;
      } else {
        final averageScore = scores.reduce((a, b) => a + b) / scores.length;
        scoreTrendData[dateStr] = averageScore;
      }
    }

    // 计算当前连击天数（所有习惯中最大的当前连击）
    int currentStreak = 0;
    final Map<String, int> habitStreaks = {};
    int positiveHabitCount = 0;
    int negativeHabitCount = 0;
    double negativeHabitControlRate = 0.0;

    for (final habit in filteredHabits) {
      habitStreaks[habit.id] = habit.currentStreak;
      if (habit.currentStreak > currentStreak) {
        currentStreak = habit.currentStreak;
      }
      if (habit.type == HabitType.positive) {
        positiveHabitCount++;
      } else {
        negativeHabitCount++;
      }
    }

    // 计算反向习惯控制率
    if (negativeHabitCount > 0) {
      final negativeHabits = filteredHabits.where((h) => h.type == HabitType.negative).toList();
      int totalTriggerDays = 0;
      final totalDays = dateRangeList.length;
      for (final habit in negativeHabits) {
        final triggerDates = habit.checkInRecords
            .where((r) => r.timestamp.isAfter(startTime) && r.timestamp.isBefore(endTime))
            .map((r) => r.timestamp.toIso8601String().split('T')[0])
            .toSet();
        totalTriggerDays += triggerDates.length;
      }
      final maxPossibleTriggerDays = negativeHabitCount * totalDays;
      negativeHabitControlRate = maxPossibleTriggerDays > 0
          ? 1.0 - (totalTriggerDays / maxPossibleTriggerDays)
          : 1.0;
    }

    // 计算每周完成率趋势
    final Map<String, double> weeklyCompletionRates = {};
    if (dateRangeList.length >= 7) {
      for (int i = 0; i < dateRangeList.length; i += 7) {
        final weekEnd = (i + 7).clamp(0, dateRangeList.length);
        final weekDates = dateRangeList.sublist(i, weekEnd);
        final weekKey = '${weekDates.first}_${weekDates.last}';
        int weekCompleted = 0;
        int weekTotal = 0;
        for (final habit in filteredHabits) {
          weekTotal++;
          final hasCheckIn = habit.checkInRecords.any((r) {
            final dateStr = r.timestamp.toIso8601String().split('T')[0];
            return weekDates.contains(dateStr);
          });
          if (hasCheckIn) weekCompleted++;
        }
        weeklyCompletionRates[weekKey] = weekTotal > 0 ? weekCompleted / weekTotal : 0.0;
      }
    }

    // 计算待办统计数据
    int totalTodos = 0;
    int completedTodos = 0;
    double todoCompletionRate = 0.0;
    Map<String, int> todoCategoryDistribution = {};
    Map<String, int> todoTrendData = {};
    Map<String, int> todoPriorityDistribution = {};
    Map<String, int> todoCompletionTimeDistribution = {};
    int recurringTodoCount = 0;
    int singleTodoCount = 0;
    double avgCompletionHours = 0.0;
    int lastPeriodCompleted = 0;
    List<Map<String, dynamic>> overdueTodos = [];

    if (todos.isNotEmpty) {
      final timeRangeTodos =
          todos.where((todo) => todo.createdAt.isAfter(startTime)).toList();
      totalTodos = timeRangeTodos.length;

      final completedTimeRangeTodos = todos
          .where((todo) => todo.isCompleted && todo.completedAt != null && todo.completedAt!.isAfter(startTime))
          .toList();
      completedTodos = completedTimeRangeTodos.length;

      todoCompletionRate = totalTodos > 0 ? completedTodos / totalTodos : 0.0;

      for (final todo in timeRangeTodos) {
        todoCategoryDistribution[todo.categoryId] =
            (todoCategoryDistribution[todo.categoryId] ?? 0) + 1;
      }

      for (final todo in completedTimeRangeTodos) {
        final dateStr = todo.completedAt!.toIso8601String().split('T')[0];
        if (DateTime.parse(dateStr).isAfter(startTime)) {
          todoTrendData[dateStr] = (todoTrendData[dateStr] ?? 0) + 1;
        }
      }

      for (final todo in timeRangeTodos) {
        final priority = todo.priority.name;
        todoPriorityDistribution[priority] =
            (todoPriorityDistribution[priority] ?? 0) + 1;
      }

      // 计算完成时段分布
      for (final todo in completedTimeRangeTodos) {
        final hour = todo.completedAt!.hour;
        String timeSlot;
        if (hour >= 6 && hour < 12) {
          timeSlot = '上午';
        } else if (hour >= 12 && hour < 18) {
          timeSlot = '下午';
        } else if (hour >= 18 && hour < 24) {
          timeSlot = '晚上';
        } else {
          timeSlot = '深夜';
        }
        todoCompletionTimeDistribution[timeSlot] =
            (todoCompletionTimeDistribution[timeSlot] ?? 0) + 1;
      }

      // 统计重复/单次任务
      for (final todo in timeRangeTodos) {
        if (todo.repeatType != RepeatType.none) {
          recurringTodoCount++;
        } else {
          singleTodoCount++;
        }
      }

      // 计算平均完成时长
      if (completedTimeRangeTodos.isNotEmpty) {
        double totalHours = 0;
        int count = 0;
        for (final todo in completedTimeRangeTodos) {
          if (todo.completedAt != null) {
            final diff = todo.completedAt!.difference(todo.createdAt);
            totalHours += diff.inMinutes / 60.0;
            count++;
          }
        }
        avgCompletionHours = count > 0 ? totalHours / count : 0.0;
      }

      // 计算上一周期完成数（用于对比）
      final periodDuration = endTime.difference(startTime);
      final prevStartTime = startTime.subtract(periodDuration);
      lastPeriodCompleted = todos
          .where((todo) =>
              todo.isCompleted &&
              todo.completedAt != null &&
              todo.completedAt!.isAfter(prevStartTime) &&
              todo.completedAt!.isBefore(startTime))
          .length;

      overdueTodos = todos
          .where((todo) => !todo.isCompleted && todo.date != null && todo.date!.isBefore(now))
          .map((todo) => {
            'id': todo.id,
            'title': todo.title,
            'date': todo.date?.toIso8601String().split('T')[0],
            'categoryId': todo.categoryId,
            'priority': todo.priority.name,
          })
          .toList();
    }

    // 计算日记统计数据
    int totalDiaries = 0;
    Map<String, int> diaryCategoryDistribution = {};
    Map<String, int> diaryTrendData = {};
    Map<String, int> diaryMediaUsage = {};
    Map<String, int> diaryTagDistribution = {};
    double averageMood = 0.0;
    Map<int, int> moodDistribution = {};
    Map<String, double> moodTrend = {};
    int longestWritingStreak = 0;
    int currentWritingStreak = 0;
    Map<String, int> monthlyDiaryCounts = {};
    Map<String, int> weeklyWordCounts = {};

    if (diaries.isNotEmpty) {
      final timeRangeDiaries =
          diaries.where((diary) => diary.date.isAfter(startTime.subtract(const Duration(seconds: 1)))).toList();
      totalDiaries = timeRangeDiaries.length;

      for (final diary in timeRangeDiaries) {
        diaryCategoryDistribution[diary.categoryId] =
            (diaryCategoryDistribution[diary.categoryId] ?? 0) + 1;
      }

      for (final diary in timeRangeDiaries) {
        final dateStr = diary.date.toIso8601String().split('T')[0];
        if (DateTime.parse(dateStr).isAfter(startTime)) {
          diaryTrendData[dateStr] = (diaryTrendData[dateStr] ?? 0) + 1;
        }
      }

      for (final diary in timeRangeDiaries) {
        for (final block in diary.content) {
          String mediaType;
          switch (block.type) {
            case ContentBlockType.text:
              mediaType = 'text';
              break;
            case ContentBlockType.image:
              mediaType = 'image';
              break;
            case ContentBlockType.audio:
              mediaType = 'audio';
              break;
            case ContentBlockType.drawing:
              mediaType = 'drawing';
              break;
            case ContentBlockType.video:
              mediaType = 'video';
              break;
          }
          if (mediaType == 'text') {
            diaryMediaUsage[mediaType] = (diaryMediaUsage[mediaType] ?? 0) + 1;
            try {
              final contentData = block.data;
              if (contentData.contains('video') || contentData.contains('Video')) {
                diaryMediaUsage['video'] = (diaryMediaUsage['video'] ?? 0) + 1;
              }
              if (contentData.contains('image') || contentData.contains('Image')) {
                diaryMediaUsage['image'] = (diaryMediaUsage['image'] ?? 0) + 1;
              }
              if (contentData.contains('audio') || contentData.contains('Audio') || contentData.contains('voice') || contentData.contains('Voice')) {
                diaryMediaUsage['audio'] = (diaryMediaUsage['audio'] ?? 0) + 1;
              }
              if (contentData.contains('drawing') || contentData.contains('Drawing')) {
                diaryMediaUsage['drawing'] = (diaryMediaUsage['drawing'] ?? 0) + 1;
              }
            } catch (e) {}
          } else {
            diaryMediaUsage[mediaType] = (diaryMediaUsage[mediaType] ?? 0) + 1;
          }
        }
      }

      for (final diary in timeRangeDiaries) {
        for (final tag in diary.tags) {
          diaryTagDistribution[tag] = (diaryTagDistribution[tag] ?? 0) + 1;
        }
      }

      // 集成 MoodStatisticsService
      final moodStats = MoodStatisticsService().calculateMoodStats(timeRangeDiaries);
      averageMood = (moodStats['averageMood'] as num?)?.toDouble() ?? 0.0;
      moodDistribution = Map<int, int>.from(moodStats['moodDistribution'] as Map? ?? {});
      final moodTrendList = moodStats['moodTrend'] as List? ?? [];
      for (final item in moodTrendList) {
        final itemMap = item as Map<String, dynamic>;
        final dateStr = itemMap['date'] as String? ?? '';
        final avgMood = (itemMap['averageMood'] as num?)?.toDouble() ?? 0.0;
        if (dateStr.isNotEmpty) {
          moodTrend[dateStr] = avgMood;
        }
      }

      // 计算写作连击
      final diaryDates = timeRangeDiaries
          .map((d) => d.date.toIso8601String().split('T')[0])
          .toSet()
          .toList();
      diaryDates.sort();
      if (diaryDates.isNotEmpty) {
        int tempStreak = 1;
        int maxStreak = 1;
        for (int i = 1; i < diaryDates.length; i++) {
          final prev = DateTime.parse(diaryDates[i - 1]);
          final curr = DateTime.parse(diaryDates[i]);
          if (curr.difference(prev).inDays == 1) {
            tempStreak++;
            if (tempStreak > maxStreak) maxStreak = tempStreak;
          } else {
            tempStreak = 1;
          }
        }
        longestWritingStreak = maxStreak;

        // 计算当前写作连击
        final today = DateTime.now();
        int curStreak = 0;
        for (int i = 0; i < 365; i++) {
          final checkDate = today.subtract(Duration(days: i));
          final checkStr = checkDate.toIso8601String().split('T')[0];
          if (diaryDates.contains(checkStr)) {
            curStreak++;
          } else {
            break;
          }
        }
        currentWritingStreak = curStreak;
      }

      // 计算月度日记数
      for (final diary in timeRangeDiaries) {
        final monthKey = '${diary.date.year}-${diary.date.month.toString().padLeft(2, '0')}';
        monthlyDiaryCounts[monthKey] = (monthlyDiaryCounts[monthKey] ?? 0) + 1;
      }

      // 计算每周字数
      for (final diary in timeRangeDiaries) {
        final weekMonday = diary.date.subtract(Duration(days: diary.date.weekday - 1));
        final weekKey = '${weekMonday.year}-${weekMonday.month.toString().padLeft(2, '0')}-${weekMonday.day.toString().padLeft(2, '0')}';
        int wordCount = 0;
        for (final block in diary.content) {
          if (block.type == ContentBlockType.text) {
            wordCount += block.data.length;
          }
        }
        weeklyWordCounts[weekKey] = (weeklyWordCounts[weekKey] ?? 0) + wordCount;
      }
    }

    // 创建仪表板数据
    return Dashboard(
      id: '1',
      totalHabits: totalHabits,
      completedHabits: completedHabits,
      completionRate: completionRate,
      completedDaysThisWeek: completedDaysThisWeek,
      completedDaysThisMonth: completedDaysThisMonth,
      totalCheckIns: totalCheckIns,
      streakDays: maxStreak,
      currentStreak: currentStreak,
      habitStreaks: habitStreaks,
      positiveHabitCount: positiveHabitCount,
      negativeHabitCount: negativeHabitCount,
      negativeHabitControlRate: negativeHabitControlRate,
      weeklyCompletionRates: weeklyCompletionRates,
      dailyActivityData: dailyActivityData,
      categoryCompletionRates: categoryCompletionRates,
      scoreTrendData: scoreTrendData,
      habitScoreTrendData: habitScoreTrendData,
      checkInHistory: checkInHistory,
      dailyCheckInScores: scoreTrendData,
      totalTodos: totalTodos,
      completedTodos: completedTodos,
      todoCompletionRate: todoCompletionRate,
      todoCategoryDistribution: todoCategoryDistribution,
      todoTrendData: todoTrendData,
      todoPriorityDistribution: todoPriorityDistribution,
      todoCompletionTimeDistribution: todoCompletionTimeDistribution,
      recurringTodoCount: recurringTodoCount,
      singleTodoCount: singleTodoCount,
      avgCompletionHours: avgCompletionHours,
      lastPeriodCompleted: lastPeriodCompleted,
      overdueTodos: overdueTodos,
      totalDiaries: totalDiaries,
      diaryCategoryDistribution: diaryCategoryDistribution,
      diaryTrendData: diaryTrendData,
      diaryMediaUsage: diaryMediaUsage,
      diaryTagDistribution: diaryTagDistribution,
      averageMood: averageMood,
      moodDistribution: moodDistribution,
      moodTrend: moodTrend,
      longestWritingStreak: longestWritingStreak,
      currentWritingStreak: currentWritingStreak,
      monthlyDiaryCounts: monthlyDiaryCounts,
      weeklyWordCounts: weeklyWordCounts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 处理加载数据看板事件
  FutureOr<void> _onLoadDashboard(
      LoadDashboard event, Emitter<DashboardState> emit) async {
    if (_cachedDashboard != null &&
        _cachedTimeRange == event.timeRange &&
        _cachedHabitFilter == event.habitFilter) {
      emit(DashboardLoaded(_cachedDashboard!));
    } else {
      emit(DashboardLoading());
    }

    try {
      if (habitBloc != null) {
        if (habitBloc!.state is! HabitLoaded) {
          habitBloc?.add(LoadHabits());
        }
        await _waitForBlocState<HabitBloc, HabitState>(
          habitBloc,
          (state) => state is HabitLoaded,
        );
      }

      if (todoBloc != null) {
        if (todoBloc!.state is! TodoLoaded) {
          todoBloc?.add(LoadTodos());
        }
        await _waitForBlocState<TodoBloc, TodoState>(
          todoBloc,
          (state) => state is TodoLoaded,
        );
      }

      if (diaryBloc != null) {
        if (diaryBloc!.state is! DiaryLoaded) {
          diaryBloc?.add(LoadDiaryEntries());
        }
        await _waitForBlocState<DiaryBloc, DiaryState>(
          diaryBloc,
          (state) => state is DiaryLoaded,
        );
      }

      final dashboard = _calculateDashboardData(event.timeRange,
          habitFilter: event.habitFilter,
          startDate: event.startDate,
          endDate: event.endDate);
      _cachedDashboard = dashboard;
      _cachedTimeRange = event.timeRange;
      _cachedHabitFilter = event.habitFilter;
      emit(DashboardLoaded(dashboard));
    } catch (e) {
      emit(DashboardError('加载数据看板失败'));
    }
  }

  /// 处理刷新数据看板事件
  FutureOr<void> _onRefreshDashboard(
      RefreshDashboard event, Emitter<DashboardState> emit) async {
    isRefreshing = true;
    _invalidateCache();
    emit(DashboardLoading());
    try {
      if (habitBloc != null) {
        if (habitBloc!.state is! HabitLoaded) {
          habitBloc?.add(LoadHabits());
        }
        await _waitForBlocState<HabitBloc, HabitState>(
          habitBloc,
          (state) => state is HabitLoaded,
        );
      }

      if (todoBloc != null) {
        if (todoBloc!.state is! TodoLoaded) {
          todoBloc?.add(LoadTodos());
        }
        await _waitForBlocState<TodoBloc, TodoState>(
          todoBloc,
          (state) => state is TodoLoaded,
        );
      }

      if (diaryBloc != null) {
        if (diaryBloc!.state is! DiaryLoaded) {
          diaryBloc?.add(LoadDiaryEntries());
        }
        await _waitForBlocState<DiaryBloc, DiaryState>(
          diaryBloc,
          (state) => state is DiaryLoaded,
        );
      }

      final dashboard = _calculateDashboardData(event.timeRange,
          habitFilter: event.habitFilter,
          startDate: event.startDate,
          endDate: event.endDate);
      _cachedDashboard = dashboard;
      _cachedTimeRange = event.timeRange;
      _cachedHabitFilter = event.habitFilter;
      emit(DashboardLoaded(dashboard));
    } catch (e) {
      emit(DashboardError('刷新数据看板失败'));
    } finally {
      isRefreshing = false;
    }
  }
}
