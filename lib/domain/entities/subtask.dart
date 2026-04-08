import 'package:equatable/equatable.dart';

/// 子任务实体
class Subtask extends Equatable {
  /// 子任务唯一标识
  final String id;

  /// 所属待办的ID
  final String todoId;

  /// 子任务标题
  final String title;

  /// 是否已完成
  final bool isCompleted;

  /// 排序索引
  final int orderIndex;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  const Subtask({
    required this.id,
    required this.todoId,
    required this.title,
    this.isCompleted = false,
    this.orderIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 JSON 创建
  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: json['id'] as String,
      todoId: json['todo_id'] as String,
      title: json['title'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      orderIndex: json['order_index'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'todo_id': todoId,
      'title': title,
      'is_completed': isCompleted,
      'order_index': orderIndex,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 复制并修改
  Subtask copyWith({
    String? id,
    String? todoId,
    String? title,
    bool? isCompleted,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subtask(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        todoId,
        title,
        isCompleted,
        orderIndex,
        createdAt,
        updatedAt,
      ];
}
