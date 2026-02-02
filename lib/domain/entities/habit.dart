import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';

/// 习惯频率枚举
enum HabitFrequency {
  daily,
  weekly,
  monthly,
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
    );
  }

  @override
  List<Object> get props => [
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
    };
  }

  /// 从JSON创建Habit
  factory Habit.fromJson(Map<String, dynamic> json) {
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
      fullStars: json['fullStars'],
      notes: json['notes'] ?? '',
    );
  }
}
