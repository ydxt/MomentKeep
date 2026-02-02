import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart'; // 用于Color类

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

  /// 连续打卡天数
  final int streakDays;

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
  
  /// 逾期待办数据（待办ID: 待办信息）
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
    required this.dailyActivityData,
    required this.categoryCompletionRates,
    this.scoreTrendData = const {},
    this.habitScoreTrendData = const {},
    this.checkInHistory = const {},
    this.totalTodos = 0,
    this.completedTodos = 0,
    this.todoCompletionRate = 0.0,
    this.todoCategoryDistribution = const {},
    this.todoTrendData = const {},
    this.todoPriorityDistribution = const {},
    this.overdueTodos = const [],
    this.totalDiaries = 0,
    this.diaryCategoryDistribution = const {},
    this.diaryTrendData = const {},
    this.diaryMediaUsage = const {},
    this.diaryTagDistribution = const {},
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
    Map<int, int>? dailyActivityData,
    Map<String, double>? categoryCompletionRates,
    Map<String, double>? scoreTrendData,
    Map<String, Map<String, double>>? habitScoreTrendData,
    Set<String>? checkInHistory,
    int? totalTodos,
    int? completedTodos,
    double? todoCompletionRate,
    Map<String, int>? todoCategoryDistribution,
    Map<String, int>? todoTrendData,
    Map<String, int>? todoPriorityDistribution,
    List<Map<String, dynamic>>? overdueTodos,
    int? totalDiaries,
    Map<String, int>? diaryCategoryDistribution,
    Map<String, int>? diaryTrendData,
    Map<String, int>? diaryMediaUsage,
    Map<String, int>? diaryTagDistribution,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Dashboard(
      id: id ?? this.id,
      totalHabits: totalHabits ?? this.totalHabits,
      completedHabits: completedHabits ?? this.completedHabits,
      completionRate: completionRate ?? this.completionRate,
      completedDaysThisWeek: 
          completedDaysThisWeek ?? this.completedDaysThisWeek,
      completedDaysThisMonth: 
          completedDaysThisMonth ?? this.completedDaysThisMonth,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      streakDays: streakDays ?? this.streakDays,
      dailyActivityData: dailyActivityData ?? this.dailyActivityData,
      categoryCompletionRates: 
          categoryCompletionRates ?? this.categoryCompletionRates,
      scoreTrendData: scoreTrendData ?? this.scoreTrendData,
      habitScoreTrendData: habitScoreTrendData ?? this.habitScoreTrendData,
      checkInHistory: checkInHistory ?? this.checkInHistory,
      totalTodos: totalTodos ?? this.totalTodos,
      completedTodos: completedTodos ?? this.completedTodos,
      todoCompletionRate: todoCompletionRate ?? this.todoCompletionRate,
      todoCategoryDistribution: todoCategoryDistribution ?? this.todoCategoryDistribution,
      todoTrendData: todoTrendData ?? this.todoTrendData,
      todoPriorityDistribution: todoPriorityDistribution ?? this.todoPriorityDistribution,
      overdueTodos: overdueTodos ?? this.overdueTodos,
      totalDiaries: totalDiaries ?? this.totalDiaries,
      diaryCategoryDistribution: diaryCategoryDistribution ?? this.diaryCategoryDistribution,
      diaryTrendData: diaryTrendData ?? this.diaryTrendData,
      diaryMediaUsage: diaryMediaUsage ?? this.diaryMediaUsage,
      diaryTagDistribution: diaryTagDistribution ?? this.diaryTagDistribution,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        totalHabits,
        completedHabits,
        completionRate,
        completedDaysThisWeek,
        completedDaysThisMonth,
        totalCheckIns,
        streakDays,
        dailyActivityData,
        categoryCompletionRates,
        scoreTrendData,
        habitScoreTrendData,
        checkInHistory,
        totalTodos,
        completedTodos,
        todoCompletionRate,
        todoCategoryDistribution,
        todoTrendData,
        todoPriorityDistribution,
        overdueTodos,
        totalDiaries,
        diaryCategoryDistribution,
        diaryTrendData,
        diaryMediaUsage,
        diaryTagDistribution,
        createdAt,
        updatedAt,
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
