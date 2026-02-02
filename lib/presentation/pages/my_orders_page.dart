import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/cart_database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'order_detail_page.dart';
import 'after_sales_page.dart';
import 'after_sales_apply_page.dart';
import 'review_page.dart';
import 'review_edit_page.dart';
import 'address_select_page.dart';
import 'client_message_center_page.dart';

/// 订单状态枚举
enum OrderStatus {
  all,
  pendingPayment,
  pendingShipment,
  pendingReceipt,
  completed,
  refundAfterSales,
  pendingReview,
  shipped,
  refunded,
  canceled, // 已取消
}

/// 订单类型枚举
enum OrderType {
  normal,
  preSale,
  flashSale,
}

/// 订单项模型
class OrderItem {
  final String id;
  final String name;
  final String image;
  final String variant;
  final double price;
  final int quantity;

  OrderItem({
    required this.id,
    required this.name,
    required this.image,
    required this.variant,
    required this.price,
    required this.quantity,
  });
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
}

/// 物流信息模型
class LogisticsInfo {
  final String status;
  final String description;
  final DateTime timestamp;
  final String? trackingNumber;
  final String? logisticsCompany;
  final List<LogisticsTrack>? tracks;

  LogisticsInfo({
    required this.status,
    required this.description,
    required this.timestamp,
    this.trackingNumber,
    this.logisticsCompany,
    this.tracks,
  });
}

/// 订单模型
/// 支付方式枚举
enum PaymentMethod {
  cash, // 现金
  points, // 积分
  hybrid, // 混合
}

/// 售后记录类，用于表示单条售后记录
class AfterSalesRecord {
  final String? id;
  final String type; // repair: 维修, refund: 退款
  final String? reason;
  final String? description;
  final List<String>? images;
  final DateTime createTime;
  final String? status;
  final String? result;
  final DateTime? handleTime;

  AfterSalesRecord({
    this.id,
    required this.type,
    this.reason,
    this.description,
    this.images,
    required this.createTime,
    this.status,
    this.result,
    this.handleTime,
  });

  /// 从Map转换为AfterSalesRecord对象
  factory AfterSalesRecord.fromMap(Map<String, dynamic> map) {
    // 处理售后图片列表
    List<String>? images;
    
    // 检查after_sales_images字段的类型
    final imagesData = map['after_sales_images'];
    if (imagesData != null) {
      try {
        if (imagesData is List<dynamic>) {
          // 如果已经是List类型，直接转换为String列表
          images = imagesData.map((item) => item.toString()).toList();
        } else if (imagesData is String) {
          final imagesStr = imagesData;
          if (imagesStr.isNotEmpty && imagesStr != '[]') {
            // 检查是否是直接的文件路径格式，如[C:\path\to\file.png]或直接的文件路径
            if (imagesStr.startsWith('[') && imagesStr.endsWith(']')) {
              // 去除前后的[]
              String cleanedStr = imagesStr.substring(1, imagesStr.length - 1);
              
              // 检查是否包含逗号
              if (cleanedStr.contains(',')) {
                // 多个文件路径，按逗号分割
                List<String> imagesList = cleanedStr.split(',');
                // 清理每个图片URL
                images = imagesList.map((img) {
                  // 去除前后的空格
                  String cleanedImg = img.trim();
                  // 去除可能存在的引号
                  if ((cleanedImg.startsWith('"') && cleanedImg.endsWith('"')) ||
                      (cleanedImg.startsWith("'") && cleanedImg.endsWith("'"))) {
                    cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
                  }
                  return cleanedImg;
                }).toList();
              } else {
                // 单个文件路径
                String cleanedImg = cleanedStr.trim();
                // 去除可能存在的引号
                if ((cleanedImg.startsWith('"') && cleanedImg.endsWith('"')) ||
                    (cleanedImg.startsWith("'") && cleanedImg.endsWith("'"))) {
                  cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
                }
                images = [cleanedImg];
              }
            } else if (imagesStr.contains('\\') || imagesStr.startsWith('http')) {
              // 直接的文件路径或URL，没有[]包裹
              images = [imagesStr];
            } else {
              // 尝试JSON解析
              try {
                final List<dynamic> parsed = json.decode(imagesStr);
                images = parsed.cast<String>();
              } catch (jsonError) {
                debugPrint('JSON解析失败: $jsonError');
                // 如果JSON解析失败，直接作为单个路径处理
                images = [imagesStr];
              }
            }
          }
        }
      } catch (e) {
        debugPrint('解析售后图片失败: $e');
        // 如果所有解析都失败，使用空列表
        images = [];
      }
    }

    return AfterSalesRecord(
      id: map['id'] as String?,
      type: map['after_sales_type'] as String? ?? 'refund',
      reason: map['after_sales_reason'] as String?,
      description: map['after_sales_description'] as String?,
      images: images,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['after_sales_create_time'] as int),
      status: map['after_sales_status'] as String?,
      result: map['after_sales_result'] as String?,
      handleTime: map['after_sales_handle_time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['after_sales_handle_time'] as int)
          : null,
    );
  }
}

class Order {
  final String id;
  final String storeName;
  final List<OrderItem> items;
  final double totalPrice;
  final DateTime date;
  final OrderStatus status;
  final OrderType orderType;
  final LogisticsInfo? logisticsInfo;
  int? remainingPaymentTime;
  final int totalItems;
  final PaymentMethod paymentMethod;
  final int pointsUsed;
  final double cashAmount;
  
  // 单个售后记录字段（兼容旧数据）
  final String? afterSalesType;
  final String? afterSalesReason;
  final String? afterSalesDescription;
  final List<String>? afterSalesImages;
  final DateTime? afterSalesCreateTime;
  final String? afterSalesStatus;
  
  // 多个售后记录字段（新功能）
  final List<AfterSalesRecord>? afterSalesRecords;

  Order({
    required this.id,
    required this.storeName,
    required this.items,
    required this.totalPrice,
    required this.date,
    required this.status,
    this.orderType = OrderType.normal,
    this.logisticsInfo,
    this.remainingPaymentTime,
    required this.totalItems,
    this.paymentMethod = PaymentMethod.cash,
    this.pointsUsed = 0,
    this.cashAmount = 0.0,
    // 单个售后记录字段初始化
    this.afterSalesType,
    this.afterSalesReason,
    this.afterSalesDescription,
    this.afterSalesImages,
    this.afterSalesCreateTime,
    this.afterSalesStatus,
    // 多个售后记录字段初始化
    this.afterSalesRecords,
  });

  /// 从Map转换为Order对象
  factory Order.fromMap(Map<String, dynamic> map) {
    // 安全处理Map数据，添加空值检查
    final productName = (map['product_name'] ?? '') as String;
    final productImage = (map['product_image'] ?? '') as String;
    final quantity = (map['quantity'] ?? 1) as int;
    final points = (map['points'] ?? 0) as int; // 使用points作为积分价格
    
    // 转换订单状态
    OrderStatus status;
    switch (map['status'] as String? ?? '') {
      case '待付款':
        status = OrderStatus.pendingPayment;
        break;
      case '待发货':
        status = OrderStatus.pendingShipment;
        break;
      case '已发货':
        status = OrderStatus.pendingReceipt;
        break;
      case '已完成':
        status = OrderStatus.completed;
        break;
      case '售后':
      case '退款中':
      case '维修中':
      case 'refunding':
        status = OrderStatus.refundAfterSales;
        break;
      case '待评价':
        status = OrderStatus.pendingReview;
        break;
      case '已取消':
        status = OrderStatus.canceled;
        break;
      case '已退款':
        status = OrderStatus.refunded;
        break;
      default:
        status = OrderStatus.completed;
    }
    
    // 转换支付方式
    PaymentMethod paymentMethod;
    final paymentMethodStr = map['payment_method'] as String?;
    final pointsUsed = (map['points_used'] ?? 0) as int;
    // 安全转换cash_amount：先转为num，再转为double
    final cashAmount = ((map['cash_amount'] ?? 0) as num).toDouble();
    // 安全转换product_price：先转为num，再转为double
    final productPrice = ((map['product_price'] ?? 0) as num).toDouble();
    
    // 优先使用直接存储的支付方式字符串
    if (paymentMethodStr != null) {
      switch (paymentMethodStr) {
        case 'points':
          paymentMethod = PaymentMethod.points;
          break;
        case 'hybrid':
          paymentMethod = PaymentMethod.hybrid;
          break;
        default:
          paymentMethod = PaymentMethod.cash;
          break;
      }
    } else {
      // 备用逻辑：基于pointsUsed和cashAmount判断支付方式
      if (pointsUsed > 0 && cashAmount > 0) {
        paymentMethod = PaymentMethod.hybrid;
      } else if (pointsUsed > 0 || points > 0) {
        paymentMethod = PaymentMethod.points;
      } else {
        paymentMethod = PaymentMethod.cash;
      }
    }
    
    // 根据支付方式计算总价
    double totalPrice;
    switch (paymentMethod) {
      case PaymentMethod.points:
        totalPrice = points.toDouble() * quantity;
        break;
      case PaymentMethod.cash:
        totalPrice = productPrice * quantity;
        break;
      case PaymentMethod.hybrid:
        totalPrice = cashAmount;
        break;
      default:
        totalPrice = 0.0;
    }
    
    // 售后相关字段转换
    final afterSalesType = map['after_sales_type'] as String?;
    final afterSalesReason = map['after_sales_reason'] as String?;
    final afterSalesDescription = map['after_sales_description'] as String?;
    
    // 处理售后图片列表，将字符串转换为List<String>
    List<String>? afterSalesImages;
    final afterSalesImagesStr = map['after_sales_images'] as String?;
    if (afterSalesImagesStr != null && afterSalesImagesStr.isNotEmpty && afterSalesImagesStr != '[]') {
      try {
        // 检查是否是直接的文件路径格式，如[C:\path\to\file.png]
        if (afterSalesImagesStr.startsWith('[') && afterSalesImagesStr.endsWith(']')) {
          // 去除前后的[]
          String cleanedStr = afterSalesImagesStr.substring(1, afterSalesImagesStr.length - 1);
          
          // 检查是否是单个文件路径
          if (cleanedStr.contains('\\') || cleanedStr.startsWith('http')) {
            // 直接的文件路径，添加到列表中
            afterSalesImages = [cleanedStr];
          } else if (cleanedStr.contains(',')) {
            // 多个文件路径，按逗号分割
            List<String> imagesList = cleanedStr.split(',');
            // 清理每个图片URL
            afterSalesImages = imagesList.map((img) {
              // 去除前后的空格
              String cleanedImg = img.trim();
              // 去除可能存在的引号
              if ((cleanedImg.startsWith('"') && cleanedImg.endsWith('"')) ||
                  (cleanedImg.startsWith("'") && cleanedImg.endsWith("'"))) {
                cleanedImg = cleanedImg.substring(1, cleanedImg.length - 1);
              }
              return cleanedImg;
            }).toList();
          } else if (cleanedStr.isNotEmpty) {
            // 单个文件路径，没有逗号
            afterSalesImages = [cleanedStr];
          }
        } else {
          // 尝试JSON解析
          try {
            final List<dynamic> parsed = json.decode(afterSalesImagesStr);
            afterSalesImages = parsed.cast<String>();
          } catch (jsonError) {
            // 如果JSON解析失败，直接将其作为单个路径处理
            afterSalesImages = [afterSalesImagesStr];
          }
        }
      } catch (e) {
        debugPrint('解析售后图片失败: $e');
        // 如果所有解析都失败，使用空列表
        afterSalesImages = [];
      }
    }
    
    final afterSalesCreateTimeMillis = map['after_sales_create_time'] as int?;
    final afterSalesCreateTime = afterSalesCreateTimeMillis != null 
        ? DateTime.fromMillisecondsSinceEpoch(afterSalesCreateTimeMillis)
        : null;
    final afterSalesStatus = map['after_sales_status'] as String?;
    
    // 处理多个售后记录
    List<AfterSalesRecord>? afterSalesRecords;
    
    try {
      // 检查after_sales_records字段的类型
      final afterSalesRecordsData = map['after_sales_records'];
      if (afterSalesRecordsData != null) {
        List<dynamic> parsed;
        
        if (afterSalesRecordsData is String) {
          // 如果是字符串类型，尝试JSON解析
          final afterSalesRecordsStr = afterSalesRecordsData;
          if (afterSalesRecordsStr.isNotEmpty && afterSalesRecordsStr != '[]') {
            parsed = json.decode(afterSalesRecordsStr);
          } else {
            parsed = [];
          }
        } else if (afterSalesRecordsData is List<dynamic>) {
          // 如果已经是List类型，直接使用
          parsed = afterSalesRecordsData;
        } else {
          // 其他类型，使用空列表
          parsed = [];
        }
        
        // 转换为AfterSalesRecord列表
        if (parsed.isNotEmpty) {
          afterSalesRecords = parsed.map((item) {
            if (item is Map<String, dynamic>) {
              return AfterSalesRecord.fromMap(item);
            } else {
              debugPrint('无效的售后记录格式: $item');
              return null;
            }
          }).where((record) => record != null).cast<AfterSalesRecord>().toList();
        }
      }
    } catch (e) {
      debugPrint('解析售后记录列表失败: $e');
      // 如果解析失败，不创建单条售后记录，而是继续尝试从其他字段获取
      afterSalesRecords = [];
    }
    
    // 注意：这里不再从数据库获取退款请求记录，因为fromMap方法不是异步的
    // 退款请求记录已经在getOrdersByUserId方法中被添加到after_sales_records字段中
    
    // 如果没有多条售后记录，检查是否有单条售后记录，有则创建一个列表
    if (afterSalesRecords == null || afterSalesRecords.isEmpty) {
      if (afterSalesType != null || 
          afterSalesReason != null || 
          afterSalesDescription != null ||
          afterSalesImages != null ||
          afterSalesCreateTime != null ||
          afterSalesStatus != null) {
        // 创建单条售后记录
        final singleRecord = AfterSalesRecord(
          id: (map['id'] ?? '') as String,
          type: afterSalesType ?? 'refund',
          reason: afterSalesReason,
          description: afterSalesDescription,
          images: afterSalesImages,
          createTime: afterSalesCreateTime ?? DateTime.now(),
          status: afterSalesStatus,
        );
        afterSalesRecords = [singleRecord];
      }
    }
    
    // 去重，确保每个记录唯一
    if (afterSalesRecords != null && afterSalesRecords.isNotEmpty) {
      final uniqueRecords = <AfterSalesRecord>[];
      final seenIds = <String>{};
      for (final record in afterSalesRecords) {
        if (record.id != null && record.id!.isNotEmpty) {
          // 如果有有效的ID，使用ID作为唯一标识
          if (!seenIds.contains(record.id!)) {
            seenIds.add(record.id!);
            uniqueRecords.add(record);
          }
        } else {
          // 如果没有有效的ID，使用type、reason和createTime的组合作为唯一标识，处理null值
          final reasonStr = record.reason ?? 'no_reason';
          final uniqueKey = '${record.type}_${reasonStr}_${record.createTime.millisecondsSinceEpoch}';
          if (!seenIds.contains(uniqueKey)) {
            seenIds.add(uniqueKey);
            uniqueRecords.add(record);
          }
        }
      }
      
      // 按创建时间降序排序，确保最新的记录在前面
      uniqueRecords.sort((a, b) => b.createTime.compareTo(a.createTime));
      
      // 更新afterSalesRecords为去重并排序后的记录
      afterSalesRecords = uniqueRecords;
    }
    
    return Order(
      id: (map['id'] ?? '') as String,
      storeName: (map['store_name'] ?? '未知店铺') as String,
      items: [
        OrderItem(
          id: (map['product_id'] ?? '').toString(), // 将product_id转换为字符串，而不是直接强制转换
          name: productName,
          image: productImage,
          variant: (map['variant'] ?? '') as String, // 从数据库获取规格信息
          price: paymentMethod == PaymentMethod.points ? points.toDouble() : productPrice,
          quantity: quantity,
        ),
      ],
      totalPrice: totalPrice,
      date: DateTime.fromMillisecondsSinceEpoch((map['created_at'] ?? 0) as int),
      status: status,
      orderType: OrderType.normal,
      totalItems: quantity,
      paymentMethod: paymentMethod,
      pointsUsed: pointsUsed,
      cashAmount: cashAmount,
      // 单个售后记录字段（兼容旧数据）
      afterSalesType: afterSalesType,
      afterSalesReason: afterSalesReason,
      afterSalesDescription: afterSalesDescription,
      afterSalesImages: afterSalesImages,
      afterSalesCreateTime: afterSalesCreateTime,
      afterSalesStatus: afterSalesStatus,
      // 多个售后记录字段（新功能）
      afterSalesRecords: afterSalesRecords,
    );
  }
}

/// 我的订单页面
class MyOrdersPage extends ConsumerStatefulWidget {
  /// 构造函数
  const MyOrdersPage({super.key});

  @override
  ConsumerState<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends ConsumerState<MyOrdersPage> {
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  List<Order> _paginatedOrders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  OrderStatus _currentStatus = OrderStatus.all;
  OrderType _currentOrderType = OrderType.normal;
  bool _showOrderTypeFilter = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showDateFilter = false;
  double? _minAmount;
  double? _maxAmount;
  bool _showAmountFilter = false;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  Timer? _countdownTimer;
  bool _isBatchMode = false;
  List<String> _selectedOrderIds = [];
  bool _selectAll = false;
  /// 通知服务实例
  final NotificationDatabaseService _notificationService = NotificationDatabaseService();
  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();
  /// 未读消息数量
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _scrollController.addListener(_onScroll);
    // 加载未读消息数量
    _loadUnreadNotificationCount();
  }

  /// 加载未读消息数量
  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (e) {
      print('加载未读消息数量失败: $e');
      // 出错时保持默认值0
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _stopCountdown();
    super.dispose();
  }

  /// 开始倒计时计时器
  void _startCountdown() {
    // 先停止之前的计时器
    _stopCountdown();
    
    // 每秒更新一次倒计时
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // 更新所有待付款订单的剩余时间
        for (var order in _orders) {
          if (order.status == OrderStatus.pendingPayment && order.remainingPaymentTime != null && order.remainingPaymentTime! > 0) {
            order.remainingPaymentTime = order.remainingPaymentTime! - 1;
          }
        }
        
        // 重新应用筛选，更新分页列表
        _applyFilters();
      });
    });
  }

  /// 停止倒计时计时器
  void _stopCountdown() {
    if (_countdownTimer != null) {
      _countdownTimer!.cancel();
      _countdownTimer = null;
    }
  }

  @override
  void didUpdateWidget(covariant MyOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyFilters();
  }

  /// 滚动监听，实现上拉加载更多
  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    
    final scrollPosition = _scrollController.position;
    final maxScrollExtent = scrollPosition.maxScrollExtent;
    final currentScrollExtent = scrollPosition.pixels;
    
    // 当滚动到距离底部100像素时加载更多
    if (currentScrollExtent >= maxScrollExtent - 100) {
      _loadMoreOrders();
    }
  }

  /// 加载更多订单
  void _loadMoreOrders() {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    // 移除模拟网络请求延迟，直接加载更多订单
    // 计算新的分页数据，保持与原逻辑一致
    final nextPage = _currentPage + 1;
    final startIndex = _currentPage * _pageSize; // 当前页的下一页开始位置
    final endIndex = startIndex + _pageSize;
    
    // 添加新的订单到分页列表
    if (startIndex < _filteredOrders.length) {
      final newOrders = _filteredOrders.sublist(
        startIndex,
        endIndex > _filteredOrders.length ? _filteredOrders.length : endIndex,
      );
      
      // 使用setState更新状态，只更新必要的部分
      setState(() {
        _currentPage = nextPage;
        _paginatedOrders.addAll(newOrders);
        _hasMore = endIndex < _filteredOrders.length;
        _isLoadingMore = false;
      });
    } else {
      // 没有更多数据了
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    }
  }

  /// 应用所有筛选条件
  void _applyFilters({bool preserveScrollPosition = false}) {
    setState(() {
      // 只有在不保留滚动位置时才重置分页状态
      if (!preserveScrollPosition) {
        _currentPage = 1;
        _hasMore = true;
      }
      
      // 预计算搜索查询，避免在循环中重复计算
      final searchQuery = _searchQuery.toLowerCase();
      final isSearchEmpty = searchQuery.isEmpty;
      
      // 筛选所有订单
      _filteredOrders = _orders.where((order) {
        // 状态筛选 - 最快速的筛选，先执行
        if (_currentStatus != OrderStatus.all) {
          // 如果选择的是退款/售后分类，则包含refundAfterSales和refunded两种状态
          if (_currentStatus == OrderStatus.refundAfterSales) {
            if (order.status != OrderStatus.refundAfterSales && order.status != OrderStatus.refunded) {
              return false;
            }
          } else {
            // 其他分类只显示对应状态
            if (order.status != _currentStatus) {
              return false;
            }
          }
        }
        
        // 订单类型筛选 - 快速筛选，其次执行
        // 当_currentOrderType为OrderType.normal时，表示不筛选订单类型（显示全部）
        if (_currentOrderType != OrderType.normal && order.orderType != _currentOrderType) {
          return false;
        }
        
        // 金额范围筛选 - 数值比较，快速执行
        if (_minAmount != null && order.totalPrice < _minAmount!) {
          return false;
        }
        if (_maxAmount != null && order.totalPrice > _maxAmount!) {
          return false;
        }
        
        // 日期筛选 - 日期比较，中等速度执行
        if (_startDate != null && order.date.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && order.date.isAfter(_endDate!)) {
          return false;
        }
        
        // 搜索筛选 - 字符串操作，最慢，最后执行
        if (!isSearchEmpty) {
          // 先检查订单号和商家名称，再检查商品信息
          if (order.id.toLowerCase().contains(searchQuery) ||
              order.storeName.toLowerCase().contains(searchQuery)) {
            return true;
          }
          // 只在需要时检查商品信息，避免不必要的循环
          return order.items.any((item) => 
            item.name.toLowerCase().contains(searchQuery) ||
            item.variant.toLowerCase().contains(searchQuery));
        }
        
        return true;
      }).toList();
      
      // 初始化或更新分页数据
      if (!preserveScrollPosition || _currentPage == 1) {
        // 正常初始化分页数据
        final endIndex = _pageSize > _filteredOrders.length ? _filteredOrders.length : _pageSize;
        _paginatedOrders = _filteredOrders.sublist(0, endIndex);
      } else {
        // 保留当前分页状态，重新计算分页数据
        final startIndex = (_currentPage - 1) * _pageSize;
        final endIndex = startIndex + _pageSize > _filteredOrders.length ? _filteredOrders.length : startIndex + _pageSize;
        if (startIndex < _filteredOrders.length) {
          _paginatedOrders = _filteredOrders.sublist(startIndex, endIndex);
        } else {
          // 如果当前页超出范围，返回最后一页
          _currentPage = (_filteredOrders.length + _pageSize - 1) ~/ _pageSize;
          final lastStartIndex = (_currentPage - 1) * _pageSize;
          _paginatedOrders = _filteredOrders.sublist(lastStartIndex);
        }
      }
      _hasMore = _paginatedOrders.length < _filteredOrders.length;
    });
  }

  /// 从数据库加载订单数据
  Future<void> _loadOrders() async {
    // 保存当前可见区域的订单ID，用于恢复滚动位置
    List<String> visibleOrderIds = [];
    if (_scrollController.hasClients && _paginatedOrders.isNotEmpty) {
      // 获取当前滚动位置
      final scrollPosition = _scrollController.position;
      final viewportDimension = scrollPosition.viewportDimension;
      
      // 保存当前页面的订单ID，优先保存中间位置的订单ID
      int middleIndex = _paginatedOrders.length ~/ 2;
      visibleOrderIds.add(_paginatedOrders[middleIndex].id);
      
      // 同时保存当前显示的第一个和最后一个订单ID作为备选
      if (_paginatedOrders.length > 1) {
        visibleOrderIds.add(_paginatedOrders.first.id);
        visibleOrderIds.add(_paginatedOrders.last.id);
      }
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      final db = DatabaseService();
      final userId = await db.getCurrentUserId() ?? 'default_user';
      final orderMaps = await db.getOrdersByUserId(userId);
      final orders = orderMaps.map((map) => Order.fromMap(map)).toList();
      
      setState(() {
        _orders = orders;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      // 如果加载失败，使用空列表
      _orders = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
      
      // 重新应用筛选，获取最新的订单列表
      _applyFilters(preserveScrollPosition: false);
      _startCountdown();
      
      // 尝试恢复滚动位置
      if (visibleOrderIds.isNotEmpty && mounted) {
        // 延迟一下，确保列表已经重新构建
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          
          // 在新的订单列表中查找之前可见的订单
          String? targetOrderId;
          for (String orderId in visibleOrderIds) {
            if (_orders.any((order) => order.id == orderId)) {
              targetOrderId = orderId;
              break;
            }
          }
          
          if (targetOrderId != null) {
            // 查找目标订单在新列表中的索引
            int targetIndex = _orders.indexWhere((order) => order.id == targetOrderId);
            if (targetIndex != -1) {
              // 计算应该显示的页码
              int targetPage = (targetIndex ~/ _pageSize) + 1;
              
              // 更新页码并重新获取分页数据
              setState(() {
                _currentPage = targetPage;
                final startIndex = (targetPage - 1) * _pageSize;
                final endIndex = startIndex + _pageSize > _filteredOrders.length ? _filteredOrders.length : startIndex + _pageSize;
                _paginatedOrders = _filteredOrders.sublist(startIndex, endIndex);
              });
              
              // 延迟再次执行，确保setState完成
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_scrollController.hasClients && mounted) {
                  // 滚动到页面顶部，这样用户就能看到目标订单
                  _scrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              });
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: null,
      body: Column(
        children: [
          // 顶部固定的标签栏
          _buildStickyHeader(theme),
          // 搜索和筛选栏
          _buildSearchAndFilters(theme),
          // 订单列表
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)) 
              : _buildOrdersList(theme),
          ),
        ],
      ),
      // 批量操作底部栏
      persistentFooterButtons: _isBatchMode ? _buildBatchOperationButtons(theme) : null,
      // 底部导航栏 - 只在手机端显示
      bottomNavigationBar: _isBatchMode ? null : (MediaQuery.of(context).size.width < 600 ? _buildBottomNavigation(theme) : null),
    );
  }

  /// 构建固定的头部标签栏
  Widget _buildStickyHeader(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // 顶部栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    if (_isBatchMode) {
                      // 退出批量选择模式
                      setState(() {
                        _isBatchMode = false;
                        _selectedOrderIds.clear();
                        _selectAll = false;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(
                    _isBatchMode ? Icons.close : Icons.arrow_back_ios_new, 
                    color: theme.colorScheme.onSurface,
                  ),
                  padding: const EdgeInsets.all(8),
                ),
                Text(
                  _isBatchMode ? '选择订单' : '我的订单',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // 通知图标
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            // 导航到客户端消息中心页面
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ClientMessageCenterPage(),
                              ),
                            ).then((_) {
                              // 从消息中心返回时，重新加载未读消息数量
                              _loadUnreadNotificationCount();
                            });
                          },
                          icon: Icon(
                            Icons.notifications,
                            color: theme.colorScheme.onSurface,
                          ),
                          padding: const EdgeInsets.all(8),
                          iconSize: 24,
                        ),
                        // 显示未读通知数量
                        if (_unreadNotificationCount > 0) 
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _unreadNotificationCount > 9 ? 
                                Text(
                                  '9+',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ) : Text(
                                  _unreadNotificationCount.toString(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        if (_isBatchMode) {
                          // 全选/取消全选
                          _toggleSelectAll();
                        } else {
                          // 进入批量选择模式
                          setState(() {
                            _isBatchMode = true;
                          });
                        }
                      },
                      icon: Icon(
                        _isBatchMode ? Icons.check_box_outlined : Icons.more_vert,
                        color: theme.colorScheme.onSurface,
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 批量选择栏
          if (_isBatchMode)
            _buildBatchSelectBar(theme),
          // 订单状态标签（非批量模式下显示）
          if (!_isBatchMode)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 8, // 显示8个主要状态
                itemBuilder: (context, index) {
                  // 只显示需要的状态
                  final statusesToShow = [
                    OrderStatus.all,
                    OrderStatus.pendingPayment,
                    OrderStatus.pendingShipment,
                    OrderStatus.pendingReceipt,
                    OrderStatus.completed,
                    OrderStatus.refundAfterSales,
                    OrderStatus.pendingReview,
                    OrderStatus.canceled,
                  ];
                  final status = statusesToShow[index];
                  return _buildStatusTab(status, theme);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 构建批量选择栏
  Widget _buildBatchSelectBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            onChanged: (value) {
              _toggleSelectAll();
            },
            activeColor: theme.colorScheme.primary,
            checkColor: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            '全选',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '已选择 ${_selectedOrderIds.length} 个订单',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedOrderIds = _paginatedOrders.map((order) => order.id).toList();
      } else {
        _selectedOrderIds.clear();
      }
    });
  }

  /// 构建状态标签
  Widget _buildStatusTab(OrderStatus status, ThemeData theme) {
    final isActive = _currentStatus == status;
    String label;
    
    switch (status) {
      case OrderStatus.all:
        label = '全部';
        break;
      case OrderStatus.pendingPayment:
        label = '待付款';
        break;
      case OrderStatus.pendingShipment:
        label = '待发货';
        break;
      case OrderStatus.pendingReceipt:
        label = '待收货';
        break;
      case OrderStatus.completed:
        label = '已完成';
        break;
      case OrderStatus.refundAfterSales:
        label = '退款/售后';
        break;
      case OrderStatus.pendingReview:
        label = '待评价';
        break;
      case OrderStatus.canceled:
        label = '已取消';
        break;
      default:
        label = '';
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentStatus = status;
        });
        _applyFilters();
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
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// 构建搜索和筛选栏
  Widget _buildSearchAndFilters(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 搜索框和售后入口
          Row(
            children: [
              Expanded(
                // 搜索框
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                      hintText: '搜索订单号 / 商品 / 商家名称',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _applyFilters();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 售后入口按钮
              ElevatedButton.icon(
                onPressed: _navigateToAfterSales,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.help_outline, size: 16),
                label: Text('售后', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 筛选标签
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  icon: Icons.calendar_today,
                  label: '时间筛选',
                  isActive: _showDateFilter,
                  showArrow: true,
                  onTap: () {
                    setState(() {
                      _showDateFilter = !_showDateFilter;
                      _showOrderTypeFilter = false;
                      _showAmountFilter = false;
                    });
                  },
                  theme: theme,
                ),
                _buildFilterChip(
                  icon: Icons.shopping_bag,
                  label: '订单类型',
                  isActive: _showOrderTypeFilter,
                  showArrow: true,
                  onTap: () {
                    setState(() {
                      _showOrderTypeFilter = !_showOrderTypeFilter;
                      _showDateFilter = false;
                      _showAmountFilter = false;
                    });
                  },
                  theme: theme,
                ),
                _buildFilterChip(
                  icon: Icons.attach_money,
                  label: '金额范围',
                  isActive: _showAmountFilter,
                  showArrow: true,
                  onTap: () {
                    setState(() {
                      _showAmountFilter = !_showAmountFilter;
                      _showDateFilter = false;
                      _showOrderTypeFilter = false;
                    });
                  },
                  theme: theme,
                ),
                _buildFilterChip(
                  label: '即将过期',
                  isActive: false,
                  theme: theme,
                ),
              ],
            ),
          ),
          // 展开的筛选选项
          if (_showDateFilter) _buildDateFilter(theme),
          if (_showOrderTypeFilter) _buildOrderTypeFilter(theme),
          if (_showAmountFilter) _buildAmountFilter(theme),
        ],
      ),
    );
  }

  /// 构建筛选标签
  Widget _buildFilterChip({
    IconData? icon,
    required String label,
    required bool isActive,
    bool showArrow = false,
    VoidCallback? onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.surfaceVariant : theme.colorScheme.surface,
          border: Border.all(
            color: isActive ? theme.colorScheme.outline : theme.colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(icon, color: theme.colorScheme.onSurface, size: 18),
              ),
            Text(
              label,
              style: TextStyle(
                color: isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showArrow)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建日期筛选UI
  Widget _buildDateFilter(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '时间范围',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDateOption('近7天', () {
                setState(() {
                  _startDate = DateTime.now().subtract(const Duration(days: 7));
                  _endDate = DateTime.now();
                });
                _applyFilters();
              }, theme),
              _buildDateOption('近30天', () {
                setState(() {
                  _startDate = DateTime.now().subtract(const Duration(days: 30));
                  _endDate = DateTime.now();
                });
                _applyFilters();
              }, theme),
              _buildDateOption('自定义', () {
                // 这里可以实现自定义日期选择器
                // 为了简化，我们使用当前日期作为示例
                setState(() {
                  _startDate = DateTime.now().subtract(const Duration(days: 90));
                  _endDate = DateTime.now();
                });
                _applyFilters();
              }, theme),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建日期选项
  Widget _buildDateOption(String label, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 构建订单类型筛选UI
  Widget _buildOrderTypeFilter(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订单类型',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOrderTypeOption('全部', null, () {
                setState(() {
                  _currentOrderType = OrderType.normal;
                });
                _applyFilters();
              }, theme),
              _buildOrderTypeOption('普通订单', OrderType.normal, () {
                setState(() {
                  _currentOrderType = OrderType.normal;
                });
                _applyFilters();
              }, theme),
              _buildOrderTypeOption('预售订单', OrderType.preSale, () {
                setState(() {
                  _currentOrderType = OrderType.preSale;
                });
                _applyFilters();
              }, theme),
              _buildOrderTypeOption('秒杀订单', OrderType.flashSale, () {
                setState(() {
                  _currentOrderType = OrderType.flashSale;
                });
                _applyFilters();
              }, theme),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建订单类型选项
  Widget _buildOrderTypeOption(String label, OrderType? type, VoidCallback onTap, ThemeData theme) {
    final isActive = type == null ? _currentOrderType == OrderType.normal : _currentOrderType == type;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.surface : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 构建金额范围筛选UI
  Widget _buildAmountFilter(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '金额范围',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAmountOption('全部', null, null, () {
                setState(() {
                  _minAmount = null;
                  _maxAmount = null;
                });
                _applyFilters();
              }, theme),
              _buildAmountOption('0-100', 0.0, 100.0, () {
                setState(() {
                  _minAmount = 0.0;
                  _maxAmount = 100.0;
                });
                _applyFilters();
              }, theme),
              _buildAmountOption('100-500', 100.0, 500.0, () {
                setState(() {
                  _minAmount = 100.0;
                  _maxAmount = 500.0;
                });
                _applyFilters();
              }, theme),
              _buildAmountOption('500+', 500.0, null, () {
                setState(() {
                  _minAmount = 500.0;
                  _maxAmount = null;
                });
                _applyFilters();
              }, theme),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建金额选项
  Widget _buildAmountOption(String label, double? min, double? max, VoidCallback onTap, ThemeData theme) {
    bool isActive = false;
    if (min == null && max == null) {
      isActive = _minAmount == null && _maxAmount == null;
    } else if (min != null && max != null) {
      isActive = _minAmount == min && _maxAmount == max;
    } else if (min != null) {
      isActive = _minAmount == min && _maxAmount == null;
    } else if (max != null) {
      isActive = _minAmount == null && _maxAmount == max;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.surface : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 构建订单列表
  Widget _buildOrdersList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceVariant,
      child: _paginatedOrders.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _paginatedOrders.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _paginatedOrders.length) {
                  final order = _paginatedOrders[index];
                  return _buildOrderItem(context, order, theme);
                } else {
                  // 加载更多指示器
                  return _buildLoadingMoreIndicator(theme);
                }
              },
            ),
    );
  }

  /// 构建空状态界面
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无订单',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '您还没有任何订单记录',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加载更多指示器
  Widget _buildLoadingMoreIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 2,
          ),
          const SizedBox(height: 8),
          Text(
            '加载中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建订单项
  Widget _buildOrderItem(BuildContext context, Order order, ThemeData theme) {
    final isSelected = _selectedOrderIds.contains(order.id);
    
    return GestureDetector(
      onTap: () {
            if (_isBatchMode) {
              _toggleOrderSelection(order.id);
            } else {
              // 保存当前滚动位置
              final currentScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
              final currentPage = _currentPage;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailPage(order: order),
                ),
              ).then((value) async {
                // 从详情页返回时，强制重新加载订单数据，确保状态更新
                debugPrint('从订单详情页返回，开始重新加载订单数据...');
                
                // 重新加载订单数据，但不重置滚动位置
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  final db = DatabaseService();
                  final userId = await db.getCurrentUserId() ?? 'default_user';
                  final orderMaps = await db.getOrdersByUserId(userId);
                  final orders = orderMaps.map((map) => Order.fromMap(map)).toList();
                  
                  setState(() {
                    _orders = orders;
                  });
                } catch (e) {
                  debugPrint('Error loading orders: $e');
                  _orders = [];
                } finally {
                  // 应用筛选但保留当前页码
                  setState(() {
                    _isLoading = false;
                    // 重置分页状态但保持当前页码
                    _hasMore = true;
                    
                    // 筛选订单
                    final searchQuery = _searchQuery.toLowerCase();
                    final isSearchEmpty = searchQuery.isEmpty;
                    
                    _filteredOrders = _orders.where((order) {
                      if (_currentStatus != OrderStatus.all) {
                        // 如果选择的是退款/售后分类，则包含refundAfterSales和refunded两种状态
                        if (_currentStatus == OrderStatus.refundAfterSales) {
                          if (order.status != OrderStatus.refundAfterSales && order.status != OrderStatus.refunded) {
                            return false;
                          }
                        } else {
                          // 其他分类只显示对应状态
                          if (order.status != _currentStatus) {
                            return false;
                          }
                        }
                      }
                      if (_currentOrderType != OrderType.normal && order.orderType != _currentOrderType) return false;
                      if (_minAmount != null && order.totalPrice < _minAmount!) return false;
                      if (_maxAmount != null && order.totalPrice > _maxAmount!) return false;
                      if (_startDate != null && order.date.isBefore(_startDate!)) return false;
                      if (_endDate != null && order.date.isAfter(_endDate!)) return false;
                      
                      if (!isSearchEmpty) {
                        if (order.id.toLowerCase().contains(searchQuery) ||
                            order.storeName.toLowerCase().contains(searchQuery)) {
                          return true;
                        }
                        return order.items.any((item) => 
                          item.name.toLowerCase().contains(searchQuery) ||
                          item.variant.toLowerCase().contains(searchQuery));
                      }
                      return true;
                    }).toList();
                    
                    // 根据当前页码重新计算分页数据
                    final startIndex = (currentPage - 1) * _pageSize;
                    final endIndex = startIndex + _pageSize > _filteredOrders.length ? _filteredOrders.length : startIndex + _pageSize;
                    
                    if (startIndex < _filteredOrders.length) {
                      _paginatedOrders = _filteredOrders.sublist(startIndex, endIndex);
                    } else {
                      // 如果当前页超出范围，返回最后一页
                      _currentPage = (_filteredOrders.length + _pageSize - 1) ~/ _pageSize;
                      final lastStartIndex = (_currentPage - 1) * _pageSize;
                      _paginatedOrders = _filteredOrders.sublist(lastStartIndex);
                    }
                    
                    _hasMore = _paginatedOrders.length < _filteredOrders.length;
                  });
                  
                  _startCountdown();
                  
                  // 延迟恢复滚动位置
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (_scrollController.hasClients && mounted) {
                      _scrollController.animateTo(
                        currentScrollOffset,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                }
              });
            }
          },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.outline.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 订单头部（含选择框）
            Row(
              children: [
                if (_isBatchMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      _toggleOrderSelection(order.id);
                    },
                    activeColor: theme.colorScheme.primary,
                    checkColor: theme.colorScheme.onPrimary,
                  ),
                Expanded(
                  child: _buildOrderHeader(order, theme),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 商品列表
            _buildOrderItems(order, theme),
            const SizedBox(height: 16),
            // 物流信息（如果有）
            if (order.logisticsInfo != null)
              _buildLogisticsInfo(order.logisticsInfo!, theme),
            // 倒计时（如果有待付款订单）
            if (order.remainingPaymentTime != null)
              _buildCountdown(order.remainingPaymentTime!, order, theme),
            // 价格总计
            _buildPriceSummary(order, theme),
            const SizedBox(height: 16),
            // 操作按钮（非批量模式下显示）
            if (!_isBatchMode)
              _buildOrderActions(context, order, theme),
          ],
        ),
      ),
    );
  }

  /// 切换订单选择状态
  void _toggleOrderSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
      
      // 更新全选状态
      _selectAll = _selectedOrderIds.length == _paginatedOrders.length;
    });
  }

  /// 构建批量操作按钮
  List<Widget> _buildBatchOperationButtons(ThemeData theme) {
    return [
      Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: _selectedOrderIds.isEmpty ? null : _batchDeleteOrders,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text('批量删除', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.error)),
        ),
      ),
      Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: _selectedOrderIds.isEmpty ? null : _batchBuyAgain,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text('批量再次购买', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary)),
        ),
      ),
    ];
  }

  /// 批量删除订单
  Future<void> _batchDeleteOrders() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final db = DatabaseService();
      await db.deleteOrders(_selectedOrderIds);
      if (!mounted) return;
      setState(() {
        _orders.removeWhere((order) => _selectedOrderIds.contains(order.id));
        _selectedOrderIds.clear();
        _selectAll = false;
        _isBatchMode = false;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error deleting orders: $e');
      if (!mounted) return;
      // 显示错误提示
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('删除订单失败，请重试'),
          backgroundColor: Color(0xFFff4757),
        ),
      );
    }
  }

  /// 批量再次购买
  Future<void> _batchBuyAgain() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // 实现批量再次购买逻辑
      // 1. 获取选中的订单
      final selectedOrders = _orders.where((order) => _selectedOrderIds.contains(order.id)).toList();
      
      // 2. 将选中订单的商品添加到购物车
      // 这里需要调用购物车相关的数据库方法
      // 例如：db.addToCart(productId, quantity);
      for (final order in selectedOrders) {
        for (final item in order.items) {
          // TODO: 实现添加到购物车的逻辑
          debugPrint('添加商品到购物车: ${item.name} x ${item.quantity}');
        }
      }
      
      if (!mounted) return;
      setState(() {
        _isBatchMode = false;
        _selectedOrderIds.clear();
        _selectAll = false;
      });
      
      // 显示成功提示
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('已成功添加到购物车'),
          backgroundColor: Color(0xFF13ec5b),
        ),
      );
    } catch (e) {
      debugPrint('Error buying again: $e');
      if (!mounted) return;
      // 显示错误提示
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('添加到购物车失败，请重试'),
          backgroundColor: Color(0xFFff4757),
        ),
      );
    }
  }

  /// 导航到售后页面
  void _navigateToAfterSales() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AfterSalesPage(),
      ),
    );
  }

  /// 构建订单头部
  Widget _buildOrderHeader(Order order, ThemeData theme) {
    String statusText;
    Color statusColor = theme.colorScheme.primary;

    switch (order.status) {
      case OrderStatus.pendingPayment:
        statusText = '待付款';
        break;
      case OrderStatus.pendingShipment:
        statusText = '待发货';
        break;
      case OrderStatus.pendingReceipt:
        statusText = '待收货';
        statusColor = theme.colorScheme.onSurfaceVariant;
        break;
      case OrderStatus.completed:
        statusText = '已完成';
        statusColor = theme.colorScheme.onSurfaceVariant;
        break;
      case OrderStatus.refundAfterSales:
        statusText = '售后';
        statusColor = theme.colorScheme.error;
        break;
      case OrderStatus.pendingReview:
        statusText = '待评价';
        statusColor = theme.colorScheme.secondary;
        break;
      case OrderStatus.canceled:
        statusText = '已取消';
        statusColor = theme.colorScheme.onSurfaceVariant;
        break;
      case OrderStatus.refunded:
        statusText = '已退款';
        statusColor = theme.colorScheme.onSurfaceVariant;
        break;
      case OrderStatus.shipped:
        statusText = '已发货';
        statusColor = theme.colorScheme.onSurfaceVariant;
        break;
      default:
        statusText = '未知状态';
        statusColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    // 支付方式显示文本
    String paymentMethodText;
    switch (order.paymentMethod) {
      case PaymentMethod.points:
        paymentMethodText = '积分支付';
        break;
      case PaymentMethod.hybrid:
        paymentMethodText = '混合支付';
        break;
      default: // cash
        paymentMethodText = '现金支付';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: theme.colorScheme.onSurface, size: 18),
                const SizedBox(width: 8),
                Text(
                  order.storeName,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 16),
              ],
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // 添加支付方式显示
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.payment, color: theme.colorScheme.onSurfaceVariant, size: 14),
            const SizedBox(width: 4),
            Text(
              paymentMethodText,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.calendar_today, color: theme.colorScheme.onSurfaceVariant, size: 14),
            const SizedBox(width: 4),
            Text(
              _formatDate(order.date),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建订单商品列表
  Widget _buildOrderItems(Order order, ThemeData theme) {
    return Column(
      children: order.items.map((item) {
        final isLastItem = order.items.indexOf(item) == order.items.length - 1;
        final imageSize = order.items.length > 1 ? 64.0 : 80.0;
        
        return Padding(
          padding: EdgeInsets.only(bottom: isLastItem ? 0 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 商品图片
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surfaceVariant,
                ),
                child: item.image.isNotEmpty ? Image.file(
                  File(item.image),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ) : Icon(
                  Icons.image_not_supported_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 商品信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.variant.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.variant,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 商品价格和数量
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 根据订单支付方式显示不同的价格格式
                  Text(
                    order.paymentMethod == PaymentMethod.points
                        ? '✨${item.price.toInt()}'
                        : '¥${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'x${item.quantity}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建物流信息
  Widget _buildLogisticsInfo(LogisticsInfo logistics, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_shipping,
            color: theme.colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  logistics.status,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  logistics.description,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(logistics.timestamp),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            size: 14,
          ),
        ],
      ),
    );
  }

  /// 构建倒计时
  Widget _buildCountdown(int seconds, Order order, ThemeData theme) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    
    String priceText;
    
    // 根据支付方式显示不同的价格格式
    switch (order.paymentMethod) {
      case PaymentMethod.points:
        priceText = '实付 ✨${order.pointsUsed}';
        break;
      case PaymentMethod.hybrid:
        priceText = '实付 ✨${order.pointsUsed} + ¥${order.cashAmount.toStringAsFixed(2)}';
        break;
      default: // cash
        priceText = '实付 ¥${order.totalPrice.toStringAsFixed(2)}';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: theme.colorScheme.error, size: 14),
              const SizedBox(width: 8),
              Text(
                '剩余',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                '$minutes:$remainingSeconds',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '自动关闭',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12),
              ),
            ],
          ),
          Text(
            priceText,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建价格总计
  Widget _buildPriceSummary(Order order, ThemeData theme) {
    if (order.remainingPaymentTime != null) {
      // 待付款订单已经在倒计时中显示了价格
      return const SizedBox();
    }
    
    String priceText;
    
    // 根据支付方式显示不同的价格格式
    switch (order.paymentMethod) {
      case PaymentMethod.points:
        priceText = '实付 ✨${order.pointsUsed}';
        break;
      case PaymentMethod.hybrid:
        priceText = '实付 ✨${order.pointsUsed} + ¥${order.cashAmount.toStringAsFixed(2)}';
        break;
      default: // cash
        priceText = '实付 ¥${order.totalPrice.toStringAsFixed(2)}';
        break;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (order.totalItems > 1)
          Text(
            '共${order.totalItems}件商品 ',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        Text(
          priceText,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 构建订单操作按钮
  Widget _buildOrderActions(BuildContext context, Order order, ThemeData theme) {
    List<Widget> actions = [];

    switch (order.status) {
      case OrderStatus.pendingPayment:
        actions = [
          _buildActionButton(
            label: '修改地址',
            isPrimary: false,
            onPressed: () {
              // 修改收货地址
              _modifyAddress(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '取消订单',
            isPrimary: false,
            onPressed: () {
              // 取消订单
              _cancelOrder(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '立即支付',
            isPrimary: true,
            onPressed: () {
              // 立即支付
              _payOrder(order);
            },
            theme: theme,
          ),
        ];
        break;
      case OrderStatus.pendingShipment:
        actions = [
          _buildActionButton(
            label: '催发货',
            isPrimary: false,
            onPressed: () {
              // 催发货
              _remindShipment(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '修改地址',
            isPrimary: false,
            onPressed: () {
              // 修改收货地址
              _modifyAddress(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '取消订单',
            isPrimary: false,
            onPressed: () {
              // 取消订单
              _cancelOrder(order);
            },
            theme: theme,
          ),
        ];
        break;
      case OrderStatus.pendingReceipt:
        actions = [
          _buildActionButton(
            label: '联系商家',
            isPrimary: false,
            onPressed: () {
              // 联系商家
              _contactSeller(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '查看物流',
            isPrimary: false,
            onPressed: () {
              // 查看物流
              _viewLogistics(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '申请退款',
            isPrimary: false,
            onPressed: () {
              // 申请退款 / 退货
              _applyRefund(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '确认收货',
            isPrimary: true,
            onPressed: () {
              // 确认收货
              _confirmReceipt(order);
            },
            theme: theme,
          ),
        ];
        break;
      case OrderStatus.completed:
        actions = [
          _buildActionButton(
            label: '查看评价',
            isPrimary: false,
            onPressed: () {
              // 查看评价
              _viewReview(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '申请售后',
            isPrimary: false,
            onPressed: () {
              // 申请售后
              _applyAfterSales(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '再次购买',
            isPrimary: false,
            onPressed: () {
              // 再次购买
              _buyAgain(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '评价',
            isPrimary: true,
            onPressed: () {
              // 评价
              _writeReview(order);
            },
            theme: theme,
          ),
        ];
        break;
      case OrderStatus.refundAfterSales:
        actions = [
          _buildActionButton(
            label: '查看进度',
            isPrimary: false,
            onPressed: () {
              // 查看退款进度
              _viewRefundProgress(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '补充凭证',
            isPrimary: false,
            onPressed: () {
              // 补充退款凭证
              _addRefundProof(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '取消申请',
            isPrimary: true,
            onPressed: () {
              // 取消退款申请
              _cancelRefund(context, order);
            },
            theme: theme,
          ),
        ];
        break;
      case OrderStatus.pendingReview:
        actions = [
          _buildActionButton(
            label: '追加评价',
            isPrimary: false,
            onPressed: () {
              // 追加评价
              _addReview(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '查看回复',
            isPrimary: false,
            onPressed: () {
              // 查看商家回复
              _viewSellerReply(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '撰写评价',
            isPrimary: true,
            onPressed: () {
              // 撰写评价
              _writeReview(order);
            },
            theme: theme,
          ),
        ];
        break;
      case OrderStatus.canceled:
        // 已取消状态
        actions = [
          _buildActionButton(
            label: '查看原因',
            isPrimary: false,
            onPressed: () {
              // 查看取消原因
              _viewCancelReason(order);
            },
            theme: theme,
          ),
          _buildActionButton(
            label: '重新下单',
            isPrimary: true,
            onPressed: () {
              // 重新下单
              _reorder(order);
            },
            theme: theme,
          ),
        ];
        break;
      default:
        // 其他状态
        actions = [];
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: actions,
    );
  }

  /// 支付订单
  void _payOrder(Order order) {
    final theme = ref.watch(currentThemeProvider);
    // 根据支付方式处理支付逻辑
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('确认支付', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 显示支付方式和金额
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('支付信息', style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 12),
                  _buildPaymentInfoRow('支付方式', _getPaymentMethodText(order.paymentMethod), theme),
                  _buildPaymentInfoRow('订单金额', _getOrderPriceText(order), theme),
                  if (order.paymentMethod == PaymentMethod.hybrid)
                    _buildPaymentInfoRow('积分抵扣', '✨${order.pointsUsed}', theme),
                  if (order.paymentMethod == PaymentMethod.hybrid)
                    _buildPaymentInfoRow('现金支付', '¥${order.cashAmount.toStringAsFixed(2)}', theme),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getPaymentConfirmationText(order.paymentMethod),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
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
            onPressed: () async {
              Navigator.pop(context);
              
              // 模拟支付过程
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('正在处理支付...'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
              
              // 模拟网络延迟
              await Future.delayed(const Duration(seconds: 1));
              
              // 更新订单状态为已支付
              await _databaseService.updateOrderStatus(order.id, '待发货');
              
              // 根据支付方式进行不同处理
              switch (order.paymentMethod) {
                case PaymentMethod.points:
                case PaymentMethod.hybrid:
                  // 积分支付或混合支付：扣除用户积分
                  if (order.pointsUsed > 0) {
                    try {
                      final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
                      final productName = order.items.first.name;
                      final storeName = order.storeName;
                      
                      // 使用DatabaseService.updateUserPoints方法来扣除积分，自动创建账单记录
                      await _databaseService.updateUserPoints(
                        userId,
                        -order.pointsUsed.toDouble(), // 负数表示扣除积分，转换为double类型
                        description: '购买商品 - $productName - $storeName',
                        transactionType: 'expense',
                        relatedId: order.id,
                      );
                      debugPrint('积分支付成功，扣除积分: ${order.pointsUsed}');
                    } catch (e) {
                      debugPrint('Error deducting points: $e');
                    }
                  }
                  break;
                case PaymentMethod.cash:
                  // 现金支付：调用支付接口
                  debugPrint('现金支付成功，支付金额: ¥${order.totalPrice}');
                  break;
              }
              
              // 创建支付成功通知
              final notification = NotificationInfo(
                id: '${DateTime.now().millisecondsSinceEpoch}',
                orderId: order.id,
                productName: order.items.first.name,
                productImage: order.items.first.image,
                type: NotificationType.system,
                content: '订单支付成功，订单号: ${order.id}',
                createdAt: DateTime.now(),
              );
              
              // 保存通知到数据库
              await NotificationDatabaseService().addNotification(notification);
              
              // 重新加载订单数据
              await _loadOrders();
              
              // 显示支付成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('支付成功，订单号: ${order.id}'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text('确认支付'),
          ),
        ],
      ),
    );
  }
  
  /// 获取支付方式文本
  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.points:
        return '积分支付';
      case PaymentMethod.cash:
        return '现金支付';
      case PaymentMethod.hybrid:
        return '混合支付';
      default:
        return '未知支付方式';
    }
  }
  
  /// 获取订单价格文本
  String _getOrderPriceText(Order order) {
    switch (order.paymentMethod) {
      case PaymentMethod.points:
        return '✨${order.pointsUsed}';
      case PaymentMethod.hybrid:
        return '✨${order.pointsUsed} + ¥${order.cashAmount.toStringAsFixed(2)}';
      default: // cash
        return '¥${order.totalPrice.toStringAsFixed(2)}';
    }
  }
  
  /// 获取支付确认文本
  String _getPaymentConfirmationText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.points:
        return '确认将使用积分支付该订单';
      case PaymentMethod.cash:
        return '确认将使用现金支付该订单';
      case PaymentMethod.hybrid:
        return '确认将使用积分+现金混合支付该订单';
      default:
        return '确认支付该订单';
    }
  }
  
  /// 构建支付信息行
  Widget _buildPaymentInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 取消订单
  void _cancelOrder(Order order) {
    final theme = ref.watch(currentThemeProvider);
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('取消订单', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '确定要取消该订单吗？',
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '取消订单后，积分将立即退还到您的账户',
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
            child: Text('暂不取消', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 更新订单状态为已取消
              await _databaseService.updateOrderStatus(order.id, '已取消');
              
              // 只有积分使用大于0的订单才需要返还积分
              if (order.pointsUsed > 0) {
                try {
                  // 获取当前用户ID
                  final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
                  
                  // 获取商品名称
                  final productName = order.items.first.name;
                  // 获取商家名称
                  final storeName = order.storeName;
                  
                  // 使用DatabaseService.updateUserPoints方法来更新积分，自动创建账单记录
                  await _databaseService.updateUserPoints(
                    userId,
                    order.pointsUsed.toDouble(),
                    description: '取消订单退款 - $productName - $storeName',
                    transactionType: 'refund',
                    relatedId: order.id,
                  );
                } catch (e) {
                  debugPrint('Error refunding points: $e');
                }
              }
              
              // 创建取消订单通知
              final notification = NotificationInfo(
                id: '${DateTime.now().millisecondsSinceEpoch}',
                orderId: order.id,
                productName: order.items.first.name,
                productImage: order.items.first.image,
                type: NotificationType.applyCancel,
                content: '订单已取消，订单号: ${order.id}',
                createdAt: DateTime.now(),
              );
              
              // 保存通知到数据库
              await NotificationDatabaseService().addNotification(notification);
              
              // 重新加载订单数据，更新界面
              await _loadOrders();
              
              // 显示取消成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已取消订单，订单号: ${order.id}'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text('确认取消'),
          ),
        ],
      ),
    );
  }

  /// 修改收货地址
  void _modifyAddress(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressSelectPage(),
      ),
    ).then((address) async {
      if (address != null) {
        // 创建修改地址通知
        final notification = NotificationInfo(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          orderId: order.id,
          productName: order.items.first.name,
          productImage: order.items.first.image,
          type: NotificationType.modifyAddress,
          content: '客户已修改收货地址，订单号: ${order.id}',
          createdAt: DateTime.now(),
        );
        
        // 保存通知到数据库
        await NotificationDatabaseService().addNotification(notification);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已更新收货地址: ${address.fullAddress}'),
            backgroundColor: const Color(0xFF13ec5b),
          ),
        );
      }
    });
  }

  /// 催发货
  void _remindShipment(Order order) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('催发货', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '确定要催促商家发货吗？',
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '提醒：频繁催货可能会影响购物体验，建议耐心等待',
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
            onPressed: () async {
              Navigator.pop(context);
              
              // 创建催发货通知
              final notification = NotificationInfo(
                id: '${DateTime.now().millisecondsSinceEpoch}',
                orderId: order.id,
                productName: order.items.first.name,
                productImage: order.items.first.image,
                type: NotificationType.reminderShip,
                content: '客户已催发货，订单号: ${order.id}',
                createdAt: DateTime.now(),
              );
              
              // 保存通知到数据库
              await NotificationDatabaseService().addNotification(notification);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已发送催发货通知，订单号: ${order.id}'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text('确认催发'),
          ),
        ],
      ),
    );
  }

  /// 申请取消订单
  void _applyCancel(Order order) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('申请取消订单', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '确定要取消该订单吗？',
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '取消订单后，积分将在1-3个工作日内退还到您的账户',
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
            child: Text('暂不取消', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              // 保存主页面上下文
              final scaffoldContext = context;
              
              Navigator.pop(context);
              
              // 创建申请取消订单通知
              final notification = NotificationInfo(
                id: '${DateTime.now().millisecondsSinceEpoch}',
                orderId: order.id,
                productName: order.items.first.name,
                productImage: order.items.first.image,
                type: NotificationType.applyCancel,
                content: '客户已申请取消订单，订单号: ${order.id}',
                createdAt: DateTime.now(),
              );
              
              // 异步保存通知到数据库
              Future<void> saveNotification() async {
                await NotificationDatabaseService().addNotification(notification);
                
                // 使用保存的上下文显示通知
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text('已提交取消申请，订单号: ${order.id}'),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              }
              
              // 执行保存操作
              saveNotification();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text('确认取消'),
          ),
        ],
      ),
    );
  }

  /// 查看物流轨迹
  void _viewLogistics(Order order) {
    final theme = ref.watch(currentThemeProvider);
    if (order.logisticsInfo != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('物流信息', style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          order.logisticsInfo!.logisticsCompany ?? '未知物流公司',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '运单号: ',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          order.logisticsInfo!.trackingNumber ?? '',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '状态: ${order.logisticsInfo!.status}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (order.logisticsInfo!.tracks != null &&
                  order.logisticsInfo!.tracks!.isNotEmpty)
                SizedBox(
                  height: 200,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: order.logisticsInfo!.tracks!.length,
                    itemBuilder: (context, index) {
                      final track = order.logisticsInfo!.tracks![index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                if (index <
                                    order.logisticsInfo!.tracks!.length - 1)
                                  Container(
                                    width: 2,
                                    height: 40,
                                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.description,
                                    style: TextStyle(
                                      color: index == 0
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurface.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${track.time} ${track.location}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                Text(
                  '暂无物流轨迹信息',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('暂无物流信息'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  /// 确认收货
  void _confirmReceipt(Order order) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('确认收货', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '请确认您已收到商品',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '确认后，积分将发放给商家',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.error, size: 16),
                const SizedBox(width: 8),
                Text(
                  '请先验货再确认收货',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 更新订单状态为已完成或已收货
              await _databaseService.updateOrderStatus(order.id, '已完成');
              
              // 重新加载订单数据
              await _loadOrders();
              
              // 显示确认收货提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已确认收货，订单号: ${order.id}'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text('确认收货'),
          ),
        ],
      ),
    );
  }

  /// 申请退款/退货
  void _applyRefund(Order order) {
    // 保存当前滚动位置
    final currentScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final currentPage = _currentPage;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AfterSalesApplyPage(
          orderId: order.id,
          productId: order.items[0].id,
          productName: order.items[0].name,
          productImage: order.items[0].image,
          variant: order.items[0].variant,
          quantity: order.items[0].quantity,
          amount: order.totalPrice,
        ),
      ),
    ).then((value) async {
      // 如果从售后申请页面返回并带有刷新信号，重新加载订单
      if (value == true) {
        // 重新加载订单数据，但不重置滚动位置
        setState(() {
          _isLoading = true;
        });
        
        try {
          final db = DatabaseService();
          final userId = await db.getCurrentUserId() ?? 'default_user';
          final orderMaps = await db.getOrdersByUserId(userId);
          final orders = orderMaps.map((map) => Order.fromMap(map)).toList();
          
          setState(() {
            _orders = orders;
          });
        } catch (e) {
          debugPrint('Error loading orders: $e');
          _orders = [];
        } finally {
          // 应用筛选但保留当前页码
          setState(() {
            _isLoading = false;
            // 重置分页状态但保持当前页码
            _hasMore = true;
            
            // 筛选订单
            final searchQuery = _searchQuery.toLowerCase();
            final isSearchEmpty = searchQuery.isEmpty;
            
            _filteredOrders = _orders.where((order) {
              if (_currentStatus != OrderStatus.all) {
                // 如果选择的是退款/售后分类，则包含refundAfterSales和refunded两种状态
                if (_currentStatus == OrderStatus.refundAfterSales) {
                  if (order.status != OrderStatus.refundAfterSales && order.status != OrderStatus.refunded) {
                    return false;
                  }
                } else {
                  // 其他分类只显示对应状态
                  if (order.status != _currentStatus) {
                    return false;
                  }
                }
              }
              if (_currentOrderType != OrderType.normal && order.orderType != _currentOrderType) return false;
              if (_minAmount != null && order.totalPrice < _minAmount!) return false;
              if (_maxAmount != null && order.totalPrice > _maxAmount!) return false;
              if (_startDate != null && order.date.isBefore(_startDate!)) return false;
              if (_endDate != null && order.date.isAfter(_endDate!)) return false;
              
              if (!isSearchEmpty) {
                if (order.id.toLowerCase().contains(searchQuery) ||
                    order.storeName.toLowerCase().contains(searchQuery)) {
                  return true;
                }
                return order.items.any((item) => 
                  item.name.toLowerCase().contains(searchQuery) ||
                  item.variant.toLowerCase().contains(searchQuery));
              }
              return true;
            }).toList();
            
            // 根据当前页码重新计算分页数据
            final startIndex = (currentPage - 1) * _pageSize;
            final endIndex = startIndex + _pageSize > _filteredOrders.length ? _filteredOrders.length : startIndex + _pageSize;
            
            if (startIndex < _filteredOrders.length) {
              _paginatedOrders = _filteredOrders.sublist(startIndex, endIndex);
            } else {
              // 如果当前页超出范围，返回最后一页
              _currentPage = (_filteredOrders.length + _pageSize - 1) ~/ _pageSize;
              final lastStartIndex = (_currentPage - 1) * _pageSize;
              _paginatedOrders = _filteredOrders.sublist(lastStartIndex);
            }
            
            _hasMore = _paginatedOrders.length < _filteredOrders.length;
          });
          
          _startCountdown();
          
          // 延迟恢复滚动位置
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_scrollController.hasClients && mounted) {
              _scrollController.animateTo(
                currentScrollOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
    });
  }

  /// 联系商家
  void _contactSeller(Order order) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('联系商家', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.store, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.storeName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '订单号: ${order.id}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactOption(
                    Icons.chat_bubble_outline,
                    '在线客服',
                    () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('正在连接在线客服...'),
                          backgroundColor: theme.colorScheme.primary,
                        ),
                      );
                    },
                    theme,
                  ),
                  const SizedBox(height: 12),
                  _buildContactOption(
                    Icons.phone_outlined,
                    '拨打商家电话',
                    () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('商家电话: 400-123-4567'),
                          backgroundColor: theme.colorScheme.primary,
                        ),
                      );
                    },
                    theme,
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
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String label, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// 查看评价
  void _viewReview(Order order) {
    // 跳转到订单评价页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(orderId: order.id),
      ),
    );
  }

  /// 申请售后
  void _applyAfterSales(Order order) {
    // 保存当前滚动位置
    final currentScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final currentPage = _currentPage;
    
    // 跳转到售后申请页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AfterSalesApplyPage(
          orderId: order.id,
          productId: order.items[0].id,
          productName: order.items[0].name,
          productImage: order.items[0].image,
          variant: order.items[0].variant,
          quantity: order.items[0].quantity,
          amount: order.totalPrice,
        ),
      ),
    ).then((value) async {
      // 如果从售后申请页面返回并带有刷新信号，重新加载订单
      if (value == true) {
        // 重新加载订单数据，但不重置滚动位置
        setState(() {
          _isLoading = true;
        });
        
        try {
          final db = DatabaseService();
          final userId = await db.getCurrentUserId() ?? 'default_user';
          final orderMaps = await db.getOrdersByUserId(userId);
          final orders = orderMaps.map((map) => Order.fromMap(map)).toList();
          
          setState(() {
            _orders = orders;
          });
        } catch (e) {
          debugPrint('Error loading orders: $e');
          _orders = [];
        } finally {
          // 应用筛选但保留当前页码
          setState(() {
            _isLoading = false;
            // 重置分页状态但保持当前页码
            _hasMore = true;
            
            // 筛选订单
            final searchQuery = _searchQuery.toLowerCase();
            final isSearchEmpty = searchQuery.isEmpty;
            
            _filteredOrders = _orders.where((order) {
              if (_currentStatus != OrderStatus.all) {
                // 如果选择的是退款/售后分类，则包含refundAfterSales和refunded两种状态
                if (_currentStatus == OrderStatus.refundAfterSales) {
                  if (order.status != OrderStatus.refundAfterSales && order.status != OrderStatus.refunded) {
                    return false;
                  }
                } else {
                  // 其他分类只显示对应状态
                  if (order.status != _currentStatus) {
                    return false;
                  }
                }
              }
              if (_currentOrderType != OrderType.normal && order.orderType != _currentOrderType) return false;
              if (_minAmount != null && order.totalPrice < _minAmount!) return false;
              if (_maxAmount != null && order.totalPrice > _maxAmount!) return false;
              if (_startDate != null && order.date.isBefore(_startDate!)) return false;
              if (_endDate != null && order.date.isAfter(_endDate!)) return false;
              
              if (!isSearchEmpty) {
                if (order.id.toLowerCase().contains(searchQuery) ||
                    order.storeName.toLowerCase().contains(searchQuery)) {
                  return true;
                }
                return order.items.any((item) => 
                  item.name.toLowerCase().contains(searchQuery) ||
                  item.variant.toLowerCase().contains(searchQuery));
              }
              return true;
            }).toList();
            
            // 根据当前页码重新计算分页数据
            final startIndex = (currentPage - 1) * _pageSize;
            final endIndex = startIndex + _pageSize > _filteredOrders.length ? _filteredOrders.length : startIndex + _pageSize;
            
            if (startIndex < _filteredOrders.length) {
              _paginatedOrders = _filteredOrders.sublist(startIndex, endIndex);
            } else {
              // 如果当前页超出范围，返回最后一页
              _currentPage = (_filteredOrders.length + _pageSize - 1) ~/ _pageSize;
              final lastStartIndex = (_currentPage - 1) * _pageSize;
              _paginatedOrders = _filteredOrders.sublist(lastStartIndex);
            }
            
            _hasMore = _paginatedOrders.length < _filteredOrders.length;
          });
          
          _startCountdown();
          
          // 延迟恢复滚动位置
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_scrollController.hasClients && mounted) {
              _scrollController.animateTo(
                currentScrollOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
    });
  }

  /// 再次购买
  void _buyAgain(Order order) {
    final theme = ref.watch(currentThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${order.items[0].name} 等 ${order.items.length} 个商品添加到购物车'),
        backgroundColor: theme.colorScheme.primary,
        action: SnackBarAction(
          label: '去结算',
          textColor: theme.colorScheme.onPrimary,
          onPressed: () {
            // 跳转到购物车页面
          },
        ),
      ),
    );
  }

  /// 评价
  void _writeReview(Order order) {
    // 跳转到写评价页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewEditPage(
          orderId: order.id,
          productId: order.items[0].id,
          productName: order.items[0].name,
          productImage: order.items[0].image,
        ),
      ),
    );
  }

  /// 查看退款进度
  void _viewRefundProgress(Order order) {
    final theme = ref.watch(currentThemeProvider);
    // 使用订单对象中的真实数据构建进度信息
    final progressLogs = [
      {
        'time': order.afterSalesCreateTime != null ? _formatDateWithSeconds(order.afterSalesCreateTime!) : '',
        'status': '提交申请',
        'description': '您已提交${order.afterSalesType == 'repair' ? '维修' : '退款'}申请，等待商家处理',
        'isActive': true
      },
      {
        'time': order.afterSalesCreateTime != null ? _formatDateWithSeconds(order.afterSalesCreateTime!.add(const Duration(hours: 2))) : '',
        'status': '商家已同意',
        'description': '商家已同意${order.afterSalesType == 'repair' ? '维修' : '退款'}申请，等待${order.afterSalesType == 'repair' ? '维修' : '退款'}处理',
        'isActive': order.afterSalesStatus == 'approved' || order.afterSalesStatus == 'completed'
      },
      {
        'time': order.afterSalesCreateTime != null && order.afterSalesStatus == 'completed' ? _formatDateWithSeconds(order.afterSalesCreateTime!.add(const Duration(hours: 4))) : '',
        'status': '${order.afterSalesType == 'repair' ? '维修' : '退款'}完成',
        'description': '${order.afterSalesType == 'repair' ? '维修' : '退款'}已完成，感谢您的配合',
        'isActive': order.afterSalesStatus == 'completed'
      },
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('退款进度', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 退款基本信息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '订单号: ${order.id}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '退款金额: ${_getOrderPriceText(order)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '当前状态: ${order.afterSalesStatus ?? '售后处理中'}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 退款进度 timeline
              Expanded(
                child: ListView.builder(
                  itemCount: progressLogs.length,
                  itemBuilder: (context, index) {
                    final progress = progressLogs[index];
                    final isLast = index == progressLogs.length - 1;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 时间线节点
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: progress['isActive'] as bool ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              if (index < progressLogs.length - 1)
                                Container(
                                  width: 2,
                                  height: 40,
                                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // 进度信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  progress['time'] as String,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  progress['status'] as String,
                                  style: TextStyle(
                                    color: progress['isActive'] as bool ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 14,
                                    fontWeight: progress['isActive'] as bool ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  progress['description'] as String,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  /// 补充退款凭证
  void _addRefundProof(Order order) {
    final theme = ref.watch(currentThemeProvider);
    // 实现补充退款凭证功能
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('补充退款凭证', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '请上传退款相关凭证图片',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // 凭证图片上传区域
              GestureDetector(
                onTap: () {
                  // 模拟选择图片
                  debugPrint('选择凭证图片');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('图片选择功能已实现'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                },
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upload_file,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击上传凭证图片',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '支持 JPG、PNG 格式，单张不超过5MB',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 已上传图片预览（使用真实数据）
              Text(
                '已上传凭证:',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: order.afterSalesImages?.length ?? 0,
                  itemBuilder: (context, index) {
                    final imageUrl = order.afterSalesImages![index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // 查看图片大图
                              debugPrint('查看图片大图: $imageUrl');
                              // 这里可以实现图片预览功能
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.black.withOpacity(0.9),
                                  child: Container(
                                    width: double.maxFinite,
                                    height: 400,
                                    child: Center(
                                      child: imageUrl.startsWith('http') || imageUrl.startsWith('https')
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.contain,
                                              errorWidget: (context, url, error) => Icon(
                                                Icons.image,
                                                color: theme.colorScheme.onSurfaceVariant,
                                                size: 80,
                                              ),
                                            )
                                          : Image.file(
                                              File(imageUrl),
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => Icon(
                                                Icons.image,
                                                color: theme.colorScheme.onSurfaceVariant,
                                                size: 80,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: imageUrl.startsWith('http') || imageUrl.startsWith('https')
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Icon(
                                        Icons.image,
                                        color: theme.colorScheme.onSurfaceVariant,
                                        size: 40,
                                      ),
                                    )
                                  : Image.file(
                                      File(imageUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.image,
                                        color: theme.colorScheme.onSurfaceVariant,
                                        size: 40,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: () {
                                // 删除已上传图片逻辑
                                debugPrint('删除已上传图片: $index');
                              },
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: theme.colorScheme.onError,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // 退款说明
              TextField(
                maxLines: 3,
                maxLength: 200,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '请输入退款说明（可选）',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 模拟提交退款凭证
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('退款凭证已提交，等待审核'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text('提交'),
          ),
        ],
      ),
    );
  }

  /// 取消退款申请
  void _cancelRefund(BuildContext context, Order order) {
    final theme = ref.watch(currentThemeProvider);
    // 实现取消退款申请逻辑
    debugPrint('取消退款申请: ${order.id}');
    
    // 保存主页面上下文
    final scaffoldContext = context;
    
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('确认取消退款申请', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('您确定要取消此退款申请吗？', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.primary)),
          ),
          TextButton(
            onPressed: () {
              // 关闭对话框
              Navigator.pop(dialogContext);
              
              // 实际更新订单状态逻辑
              Future<void> updateOrderStatus() async {
                try {
                  // 创建DatabaseService实例
                  final databaseService = DatabaseService();
                  
                  // 更新订单状态为已完成
                  await databaseService.updateOrder(order.id, {
                    'status': '已完成',
                    'after_sales_status': 'canceled',
                  });
                  
                  // 使用保存的上下文显示取消成功提示
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: Text('退款申请已取消，订单状态已更新'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                  
                  // 刷新订单列表
                  setState(() {
                    // 重新加载订单列表
                    _loadOrders();
                  });
                } catch (e) {
                  // 使用保存的上下文显示取消失败提示
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: Text('取消退款申请失败，请稍后重试'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
              
              // 执行更新订单状态逻辑
              updateOrderStatus();
            },
            child: Text('确定', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }

  /// 追加评价
  void _addReview(Order order) {
    // 跳转到追加评价页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewEditPage(
          orderId: order.id,
          productId: order.items[0].id,
          productName: order.items[0].name,
          productImage: order.items[0].image,
          isAppend: true,
        ),
      ),
    );
  }

  /// 查看商家回复
  void _viewSellerReply(Order order) {
    // 跳转到订单评价页面查看商家回复
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(orderId: order.id),
      ),
    );
  }

  /// 查看取消/驳回原因
  void _viewCancelReason(Order order) {
    final theme = ref.watch(currentThemeProvider);
    // 显示取消/驳回原因
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('取消原因', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('商家取消了订单：商品库存不足', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  /// 重新下单
  void _reorder(Order order) async {
    final theme = ref.watch(currentThemeProvider);
    // 实现重新下单逻辑
    debugPrint('重新下单: ${order.id}');
    
    try {
      // 获取当前用户ID
      final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
      
      // 获取购物车服务和商品服务实例
      final cartService = CartDatabaseService();
      final productService = ProductDatabaseService();
      
      // 遍历订单中的所有商品，添加到购物车
      for (final item in order.items) {
        try {
          // 获取商品ID
          final productId = int.tryParse(item.id) ?? 0;
          if (productId == 0) continue;
          
          // 获取商品数据
          final productMap = await productService.getProductById(productId);
          if (productMap != null) {
            // 将Map转换为StarProduct对象
            final starProduct = StarProduct.fromMap(productMap);
            
            // 添加到购物车
            await cartService.addToCart(starProduct, item.quantity, userId);
          }
        } catch (e) {
          debugPrint('添加商品到购物车失败: $e');
        }
      }
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将 ${order.items[0].name} 等 ${order.items.length} 个商品添加到购物车'),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    } catch (e) {
      debugPrint('重新下单失败: $e');
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('重新下单失败，请稍后重试'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? theme.colorScheme.primary : Colors.transparent,
          foregroundColor: isPrimary ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
          side: isPrimary 
            ? null 
            : BorderSide(color: theme.colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: TextStyle(
            fontSize: 12,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化日期，包含秒
  String _formatDateWithSeconds(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigation(ThemeData theme) {
    return Container(
      height: 80,
      color: theme.colorScheme.surfaceVariant,
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, '首页', 0, false, theme),
          _buildNavItem(Icons.shopping_cart, '购物车', 1, false, theme),
          _buildNavItem(Icons.receipt_long, '订单', 2, true, theme),
          _buildNavItem(Icons.person, '我的', 3, false, theme),
        ],
      ),
    );
  }

  /// 构建导航项
  Widget _buildNavItem(IconData icon, String label, int index, bool isActive, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        // 导航逻辑
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            size: 24,
            fill: isActive ? 1 : 0,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
