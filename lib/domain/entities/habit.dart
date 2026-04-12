import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';

/// 习惯频率枚举
enum HabitFrequency {
  daily,
  weekly,
  monthly,
}

/// 习惯类型枚举
enum HabitType {
  positive,
  negative,
}

/// 计分模式枚举
enum ScoringMode {
  daily,    // 每天计分（打卡即得分，分数=用户选的星星数）
  weekly,   // 按周计分（周期内达标目标天数得奖励分）
  custom,   // 自定义周期计分（自定义天数周期内达标得奖励分）
}

extension ScoringModeExtension on ScoringMode {
  String get displayName {
    switch (this) {
      case ScoringMode.daily:
        return '每天计分';
      case ScoringMode.weekly:
        return '按周计分';
      case ScoringMode.custom:
        return '自定义周期';
    }
  }
}

/// HabitType 扩展方法
extension HabitTypeExtension on HabitType {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case HabitType.positive:
        return '加分项';
      case HabitType.negative:
        return '减分项';
    }
  }
  
  /// 获取图标
  IconData get icon {
    switch (this) {
      case HabitType.positive:
        return Icons.add_circle;
      case HabitType.negative:
        return Icons.remove_circle;
    }
  }
  
  /// 获取颜色
  Color getColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (this) {
      case HabitType.positive:
        return theme.colorScheme.primary;
      case HabitType.negative:
        return theme.colorScheme.error;
    }
  }
}

/// 习惯实体
class Habit extends Equatable {
  final String id;
  final String categoryId;
  final String category;
  final String name;
  final List<ContentBlock> content;
  final String icon;
  final int color;
  final HabitFrequency frequency;
  final List<int> reminderDays;
  final DateTime? reminderTime;
  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;
  final List<String> history;
  final List<CheckInRecord> checkInRecords;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int fullStars;
  final String notes;
  final HabitType type;
  
  // 计分周期相关字段
  final ScoringMode scoringMode;       // 计分模式
  final int targetDays;                // 周期内目标打卡天数
  final int customCycleDays;           // 自定义周期天数（仅当 scoringMode == custom 时有效）
  final int cycleRewardPoints;         // 周期达标奖励积分（默认等于 fullStars）
  final DateTime? lastCycleRewardTime; // 上次获得周期奖励的时间（用于判断是否已发奖）

  const Habit({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.name,
    this.content = const [],
    required this.icon,
    required this.color,
    this.frequency = HabitFrequency.daily,
    this.reminderDays = const [],
    this.reminderTime,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompletions = 0,
    this.history = const [],
    this.checkInRecords = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.fullStars = 5,
    this.notes = '',
    this.type = HabitType.positive,
    this.scoringMode = ScoringMode.daily,
    this.targetDays = 1,
    this.customCycleDays = 7,
    this.cycleRewardPoints = 0, // 0 表示默认使用 fullStars
    this.lastCycleRewardTime,
  });

  Habit copyWith({
    String? id,
    String? categoryId,
    String? category,
    String? name,
    List<ContentBlock>? content,
    String? icon,
    int? color,
    HabitFrequency? frequency,
    List<int>? reminderDays,
    DateTime? reminderTime,
    int? currentStreak,
    int? bestStreak,
    int? totalCompletions,
    List<String>? history,
    List<CheckInRecord>? checkInRecords,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? fullStars,
    String? notes,
    HabitType? type,
    ScoringMode? scoringMode,
    int? targetDays,
    int? customCycleDays,
    int? cycleRewardPoints,
    DateTime? lastCycleRewardTime,
  }) {
    return Habit(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      name: name ?? this.name,
      content: content ?? this.content,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      frequency: frequency ?? this.frequency,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderTime: reminderTime ?? this.reminderTime,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      history: history ?? this.history,
      checkInRecords: checkInRecords ?? this.checkInRecords,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fullStars: fullStars ?? this.fullStars,
      notes: notes ?? this.notes,
      type: type ?? this.type,
      scoringMode: scoringMode ?? this.scoringMode,
      targetDays: targetDays ?? this.targetDays,
      customCycleDays: customCycleDays ?? this.customCycleDays,
      cycleRewardPoints: cycleRewardPoints ?? this.cycleRewardPoints,
      lastCycleRewardTime: lastCycleRewardTime ?? this.lastCycleRewardTime,
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        category,
        name,
        content,
        icon,
        color,
        frequency,
        currentStreak,
        bestStreak,
        totalCompletions,
        history,
        createdAt,
        updatedAt,
        fullStars,
        notes,
        type,
        scoringMode,
        targetDays,
        customCycleDays,
        cycleRewardPoints,
        lastCycleRewardTime,
      ];

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'category': category,
      'name': name,
      'content': content.map((block) => block.toJson()).toList(),
      'icon': icon,
      'color': color,
      'frequency': frequency.toString().split('.').last,
      'reminderDays': reminderDays,
      'reminderTime': reminderTime?.toIso8601String(),
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalCompletions': totalCompletions,
      'history': history,
      'checkInRecords':
          checkInRecords.map((record) => record.toJson()).toList(),
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'fullStars': fullStars,
      'notes': notes,
      'type': type.toString().split('.').last,
      'scoringMode': scoringMode.toString().split('.').last,
      'targetDays': targetDays,
      'customCycleDays': customCycleDays,
      'cycleRewardPoints': cycleRewardPoints,
      'lastCycleRewardTime': lastCycleRewardTime?.toIso8601String(),
    };
  }

  /// 解析习惯类型（向后兼容）
  static HabitType _parseHabitType(dynamic value) {
    if (value == null) return HabitType.positive;
    try {
      return HabitType.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => HabitType.positive,
      );
    } catch (e) {
      return HabitType.positive;
    }
  }

  /// 解析计分模式（向后兼容）
  static ScoringMode _parseScoringMode(dynamic value) {
    if (value == null) return ScoringMode.daily;
    try {
      return ScoringMode.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => ScoringMode.daily,
      );
    } catch (e) {
      return ScoringMode.daily;
    }
  }

  /// 从JSON创建Habit
  factory Habit.fromJson(Map<String, dynamic> json) {
    // 向后兼容：如果是旧数据，没有 scoringMode，则默认 daily
    final scoringMode = _parseScoringMode(json['scoringMode']);
    final targetDays = json['targetDays'] ?? 1;
    final customCycleDays = json['customCycleDays'] ?? 7;
    // 如果 cycleRewardPoints 为 0 或不存在，默认等于 fullStars
    final int fullStarsVal = json['fullStars'] ?? 5;
    final int cycleRewardPoints = (json['cycleRewardPoints'] ?? 0) == 0 
        ? fullStarsVal 
        : json['cycleRewardPoints'];

    return Habit(
      id: json['id'],
      categoryId: json['categoryId'],
      category: json['category'],
      name: json['name'],
      content: (json['content'] as List<dynamic>)
          .map((blockJson) =>
              ContentBlock.fromJson(blockJson as Map<String, dynamic>))
          .toList(),
      icon: json['icon'],
      color: json['color'],
      frequency: HabitFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['frequency'],
        orElse: () => HabitFrequency.daily,
      ),
      reminderDays: List<int>.from(json['reminderDays'] ?? []),
      reminderTime: json['reminderTime'] != null
          ? DateTime.parse(json['reminderTime'])
          : null,
      currentStreak: json['currentStreak'],
      bestStreak: json['bestStreak'],
      totalCompletions: json['totalCompletions'],
      history: List<String>.from(json['history'] ?? []),
      checkInRecords: (json['checkInRecords'] as List<dynamic>)
          .map((recordJson) =>
              CheckInRecord.fromJson(recordJson as Map<String, dynamic>))
          .toList(),
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      fullStars: fullStarsVal,
      notes: json['notes'] ?? '',
      type: _parseHabitType(json['type']),
      scoringMode: scoringMode,
      targetDays: targetDays,
      customCycleDays: customCycleDays,
      cycleRewardPoints: cycleRewardPoints,
      lastCycleRewardTime: json['lastCycleRewardTime'] != null
          ? DateTime.parse(json['lastCycleRewardTime'])
          : null,
    );
  }
}
