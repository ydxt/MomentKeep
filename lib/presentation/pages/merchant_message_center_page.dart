import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/message.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/presentation/pages/merchant_order_management_page.dart';
import 'package:moment_keep/presentation/pages/merchant_order_detail_page.dart';

/// 商家消息标签枚举
enum MerchantMessageTab {
  all,
  order,
  refundAfterSales,
  productAudit,
  system,
}

/// 获取商家端消息图标
IconData getMerchantMessageIcon(MerchantMessageType type) {
  switch (type) {
    case MerchantMessageType.order:
      return Icons.inventory_2;
    case MerchantMessageType.refundAfterSales:
      return Icons.warning;
    case MerchantMessageType.productAudit:
      return Icons.rate_review;
    case MerchantMessageType.system:
      return Icons.dns;
    default:
      return Icons.info;
  }
}

/// 获取商家端消息图标颜色
Color getMerchantMessageIconColor(MerchantMessageType type) {
  switch (type) {
    case MerchantMessageType.order:
      return const Color(0xFF13ec5b);
    case MerchantMessageType.refundAfterSales:
      return const Color(0xFFEF5350);
    case MerchantMessageType.productAudit:
      return const Color(0xFFFF9800);
    case MerchantMessageType.system:
      return const Color(0xFF2196F3);
    default:
      return const Color(0xFF607D8B);
  }
}

/// 获取时间显示文本
String getTimeText(DateTime createdAt) {
  final now = DateTime.now();
  final difference = now.difference(createdAt);

  if (difference.inMinutes < 1) {
    return '刚刚';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}分钟前';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}小时前';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}天前';
  } else {
    return '${createdAt.month}月${createdAt.day}日';
  }
}

/// 商家端消息中心页面
class MerchantMessageCenterPage extends StatefulWidget {
  /// 构造函数
  const MerchantMessageCenterPage({super.key});

  @override
  State<MerchantMessageCenterPage> createState() =>
      _MerchantMessageCenterPageState();
}

class _MerchantMessageCenterPageState extends State<MerchantMessageCenterPage> {
  /// 当前选中的标签
  MerchantMessageTab _currentTab = MerchantMessageTab.all;

  /// 通知服务实例
  final NotificationDatabaseService _notificationService =
      NotificationDatabaseService();

  /// 消息列表
  List<Message> _messages = [];

  /// 加载状态
  bool _isLoading = true;

  /// 搜索相关状态
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// 分页相关状态
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  /// 批量操作相关状态
  bool _isBatchMode = false;
  List<String> _selectedMessageIds = [];
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 加载消息数据
  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _messages = [];
      _hasMore = true;
    });

    try {
      // 从通知服务获取第一页通知
      final notifications =
          await _notificationService.getNotificationsByPage(1, _pageSize);

      // 将通知转换为商家消息模型
      final messages = notifications.map((notification) {
        // 根据通知类型转换为商家消息类型
        MerchantMessageType merchantType;
        MessagePriority priority;
        String actionText;
        String actionType;

        switch (notification.type) {
          case NotificationType.reminderShip:
            merchantType = MerchantMessageType.order;
            priority = MessagePriority.medium;
            actionText = '立即发货';
            actionType = 'ship';
            break;
          case NotificationType.modifyAddress:
            merchantType = MerchantMessageType.order;
            priority = MessagePriority.high;
            actionText = '查看详情';
            actionType = 'address';
            break;
          case NotificationType.applyCancel:
            merchantType = MerchantMessageType.refundAfterSales;
            priority = MessagePriority.high;
            actionText = '立即处理';
            actionType = 'cancel';
            break;
          case NotificationType.applyAfterSales:
            merchantType = MerchantMessageType.refundAfterSales;
            priority = MessagePriority.high;
            actionText = '立即处理';
            actionType = 'aftersales';
            break;
          case NotificationType.review:
            merchantType = MerchantMessageType.order;
            priority = MessagePriority.medium;
            actionText = '查看评价';
            actionType = 'review';
            break;
          case NotificationType.system:
            merchantType = MerchantMessageType.system;
            priority = MessagePriority.low;
            actionText = '了解更多';
            actionType = 'system';
            break;
        }

        return Message(
          id: notification.id,
          title: notification.productName ?? '订单通知',
          content: notification.content,
          merchantType: merchantType,
          priority: priority,
          createdAt: notification.createdAt,
          isRead: notification.status != NotificationStatus.unread,
          orderId: notification.orderId,
          productImageUrl: notification.productImage,
          actionText: actionText,
          actionType: actionType,
        );
      }).toList();

      // 添加一些模拟的系统和审核消息
      messages.addAll([
        Message(
          id: 'system_1',
          title: '系统升级通知',
          content: '平台将于 2024-06-20 02:00-04:00 进行服务器升级维护，届时商家后台将暂停服务。',
          merchantType: MerchantMessageType.system,
          priority: MessagePriority.low,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
          actionText: '了解更多',
          actionType: 'system',
        ),
        Message(
          id: 'audit_1',
          title: '审核未通过: 夏季透气...',
          content: '您的商品图片清晰度不足，未能通过平台审核，请修改后重新提交。',
          merchantType: MerchantMessageType.productAudit,
          priority: MessagePriority.medium,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
          actionText: '查看详情',
          actionType: 'audit',
          productImageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuB74pJnU5_gKMbuiiHFu49Vj1qA43blp88ds347DQVs_E22u3QrGzjnYesVeAfr75eipMF_B_nDOkJfgCQUhRpCBLchOcULojirYHSfdzHK1zL2F6jyLVlSuU4mF4SQg9OJQTDoJXpBapL44zixE-GK53T6i9uk0s0_9VA89jgN_8-jzr1oD9ixWw5lp7_1lZYbgRIGECF4pb4W7mm3FEwMEqNud5i67qhjSTplC7v0raFvcouECM69j8FGOvEdfOJiSDBZOFuxWVMw',
        ),
      ]);

      setState(() {
        _messages = messages;
        _hasMore = notifications.length == _pageSize;
      });
    } catch (e) {
      print('加载消息失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 监听滚动事件，实现上拉加载更多
  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;

    final scrollPosition = _scrollController.position;
    final maxScrollExtent = scrollPosition.maxScrollExtent;
    final currentScrollExtent = scrollPosition.pixels;

    // 当滚动到距离底部100像素时加载更多
    if (currentScrollExtent >= maxScrollExtent - 100) {
      _loadMoreMessages();
    }
  }

  /// 加载更多消息
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      // 从通知服务获取下一页通知
      final notifications = await _notificationService.getNotificationsByPage(
          _currentPage, _pageSize);

      // 将通知转换为商家消息模型
      final newMessages = notifications.map((notification) {
        // 根据通知类型转换为商家消息类型
        MerchantMessageType merchantType;
        MessagePriority priority;
        String actionText;
        String actionType;

        switch (notification.type) {
          case NotificationType.reminderShip:
            merchantType = MerchantMessageType.order;
            priority = MessagePriority.medium;
            actionText = '立即发货';
            actionType = 'ship';
            break;
          case NotificationType.modifyAddress:
            merchantType = MerchantMessageType.order;
            priority = MessagePriority.high;
            actionText = '查看详情';
            actionType = 'address';
            break;
          case NotificationType.applyCancel:
            merchantType = MerchantMessageType.refundAfterSales;
            priority = MessagePriority.high;
            actionText = '立即处理';
            actionType = 'cancel';
            break;
          case NotificationType.applyAfterSales:
            merchantType = MerchantMessageType.refundAfterSales;
            priority = MessagePriority.high;
            actionText = '立即处理';
            actionType = 'aftersales';
            break;
          case NotificationType.review:
            merchantType = MerchantMessageType.order;
            priority = MessagePriority.medium;
            actionText = '查看评价';
            actionType = 'review';
            break;
          case NotificationType.system:
            merchantType = MerchantMessageType.system;
            priority = MessagePriority.low;
            actionText = '了解更多';
            actionType = 'system';
            break;
        }

        return Message(
          id: notification.id,
          title: notification.productName ?? '订单通知',
          content: notification.content,
          merchantType: merchantType,
          priority: priority,
          createdAt: notification.createdAt,
          isRead: notification.status != NotificationStatus.unread,
          orderId: notification.orderId,
          productImageUrl: notification.productImage,
          actionText: actionText,
          actionType: actionType,
        );
      }).toList();

      setState(() {
        _messages.addAll(newMessages);
        _hasMore = newMessages.length == _pageSize;
      });
    } catch (e) {
      print('加载更多消息失败: $e');
      // 加载失败时恢复页码
      _currentPage--;
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// 下拉刷新消息
  Future<void> _refreshMessages() async {
    // 重置分页状态
    _currentPage = 1;
    _hasMore = true;
    // 重新加载消息
    await _loadMessages();
  }

  /// 获取当前标签下的消息
  List<Message> get _filteredMessages {
    // 先根据标签过滤
    List<Message> filteredByTab;
    switch (_currentTab) {
      case MerchantMessageTab.all:
        filteredByTab = _messages;
        break;
      case MerchantMessageTab.order:
        filteredByTab = _messages
            .where((msg) => msg.merchantType == MerchantMessageType.order)
            .toList();
        break;
      case MerchantMessageTab.refundAfterSales:
        filteredByTab = _messages
            .where((msg) =>
                msg.merchantType == MerchantMessageType.refundAfterSales)
            .toList();
        break;
      case MerchantMessageTab.productAudit:
        filteredByTab = _messages
            .where(
                (msg) => msg.merchantType == MerchantMessageType.productAudit)
            .toList();
        break;
      case MerchantMessageTab.system:
        filteredByTab = _messages
            .where((msg) => msg.merchantType == MerchantMessageType.system)
            .toList();
        break;
      default:
        filteredByTab = _messages;
    }

    // 如果有搜索查询，再根据搜索查询过滤
    if (_searchQuery.isNotEmpty) {
      final lowerCaseQuery = _searchQuery.toLowerCase();
      return filteredByTab.where((msg) {
        return msg.title.toLowerCase().contains(lowerCaseQuery) ||
            msg.content.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    }

    return filteredByTab;
  }

  /// 标记所有消息为已读
  Future<void> _markAllAsRead() async {
    try {
      // 标记所有通知为已读
      await _notificationService.markAllAsRead();

      // 更新本地状态
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          _messages[i] = _messages[i].copyWith(isRead: true);
        }
      });
    } catch (e) {
      print('标记所有消息为已读失败: $e');
    }
  }

  /// 标记单条消息为已读
  Future<void> _markAsRead(Message message) async {
    try {
      // 如果是订单相关消息，标记对应的通知为已读
      if (message.id.startsWith('notification_')) {
        await _notificationService.markAsRead(message.id);
      }

      // 更新本地状态
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(isRead: true);
        }
      });
    } catch (e) {
      print('标记消息为已读失败: $e');
    }
  }

  /// 删除消息
  Future<void> _deleteMessage(Message message, BuildContext context) async {
    try {
      // 显示确认对话框
      final bool? confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF152e1e),
            title: const Text(
              '确认删除',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              '您确定要删除这条消息吗？',
              style: TextStyle(color: Color(0xFF92c9a4)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  '取消',
                  style: TextStyle(color: Color(0xFF92c9a4)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '删除',
                  style: TextStyle(color: Color(0xFFEF5350)),
                ),
              ),
            ],
          );
        },
      );

      if (confirmDelete == true) {
        // 如果是订单相关消息，从数据库中删除
        if (message.id.startsWith('notification_')) {
          await _notificationService.deleteNotification(message.id);
        }

        // 更新本地状态
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      }
    } catch (e) {
      print('删除消息失败: $e');
    }
  }

  /// 处理消息操作
  Future<void> _handleAction(Message message) async {
    await _markAsRead(message);
    // 根据actionType处理不同的操作
    if (message.orderId != null) {
      // 对于订单相关消息，直接跳转到订单详情页
      // 首先获取订单详情
      final databaseService = DatabaseService();
      final orderMaps = await databaseService.getAllOrders();
      final orderMap = orderMaps.firstWhere(
          (order) => order['id'] == message.orderId,
          orElse: () => {});

      if (orderMap.isNotEmpty) {
        // 将订单数据转换为MerchantOrder对象
        MerchantOrderStatus status = MerchantOrderStatus.all;
        switch (orderMap['status']) {
          case '待付款':
            status = MerchantOrderStatus.pendingPayment;
            break;
          case '待接单':
            status = MerchantOrderStatus.pendingAccept;
            break;
          case '待发货':
            status = MerchantOrderStatus.pendingShip;
            break;
          case '已发货':
            status = MerchantOrderStatus.shipped;
            break;
          case '退款中':
            status = MerchantOrderStatus.refunding;
            break;
          case '已完成':
            status = MerchantOrderStatus.completed;
            break;
          case '已取消':
            status = MerchantOrderStatus.cancelled;
            break;
          case '已退款':
            status = MerchantOrderStatus.refunded;
            break;
          case '已拒单':
            status = MerchantOrderStatus.rejected;
            break;
          default:
            status = MerchantOrderStatus.all;
        }

        // 解析支付方式
        String paymentMethod = orderMap['payment_method'] as String? ?? '';
        String paymentMethodText;
        switch (paymentMethod) {
          case 'points':
            paymentMethodText = '积分支付';
            break;
          case 'hybrid':
            paymentMethodText = '混合支付';
            break;
          case 'cash':
          default:
            paymentMethodText = '现金支付';
            break;
        }

        final merchantOrder = MerchantOrder(
          id: orderMap['id'] as String,
          productName: orderMap['product_name'] as String? ?? '',
          productImage: orderMap['product_image'] as String? ?? '',
          productVariant: orderMap['variant'] as String? ?? '',
          quantity: orderMap['quantity'] as int? ?? 1,
          points: orderMap['points'] as int? ?? 0,
          originalAmount: 0.0,
          actualAmount: 0.0,
          buyerName: '匿名用户',
          buyerPhone: '',
          deliveryAddress: '',
          buyerNote: '',
          paymentMethod: paymentMethodText,
          deliveryMethod: '',
          isAbnormal: false,
          orderTime: DateTime.fromMillisecondsSinceEpoch(
              orderMap['created_at'] as int? ?? 0),
          paymentTime: null,
          isPaid: true,
          status: status,
          logisticsInfo: null,
          refundReason: null,
          merchantNote: null,
        );

        // 跳转到订单详情页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MerchantOrderDetailPage(order: merchantOrder),
          ),
        ).then((_) => _loadMessages());
      } else {
        // 如果找不到订单，导航到订单管理页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MerchantOrderManagementPage(),
          ),
        );
      }
    }
  }

  /// 进入/退出批量选择模式
  void _toggleBatchMode() {
    setState(() {
      _isBatchMode = !_isBatchMode;
      if (!_isBatchMode) {
        _selectedMessageIds.clear();
        _selectAll = false;
      }
    });
  }

  /// 选择/取消选择单个消息
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
      // 更新全选状态
      _selectAll = _selectedMessageIds.length == _filteredMessages.length;
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedMessageIds = _filteredMessages.map((msg) => msg.id).toList();
      } else {
        _selectedMessageIds.clear();
      }
    });
  }

  /// 批量标记已读
  Future<void> _batchMarkAsRead() async {
    if (_selectedMessageIds.isEmpty) return;

    try {
      // 标记所有选中的消息为已读
      for (final messageId in _selectedMessageIds) {
        if (messageId.startsWith('notification_')) {
          await _notificationService.markAsRead(messageId);
        }
      }

      // 更新本地状态
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          if (_selectedMessageIds.contains(_messages[i].id)) {
            _messages[i] = _messages[i].copyWith(isRead: true);
          }
        }
        // 退出批量模式
        _isBatchMode = false;
        _selectedMessageIds.clear();
        _selectAll = false;
      });
    } catch (e) {
      print('批量标记已读失败: $e');
    }
  }

  /// 批量删除消息
  Future<void> _batchDeleteMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    // 显示确认对话框
    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF152e1e),
          title: const Text(
            '确认删除',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '您确定要删除选中的 ${_selectedMessageIds.length} 条消息吗？',
            style: const TextStyle(color: Color(0xFF92c9a4)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                '取消',
                style: TextStyle(color: Color(0xFF92c9a4)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                '删除',
                style: TextStyle(color: Color(0xFFEF5350)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        // 删除所有选中的消息
        for (final messageId in _selectedMessageIds) {
          if (messageId.startsWith('notification_')) {
            await _notificationService.deleteNotification(messageId);
          }
        }

        // 更新本地状态
        setState(() {
          _messages.removeWhere((msg) => _selectedMessageIds.contains(msg.id));
          // 退出批量模式
          _isBatchMode = false;
          _selectedMessageIds.clear();
          _selectAll = false;
        });
      } catch (e) {
        print('批量删除消息失败: $e');
      }
    }
  }

  /// 构建消息标签
  Widget _buildMessageTab(MerchantMessageTab tab, String label, int unreadCount,
      {bool isCritical = false}) {
    final isActive = _currentTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = tab;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive
                  ? (isCritical
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF13ec5b))
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF92c9a4),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF13ec5b),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    color: isCritical ? Colors.white : Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建高优先级退款消息项
  Widget _buildHighPriorityRefundItem(Message message) {
    return GestureDetector(
      onTap: () {
        if (_isBatchMode) {
          _toggleMessageSelection(message.id);
        } else {
          _markAsRead(message);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF152e1e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedMessageIds.contains(message.id)
                ? const Color(0xFF13ec5b)
                : const Color(0xFFEF5350).withOpacity(0.3),
            width: _selectedMessageIds.contains(message.id) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 左侧红色指示条
            if (!_isBatchMode) ...[
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF5350),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
            // 内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 批量选择复选框
                  if (_isBatchMode) ...[
                    Checkbox(
                      value: _selectedMessageIds.contains(message.id),
                      onChanged: (value) {
                        _toggleMessageSelection(message.id);
                      },
                      activeColor: const Color(0xFF13ec5b),
                      checkColor: Colors.black,
                      fillColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return const Color(0xFF13ec5b);
                        }
                        return const Color(0xFF326744);
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 消息内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标签和时间
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!_isBatchMode) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFEF5350).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning,
                                      size: 16,
                                      color: Color(0xFFEF5350),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '加急处理',
                                      style: TextStyle(
                                        color: Color(0xFFEF5350),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Row(
                              children: [
                                Text(
                                  getTimeText(message.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF92c9a4),
                                    fontSize: 12,
                                  ),
                                ),
                                if (!_isBatchMode) ...[
                                  IconButton(
                                    onPressed: () =>
                                        _deleteMessage(message, context),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFF92c9a4),
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(minWidth: 32),
                                    tooltip: '删除消息',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 标题
                        Text(
                          message.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 内容
                        Text(
                          message.content,
                          style: const TextStyle(
                            color: Color(0xFF92c9a4),
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!_isBatchMode) ...[
                          const SizedBox(height: 12),
                          // 操作按钮
                          ElevatedButton(
                            onPressed: () => _handleAction(message),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF5350),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                              shadowColor:
                                  const Color(0xFFEF5350).withOpacity(0.3),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  message.actionText!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 商品图片
                  if (message.productImageUrl != null && !_isBatchMode) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 96,
                      height: 128,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(message.productImageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建普通订单消息项
  Widget _buildOrderMessageItem(Message message) {
    return GestureDetector(
      onTap: () {
        if (_isBatchMode) {
          _toggleMessageSelection(message.id);
        } else {
          _markAsRead(message);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF152e1e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedMessageIds.contains(message.id)
                ? const Color(0xFF13ec5b)
                : const Color(0xFF13ec5b).withOpacity(0.2),
            width: _selectedMessageIds.contains(message.id) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 未读指示器
            if (!message.isRead && !_isBatchMode) ...[
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13ec5b),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF13ec5b).withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // 内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 批量选择复选框
                  if (_isBatchMode) ...[
                    Checkbox(
                      value: _selectedMessageIds.contains(message.id),
                      onChanged: (value) {
                        _toggleMessageSelection(message.id);
                      },
                      activeColor: const Color(0xFF13ec5b),
                      checkColor: Colors.black,
                      fillColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return const Color(0xFF13ec5b);
                        }
                        return const Color(0xFF326744);
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 消息内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标签和时间
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!_isBatchMode) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF13ec5b).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.inventory_2,
                                      size: 16,
                                      color: Color(0xFF13ec5b),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '新订单',
                                      style: TextStyle(
                                        color: Color(0xFF13ec5b),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Row(
                              children: [
                                Text(
                                  getTimeText(message.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF92c9a4),
                                    fontSize: 12,
                                  ),
                                ),
                                if (!_isBatchMode) ...[
                                  IconButton(
                                    onPressed: () =>
                                        _deleteMessage(message, context),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFF92c9a4),
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(minWidth: 32),
                                    tooltip: '删除消息',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 标题
                        Text(
                          message.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 内容
                        Text(
                          message.content,
                          style: const TextStyle(
                            color: Color(0xFF92c9a4),
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!_isBatchMode) ...[
                          const SizedBox(height: 12),
                          // 操作按钮
                          ElevatedButton(
                            onPressed: () => _handleAction(message),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13ec5b),
                              foregroundColor: const Color(0xFF102216),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                              shadowColor:
                                  const Color(0xFF13ec5b).withOpacity(0.3),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  message.actionText!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.local_shipping, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 商品图片
                  if (message.productImageUrl != null && !_isBatchMode) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 96,
                      height: 128,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(message.productImageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建商品审核消息项
  Widget _buildProductAuditMessageItem(Message message) {
    return GestureDetector(
      onTap: () {
        if (_isBatchMode) {
          _toggleMessageSelection(message.id);
        } else {
          _markAsRead(message);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF152e1e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedMessageIds.contains(message.id)
                ? const Color(0xFF13ec5b)
                : Colors.white.withOpacity(0.05),
            width: _selectedMessageIds.contains(message.id) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 批量选择复选框
              if (_isBatchMode) ...[
                Checkbox(
                  value: _selectedMessageIds.contains(message.id),
                  onChanged: (value) {
                    _toggleMessageSelection(message.id);
                  },
                  activeColor: const Color(0xFF13ec5b),
                  checkColor: Colors.black,
                  fillColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF13ec5b);
                    }
                    return const Color(0xFF326744);
                  }),
                ),
                const SizedBox(width: 8),
              ],
              // 消息内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标签和时间
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isBatchMode) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.rate_review,
                                size: 18,
                                color: Color(0xFFFF9800),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '商品审核',
                                style: TextStyle(
                                  color: Color(0xFFFF9800),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        Row(
                          children: [
                            Text(
                              getTimeText(message.createdAt),
                              style: const TextStyle(
                                color: Color(0xFF92c9a4),
                                fontSize: 12,
                              ),
                            ),
                            if (!_isBatchMode) ...[
                              IconButton(
                                onPressed: () =>
                                    _deleteMessage(message, context),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFF92c9a4),
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(minWidth: 32),
                                tooltip: '删除消息',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 标题
                    Text(
                      message.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 内容
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: Color(0xFF92c9a4),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!_isBatchMode) ...[
                      const SizedBox(height: 12),
                      // 操作按钮
                      ElevatedButton(
                        onPressed: () => _handleAction(message),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(message.actionText!),
                      ),
                    ],
                  ],
                ),
              ),
              // 商品图片
              if (message.productImageUrl != null && !_isBatchMode) ...[
                const SizedBox(width: 12),
                Container(
                  width: 96,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(message.productImageUrl!),
                      fit: BoxFit.cover,
                      opacity: 0.7,
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.block,
                        size: 32,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建系统消息项
  Widget _buildSystemMessageItem(Message message) {
    return GestureDetector(
      onTap: () {
        if (_isBatchMode) {
          _toggleMessageSelection(message.id);
        } else {
          _markAsRead(message);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF152e1e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedMessageIds.contains(message.id)
                ? const Color(0xFF13ec5b)
                : Colors.white.withOpacity(0.05),
            width: _selectedMessageIds.contains(message.id) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图标和标题
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 批量选择复选框
                  if (_isBatchMode) ...[
                    Checkbox(
                      value: _selectedMessageIds.contains(message.id),
                      onChanged: (value) {
                        _toggleMessageSelection(message.id);
                      },
                      activeColor: const Color(0xFF13ec5b),
                      checkColor: Colors.black,
                      fillColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return const Color(0xFF13ec5b);
                        }
                        return const Color(0xFF326744);
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!_isBatchMode) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dns,
                        size: 24,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              message.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  getTimeText(message.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF92c9a4),
                                    fontSize: 12,
                                  ),
                                ),
                                if (!_isBatchMode) ...[
                                  IconButton(
                                    onPressed: () =>
                                        _deleteMessage(message, context),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFF92c9a4),
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(minWidth: 32),
                                    tooltip: '删除消息',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message.content,
                          style: const TextStyle(
                            color: Color(0xFF92c9a4),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 操作按钮
              if (message.actionText != null && !_isBatchMode) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: ElevatedButton(
                    onPressed: () => _handleAction(message),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF13ec5b),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      children: [
                        Text(message.actionText!),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建活动通知消息项
  Widget _buildCampaignMessageItem(Message message) {
    return GestureDetector(
      onTap: () {
        if (_isBatchMode) {
          _toggleMessageSelection(message.id);
        } else {
          _markAsRead(message);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: _selectedMessageIds.contains(message.id)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a3825),
                    Color(0xFF102216),
                  ],
                ),
          color: _selectedMessageIds.contains(message.id)
              ? const Color(0xFF152e1e)
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedMessageIds.contains(message.id)
                ? const Color(0xFF13ec5b)
                : const Color(0xFF13ec5b).withOpacity(0.1),
            width: _selectedMessageIds.contains(message.id) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 批量选择复选框
              if (_isBatchMode) ...[
                Checkbox(
                  value: _selectedMessageIds.contains(message.id),
                  onChanged: (value) {
                    _toggleMessageSelection(message.id);
                  },
                  activeColor: const Color(0xFF13ec5b),
                  checkColor: Colors.black,
                  fillColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF13ec5b);
                    }
                    return const Color(0xFF326744);
                  }),
                ),
                const SizedBox(width: 8),
              ],
              // 消息内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标签和时间
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isBatchMode) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.campaign,
                                size: 18,
                                color: Color(0xFF9C27B0),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '活动通知',
                                style: TextStyle(
                                  color: Color(0xFF9C27B0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        Row(
                          children: [
                            Text(
                              getTimeText(message.createdAt),
                              style: const TextStyle(
                                color: Color(0xFF92c9a4),
                                fontSize: 12,
                              ),
                            ),
                            if (!_isBatchMode) ...[
                              IconButton(
                                onPressed: () =>
                                    _deleteMessage(message, context),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFF92c9a4),
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(minWidth: 32),
                                tooltip: '删除消息',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 标题
                    Text(
                      message.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 内容
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: Color(0xFF92c9a4),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!_isBatchMode) ...[
                      const SizedBox(height: 12),
                      // 操作按钮
                      ElevatedButton(
                        onPressed: () => _handleAction(message),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF9C27B0).withOpacity(0.2),
                          foregroundColor: const Color(0xFFE1BEE7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: const Color(0xFF9C27B0).withOpacity(0.3),
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(message.actionText!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建消息项
  Widget _buildMessageItem(Message message) {
    if (message.merchantType == MerchantMessageType.refundAfterSales &&
        message.priority == MessagePriority.high) {
      return _buildHighPriorityRefundItem(message);
    } else if (message.merchantType == MerchantMessageType.order) {
      return _buildOrderMessageItem(message);
    } else if (message.merchantType == MerchantMessageType.productAudit) {
      return _buildProductAuditMessageItem(message);
    } else if (message.title.contains('活动')) {
      return _buildCampaignMessageItem(message);
    } else {
      return _buildSystemMessageItem(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102216).withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: _isBatchMode
              ? const Icon(
                  Icons.close,
                  color: Colors.white,
                )
              : const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
          onPressed: () {
            if (_isBatchMode) {
              _toggleBatchMode();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isBatchMode ? '选择消息' : '消息中心',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: _isBatchMode
            ? [
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _selectAll ? '取消全选' : '全选',
                    style: const TextStyle(
                      color: Color(0xFF13ec5b),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(
                    Icons.select_all,
                    color: Colors.white,
                  ),
                  onPressed: _toggleBatchMode,
                  tooltip: '批量操作',
                ),
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text(
                    '全部已读',
                    style: TextStyle(
                      color: Color(0xFF13ec5b),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF326744).withOpacity(0.3),
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // 消息标签栏（仅在非批量模式显示）
          if (!_isBatchMode) ...[
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) {
                  final unreadCount = _messages.where((msg) {
                    switch (index) {
                      case 0:
                        return !msg.isRead;
                      case 1:
                        return !msg.isRead &&
                            msg.merchantType == MerchantMessageType.order;
                      case 2:
                        return !msg.isRead &&
                            msg.merchantType ==
                                MerchantMessageType.refundAfterSales;
                      case 3:
                        return !msg.isRead &&
                            msg.merchantType ==
                                MerchantMessageType.productAudit;
                      case 4:
                        return !msg.isRead &&
                            msg.merchantType == MerchantMessageType.system;
                      default:
                        return false;
                    }
                  }).length;

                  switch (index) {
                    case 0:
                      return _buildMessageTab(
                          MerchantMessageTab.all, '全部', unreadCount);
                    case 1:
                      return _buildMessageTab(
                          MerchantMessageTab.order, '订单消息', unreadCount);
                    case 2:
                      return _buildMessageTab(
                          MerchantMessageTab.refundAfterSales,
                          '退款/售后',
                          unreadCount,
                          isCritical: true);
                    case 3:
                      return _buildMessageTab(
                          MerchantMessageTab.productAudit, '商品审核', unreadCount);
                    case 4:
                      return _buildMessageTab(
                          MerchantMessageTab.system, '系统通知', unreadCount);
                    default:
                      return const SizedBox();
                  }
                },
              ),
            ),
            // 分隔线
            Container(
              height: 1.0,
              color: const Color(0xFF326744).withOpacity(0.3),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF152e1e),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF326744).withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF92c9a4),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Color(0xFF92c9a4),
                            ),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    hintText: '搜索消息',
                    hintStyle: const TextStyle(
                      color: Color(0xFF92c9a4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // 分隔线
            Container(
              height: 1.0,
              color: const Color(0xFF326744).withOpacity(0.3),
            ),
          ],
          // 消息列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshMessages,
              color: const Color(0xFF13ec5b),
              backgroundColor: const Color(0xFF102216),
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF13ec5b)),
                    )
                  : _filteredMessages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: Color(0xFF326744),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '没有更多消息了',
                                style: TextStyle(
                                  color: Color(0xFF92c9a4),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredMessages.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _filteredMessages.length) {
                              return _buildMessageItem(
                                  _filteredMessages[index]);
                            } else {
                              // 显示加载更多指示器
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF13ec5b)),
                                ),
                              );
                            }
                          },
                        ),
            ),
          ),
          // 批量操作底部栏
          if (_isBatchMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF152e1e),
                border: Border(
                    top: BorderSide(
                        color: const Color(0xFF326744).withOpacity(0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已选择 ${_selectedMessageIds.length} 条',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _batchMarkAsRead,
                        child: const Text(
                          '标记已读',
                          style: TextStyle(
                            color: Color(0xFF13ec5b),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _batchDeleteMessages,
                        child: const Text(
                          '删除',
                          style: TextStyle(
                            color: Color(0xFFEF5350),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
