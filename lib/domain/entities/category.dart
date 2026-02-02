import 'package:equatable/equatable.dart';

/// 分类类型枚举
enum CategoryType {
  todo,
  habit,
  journal,
}

/// 分类实体
class Category extends Equatable {
  final String id;
  final String name;
  final CategoryType type;
  final String icon;
  final int color;
  final bool isExpanded;

  /// 日记分类特有字段：是否为题库模式
  final bool isQuestionBank;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.isExpanded = false,
    this.isQuestionBank = false,
  });

  Category copyWith({
    String? id,
    String? name,
    CategoryType? type,
    String? icon,
    int? color,
    bool? isExpanded,
    bool? isQuestionBank,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isExpanded: isExpanded ?? this.isExpanded,
      isQuestionBank: isQuestionBank ?? this.isQuestionBank,
    );
  }

  @override
  List<Object> get props => [
        id,
        name,
        type,
        icon,
        color,
        isExpanded,
        isQuestionBank,
      ];

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'icon': icon,
      'color': color,
      'isExpanded': isExpanded,
      'isQuestionBank': isQuestionBank,
    };
  }

  /// 从JSON创建Category
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      type: CategoryType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => CategoryType.todo,
      ),
      icon: json['icon'],
      color: json['color'],
      isExpanded: json['isExpanded'] ?? false,
      isQuestionBank: json['isQuestionBank'] ?? false,
    );
  }
}
