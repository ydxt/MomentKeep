import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/diary.dart';

/// 待办事项优先级枚举
enum TodoPriority {
  high,
  medium,
  low,
}

/// 重复任务类型枚举
enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
  custom,
}

/// 待办事项实体
class Todo extends Equatable {
  final String id;
  final String categoryId;
  final String title;
  final List<ContentBlock> content;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? startDate;
  final DateTime? date;
  final DateTime? reminderTime;
  final TodoPriority priority;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RepeatType repeatType;
  final int repeatInterval;
  final DateTime? repeatEndDate;
  final DateTime? lastRepeatDate;
  // 位置提醒相关字段
  final bool isLocationReminderEnabled;
  final double? latitude;
  final double? longitude;
  final double? radius;
  final String? locationName;

  const Todo({
    required this.id,
    required this.categoryId,
    required this.title,
    this.content = const [],
    this.isCompleted = false,
    this.completedAt,
    this.startDate,
    this.date,
    this.reminderTime,
    this.priority = TodoPriority.medium,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.repeatType = RepeatType.none,
    this.repeatInterval = 1,
    this.repeatEndDate,
    this.lastRepeatDate,
    this.isLocationReminderEnabled = false,
    this.latitude,
    this.longitude,
    this.radius = 100.0,
    this.locationName,
  });

  Todo copyWith({
    String? id,
    String? categoryId,
    String? title,
    List<ContentBlock>? content,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? startDate,
    DateTime? date,
    DateTime? reminderTime,
    TodoPriority? priority,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    RepeatType? repeatType,
    int? repeatInterval,
    DateTime? repeatEndDate,
    DateTime? lastRepeatDate,
    bool? isLocationReminderEnabled,
    double? latitude,
    double? longitude,
    double? radius,
    String? locationName,
  }) {
    return Todo(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      startDate: startDate ?? this.startDate,
      date: date ?? this.date,
      reminderTime: reminderTime ?? this.reminderTime,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      lastRepeatDate: lastRepeatDate ?? this.lastRepeatDate,
      isLocationReminderEnabled: isLocationReminderEnabled ?? this.isLocationReminderEnabled,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      locationName: locationName ?? this.locationName,
    );
  }

  @override
  List<Object> get props => [
        id,
        categoryId,
        title,
        content,
        isCompleted,
        priority,
        tags,
        createdAt,
        updatedAt,
        repeatType,
        repeatInterval,
        isLocationReminderEnabled,
      ];

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'title': title,
      'content': content.map((block) => block.toJson()).toList(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'date': date?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'priority': priority.toString().split('.').last,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'repeatType': repeatType.toString().split('.').last,
      'repeatInterval': repeatInterval,
      'repeatEndDate': repeatEndDate?.toIso8601String(),
      'lastRepeatDate': lastRepeatDate?.toIso8601String(),
      'isLocationReminderEnabled': isLocationReminderEnabled,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'locationName': locationName,
    };
  }

  /// 从JSON创建Todo
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      categoryId: json['categoryId'],
      title: json['title'],
      content: (json['content'] as List<dynamic>)
          .map((blockJson) =>
              ContentBlock.fromJson(blockJson as Map<String, dynamic>))
          .toList(),
      isCompleted: json['isCompleted'],
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      startDate:
          json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      reminderTime: json['reminderTime'] != null
          ? DateTime.parse(json['reminderTime'])
          : null,
      priority: TodoPriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'],
        orElse: () => TodoPriority.medium,
      ),
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      repeatType: json.containsKey('repeatType')
          ? RepeatType.values.firstWhere(
              (e) => e.toString().split('.').last == json['repeatType'],
              orElse: () => RepeatType.none,
            )
          : RepeatType.none,
      repeatInterval: json.containsKey('repeatInterval') ? json['repeatInterval'] : 1,
      repeatEndDate: json['repeatEndDate'] != null
          ? DateTime.parse(json['repeatEndDate'])
          : null,
      lastRepeatDate: json['lastRepeatDate'] != null
          ? DateTime.parse(json['lastRepeatDate'])
          : null,
      isLocationReminderEnabled: json.containsKey('isLocationReminderEnabled') ? json['isLocationReminderEnabled'] : false,
      latitude: json.containsKey('latitude') ? json['latitude'] : null,
      longitude: json.containsKey('longitude') ? json['longitude'] : null,
      radius: json.containsKey('radius') ? json['radius'] : 100.0,
      locationName: json.containsKey('locationName') ? json['locationName'] : null,
    );
  }
}
