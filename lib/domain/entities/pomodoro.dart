import 'package:equatable/equatable.dart';

/// 番茄钟实体类
class Pomodoro extends Equatable {
  /// 唯一标识符
  final String id;

  /// 持续时间（秒）
  final int duration;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  final DateTime? endTime;

  /// 标签
  final String tag;

  /// 构造函数
  const Pomodoro({
    required this.id,
    required this.duration,
    required this.startTime,
    this.endTime,
    required this.tag,
  });

  /// 复制方法，用于更新番茄钟
  Pomodoro copyWith({
    String? id,
    int? duration,
    DateTime? startTime,
    DateTime? endTime,
    String? tag,
  }) {
    return Pomodoro(
      id: id ?? this.id,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tag: tag ?? this.tag,
    );
  }

  /// 将Pomodoro转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'duration': duration,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'tag': tag,
    };
  }

  /// 从JSON创建Pomodoro
  factory Pomodoro.fromJson(Map<String, dynamic> json) {
    return Pomodoro(
      id: json['id'],
      duration: json['duration'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      tag: json['tag'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        duration,
        startTime,
        endTime,
        tag,
      ];
}
