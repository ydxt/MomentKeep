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

  /// 打卡时间（目标日期）
  final DateTime timestamp;

  /// 实际打卡时间（补卡时记录何时操作的，当日打卡为null）
  final DateTime? checkedInAt;

  /// 是否为负向打卡（扣分）
  final bool isNegative;

  const CheckInRecord({
    required this.id,
    required this.habitId,
    required this.score,
    this.comment = const [],
    required this.timestamp,
    this.checkedInAt,
    this.isNegative = false,
  });

  /// 复制并修改
  CheckInRecord copyWith({
    String? id,
    String? habitId,
    int? score,
    List<ContentBlock>? comment,
    DateTime? timestamp,
    DateTime? checkedInAt,
    bool? isNegative,
  }) {
    return CheckInRecord(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      score: score ?? this.score,
      comment: comment ?? this.comment,
      timestamp: timestamp ?? this.timestamp,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      isNegative: isNegative ?? this.isNegative,
    );
  }

  @override
  List<Object?> get props => [
        id,
        habitId,
        score,
        comment,
        timestamp,
        checkedInAt,
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
      'checkedInAt': checkedInAt?.toIso8601String(),
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
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.parse(json['checkedInAt'])
          : null,
      isNegative: json['isNegative'] ?? false,
    );
  }
}
