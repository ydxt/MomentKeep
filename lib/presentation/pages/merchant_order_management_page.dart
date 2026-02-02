import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/presentation/pages/merchant_order_detail_page.dart';
import 'package:moment_keep/presentation/pages/merchant_message_center_page.dart';
import 'package:moment_keep/presentation/pages/date_picker_utils.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 商家订单状态枚举
enum MerchantOrderStatus {
  all,
  pendingPayment,
  pendingAccept,
  pendingShip,
  shipped,
  refunding,
  repair,
  completed,
  cancelled,
  refunded,
  rejected,
}

/// 物流信息模型
class LogisticsInfo {
  final String? trackingNumber;
  final String? logisticsCompany;
  final String? logisticsStatus;
  final List<LogisticsTrack>? tracks;

  LogisticsInfo({
    this.trackingNumber,
    this.logisticsCompany,
    this.logisticsStatus,
    this.tracks,
  });

  factory LogisticsInfo.fromMap(Map<String, dynamic> map) {
    return LogisticsInfo(
      trackingNumber: map['tracking_number'] as String?,
      logisticsCompany: map['logistics_company'] as String?,
      logisticsStatus: map['logistics_status'] as String?,
      tracks: map['tracks'] != null
          ? List<LogisticsTrack>.from((map['tracks'] as List).map(
              (track) => LogisticsTrack.fromMap(track as Map<String, dynamic>)))
          : null,
    );
  }
}

/// 物流轨迹模型
class LogisticsTrack {
  final String time;
  final String location;
  final String description;

  LogisticsTrack({
    required this.time,
    required this.location,
    required this.description,
  });

  factory LogisticsTrack.fromMap(Map<String, dynamic> map) {
    return LogisticsTrack(
      time: map['time'] as String,
      location: map['location'] as String,
      description: map['description'] as String,
    );
  }
}

/// 商家订单模型
class MerchantOrder {
  final String id;
  final String productName;
  final String productImage;
  final String productVariant;
  final int quantity;
  final int points;
  final double originalAmount;
  final double actualAmount;
  final String buyerName;
  final String buyerPhone;
  final String deliveryAddress;
  final String buyerNote;
  final String paymentMethod;
  final String deliveryMethod;
  final bool isAbnormal;
  final DateTime orderTime;
  final DateTime? paymentTime;
  final bool isPaid;
  final MerchantOrderStatus status;
  final LogisticsInfo? logisticsInfo;
  final String? refundReason;
  final List<String>? refundImages;
  final String? merchantNote;
  final String? afterSalesType;
  final String? afterSalesDescription;
  final DateTime? afterSalesApplyTime;
  final String? afterSalesStatus;
  final List<AfterSalesRecord>? afterSalesRecords;

  MerchantOrder({
    required this.id,
    required this.productName,
    required this.productImage,
    required this.productVariant,
    required this.quantity,
    required this.points,
    required this.originalAmount,
    required this.actualAmount,
    required this.buyerName,
    required this.buyerPhone,
    required this.deliveryAddress,
    required this.buyerNote,
    required this.paymentMethod,
    required this.deliveryMethod,
    required this.isAbnormal,
    required this.orderTime,
    this.paymentTime,
    this.isPaid = false,
    required this.status,
    this.logisticsInfo,
    this.refundReason,
    this.refundImages,
    this.merchantNote,
    this.afterSalesType,
    this.afterSalesDescription,
    this.afterSalesApplyTime,
    this.afterSalesStatus,
    this.afterSalesRecords,
  });

  factory MerchantOrder.fromMap(Map<String, dynamic> map) {
    // 解析售后记录
    List<AfterSalesRecord>? afterSalesRecords;
    if (map['after_sales_records'] != null) {
      try {
        final recordsJson = map['after_sales_records'] as String;
        if (recordsJson.isNotEmpty && recordsJson != '[]') {
          final recordsList = json.decode(recordsJson) as List;
          afterSalesRecords = recordsList
              .map((record) =>
                  AfterSalesRecord.fromMap(record as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('解析售后记录失败: $e');
      }
    }

    // 解析物流信息
    LogisticsInfo? logisticsInfo;
    if (map['logistics_info'] != null) {
      try {
        final logisticsJson = map['logistics_info'] as String;
        if (logisticsJson.isNotEmpty) {
          final logisticsMap =
              json.decode(logisticsJson) as Map<String, dynamic>;
          logisticsInfo = LogisticsInfo.fromMap(logisticsMap);
        }
      } catch (e) {
        debugPrint('解析物流信息失败: $e');
      }
    }

    // 解析订单状态
    MerchantOrderStatus status;
    switch (map['status'] as String? ?? '') {
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
      case '已退款':
        status = MerchantOrderStatus.refunded;
        break;
      case '维修中':
        status = MerchantOrderStatus.repair;
        break;
      case '已完成':
        status = MerchantOrderStatus.completed;
        break;
      case '已取消':
        status = MerchantOrderStatus.cancelled;
        break;
      case '已拒绝':
        status = MerchantOrderStatus.rejected;
        break;
      default:
        status = MerchantOrderStatus.completed;
    }

    return MerchantOrder(
      id: (map['id'] ?? '') as String,
      productName: (map['product_name'] ?? '') as String,
      productImage: (map['product_image'] ?? '') as String,
      productVariant: (map['variant'] ?? '') as String,
      quantity: (map['quantity'] ?? 1) as int,
      points: (map['points'] ?? 0) as int,
      originalAmount: ((map['total_amount'] ?? 0) as num).toDouble(),
      actualAmount: ((map['total_amount'] ?? 0) as num).toDouble(),
      buyerName: (map['buyer_name'] ?? '') as String,
      buyerPhone: (map['buyer_phone'] ?? '') as String,
      deliveryAddress: (map['delivery_address'] ?? '') as String,
      buyerNote: (map['buyer_note'] ?? '') as String,
      paymentMethod: (map['payment_method'] ?? '') as String,
      deliveryMethod: (map['delivery_method'] ?? '') as String,
      isAbnormal: (map['is_abnormal'] ?? false) as bool,
      orderTime:
          DateTime.fromMillisecondsSinceEpoch((map['created_at'] ?? 0) as int),
      paymentTime: map['paid_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['paid_at'] as int)
          : null,
      isPaid: (map['is_paid'] ?? false) as bool,
      status: status,
      logisticsInfo: logisticsInfo,
      refundReason: map['refund_reason'] as String?,
      refundImages: map['refund_images'] != null
          ? List<String>.from(map['refund_images'])
          : null,
      merchantNote: map['merchant_note'] as String?,
      afterSalesType: map['after_sales_type'] as String?,
      afterSalesDescription: map['after_sales_description'] as String?,
      afterSalesApplyTime: map['after_sales_create_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['after_sales_create_time'] as int)
          : null,
      afterSalesStatus: map['after_sales_status'] as String?,
      afterSalesRecords: afterSalesRecords,
    );
  }
}

/// 商家订单管理页面
class MerchantOrderManagementPage extends ConsumerStatefulWidget {
  /// 构造函数
  const MerchantOrderManagementPage({super.key});

  @override
  ConsumerState<MerchantOrderManagementPage> createState() =>
      _MerchantOrderManagementPageState();
}

class _MerchantOrderManagementPageState
    extends ConsumerState<MerchantOrderManagementPage> {
  /// 主题数据
  late ThemeData theme;
  
  /// 当前选中的订单状态
  MerchantOrderStatus _selectedStatus = MerchantOrderStatus.all;

  /// 搜索查询
  String _searchQuery = '';

  /// 筛选条件
  String _buyerPhoneLastFour = '';
  String _paymentMethod = 'all';
  String _deliveryMethod = 'all';
  bool _isAbnormal = false;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;

  /// 显示筛选选项
  bool _showFilters = false;

  /// 排序选项
  String _sortBy = 'orderTime'; // orderTime, id, totalAmount, points
  bool _sortAscending = false;

  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();

  /// 商品数据库服务实例
  final ProductDatabaseService _productDatabaseService =
      ProductDatabaseService();

  /// 通知服务实例
  final NotificationDatabaseService _notificationService =
      NotificationDatabaseService();

  /// 订单列表
  List<MerchantOrder> _orders = [];

  /// 筛选后的订单列表
  List<MerchantOrder> _filteredOrders = [];

  /// 每个订单的未读消息数量映射
  Map<String, int> _unreadMessageCounts = {};

  /// 是否处于批量操作模式
  bool _isBatchMode = false;

  /// 选中的订单ID列表
  List<String> _selectedOrderIds = [];

  /// 是否全选
  bool _selectAll = false;

  /// 新订单提醒
  bool _hasNewOrders = true;

  /// 超时提醒
  bool _hasTimeoutOrders = true;

  /// 是否正在加载订单
  bool _isLoading = false;

  /// 是否正在手动刷新中，用于并发控制
  bool _isRefreshing = false;

  /// 通知列表
  List<NotificationInfo> _notifications = [];

  /// 未读通知数量
  int _unreadNotificationCount = 0;

  /// 下拉刷新控制器
  final _refreshController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadNotifications();
  }

  /// 加载通知数据
  Future<void> _loadNotifications() async {
    try {
      final notificationService = NotificationDatabaseService();
      _notifications = await notificationService.getAllNotifications();
      _unreadNotificationCount = await notificationService.getUnreadCount();
      setState(() {
        _hasNewOrders = _unreadNotificationCount > 0;
      });
    } catch (e) {
      debugPrint('加载通知失败: $e');
    }
  }

  /// 加载订单数据
  Future<void> _loadOrders({bool preserveScrollPosition = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    // 保存当前滚动位置
    final currentScrollOffset = preserveScrollPosition && _refreshController.hasClients 
        ? _refreshController.offset 
        : 0.0;

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint('[$currentTime] 开始加载订单数据...');

      // 使用单例 ProductDatabaseService
      final productDb = ProductDatabaseService();

      // 使用服务类的 getAllOrders 方法，已经内置了最新的数据读取逻辑
      final ordersList = await productDb.getAllOrders();
      debugPrint('[$currentTime] 从数据库获取到 ${ordersList.length} 个订单');

      // 将数据库获取的订单数据转换为 MerchantOrder 对象
      final List<MerchantOrder> orders = 
          ordersList.map((map) => MerchantOrder.fromMap(map)).toList();

      for (final order in orders) {
        debugPrint('[$currentTime] 转换后的订单 ${order.id} 的状态: ${order.status}');
      }

      // 获取每个订单的未读消息数量
      final unreadCounts = <String, int>{};
      for (final order in orders) {
        final notifications = 
            await _notificationService.getNotificationsByOrderId(order.id);
        final unreadCount = notifications
            .where((n) => n.status == NotificationStatus.unread)
            .length;
        if (unreadCount > 0) {
          unreadCounts[order.id] = unreadCount;
        }
      }

      setState(() {
        _orders = orders;
        _unreadMessageCounts = unreadCounts;
        _applyFilters();
        _isLoading = false;
        _isRefreshing = false;
        debugPrint(
            '[$currentTime] 订单数据已更新，共 ${_orders.length} 个订单，筛选后 ${_filteredOrders.length} 个订单');
        // 打印所有订单的详细信息，用于调试
        for (final order in _orders) {
          debugPrint(
              '[$currentTime] _orders列表中订单 ${order.id} 的状态: ${order.status}');
        }
      });
      
      // 延迟恢复滚动位置，确保列表已经重新构建
      if (preserveScrollPosition && currentScrollOffset > 0) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_refreshController.hasClients && mounted) {
            _refreshController.animateTo(
              currentScrollOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[$currentTime] 加载订单失败: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      // 显示加载失败的提示
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载订单失败: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 应用筛选条件
  void _applyFilters() {
    debugPrint('开始应用筛选条件...');
    debugPrint('当前筛选状态: $_selectedStatus');
    debugPrint('当前搜索查询: $_searchQuery');
    // 筛选订单
    _filteredOrders = _orders.where((order) {
      // 状态筛选
      final statusMatch = _selectedStatus == MerchantOrderStatus.all ||
          order.status == _selectedStatus;
      debugPrint('订单 ${order.id} 的状态: ${order.status}, 状态匹配: $statusMatch');

      if (!statusMatch) {
        return false;
      }

      // 搜索筛选
      final searchMatch = _searchQuery.isEmpty ||
          order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.productName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          order.buyerPhone.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!searchMatch) {
        return false;
      }

      // 买家手机号后四位筛选
      final phoneMatch = _buyerPhoneLastFour.isEmpty ||
          order.buyerPhone.endsWith(_buyerPhoneLastFour);

      if (!phoneMatch) {
        return false;
      }

      // 支付方式筛选
      final paymentMatch =
          _paymentMethod == 'all' || order.paymentMethod == _paymentMethod;

      if (!paymentMatch) {
        return false;
      }

      // 配送方式筛选
      final deliveryMatch =
          _deliveryMethod == 'all' || order.deliveryMethod == _deliveryMethod;

      if (!deliveryMatch) {
        return false;
      }

      // 异常订单筛选
      final abnormalMatch = !_isAbnormal || order.isAbnormal;

      if (!abnormalMatch) {
        return false;
      }

      // 订单时间范围筛选
      final dateMatch =
          (_startDate == null || !order.orderTime.isBefore(_startDate!)) &&
              (_endDate == null || !order.orderTime.isAfter(_endDate!));

      if (!dateMatch) {
        return false;
      }

      // 订单金额范围筛选
      final amountMatch =
          (_minAmount == null || order.actualAmount >= _minAmount!) &&
              (_maxAmount == null || order.actualAmount <= _maxAmount!);

      return amountMatch;
    }).toList();

    debugPrint('筛选完成，共 ${_filteredOrders.length} 个订单匹配筛选条件');

    // 排序订单
    _sortOrders();

    // 更新全选状态
    _selectAll = _selectedOrderIds.length == _filteredOrders.length;
  }

  /// 排序订单
  void _sortOrders() {
    _filteredOrders.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'orderTime':
          comparison = a.orderTime.compareTo(b.orderTime);
          break;
        case 'id':
          comparison = a.id.compareTo(b.id);
          break;
        case 'totalAmount':
          comparison = a.actualAmount.compareTo(b.actualAmount);
          break;
        case 'points':
          comparison = a.points.compareTo(b.points);
          break;
        default:
          comparison = a.orderTime.compareTo(b.orderTime);
      }

      return _sortAscending ? comparison : -comparison;
    });
  }

  /// 切换订单选择状态
  void _toggleOrderSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
      _selectAll = _selectedOrderIds.length == _orders.length;
    });
  }

  /// 切换全选状态
  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedOrderIds = _orders.map((order) => order.id).toList();
      } else {
        _selectedOrderIds.clear();
      }
    });
  }

  /// 切换批量操作模式
  void _toggleBatchMode() {
    setState(() {
      _isBatchMode = !_isBatchMode;
      if (!_isBatchMode) {
        _selectedOrderIds.clear();
        _selectAll = false;
      }
    });
  }

  /// 批量接单
  void _batchAcceptOrders() {
    if (_selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择要接单的订单'),
          backgroundColor: Color(0xFFf39c12),
        ),
      );
      return;
    }

    final selectedOrders =
        _orders.where((order) => _selectedOrderIds.contains(order.id)).toList();

    final pendingAcceptOrders = selectedOrders
        .where((order) => order.status == MerchantOrderStatus.pendingAccept)
        .toList();

    if (pendingAcceptOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('所选订单中没有待接单的订单'),
          backgroundColor: Color(0xFFf39c12),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceVariant,
        title: Text(
          '批量接单',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '确定要接单这 ${pendingAcceptOrders.length} 个订单吗？',
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '接单后请及时发货，超时将影响店铺评分',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performBatchAccept(pendingAcceptOrders);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('确认接单'),
          ),
        ],
      ),
    );
  }

  /// 执行批量接单
  Future<void> _performBatchAccept(List<MerchantOrder> orders) async {
    int successCount = 0;
    for (final order in orders) {
      try {
        await _productDatabaseService.updateOrderStatus(order.id, '待发货');
        successCount++;
      } catch (e) {
        debugPrint('接单失败: ${order.id} - $e');
      }
    }

    await _loadOrders(preserveScrollPosition: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('成功接单 $successCount 个订单'),
        backgroundColor: const Color(0xFF13ec5b),
      ),
    );

    setState(() {
      _isBatchMode = false;
      _selectedOrderIds.clear();
      _selectAll = false;
    });
  }

  /// 批量发货
  void _batchShipOrders() {
    if (_selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先选择要发货的订单'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }

    final selectedOrders = 
        _orders.where((order) => _selectedOrderIds.contains(order.id)).toList();

    final pendingShipOrders = selectedOrders
        .where((order) => order.status == MerchantOrderStatus.pendingShip)
        .toList();

    if (pendingShipOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('所选订单中没有待发货的订单'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text(
            '批量发货',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '确定要发货这 ${pendingShipOrders.length} 个订单吗？',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请确保已填写物流信息，发货后无法修改',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showBatchLogisticsDialog(pendingShipOrders);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('填写物流'),
            ),
          ],
        );
      },
    );
  }

  /// 显示批量物流信息填写对话框
  void _showBatchLogisticsDialog(List<MerchantOrder> orders) {
    String logisticsCompany = '';
    String trackingNumber = '';

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text(
            '填写物流信息',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '将为 ${orders.length} 个订单填写相同的物流信息',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                    onChanged: (value) {
                      logisticsCompany = value;
                    },
                    decoration: InputDecoration(
                      hintText: '请输入物流公司',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      labelText: '物流公司',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
              const SizedBox(height: 16),
              TextField(
                    onChanged: (value) {
                      trackingNumber = value;
                    },
                    decoration: InputDecoration(
                      hintText: '请输入物流单号',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      labelText: '物流单号',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            ElevatedButton(
              onPressed: () {
                if (logisticsCompany.isEmpty || trackingNumber.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('请填写完整的物流信息'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _performBatchShip(orders, logisticsCompany, trackingNumber);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('确认发货'),
            ),
          ],
        );
      },
    );
  }

  /// 执行批量发货
  Future<void> _performBatchShip(
      List<MerchantOrder> orders, String company, String trackingNumber) async {
    int successCount = 0;
    for (final order in orders) {
      try {
        await _productDatabaseService.updateOrderStatus(order.id, '已发货');
        successCount++;
      } catch (e) {
        debugPrint('发货失败: ${order.id} - $e');
      }
    }

    await _loadOrders(preserveScrollPosition: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('成功发货 $successCount 个订单'),
        backgroundColor: const Color(0xFF13ec5b),
      ),
    );

    setState(() {
      _isBatchMode = false;
      _selectedOrderIds.clear();
      _selectAll = false;
    });
  }

  /// 接单操作
  void _acceptOrder(String orderId) {
    // 实现接单逻辑
    debugPrint('接单: $orderId');

    // 更新订单状态为待发货
    _productDatabaseService.updateOrderStatus(orderId, '待发货').then((_) {
      // 重新加载订单数据
      _loadOrders(preserveScrollPosition: true);

      // 显示接单成功的提示
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功接单'),
          backgroundColor: const Color(0xFF13ec5b),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }).catchError((e) {
      debugPrint('接单失败: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('接单失败: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  /// 拒单操作
  void _rejectOrder(String orderId) {
    // 实现拒单逻辑
    debugPrint('拒单: $orderId');

    // 更新订单状态为已拒单
    _productDatabaseService.updateOrderStatus(orderId, '已拒单').then((_) {
      // 重新加载订单数据
      _loadOrders(preserveScrollPosition: true);

      // 显示拒单成功的提示
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功拒单'),
          backgroundColor: const Color(0xFF13ec5b),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }).catchError((e) {
      debugPrint('拒单失败: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('拒单失败: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  /// 录入物流
  void _enterLogistics(String orderId) {
    // 创建物流信息录入对话框
    showDialog(
      context: context,
      builder: (context) {
        String logisticsCompany = '';
        String trackingNumber = '';

        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text(
            '录入物流信息',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 物流公司输入框
                  TextField(
                    onChanged: (value) {
                      logisticsCompany = value;
                    },
                    decoration: InputDecoration(
                        hintText: '请输入物流公司',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        labelText: '物流公司',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  // 物流单号输入框
                  TextField(
                    onChanged: (value) {
                      trackingNumber = value;
                    },
                    decoration: InputDecoration(
                      hintText: '请输入物流单号',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      labelText: '物流单号',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // 验证输入
                if (logisticsCompany.isEmpty || trackingNumber.isEmpty) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('请填写完整的物流信息'),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                // 更新订单状态为已发货
                  _productDatabaseService
                      .updateOrderStatus(orderId, '已发货')
                      .then((_) {
                    // 重新加载订单数据
                    _loadOrders(preserveScrollPosition: true);

                    // 显示录入成功的提示
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已成功录入物流信息'),
                        backgroundColor: theme.colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );

                    Navigator.pop(context);
                  }).catchError((e) {
                    debugPrint('录入物流失败: $e');
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('录入物流失败: $e'),
                        backgroundColor: theme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('确认录入'),
            ),
          ],
        );
      },
    );
  }

  /// 查看详情
  void _viewOrderDetails(String orderId, {bool showAfterSalesRecords = false}) {
    // 保存当前滚动位置
    final currentScrollOffset = _refreshController.hasClients ? _refreshController.offset : 0.0;
    
    // 导航到订单详情页面，并在返回时刷新订单列表
    // 不使用缓存的订单对象，而是在详情页重新获取，确保数据最新
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) {
          // 创建新的ProductDatabaseService实例获取最新订单数据
          final productDb = ProductDatabaseService();
          return FutureBuilder<Map<String, dynamic>?>(
            future: productDb.getOrderById(orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.data != null) {
                  final order = MerchantOrder.fromMap(snapshot.data!);
                  return MerchantOrderDetailPage(
                      order: order,
                      showAfterSalesRecords: showAfterSalesRecords);
                } else {
                  // 如果获取失败，使用旧的订单对象作为后备
                  final order = 
                      _orders.firstWhere((order) => order.id == orderId);
                  return MerchantOrderDetailPage(
                      order: order,
                      showAfterSalesRecords: showAfterSalesRecords);
                }
              } else {
                // 显示加载指示器
                return Scaffold(
                  backgroundColor: const Color(0xFF102216),
                  body: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF13ec5b)),
                  ),
                );
              }
            },
          );
        },
      ),
    ).then((value) async {
      // 从详情页返回时，强制重新加载订单数据，确保状态更新
      debugPrint('从订单详情页返回，返回值: $value，开始重新加载订单数据...');
      
      // 立即重新加载，不使用延迟，确保获取最新数据
      await _loadOrders(preserveScrollPosition: true);
      
      // 延迟恢复滚动位置，确保列表已经重新构建
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_refreshController.hasClients && mounted) {
          _refreshController.animateTo(
            currentScrollOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  /// 同意售后申请
  void _approveAfterSales(String orderId, bool isRepair) {
    // 实现同意售后申请逻辑
    if (isRepair) {
      // 同意维修
      _productDatabaseService.approveRepair(orderId, '商家', '同意维修申请').then((_) {
        // 显示同意成功的提示
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功同意维修申请'),
            backgroundColor: const Color(0xFF13ec5b),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // 延迟重新加载订单数据，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          _loadOrders(preserveScrollPosition: true);
        });
      }).catchError((e) {
        debugPrint('同意维修失败: $e');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同意维修失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      });
    } else {
      // 同意退款
      _productDatabaseService
          .approveRefund(orderId, '商家', '同意退款申请',
              databaseService: _databaseService)
          .then((_) {
        // 显示同意成功的提示
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功同意退款申请'),
            backgroundColor: const Color(0xFF13ec5b),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // 延迟重新加载订单数据，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          _loadOrders(preserveScrollPosition: true);
        });
      }).catchError((e) {
        debugPrint('同意退款失败: $e');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同意退款失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      });
    }
  }

  /// 拒绝售后申请
  void _rejectAfterSales(String orderId, bool isRepair) {
    // 实现拒绝售后申请逻辑
    if (isRepair) {
      // 拒绝维修
      _productDatabaseService.rejectRepair(orderId, '商家', '拒绝维修申请').then((_) {
        // 显示拒绝成功的提示
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功拒绝维修申请'),
            backgroundColor: const Color(0xFF13ec5b),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // 延迟重新加载订单数据，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          _loadOrders(preserveScrollPosition: true);
        });
      }).catchError((e) {
        debugPrint('拒绝维修失败: $e');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拒绝维修失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      });
    } else {
      // 拒绝退款
      _productDatabaseService.rejectRefund(orderId, '商家', '拒绝退款申请').then((_) {
        // 显示拒绝成功的提示
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功拒绝退款申请'),
            backgroundColor: const Color(0xFF13ec5b),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // 延迟重新加载订单数据，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          _loadOrders(preserveScrollPosition: true);
        });
      }).catchError((e) {
        debugPrint('拒绝退款失败: $e');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拒绝退款失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      });
    }
  }

  /// 维修完成
  void _completeRepair(String orderId) {
    // 实现维修完成逻辑
    _productDatabaseService.completeRepair(orderId, '商家', '维修完成').then((_) {
      // 显示维修完成的提示
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功完成维修'),
          backgroundColor: const Color(0xFF13ec5b),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      // 延迟重新加载订单数据，确保数据库操作完成
      Future.delayed(const Duration(milliseconds: 300), () {
        _loadOrders(preserveScrollPosition: true);
      });
    }).catchError((e) {
      debugPrint('维修完成失败: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('维修完成失败: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  /// 取消订单
  void _cancelOrder(String orderId) {
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            '取消订单',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            '确定要取消这个订单吗？',
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 更新订单状态为已取消
                _productDatabaseService
                    .updateOrderStatus(orderId, '已取消')
                    .then((_) {
                  // 重新加载订单数据
                  _loadOrders(preserveScrollPosition: true);

                  // 显示取消成功的提示
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已成功取消订单'),
                      backgroundColor: theme.colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }).catchError((e) {
                  debugPrint('取消订单失败: $e');
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('取消订单失败: $e'),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('确认取消'),
            ),
          ],
        );
      },
    );
  }

  /// 联系买家
  void _contactBuyer(String orderId) {
    // 实现联系买家逻辑
    debugPrint('联系买家: $orderId');
  }

  /// 查看物流
  void _viewLogistics(String orderId) {
    // 实现查看物流逻辑
    debugPrint('查看物流: $orderId');
  }

  /// 导出订单数据
  void _exportOrders() async {
    // 实现订单导出逻辑
    debugPrint(
        '导出订单数据: ${_selectedOrderIds.isNotEmpty ? _selectedOrderIds.length : _filteredOrders.length}个订单');

    // 如果有选中的订单，只导出选中的订单，否则导出筛选后的所有订单
    final ordersToExport = _selectedOrderIds.isNotEmpty
        ? _orders
            .where((order) => _selectedOrderIds.contains(order.id))
            .toList()
        : _filteredOrders;

    if (ordersToExport.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('没有订单可以导出'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 准备CSV数据
    String csv = '订单编号,商品名称,商品图片,积分,订单时间,订单状态\n';

    for (var order in ordersToExport) {
      csv +=
          '"${order.id}","${order.productName}","${order.productImage}","${order.points}","${order.orderTime}","${_getStatusText(order.status)}"\n';
    }

    // 添加UTF-8 BOM以确保中文正常显示
    final bytes = utf8.encode(csv);
    final bom = utf8.encode('\ufeff');
    final bytesWithBom = [...bom, ...bytes];

    try {
      // 使用file_picker库让用户选择保存位置
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存订单数据',
        fileName: '订单数据_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savePath != null) {
        // 保存文件
        final file = File(savePath);
        await file.writeAsBytes(bytesWithBom);

        // 显示保存成功的提示
      ScaffoldMessenger.of(context).clearSnackBars();
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功导出 ${ordersToExport.length}个订单到 $savePath'),
          backgroundColor: theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      } else {
        // 用户取消了保存
        debugPrint('用户取消了导出');
      }
    } catch (e) {
      debugPrint('导出订单失败: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出订单失败: $e'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 获取状态文本
  String _getStatusText(MerchantOrderStatus status) {
    switch (status) {
      case MerchantOrderStatus.pendingPayment:
        return '待付款';
      case MerchantOrderStatus.pendingAccept:
        return '待接单';
      case MerchantOrderStatus.pendingShip:
        return '待发货';
      case MerchantOrderStatus.shipped:
        return '已发货';
      case MerchantOrderStatus.refunding:
        return '退款中';
      case MerchantOrderStatus.completed:
        return '已完成';
      case MerchantOrderStatus.cancelled:
        return '已取消';
      case MerchantOrderStatus.refunded:
        return '已退款';
      case MerchantOrderStatus.rejected:
        return '已拒单';
      default:
        return '未知状态';
    }
  }

  /// 渲染订单状态标签
  Widget _renderStatusBadge(MerchantOrderStatus status, ThemeData theme) {
    switch (status) {
      case MerchantOrderStatus.pendingPayment:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '待付款',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case MerchantOrderStatus.pendingAccept:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '待接单',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case MerchantOrderStatus.pendingShip:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '待发货',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case MerchantOrderStatus.shipped:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '已发货',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case MerchantOrderStatus.refunding:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sync_problem,
                size: 12,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                '退款中',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case MerchantOrderStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '已完成',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case MerchantOrderStatus.cancelled:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '已取消',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case MerchantOrderStatus.refunded:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '已退款',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case MerchantOrderStatus.repair:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.build,
                size: 12,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                '维修中',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case MerchantOrderStatus.rejected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '已拒单',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      default:
        return const SizedBox();
    }
  }

  /// 构建统计卡片
  Widget _buildStatCard(String title, String value, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取待处理订单数量
  int _getPendingOrdersCount() {
    return _orders.where((order) {
      return [
        MerchantOrderStatus.pendingAccept,
        MerchantOrderStatus.pendingShip,
        MerchantOrderStatus.refunding,
      ].contains(order.status);
    }).length;
  }

  /// 获取异常订单数量
  int _getAbnormalOrdersCount() {
    return _orders.where((order) => order.isAbnormal).length;
  }

  /// 获取已完成订单数量
  int _getCompletedOrdersCount() {
    return _orders
        .where((order) => order.status == MerchantOrderStatus.completed)
        .length;
  }

  /// 格式化日期范围显示
  String _formatDateRange() {
    if (_startDate == null && _endDate == null) {
      return '';
    }
    final start =
        _startDate != null ? '${_startDate!.month}/${_startDate!.day}' : '';
    final end = _endDate != null ? '${_endDate!.month}/${_endDate!.day}' : '';
    return '$start-$end';
  }

  /// 显示日期范围选择器
  void _showDateRangePicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surfaceVariant,
      isScrollControlled: true,
      builder: (context) => DateRangeFilterPanel(
        startDate: _startDate,
        endDate: _endDate,
        onDateChanged: (startDate, endDate) {
          setState(() {
            _startDate = startDate;
            _endDate = endDate;
            _applyFilters();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  /// 清除日期筛选
  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _applyFilters();
    });
  }

  /// 渲染订单操作按钮
  Widget _renderOrderActions(MerchantOrder order, ThemeData theme) {
    // 根据订单状态和售后类型获取操作按钮配置
    Map<String, dynamic> getActionConfig() {
      // 获取售后类型，默认是退款
      final isRepair = order.afterSalesType == 'repair';

      switch (order.status) {
        case MerchantOrderStatus.pendingPayment:
          return {
            'primaryAction': {
              'text': '联系买家',
              'icon': Icons.message,
              'color': const Color(0xFF13ec5b),
              'onPressed': () => _contactBuyer(order.id),
            },
            'secondaryAction': {
              'text': '取消订单',
              'color': Colors.red,
              'onPressed': () => _cancelOrder(order.id),
            },
          };
        case MerchantOrderStatus.pendingAccept:
          return {
            'primaryAction': {
              'text': '立即接单',
              'icon': Icons.check_circle,
              'color': const Color(0xFF13ec5b),
              'onPressed': () => _acceptOrder(order.id),
            },
            'secondaryAction': {
              'text': '拒单',
              'color': Colors.red,
              'onPressed': () => _rejectOrder(order.id),
            },
          };
        case MerchantOrderStatus.pendingShip:
          return {
            'primaryAction': {
              'text': '录入物流',
              'icon': Icons.local_shipping,
              'color': const Color(0xFF13ec5b),
              'onPressed': () => _enterLogistics(order.id),
            },
            'secondaryAction': {
              'text': '取消订单',
              'color': Colors.red,
              'onPressed': () => _cancelOrder(order.id),
            },
          };
        case MerchantOrderStatus.shipped:
          return {
            'primaryAction': {
              'text': '联系买家',
              'icon': Icons.message,
              'color': const Color(0xFF13ec5b),
              'onPressed': () => _contactBuyer(order.id),
            },
            'secondaryAction': {
              'text': '查看物流',
              'color': Colors.grey,
              'onPressed': () => _viewLogistics(order.id),
            },
          };
        case MerchantOrderStatus.refunding:
        case MerchantOrderStatus.repair:
          // 根据售后状态显示不同的按钮
          if (order.afterSalesStatus == 'approved' && isRepair) {
            // 维修已同意，显示维修完成按钮
            return {
              'primaryAction': {
                'text': '维修完成',
                'color': const Color(0xFF13ec5b),
                'onPressed': () => _completeRepair(order.id),
              },
            };
          } else {
            // 待审核状态，显示同意和拒绝按钮
            return {
              'primaryAction': {
                'text': isRepair ? '审核维修' : '审核退款',
                'color': const Color(0xFF13ec5b),
                'onPressed': () =>
                    _viewOrderDetails(order.id, showAfterSalesRecords: true),
              },
              'secondaryAction': {
                'text': isRepair ? '拒绝维修' : '拒绝退款',
                'color': Colors.red,
                'onPressed': () => _rejectAfterSales(order.id, isRepair),
              },
            };
          }
          ;
        case MerchantOrderStatus.refunded:
          return {
            'primaryAction': {
              'text': '查看详情',
              'color': Colors.grey,
              'onPressed': () => _viewOrderDetails(order.id),
            },
          };
        default:
          return {
            'primaryAction': {
              'text': '查看详情',
              'color': Colors.grey,
              'onPressed': () => _viewOrderDetails(order.id),
            },
          };
      }
    }

    final config = getActionConfig();
    final primaryAction = config['primaryAction'] as Map<String, dynamic>;
    final secondaryAction = config['secondaryAction'] as Map<String, dynamic>?;

    // 如果只有一个操作按钮，显示为单个按钮
    if (secondaryAction == null) {
      return Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(
          onPressed: primaryAction['onPressed'] as VoidCallback,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: primaryAction['color'] as Color,
            side: BorderSide(
                color: (primaryAction['color'] as Color).withOpacity(0.3)),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            primaryAction['text'] as String,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // 显示两个操作按钮
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: ElevatedButton(
            onPressed: secondaryAction['onPressed'] as VoidCallback,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: secondaryAction['color'] as Color,
              side: BorderSide(
                  color: (secondaryAction['color'] as Color).withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              secondaryAction['text'] as String,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: ElevatedButton(
            onPressed: primaryAction['onPressed'] as VoidCallback,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAction['color'] as Color,
              foregroundColor: primaryAction['color'] == const Color(0xFF13ec5b)
                  ? Colors.black
                  : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation:
                  primaryAction['color'] == const Color(0xFF13ec5b) ? 2 : 0,
              shadowColor: primaryAction['color'] == const Color(0xFF13ec5b)
                  ? const Color(0xFF13ec5b).withOpacity(0.3)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (primaryAction.containsKey('icon')) ...[
                  Icon(
                    primaryAction['icon'] as IconData,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  primaryAction['text'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '订单管理',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // 消息提醒图标
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () {
                  // 导航到商家消息中心页面
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MerchantMessageCenterPage(),
                    ),
                  ).then((_) => _loadOrders(preserveScrollPosition: true));
                },
              ),
              if (_unreadNotificationCount > 0) ...[
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            icon: Icon(
              _isBatchMode ? Icons.check_box_outlined : Icons.more_vert,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: _toggleBatchMode,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline,
                  width: 0.5,
                ),
              ),
              color: theme.colorScheme.surface,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusTab(MerchantOrderStatus.all, '全部'),
                  _buildStatusTab(MerchantOrderStatus.pendingAccept, '待接单'),
                  _buildStatusTab(MerchantOrderStatus.pendingShip, '待发货'),
                  _buildStatusTab(MerchantOrderStatus.shipped, '已发货'),
                  _buildStatusTab(MerchantOrderStatus.refunding, '退款中'),
                  _buildStatusTab(MerchantOrderStatus.rejected, '已拒单'),
                  _buildStatusTab(MerchantOrderStatus.completed, '已完成'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 搜索和日期筛选
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // 搜索输入框
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _applyFilters();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '订单号 / 买家手机号 / 商品',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 日期筛选按钮
                    ElevatedButton(
                      onPressed: () {
                        _showDateRangePicker(theme);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _startDate != null || _endDate != null
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : theme.colorScheme.surfaceVariant,
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: _startDate != null || _endDate != null
                            ? BorderSide(color: theme.colorScheme.primary)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          if (_startDate != null || _endDate != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              _formatDateRange(),
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // 批量操作栏
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _batchAcceptOrders,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              foregroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                            icon: const Icon(
                              Icons.checklist,
                              size: 16,
                            ),
                            label: Text(
                              '批量接单',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _batchShipOrders,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              foregroundColor: theme.colorScheme.onSurface,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            icon: const Icon(
                              Icons.local_shipping,
                              size: 16,
                            ),
                            label: Text(
                              '批量发货',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 导出数据按钮
                      TextButton.icon(
                        onPressed: _exportOrders,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                        ),
                        icon: const Icon(
                          Icons.download,
                          size: 16,
                        ),
                        label: Text(
                          '导出数据',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 订单列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceVariant,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : _filteredOrders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              '没有更多订单了',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _refreshController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _buildOrderCard(order, theme);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建订单卡片
  Widget _buildOrderCard(MerchantOrder order, ThemeData theme) {
    // 确定卡片的透明度
    double opacity = 1.0;
    if (order.status == MerchantOrderStatus.refunding ||
        order.status == MerchantOrderStatus.refunded) {
      opacity = 0.9;
    } else if (order.status == MerchantOrderStatus.completed) {
      opacity = 0.75;
    }

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        // 添加点击事件，跳转到订单详情页
        onTap: () => _viewOrderDetails(order.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Stack(
            children: [
              // 订单卡片内容
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 批量选择框
                    if (_isBatchMode) ...[
                      Row(
                        children: [
                          Checkbox(
                            value: _selectedOrderIds.contains(order.id),
                            onChanged: (value) =>
                                _toggleOrderSelection(order.id),
                            activeColor: theme.colorScheme.primary,
                            checkColor: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            order.id,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Monaco',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    // 订单头部
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_isBatchMode) ...[
                              Text(
                                'Order ID',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.id,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Monaco',
                                ),
                              ),
                            ],
                          ],
                        ),
                        _renderStatusBadge(order.status, theme),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 商品信息
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surface,
                          ),
                          child: order.productImage.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: order.productImage,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF13ec5b),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(order.productImage),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.productName,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (order.productVariant.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      order.productVariant,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  if (order.refundReason != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      order.refundReason!,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.yellow,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.points.toString(),
                                    style: const TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Monaco',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 买家信息
                    if (order.status != MerchantOrderStatus.completed) ...[
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                order.buyerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 1,
                                height: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                order.buyerPhone,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Monaco',
                                ),
                              ),
                            ],
                          ),
                          if (order.status ==
                              MerchantOrderStatus.pendingAccept) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Colors.grey,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${order.orderTime.year}-${order.orderTime.month.toString().padLeft(2, '0')}-${order.orderTime.day.toString().padLeft(2, '0')} ${order.orderTime.hour.toString().padLeft(2, '0')}:${order.orderTime.minute.toString().padLeft(2, '0')}:${order.orderTime.second.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                    // 操作按钮
                    const SizedBox(height: 16),
                    _renderOrderActions(order, theme),
                  ],
                ),
              ),
              // 消息提示
              if (_unreadMessageCounts.containsKey(order.id)) ...[
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _unreadMessageCounts[order.id]!.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  /// 构建筛选选项
  Widget _buildFilterOption(String label, String value, String selectedValue,
      Function(String) onChanged) {
    final isSelected = selectedValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF13ec5b) : const Color(0xFF1e3626),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusTab(MerchantOrderStatus status, String title) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
          _applyFilters();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF13ec5b) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF92c9a4),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
