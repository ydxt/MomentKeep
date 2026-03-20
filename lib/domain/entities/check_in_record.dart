import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/diary.dart';

/// 打卡记录实体
class CheckInRecord extends Equatable {
  /// 记录ID
  final String id;

  /// 关联的习惯ID
  final String habitId;

  /// 评分 (1-5星)
  final int score;

  /// 备注内容（富文本块）
  final List<ContentBlock> comment;

  /// 打卡时间
  final DateTime timestamp;

  /// 是否为负向打卡（扣分）
  final bool isNegative;

  const CheckInRecord({
    required this.id,
    required this.habitId,
    required this.score,
    this.comment = const [],
    required this.timestamp,
    this.isNegative = false,
  });

  /// 复制并修改
  CheckInRecord copyWith({
    String? id,
    String? habitId,
    int? score,
    List<ContentBlock>? comment,
    DateTime? timestamp,
    bool? isNegative,
  }) {
    return CheckInRecord(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      score: score ?? this.score,
      comment: comment ?? this.comment,
      timestamp: timestamp ?? this.timestamp,
      isNegative: isNegative ?? this.isNegative,
    );
  }

  @override
  List<Object> get props => [
        id,
        habitId,
        score,
        comment,
        timestamp,
        isNegative,
      ];

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habitId,
      'score': score,
      'comment': comment.map((block) => block.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'isNegative': isNegative,
    };
  }

  /// 从JSON创建CheckInRecord
  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      id: json['id'],
      habitId: json['habitId'],
      score: json['score'],
      comment: (json['comment'] as List<dynamic>)
          .map((blockJson) =>
              ContentBlock.fromJson(blockJson as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(json['timestamp']),
      isNegative: json['isNegative'] ?? false,
    );
  }
}
