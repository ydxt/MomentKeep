import 'package:equatable/equatable.dart';

class KanbanColumnEntity extends Equatable {
  final String id;
  final String title;
  final String color;
  final int position;
  final String userId;

  const KanbanColumnEntity({
    required this.id,
    required this.title,
    required this.color,
    required this.position,
    required this.userId,
  });

  KanbanColumnEntity copyWith({
    String? id,
    String? title,
    String? color,
    int? position,
    String? userId,
  }) {
    return KanbanColumnEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      position: position ?? this.position,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'color': color,
        'position': position,
        'user_id': userId,
      };

  factory KanbanColumnEntity.fromJson(Map<String, dynamic> json) {
    return KanbanColumnEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      color: json['color'] as String,
      position: json['position'] as int,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, title, color, position, userId];
}
