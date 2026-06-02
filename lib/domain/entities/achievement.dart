import 'package:equatable/equatable.dart';

/// 成就类型枚举
enum AchievementType {
  habit,
  plan,
  pomodoro,
  todo,
  diary,
}

/// 成就实体类
class Achievement extends Equatable {
  /// 唯一标识符
  final String id;

  /// 名称
  final String name;

  /// 描述
  final String description;

  /// 类型
  final AchievementType type;

  /// 是否解锁
  final bool isUnlocked;

  /// 解锁时间
  final DateTime? unlockedAt;

  /// 所需进度
  final int requiredProgress;

  /// 当前进度
  final int currentProgress;

  /// 构造函数
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.isUnlocked,
    this.unlockedAt,
    required this.requiredProgress,
    required this.currentProgress,
  });

  /// 复制方法，用于更新成就
  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    AchievementType? type,
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? requiredProgress,
    int? currentProgress,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      requiredProgress: requiredProgress ?? this.requiredProgress,
      currentProgress: currentProgress ?? this.currentProgress,
    );
  }

  /// 将Achievement转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'requiredProgress': requiredProgress,
      'currentProgress': currentProgress,
    };
  }

  /// 从JSON创建Achievement
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: AchievementType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AchievementType.habit,
      ),
      isUnlocked: json['isUnlocked'],
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
      requiredProgress: json['requiredProgress'],
      currentProgress: json['currentProgress'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        type,
        isUnlocked,
        unlockedAt,
        requiredProgress,
        currentProgress,
      ];
}
