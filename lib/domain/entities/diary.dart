import 'dart:math';
import 'package:equatable/equatable.dart';

/// 内容块类型枚举
enum ContentBlockType {
  text,
  image,
  audio,
  drawing,
  video,
}

/// 内容块实体
class ContentBlock extends Equatable {
  final String id;
  final ContentBlockType type;
  final String data;
  final int orderIndex;
  final Map<String, dynamic> attributes;

  const ContentBlock({
    required this.id,
    required this.type,
    required this.data,
    required this.orderIndex,
    this.attributes = const {},
  });

  ContentBlock copyWith({
    String? id,
    ContentBlockType? type,
    String? data,
    int? orderIndex,
    Map<String, dynamic>? attributes,
  }) {
    return ContentBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      orderIndex: orderIndex ?? this.orderIndex,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  List<Object> get props => [
        id,
        type,
        data,
        orderIndex,
        attributes,
      ];

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'data': data,
      'orderIndex': orderIndex,
      'attributes': attributes,
    };
  }

  /// 从JSON创建ContentBlock
  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      id: json['id'] ?? '',
      type: () {
        try {
          final typeStr = json['type'] as String? ?? '';
          // 类型映射，处理可能的类型名称差异
          final typeMap = {
            'voice': ContentBlockType.audio,
            'sound': ContentBlockType.audio,
            'img': ContentBlockType.image,
            'picture': ContentBlockType.image,
            'vid': ContentBlockType.video,
            'movie': ContentBlockType.video,
            'draw': ContentBlockType.drawing,
            'sketch': ContentBlockType.drawing,
          };
          
          // 首先检查类型映射
          if (typeMap.containsKey(typeStr.toLowerCase())) {
            return typeMap[typeStr.toLowerCase()]!;
          }
          
          // 然后尝试直接匹配枚举
          return ContentBlockType.values.firstWhere(
            (e) => e.toString().split('.').last == typeStr,
            orElse: () => ContentBlockType.text,
          );
        } catch (e) {
          return ContentBlockType.text;
        }
      }(),
      data: json['data'] ?? '',
      orderIndex: json['orderIndex'] as int? ?? 0,
      attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
    );
  }
}

/// 智能日记实体
class Journal extends Equatable {
  final String id;
  final String categoryId;
  final String title;
  final List<ContentBlock> content;
  final List<String> tags;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 题库特有字段
  final String? subject;
  final String? remarks;

  const Journal({
    required this.id,
    required this.categoryId,
    required this.title,
    this.content = const [],
    this.tags = const [],
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.subject,
    this.remarks,
  });

  Journal copyWith({
    String? id,
    String? categoryId,
    String? title,
    List<ContentBlock>? content,
    List<String>? tags,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subject,
    String? remarks,
  }) {
    return Journal(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subject: subject ?? this.subject,
      remarks: remarks ?? this.remarks,
    );
  }

  @override
  List<Object> get props => [
        id,
        categoryId,
        title,
        content,
        tags,
        date,
        createdAt,
        updatedAt,
      ];

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'title': title,
      'content': content.map((block) => block.toJson()).toList(),
      'tags': tags,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'subject': subject,
      'remarks': remarks,
    };
  }

  /// 从JSON创建Journal
  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      id: json['id'] ?? '',
      categoryId: json['categoryId'] ?? '',
      title: json['title'] ?? '',
      content: (json['content'] as List<dynamic>? ?? [])
          .map((blockJson) {
            if (blockJson is Map<String, dynamic>) {
              final contentBlock = ContentBlock.fromJson(blockJson);
              // 如果id为空，生成一个唯一id
              return contentBlock.id.isNotEmpty 
                  ? contentBlock 
                  : contentBlock.copyWith(
                      id: 'block_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
                    );
            }
            // 忽略无效的内容块
            return ContentBlock(
              id: 'block_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
              type: ContentBlockType.text,
              data: '',
              orderIndex: 0,
            );
          })
          .toList(),
      tags: List<String>.from(json['tags'] ?? []),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      subject: json['subject'],
      remarks: json['remarks'],
    );
  }
}
