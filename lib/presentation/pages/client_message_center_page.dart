import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/domain/entities/message.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 客户端消息标签枚举
enum ClientMessageTab {
  all,
  notification,
  order,
  promotion,
  interaction,
}

/// 获取消息图标
IconData getMessageIcon(ClientMessageType type) {
  switch (type) {
    case ClientMessageType.order:
      return Icons.local_shipping;
    case ClientMessageType.promotion:
      return Icons.local_fire_department;
    case ClientMessageType.notification:
      return Icons.shield;
    case ClientMessageType.interaction:
      return Icons.person;
    default:
      return Icons.info;
  }
}

/// 获取消息图标背景色
Color getMessageIconBackgroundColor(ClientMessageType type) {
  switch (type) {
    case ClientMessageType.order:
      return const Color(0xFF13ec5b);
    case ClientMessageType.promotion:
      return const Color(0xFFFF9800);
    case ClientMessageType.notification:
      return const Color(0xFF2196F3);
    case ClientMessageType.interaction:
      return const Color(0xFF9C27B0);
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

/// 客户端消息中心页面
class ClientMessageCenterPage extends ConsumerStatefulWidget {
  /// 构造函数
  const ClientMessageCenterPage({super.key});

  @override
  ConsumerState<ClientMessageCenterPage> createState() => _ClientMessageCenterPageState();
}

class _ClientMessageCenterPageState extends ConsumerState<ClientMessageCenterPage> {
  /// 当前选中的标签
  ClientMessageTab _currentTab = ClientMessageTab.all;
  
  /// 通知服务实例
  final NotificationDatabaseService _notificationService = NotificationDatabaseService();
  
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
      final notifications = await _notificationService.getNotificationsByPage(1, _pageSize);
      
      // 将通知转换为消息模型
      final messages = notifications.map((notification) {
        // 根据通知类型转换为客户端消息类型
        ClientMessageType clientType;
        switch (notification.type) {
          case NotificationType.reminderShip:
          case NotificationType.modifyAddress:
          case NotificationType.applyCancel:
          case NotificationType.applyAfterSales:
          case NotificationType.review:
            clientType = ClientMessageType.order;
            break;
          case NotificationType.system:
            clientType = ClientMessageType.notification;
            break;
        }
        
        return Message(
          id: notification.id,
          title: notification.productName ?? '订单通知',
          content: notification.content,
          clientType: clientType,
          priority: MessagePriority.medium,
          createdAt: notification.createdAt,
          isRead: notification.status != NotificationStatus.unread,
          orderId: notification.orderId,
          productImageUrl: notification.productImage,
        );
      }).toList();
      
      // 添加一些模拟的促销和互动消息
      messages.addAll([
        Message(
          id: 'promo_1',
          title: '限时抢购开始',
          content: '双11返场！接下来的一个小时内，所有 Nike 运动装享 8 折优惠。',
          clientType: ClientMessageType.promotion,
          priority: MessagePriority.medium,
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
          isRead: false,
        ),
        Message(
          id: 'interaction_1',
          title: 'SneakerHead 官方店',
          content: '亲，这款目前有现货的，下午4点前下单当天发货...',
          clientType: ClientMessageType.interaction,
          priority: MessagePriority.medium,
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          isRead: true,
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
      final notifications = await _notificationService.getNotificationsByPage(_currentPage, _pageSize);
      
      // 将通知转换为消息模型
      final newMessages = notifications.map((notification) {
        // 根据通知类型转换为客户端消息类型
        ClientMessageType clientType;
        switch (notification.type) {
          case NotificationType.reminderShip:
          case NotificationType.modifyAddress:
          case NotificationType.applyCancel:
          case NotificationType.applyAfterSales:
          case NotificationType.review:
            clientType = ClientMessageType.order;
            break;
          case NotificationType.system:
            clientType = ClientMessageType.notification;
            break;
        }
        
        return Message(
          id: notification.id,
          title: notification.productName ?? '订单通知',
          content: notification.content,
          clientType: clientType,
          priority: MessagePriority.medium,
          createdAt: notification.createdAt,
          isRead: notification.status != NotificationStatus.unread,
          orderId: notification.orderId,
          productImageUrl: notification.productImage,
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
    final theme = ref.watch(currentThemeProvider);
    // 显示确认对话框
    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text(
            '确认删除',
            style: TextStyle(color: theme.colorScheme.onBackground),
          ),
          content: Text(
            '您确定要删除选中的 ${_selectedMessageIds.length} 条消息吗？',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '删除',
                style: TextStyle(color: theme.colorScheme.error),
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

  /// 获取当前标签下的消息
  List<Message> get _filteredMessages {
    // 先根据标签过滤
    List<Message> filteredByTab;
    switch (_currentTab) {
      case ClientMessageTab.all:
        filteredByTab = _messages;
        break;
      case ClientMessageTab.notification:
        filteredByTab = _messages.where((msg) => msg.clientType == ClientMessageType.notification).toList();
        break;
      case ClientMessageTab.order:
        filteredByTab = _messages.where((msg) => msg.clientType == ClientMessageType.order).toList();
        break;
      case ClientMessageTab.promotion:
        filteredByTab = _messages.where((msg) => msg.clientType == ClientMessageType.promotion).toList();
        break;
      case ClientMessageTab.interaction:
        filteredByTab = _messages.where((msg) => msg.clientType == ClientMessageType.interaction).toList();
        break;
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
    final theme = ref.watch(currentThemeProvider);
    try {
      // 显示确认对话框
      final bool? confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surfaceVariant,
            title: Text(
              '确认删除',
              style: TextStyle(color: theme.colorScheme.onBackground),
            ),
            content: Text(
              '您确定要删除这条消息吗？',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  '取消',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  '删除',
                  style: TextStyle(color: theme.colorScheme.error),
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

  /// 构建消息标签
  Widget _buildMessageTab(ClientMessageTab tab, String label, int unreadCount) {
    final theme = ref.watch(currentThemeProvider);
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
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? theme.colorScheme.onBackground : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
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

  /// 构建消息项
  Widget _buildMessageItem(Message message) {
    final theme = ref.watch(currentThemeProvider);
    return GestureDetector(
      onTap: () {
        if (_isBatchMode) {
          _toggleMessageSelection(message.id);
        } else {
          _markAsRead(message);
          // 这里可以导航到消息详情页
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedMessageIds.contains(message.id)
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                activeColor: theme.colorScheme.primary,
                checkColor: theme.colorScheme.onPrimary,
                fillColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return theme.colorScheme.primary;
                  }
                  return theme.colorScheme.surfaceVariant;
                }),
              ),
              const SizedBox(width: 8),
            ] else ...[
              // 消息图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: getMessageIconBackgroundColor(message.clientType!).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  getMessageIcon(message.clientType!),
                  color: getMessageIconBackgroundColor(message.clientType!),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
            ],
            // 消息内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        message.title,
                        style: TextStyle(
                          color: theme.colorScheme.onBackground,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            getTimeText(message.createdAt),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          if (!message.isRead && !_isBatchMode) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 删除按钮
            if (!_isBatchMode) ...[
              IconButton(
                onPressed: () => _deleteMessage(message, context),
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32),
                tooltip: '删除消息',
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: _isBatchMode 
              ? Icon(
                  Icons.close,
                  color: theme.colorScheme.onBackground,
                )
              : Icon(
                  Icons.arrow_back_ios_new,
                  color: theme.colorScheme.onBackground,
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
          style: TextStyle(
            color: theme.colorScheme.onBackground,
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
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: _markAllAsRead,
                  child: Text(
                    '全部已读',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.select_all,
                    color: theme.colorScheme.onBackground,
                  ),
                  onPressed: _toggleBatchMode,
                  tooltip: '批量操作',
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.colorScheme.outline.withOpacity(0.3),
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
                        return !msg.isRead && msg.clientType == ClientMessageType.notification;
                      case 2:
                        return !msg.isRead && msg.clientType == ClientMessageType.order;
                      case 3:
                        return !msg.isRead && msg.clientType == ClientMessageType.promotion;
                      case 4:
                        return !msg.isRead && msg.clientType == ClientMessageType.interaction;
                      default:
                        return false;
                      }
                  }).length;
                  
                  switch (index) {
                    case 0:
                      return _buildMessageTab(ClientMessageTab.all, '全部', unreadCount);
                    case 1:
                      return _buildMessageTab(ClientMessageTab.notification, '通知', unreadCount);
                    case 2:
                      return _buildMessageTab(ClientMessageTab.order, '订单消息', unreadCount);
                    case 3:
                      return _buildMessageTab(ClientMessageTab.promotion, '活动优惠', unreadCount);
                    case 4:
                      return _buildMessageTab(ClientMessageTab.interaction, '互动消息', unreadCount);
                    default:
                      return const SizedBox();
                  }
                },
              ),
            ),
            // 分隔线
            Container(
              height: 1.0,
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
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
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: theme.colorScheme.onSurfaceVariant,
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
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
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
              color: theme.colorScheme.primary,
              backgroundColor: theme.scaffoldBackgroundColor,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _filteredMessages.isEmpty
                      ? Center(
                          child: Text(
                            '暂无消息',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredMessages.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _filteredMessages.length) {
                              return _buildMessageItem(_filteredMessages[index]);
                            } else {
                              // 显示加载更多指示器
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(color: Color(0xFF13ec5b)),
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
                color: theme.colorScheme.surfaceVariant,
                border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已选择 ${_selectedMessageIds.length} 条',
                    style: TextStyle(
                      color: theme.colorScheme.onBackground,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _batchMarkAsRead,
                        child: Text(
                          '标记已读',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _batchDeleteMessages,
                        child: Text(
                          '删除',
                          style: TextStyle(
                            color: theme.colorScheme.error,
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
