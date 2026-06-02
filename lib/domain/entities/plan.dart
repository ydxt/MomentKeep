import 'package:equatable/equatable.dart';

/// 计划实体类
class Plan extends Equatable {
  /// 唯一标识符
  final String id;

  /// 名称
  final String name;

  /// 描述
  final String description;

  /// 开始日期
  final DateTime startDate;

  /// 结束日期
  final DateTime endDate;

  /// 是否完成
  final bool isCompleted;

  /// 关联的习惯ID列表
  final List<String> habitIds;

  /// 构造函数
  const Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.isCompleted,
    required this.habitIds,
  });

  /// 复制方法，用于更新计划
  Plan copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCompleted,
    List<String>? habitIds,
  }) {
    return Plan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCompleted: isCompleted ?? this.isCompleted,
      habitIds: habitIds ?? this.habitIds,
    );
  }

  /// 将Plan转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isCompleted': isCompleted,
      'habitIds': habitIds,
    };
  }

  /// 从JSON创建Plan
  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isCompleted: json['isCompleted'],
      habitIds: List<String>.from(json['habitIds']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        startDate,
        endDate,
        isCompleted,
        habitIds,
      ];
}
