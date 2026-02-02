import 'package:equatable/equatable.dart';

/// 客户端消息类型枚举
enum ClientMessageType {
  all,
  notification,
  order,
  promotion,
  interaction,
}

/// 商家端消息类型枚举
enum MerchantMessageType {
  all,
  order,
  refundAfterSales,
  productAudit,
  system,
}

/// 消息优先级枚举
enum MessagePriority {
  high,
  medium,
  low,
}

/// 消息实体类
class Message extends Equatable {
  /// 唯一标识符
  final String id;
  
  /// 消息标题
  final String title;
  
  /// 消息内容
  final String content;
  
  /// 客户端消息类型
  final ClientMessageType? clientType;
  
  /// 商家端消息类型
  final MerchantMessageType? merchantType;
  
  /// 优先级
  final MessagePriority priority;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 是否已读
  final bool isRead;
  
  /// 相关订单号
  final String? orderId;
  
  /// 相关商品图片URL
  final String? productImageUrl;
  
  /// 操作按钮文本
  final String? actionText;
  
  /// 操作按钮类型
  final String? actionType;
  
  /// 构造函数
  const Message({
    required this.id,
    required this.title,
    required this.content,
    this.clientType,
    this.merchantType,
    required this.priority,
    required this.createdAt,
    required this.isRead,
    this.orderId,
    this.productImageUrl,
    this.actionText,
    this.actionType,
  });
  
  /// 复制方法，用于更新消息
  Message copyWith({
    String? id,
    String? title,
    String? content,
    ClientMessageType? clientType,
    MerchantMessageType? merchantType,
    MessagePriority? priority,
    DateTime? createdAt,
    bool? isRead,
    String? orderId,
    String? productImageUrl,
    String? actionText,
    String? actionType,
  }) {
    return Message(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      clientType: clientType ?? this.clientType,
      merchantType: merchantType ?? this.merchantType,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      orderId: orderId ?? this.orderId,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      actionText: actionText ?? this.actionText,
      actionType: actionType ?? this.actionType,
    );
  }
  
  /// 将Message转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'clientType': clientType?.toString().split('.').last,
      'merchantType': merchantType?.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'orderId': orderId,
      'productImageUrl': productImageUrl,
      'actionText': actionText,
      'actionType': actionType,
    };
  }
  
  /// 从JSON创建Message
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      clientType: json['clientType'] != null
          ? ClientMessageType.values.firstWhere(
              (e) => e.toString().split('.').last == json['clientType'],
              orElse: () => ClientMessageType.all,
            )
          : null,
      merchantType: json['merchantType'] != null
          ? MerchantMessageType.values.firstWhere(
              (e) => e.toString().split('.').last == json['merchantType'],
              orElse: () => MerchantMessageType.all,
            )
          : null,
      priority: MessagePriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'],
        orElse: () => MessagePriority.medium,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'],
      orderId: json['orderId'],
      productImageUrl: json['productImageUrl'],
      actionText: json['actionText'],
      actionType: json['actionType'],
    );
  }
  
  @override
  List<Object?> get props => [
        id,
        title,
        content,
        clientType,
        merchantType,
        priority,
        createdAt,
        isRead,
        orderId,
        productImageUrl,
        actionText,
        actionType,
      ];
}
