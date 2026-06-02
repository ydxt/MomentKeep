import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// 数据看板实体类
class Dashboard extends Equatable {
  /// 唯一标识符
  final String id;

  /// 总习惯数
  final int totalHabits;

  /// 已完成习惯数
  final int completedHabits;

  /// 习惯完成率
  final double completionRate;

  /// 本周完成天数
  final int completedDaysThisWeek;

  /// 本月完成天数
  final int completedDaysThisMonth;

  /// 总打卡次数
  final int totalCheckIns;

  /// 连续打卡天数（最长连击）
  final int streakDays;

  /// 当前连击天数
  final int currentStreak;

  /// 每个习惯的当前连击（习惯ID: 连击天数）
  final Map<String, int> habitStreaks;

  /// 正向习惯数
  final int positiveHabitCount;

  /// 反向习惯数
  final int negativeHabitCount;

  /// 反向习惯控制率（越低越好）
  final double negativeHabitControlRate;

  /// 每周完成率趋势（周标识: 完成率）
  final Map<String, double> weeklyCompletionRates;

  /// 每日活跃时段数据（小时: 活跃次数）
  final Map<int, int> dailyActivityData;

  /// 习惯分类完成率（分类: 完成率）
  final Map<String, double> categoryCompletionRates;

  /// 分数趋势数据（日期: 平均分数）
  final Map<String, double> scoreTrendData;

  /// 每个习惯的分数趋势数据（习惯ID: {日期: 分数}）
  final Map<String, Map<String, double>> habitScoreTrendData;

  /// 打卡历史数据（日期: 打卡状态）
  final Set<String> checkInHistory;

  /// 每日打卡平均分数（日期: 平均分数 1-5）
  final Map<String, double> dailyCheckInScores;

  /// 待办统计数据

  /// 总待办数
  final int totalTodos;

  /// 已完成待办数
  final int completedTodos;

  /// 待办完成率
  final double todoCompletionRate;

  /// 待办分类分布（分类: 待办数）
  final Map<String, int> todoCategoryDistribution;

  /// 待办趋势数据（日期: 完成待办数）
  final Map<String, int> todoTrendData;

  /// 待办优先级分布（优先级: 待办数）
  final Map<String, int> todoPriorityDistribution;

  /// 待办完成时段分布（时段名: 完成数）
  final Map<String, int> todoCompletionTimeDistribution;

  /// 重复任务数
  final int recurringTodoCount;

  /// 单次任务数
  final int singleTodoCount;

  /// 平均完成时长（小时）
  final double avgCompletionHours;

  /// 上一周期完成数（用于对比）
  final int lastPeriodCompleted;

  /// 逾期待办数据
  final List<Map<String, dynamic>> overdueTodos;

  /// 日记统计数据

  /// 总日记数
  final int totalDiaries;

  /// 日记分类分布（分类: 日记数）
  final Map<String, int> diaryCategoryDistribution;

  /// 日记趋势数据（日期: 日记数）
  final Map<String, int> diaryTrendData;

  /// 日记媒体使用统计（媒体类型: 使用次数）
  final Map<String, int> diaryMediaUsage;

  /// 日记标签分布（标签: 使用次数）
  final Map<String, int> diaryTagDistribution;

  /// 平均心情（1-5）
  final double averageMood;

  /// 心情分布（心情值: 次数）
  final Map<int, int> moodDistribution;

  /// 心情趋势（日期: 平均心情值）
  final Map<String, double> moodTrend;

  /// 最长连续写作天数
  final int longestWritingStreak;

  /// 当前连续写作天数
  final int currentWritingStreak;

  /// 月度日记数（月份标识: 日记数）
  final Map<String, int> monthlyDiaryCounts;

  /// 每周字数（周标识: 总字数）
  final Map<String, int> weeklyWordCounts;

  /// 积分统计数据

  /// 总收入
  final double totalIncome;

  /// 总支出
  final double totalExpense;

  /// 净收入
  final double netIncome;

  /// 积分趋势数据
  final List<PointsTrendPoint> pointsTrendData;

  /// 积分来源分布（来源类型: 金额）
  final Map<String, double> incomeTypeDistribution;

  /// 积分消耗分布（消耗类型: 金额）
  final Map<String, double> expenseTypeDistribution;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 构造函数
  const Dashboard({
    required this.id,
    required this.totalHabits,
    required this.completedHabits,
    required this.completionRate,
    required this.completedDaysThisWeek,
    required this.completedDaysThisMonth,
    required this.totalCheckIns,
    required this.streakDays,
    this.currentStreak = 0,
    this.habitStreaks = const {},
    this.positiveHabitCount = 0,
    this.negativeHabitCount = 0,
    this.negativeHabitControlRate = 0.0,
    this.weeklyCompletionRates = const {},
    required this.dailyActivityData,
    required this.categoryCompletionRates,
    this.scoreTrendData = const {},
    this.habitScoreTrendData = const {},
    this.checkInHistory = const {},
    this.dailyCheckInScores = const {},
    this.totalTodos = 0,
    this.completedTodos = 0,
    this.todoCompletionRate = 0.0,
    this.todoCategoryDistribution = const {},
    this.todoTrendData = const {},
    this.todoPriorityDistribution = const {},
    this.todoCompletionTimeDistribution = const {},
    this.recurringTodoCount = 0,
    this.singleTodoCount = 0,
    this.avgCompletionHours = 0.0,
    this.lastPeriodCompleted = 0,
    this.overdueTodos = const [],
    this.totalDiaries = 0,
    this.diaryCategoryDistribution = const {},
    this.diaryTrendData = const {},
    this.diaryMediaUsage = const {},
    this.diaryTagDistribution = const {},
    this.averageMood = 0.0,
    this.moodDistribution = const {},
    this.moodTrend = const {},
    this.longestWritingStreak = 0,
    this.currentWritingStreak = 0,
    this.monthlyDiaryCounts = const {},
    this.weeklyWordCounts = const {},
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    this.netIncome = 0.0,
    this.pointsTrendData = const [],
    this.incomeTypeDistribution = const {},
    this.expenseTypeDistribution = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// 复制方法，用于更新数据看板
  Dashboard copyWith({
    String? id,
    int? totalHabits,
    int? completedHabits,
    double? completionRate,
    int? completedDaysThisWeek,
    int? completedDaysThisMonth,
    int? totalCheckIns,
    int? streakDays,
    int? currentStreak,
    Map<String, int>? habitStreaks,
    int? positiveHabitCount,
    int? negativeHabitCount,
    double? negativeHabitControlRate,
    Map<String, double>? weeklyCompletionRates,
    Map<int, int>? dailyActivityData,
    Map<String, double>? categoryCompletionRates,
    Map<String, double>? scoreTrendData,
    Map<String, Map<String, double>>? habitScoreTrendData,
    Set<String>? checkInHistory,
    Map<String, double>? dailyCheckInScores,
    int? totalTodos,
    int? completedTodos,
    double? todoCompletionRate,
    Map<String, int>? todoCategoryDistribution,
    Map<String, int>? todoTrendData,
    Map<String, int>? todoPriorityDistribution,
    Map<String, int>? todoCompletionTimeDistribution,
    int? recurringTodoCount,
    int? singleTodoCount,
    double? avgCompletionHours,
    int? lastPeriodCompleted,
    List<Map<String, dynamic>>? overdueTodos,
    int? totalDiaries,
    Map<String, int>? diaryCategoryDistribution,
    Map<String, int>? diaryTrendData,
    Map<String, int>? diaryMediaUsage,
    Map<String, int>? diaryTagDistribution,
    double? averageMood,
    Map<int, int>? moodDistribution,
    Map<String, double>? moodTrend,
    int? longestWritingStreak,
    int? currentWritingStreak,
    Map<String, int>? monthlyDiaryCounts,
    Map<String, int>? weeklyWordCounts,
    double? totalIncome,
    double? totalExpense,
    double? netIncome,
    List<PointsTrendPoint>? pointsTrendData,
    Map<String, double>? incomeTypeDistribution,
    Map<String, double>? expenseTypeDistribution,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Dashboard(
      id: id ?? this.id,
      totalHabits: totalHabits ?? this.totalHabits,
      completedHabits: completedHabits ?? this.completedHabits,
      completionRate: completionRate ?? this.completionRate,
      completedDaysThisWeek: completedDaysThisWeek ?? this.completedDaysThisWeek,
      completedDaysThisMonth: completedDaysThisMonth ?? this.completedDaysThisMonth,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      streakDays: streakDays ?? this.streakDays,
      currentStreak: currentStreak ?? this.currentStreak,
      habitStreaks: habitStreaks ?? this.habitStreaks,
      positiveHabitCount: positiveHabitCount ?? this.positiveHabitCount,
      negativeHabitCount: negativeHabitCount ?? this.negativeHabitCount,
      negativeHabitControlRate: negativeHabitControlRate ?? this.negativeHabitControlRate,
      weeklyCompletionRates: weeklyCompletionRates ?? this.weeklyCompletionRates,
      dailyActivityData: dailyActivityData ?? this.dailyActivityData,
      categoryCompletionRates: categoryCompletionRates ?? this.categoryCompletionRates,
      scoreTrendData: scoreTrendData ?? this.scoreTrendData,
      habitScoreTrendData: habitScoreTrendData ?? this.habitScoreTrendData,
      checkInHistory: checkInHistory ?? this.checkInHistory,
      dailyCheckInScores: dailyCheckInScores ?? this.dailyCheckInScores,
      totalTodos: totalTodos ?? this.totalTodos,
      completedTodos: completedTodos ?? this.completedTodos,
      todoCompletionRate: todoCompletionRate ?? this.todoCompletionRate,
      todoCategoryDistribution: todoCategoryDistribution ?? this.todoCategoryDistribution,
      todoTrendData: todoTrendData ?? this.todoTrendData,
      todoPriorityDistribution: todoPriorityDistribution ?? this.todoPriorityDistribution,
      todoCompletionTimeDistribution: todoCompletionTimeDistribution ?? this.todoCompletionTimeDistribution,
      recurringTodoCount: recurringTodoCount ?? this.recurringTodoCount,
      singleTodoCount: singleTodoCount ?? this.singleTodoCount,
      avgCompletionHours: avgCompletionHours ?? this.avgCompletionHours,
      lastPeriodCompleted: lastPeriodCompleted ?? this.lastPeriodCompleted,
      overdueTodos: overdueTodos ?? this.overdueTodos,
      totalDiaries: totalDiaries ?? this.totalDiaries,
      diaryCategoryDistribution: diaryCategoryDistribution ?? this.diaryCategoryDistribution,
      diaryTrendData: diaryTrendData ?? this.diaryTrendData,
      diaryMediaUsage: diaryMediaUsage ?? this.diaryMediaUsage,
      diaryTagDistribution: diaryTagDistribution ?? this.diaryTagDistribution,
      averageMood: averageMood ?? this.averageMood,
      moodDistribution: moodDistribution ?? this.moodDistribution,
      moodTrend: moodTrend ?? this.moodTrend,
      longestWritingStreak: longestWritingStreak ?? this.longestWritingStreak,
      currentWritingStreak: currentWritingStreak ?? this.currentWritingStreak,
      monthlyDiaryCounts: monthlyDiaryCounts ?? this.monthlyDiaryCounts,
      weeklyWordCounts: weeklyWordCounts ?? this.weeklyWordCounts,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      netIncome: netIncome ?? this.netIncome,
      pointsTrendData: pointsTrendData ?? this.pointsTrendData,
      incomeTypeDistribution: incomeTypeDistribution ?? this.incomeTypeDistribution,
      expenseTypeDistribution: expenseTypeDistribution ?? this.expenseTypeDistribution,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, totalHabits, completedHabits, completionRate,
        completedDaysThisWeek, completedDaysThisMonth, totalCheckIns,
        streakDays, currentStreak, habitStreaks, positiveHabitCount,
        negativeHabitCount, negativeHabitControlRate, weeklyCompletionRates,
        dailyActivityData, categoryCompletionRates, scoreTrendData,
        habitScoreTrendData, checkInHistory, dailyCheckInScores,
        totalTodos, completedTodos, todoCompletionRate,
        todoCategoryDistribution, todoTrendData, todoPriorityDistribution,
        todoCompletionTimeDistribution, recurringTodoCount, singleTodoCount,
        avgCompletionHours, lastPeriodCompleted, overdueTodos,
        totalDiaries, diaryCategoryDistribution, diaryTrendData,
        diaryMediaUsage, diaryTagDistribution, averageMood,
        moodDistribution, moodTrend, longestWritingStreak,
        currentWritingStreak, monthlyDiaryCounts, weeklyWordCounts,
        totalIncome, totalExpense, netIncome, pointsTrendData,
        incomeTypeDistribution, expenseTypeDistribution,
        createdAt, updatedAt,
      ];
}

/// 习惯分类统计实体类
class CategoryStats extends Equatable {
  /// 分类名称
  final String category;

  /// 习惯数
  final int habitCount;

  /// 完成率
  final double completionRate;

  /// 颜色
  final Color color;

  /// 构造函数
  const CategoryStats({
    required this.category,
    required this.habitCount,
    required this.completionRate,
    required this.color,
  });

  @override
  List<Object?> get props => [category, habitCount, completionRate, color];
}

/// 每日活跃时段统计实体类
class DailyActivityStats extends Equatable {
  /// 小时（0-23）
  final int hour;

  /// 活跃次数
  final int count;

  /// 构造函数
  const DailyActivityStats({
    required this.hour,
    required this.count,
  });

  @override
  List<Object?> get props => [hour, count];
}

/// 积分趋势数据点
class PointsTrendPoint extends Equatable {
  /// 日期
  final DateTime date;

  /// 收入
  final double income;

  /// 支出
  final double expense;

  /// 构造函数
  const PointsTrendPoint({
    required this.date,
    required this.income,
    required this.expense,
  });

  @override
  List<Object?> get props => [date, income, expense];
}
