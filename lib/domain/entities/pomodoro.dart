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
      'pomodoro_id': id,
      'duration_minutes': duration ~/ 60,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'tag': tag,
    };
  }

  /// 从JSON创建Pomodoro
  factory Pomodoro.fromJson(Map<String, dynamic> json) {
    final startTimeValue = json['start_time'] ?? json['startTime'];
    final endTimeValue = json['end_time'] ?? json['endTime'];
    final idValue = json['pomodoro_id'] ?? json['id'];
    final durationValue = json['duration_minutes'] ?? json['duration'];

    return Pomodoro(
      id: idValue.toString(),
      duration: durationValue is int
          ? (json.containsKey('duration_minutes') ? durationValue * 60 : durationValue)
          : 0,
      startTime: startTimeValue is int
          ? DateTime.fromMillisecondsSinceEpoch(startTimeValue)
          : DateTime.parse(startTimeValue.toString()),
      endTime: endTimeValue != null
          ? (endTimeValue is int
              ? DateTime.fromMillisecondsSinceEpoch(endTimeValue)
              : DateTime.parse(endTimeValue.toString()))
          : null,
      tag: json['tag']?.toString() ?? '',
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
