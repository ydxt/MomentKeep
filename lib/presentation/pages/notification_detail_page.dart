import 'package:flutter/material.dart';
import 'dart:io';
import 'package:moment_keep/services/notification_service.dart';

/// 通知详情页面
class NotificationDetailPage extends StatefulWidget {
  /// 构造函数
  const NotificationDetailPage({super.key});

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  /// 通知列表
  List<NotificationInfo> _notifications = [];
  
  /// 是否正在加载通知
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  /// 加载通知数据
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationService = NotificationDatabaseService();
      _notifications = await notificationService.getAllNotifications();
    } catch (e) {
      debugPrint('加载通知失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载通知失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 标记通知为已读
  Future<void> _markAsRead(NotificationInfo notification) async {
    try {
      final notificationService = NotificationDatabaseService();
      await notificationService.markAsRead(notification.id);
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notification.id) {
            return NotificationInfo(
              id: n.id,
              orderId: n.orderId,
              productName: n.productName,
              productImage: n.productImage,
              type: n.type,
              status: NotificationStatus.read,
              content: n.content,
              createdAt: n.createdAt,
              processedAt: n.processedAt,
            );
          }
          return n;
        }).toList();
      });
    } catch (e) {
      debugPrint('标记通知为已读失败: $e');
    }
  }

  /// 标记通知为已处理
  Future<void> _markAsProcessed(NotificationInfo notification) async {
    try {
      final notificationService = NotificationDatabaseService();
      await notificationService.markAsProcessed(notification.id);
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notification.id) {
            return NotificationInfo(
              id: n.id,
              orderId: n.orderId,
              productName: n.productName,
              productImage: n.productImage,
              type: n.type,
              status: NotificationStatus.processed,
              content: n.content,
              createdAt: n.createdAt,
              processedAt: DateTime.now(),
            );
          }
          return n;
        }).toList();
      });
    } catch (e) {
      debugPrint('标记通知为已处理失败: $e');
    }
  }

  /// 获取通知类型的图标
  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.reminderShip:
        return Icons.local_shipping;
      case NotificationType.modifyAddress:
        return Icons.location_on;
      case NotificationType.applyCancel:
        return Icons.cancel;
      case NotificationType.applyAfterSales:
        return Icons.help_outline;
      case NotificationType.review:
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  /// 获取通知类型的颜色
  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.reminderShip:
        return const Color(0xFF13ec5b);
      case NotificationType.modifyAddress:
        return Colors.blue;
      case NotificationType.applyCancel:
        return Colors.red;
      case NotificationType.applyAfterSales:
        return Colors.orange;
      case NotificationType.review:
        return const Color(0xFFffc107);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102216),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '通知中心',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13ec5b)))
          : _notifications.isEmpty
              ? const Center(
                  child: Text(
                    '暂无通知',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF13ec5b),
                  backgroundColor: const Color(0xFF16291d),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16291d),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: notification.status == NotificationStatus.unread
                                ? const Color(0xFF13ec5b)
                                : const Color(0xFF1a3525),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 通知头部
                            Row(
                              children: [
                                // 通知类型图标
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getNotificationColor(notification.type)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(notification.type),
                                    color: _getNotificationColor(notification.type),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 通知类型和状态
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification.typeText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification.createdAt
                                            .toString()
                                            .substring(0, 16),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 未读标记
                                if (notification.status == NotificationStatus.unread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 商品信息
                            if (notification.productName != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF102216),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    // 商品图片
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color(0xFF1a3525),
                                      ),
                                      child: notification.productImage != null &&
                                              notification.productImage!.isNotEmpty
                                          ? Image.file(
                                              File(notification.productImage!),
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.image_not_supported_outlined,
                                              color: Colors.grey,
                                              size: 24,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 商品名称和订单号
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notification.productName!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '订单号: ${notification.orderId}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            // 通知内容
                            Text(
                              notification.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 操作按钮
                            if (notification.status != NotificationStatus.processed)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 标记为已读按钮
                                  if (notification.status == NotificationStatus.unread)
                                    TextButton(
                                      onPressed: () => _markAsRead(notification),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF13ec5b),
                                      ),
                                      child: const Text('标记为已读'),
                                    ),
                                  // 标记为已处理按钮
                                  ElevatedButton(
                                    onPressed: () => _markAsProcessed(notification),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF13ec5b),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('标记为已处理'),
                                  ),
                                ],
                              ),
                            // 已处理标记
                            if (notification.status == NotificationStatus.processed)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '已处理',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
