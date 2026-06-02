import 'package:equatable/equatable.dart';

/// 回收箱实体
class RecycleBinItem extends Equatable {
  final String id;
  final String type; // 类型：todo, habit, category等
  final String name;
  final Map<String, dynamic> data;
  final DateTime deletedAt;

  const RecycleBinItem({
    required this.id,
    required this.type,
    required this.name,
    required this.data,
    required this.deletedAt,
  });

  @override
  List<Object> get props => [id, type, name, data, deletedAt];

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'data': data,
      'deletedAt': deletedAt.toIso8601String(),
    };
  }

  /// 从JSON创建RecycleBinItem
  factory RecycleBinItem.fromJson(Map<String, dynamic> json) {
    return RecycleBinItem(
      id: json['id'],
      type: json['type'],
      name: json['name'],
      data: json['data'] as Map<String, dynamic>,
      deletedAt: DateTime.parse(json['deletedAt']),
    );
  }
}
