import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/presentation/pages/merchant_order_management_page.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'dart:developer' as debug;

/// 售后记录模型
class AfterSalesRecord {
  final String? id;
  final String? type;
  final String? reason;
  final String? description;
  final List<String>? images;
  final DateTime? applyTime;
  final String? status;

  AfterSalesRecord({
    this.id,
    this.type,
    this.reason,
    this.description,
    this.images,
    this.applyTime,
    this.status,
  });

  factory AfterSalesRecord.fromMap(Map<String, dynamic> map) {
    return AfterSalesRecord(
      id: map['id'] as String?,
      type: map['after_sales_type'] as String?,
      reason: map['after_sales_reason'] as String?,
      description: map['after_sales_description'] as String?,
      images: map['after_sales_images'] != null
          ? List<String>.from(map['after_sales_images'])
          : null,
      applyTime: map['after_sales_create_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['after_sales_create_time'] as int)
          : null,
      status: map['after_sales_status'] as String?,
    );
  }
}

/// 商家订单详情页面
class MerchantOrderDetailPage extends ConsumerStatefulWidget {
  /// 构造函数
  const MerchantOrderDetailPage({
    super.key,
    required this.order,
    this.showAfterSalesRecords = false,
  });

  /// 订单数据
  final MerchantOrder order;

  /// 是否直接显示售后记录
  final bool showAfterSalesRecords;

  @override
  ConsumerState<MerchantOrderDetailPage> createState() =>
      _MerchantOrderDetailPageState();
}

class _MerchantOrderDetailPageState extends ConsumerState<MerchantOrderDetailPage> {
  /// 订单数据，使用状态管理
  late MerchantOrder _order;

  /// 数据库服务实例
  late final DatabaseService _databaseService;

  /// 商品数据库服务实例，用于处理售后操作
  late final ProductDatabaseService _productDatabaseService;

  /// 通知服务实例
  late final NotificationDatabaseService _notificationService;

  /// 滚动控制器，用于滚动到售后记录位置
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 初始化订单数据
    _order = widget.order;
    // 初始化服务实例
    _databaseService = DatabaseService();
    _productDatabaseService = ProductDatabaseService();
    _notificationService = NotificationDatabaseService();
    // 初始加载沟通记录
    _loadCommunicationLogs();

    // 如果需要直接显示售后记录，延迟滚动到售后记录位置
    if (widget.showAfterSalesRecords) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 移除固定位置滚动，避免干扰鼠标滚轮事件
        // 让用户手动滚动到售后记录，或者使用更可靠的位置计算方式
      });
    }
  }

  @override
  void dispose() {
    // 释放滚动控制器
    _scrollController.dispose();
    super.dispose();
  }

  /// 刷新订单数据
  Future<void> _refreshOrderData() async {
    try {
      // 直接使用商品数据库服务获取订单数据（单例模式）
      final orderMap = await ProductDatabaseService().getOrderById(_order.id);
      if (orderMap != null) {
        // 将Map转换为MerchantOrder对象
        final updatedOrder = MerchantOrder.fromMap(orderMap);
        setState(() {
          _order = updatedOrder;
        });
        debugPrint('刷新订单数据成功，订单 ${_order.id} 的状态: ${_order.status}');
      }
    } catch (e) {
      debugPrint('刷新订单数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
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
            // 返回true，确保订单管理页刷新订单列表
            Navigator.pop(context, true);
          },
        ),
        title: Text(
          '订单详情',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 订单状态卡片
            _buildStatusCard(theme),
            const SizedBox(height: 16),
            // 买家信息卡片
            _buildBuyerInfoCard(theme),
            const SizedBox(height: 16),
            // 商品信息卡片
            _buildProductInfoCard(theme),
            const SizedBox(height: 16),
            // 订单信息卡片
            _buildOrderInfoCard(context, theme),
            const SizedBox(height: 16),
            // 物流信息卡片
            _buildLogisticsInfoCard(theme),
            const SizedBox(height: 16),
            // 支付信息卡片
            _buildPaymentInfoCard(theme),
            const SizedBox(height: 16),
            // 商家备注卡片
            _buildMerchantNoteCard(context, theme),
            const SizedBox(height: 16),
            // 操作记录卡片
            _buildOperationLogCard(theme),
            const SizedBox(height: 16),
            // 沟通记录卡片
            _buildCommunicationLogCard(context, theme),
            const SizedBox(height: 32),
            // 订单操作按钮
            _buildOrderActionButtons(context, theme),
          ],
        ),
      ),
    );
  }

  /// 构建订单状态卡片
  Widget _buildStatusCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '订单状态',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getStatusText(_order.status),
                  style: TextStyle(
                    color: _getStatusColor(_order.status, theme),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _order.id,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontFamily: 'Monaco',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '下单时间: ${_formatDate(_order.orderTime)}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建买家信息卡片
  Widget _buildBuyerInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '买家信息',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 确保买家信息始终显示，即使字段为空
            _buildInfoRow('买家昵称',
                _order.buyerName.isNotEmpty ? _order.buyerName : '匿名用户', theme),
            _buildInfoRow('手机号',
                _order.buyerPhone.isNotEmpty ? _order.buyerPhone : '未提供', theme),
            _buildInfoRow(
                '收货地址',
                _order.deliveryAddress.isNotEmpty
                    ? _order.deliveryAddress
                    : '未提供', theme),
            if (_order.buyerNote.isNotEmpty) ...[
              _buildInfoRow('买家备注', _order.buyerNote, theme),
            ] else ...[
              _buildInfoRow('买家备注', '暂无备注', theme),
            ],
            // 使用Builder来封装售后记录逻辑
            Builder(
              builder: (context) {
                // 收集所有售后记录，包括兼容旧数据的情况
                List<AfterSalesRecord> allAfterSalesRecords = [];

                // 1. 优先使用售后记录列表，无论是否为空
                if (_order.afterSalesRecords != null) {
                  allAfterSalesRecords = _order.afterSalesRecords!;
                }
                // 2. 兼容旧数据：如果没有售后记录列表但有单个售后信息，创建一个售后记录
                if (allAfterSalesRecords.isEmpty) {
                  if ([
                        MerchantOrderStatus.refunding,
                        MerchantOrderStatus.refunded,
                        MerchantOrderStatus.repair
                      ].contains(_order.status) ||
                      _order.refundReason != null ||
                      _order.afterSalesDescription != null) {
                    allAfterSalesRecords.add(AfterSalesRecord(
                      type: _order.afterSalesType ??
                          (_order.status == MerchantOrderStatus.repair
                              ? 'repair'
                              : 'refund'),
                      reason: _order.refundReason,
                      description: _order.afterSalesDescription,
                      images: _order.refundImages,
                      applyTime: _order.afterSalesApplyTime,
                      status: _order.afterSalesStatus,
                    ));
                  }
                }

                // 如果有售后记录，显示它们
                if (allAfterSalesRecords.isNotEmpty) {
                  // 按申请时间降序排序，确保最新的记录在前面
                  allAfterSalesRecords.sort((a, b) =>
                      (b.applyTime ?? DateTime.now())
                          .compareTo(a.applyTime ?? DateTime.now()));

                  // 使用独立的StatefulWidget来管理显示全部/仅显示最近2条的状态
                  return MerchantAfterSalesRecordsWidget(
                    afterSalesRecords: allAfterSalesRecords,
                    buildSingleRecord: (record) => _buildAfterSalesRecordItem(record, theme),
                  );
                } else {
                  // 如果没有售后记录，返回空容器
                  return Container();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建商品信息卡片
  Widget _buildProductInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '商品信息',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surface,
                  ),
                  child: _order.productImage.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: _order.productImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Image.file(
                          File(_order.productImage),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _order.productName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_order.productVariant.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _order.productVariant,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.yellow,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _order.points.toString(),
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Monaco',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '¥${(_order.actualAmount / _order.quantity).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建订单信息卡片
  Widget _buildOrderInfoCard(BuildContext context, ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '订单信息',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (!_order.isAbnormal) ...[
                      IconButton(
                        icon: Icon(
                          Icons.warning_amber,
                          color: theme.colorScheme.error,
                          size: 16,
                        ),
                        onPressed: () {
                          // 标记订单为异常
                          _markOrderAbnormal(context);
                        },
                        tooltip: '标记异常',
                      ),
                    ] else ...[
                      IconButton(
                        icon: Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        onPressed: () {
                          // 取消异常标记
                          _cancelOrderAbnormal(context);
                        },
                        tooltip: '取消异常',
                      ),
                    ],
                    IconButton(
                      icon: Icon(
                        Icons.edit_note,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      onPressed: () {
                        // 手动改价功能
                        _showPriceEditDialog(context);
                      },
                      tooltip: '手动改价',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      onPressed: () {
                        // 订单锁定功能
                        _toggleOrderLock(context);
                      },
                      tooltip: '锁定/解锁订单',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('订单号', _order.id, theme),
            _buildInfoRow('支付方式', _order.paymentMethod, theme),
            _buildInfoRow('配送方式', _order.deliveryMethod, theme),
            _buildInfoRow('是否异常', _order.isAbnormal ? '是' : '否', theme),
            if (_order.isAbnormal) ...[
              _buildInfoRow('异常原因', '请填写异常原因', theme),
            ],
            if (_order.refundReason != null) ...[
              _buildInfoRow(
                _order.afterSalesType == 'repair' ? '维修原因' : '退款原因',
                _order.refundReason!,
                theme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建物流信息卡片
  Widget _buildLogisticsInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '物流信息',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 显示真实物流信息
            if (_order.logisticsInfo != null) ...[
              _buildInfoRow(
                  '物流单号', _order.logisticsInfo!.trackingNumber ?? '-', theme),
              _buildInfoRow(
                  '物流公司', _order.logisticsInfo!.logisticsCompany ?? '-', theme),
              _buildInfoRow(
                  '物流状态', _order.logisticsInfo!.logisticsStatus ?? '-', theme),
              const SizedBox(height: 12),

              // 显示物流轨迹
              Text(
                '物流轨迹',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (_order.logisticsInfo!.tracks != null &&
                  _order.logisticsInfo!.tracks!.isNotEmpty) ...[
                ..._order.logisticsInfo!.tracks!.map((track) {
                  final isFirst = _order.logisticsInfo!.tracks!.first == track;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 时间线节点和线
                        Column(
                          children: [
                            Container(
                              width: isFirst ? 12 : 8,
                              height: isFirst ? 12 : 8,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isFirst
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                borderRadius:
                                    BorderRadius.circular(isFirst ? 6 : 4),
                                border: isFirst
                                    ? Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                            if (_order.logisticsInfo!.tracks!.last !=
                                track) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 1,
                                height: 40,
                                margin: const EdgeInsets.only(right: 15),
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                              ),
                            ],
                          ],
                        ),
                        // 物流信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.description,
                                style: TextStyle(
                                  color: isFirst
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: isFirst
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${track.time} ${track.location}',
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
                }),
              ] else ...[
                Text(
                  '暂无物流轨迹信息',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ] else ...[
              Text(
                '暂无物流信息',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建支付信息卡片
  Widget _buildPaymentInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支付信息',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('支付方式', _order.paymentMethod, theme),
            _buildInfoRow(
                '支付时间',
                _order.paymentTime != null
                    ? _formatDate(_order.paymentTime!)
                    : '未支付', theme),
            _buildInfoRow('支付状态', _order.isPaid ? '已支付' : '未支付', theme),
            _buildInfoRow('购买数量', '${_order.quantity} 件', theme),
            // 添加积分支付信息
            if (_order.points > 0) ...[
              _buildInfoRow('积分金额',
                  '${_order.points} 积分 (${_order.points ~/ _order.quantity} 积分/件 × ${_order.quantity} 件)', theme),
              _buildInfoRow('支付类型', '积分兑换', theme),
            ] else ...[
              _buildInfoRow('支付类型', '现金购买', theme),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '单价',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '¥${(_order.originalAmount / _order.quantity).toStringAsFixed(2)}/件',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '数量',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '× ${_order.quantity}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Divider(color: theme.colorScheme.outline.withOpacity(0.1), height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '原价',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '¥${_order.originalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '实付金额',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _order.points > 0
                      ? '${_order.points} 积分'
                      : '¥${_order.actualAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化日期时间，包含秒
  String _formatDateWithSeconds(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  /// 构建操作记录卡片
  Widget _buildOperationLogCard(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productDatabaseService.getOperationLogsByOrderId(_order.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: theme.colorScheme.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '操作记录',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            color: theme.colorScheme.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '操作记录',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无操作记录',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final operationLogs = snapshot.data!;

        // 如果没有操作记录，添加基础的订单创建记录
        List<Map<String, dynamic>> displayLogs = [];
        if (operationLogs.isEmpty) {
          displayLogs.add({
            'operator': '系统',
            'action': '订单创建',
            'created_at': _order.orderTime.millisecondsSinceEpoch,
          });
          if (_order.paymentTime != null) {
            displayLogs.add({
              'operator': '系统',
              'action': '支付成功',
              'created_at': _order.paymentTime!.millisecondsSinceEpoch,
            });
          }
        } else {
          displayLogs = operationLogs;
        }

        // 使用ValueNotifier来管理折叠状态
        final isCollapsedNotifier = ValueNotifier<bool>(false);

        return Card(
          color: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和折叠按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '操作记录',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (displayLogs.length > 3) ...[
                      TextButton.icon(
                        onPressed: () {
                          isCollapsedNotifier.value =
                              !isCollapsedNotifier.value;
                        },
                        icon: ValueListenableBuilder<bool>(
                          valueListenable: isCollapsedNotifier,
                          builder: (context, isCollapsed, child) {
                            return Icon(
                              isCollapsed
                                  ? Icons.expand_more
                                  : Icons.expand_less,
                              color: theme.colorScheme.primary,
                              size: 16,
                            );
                          },
                        ),
                        label: ValueListenableBuilder<bool>(
                          valueListenable: isCollapsedNotifier,
                          builder: (context, isCollapsed, child) {
                            return Text(
                              isCollapsed ? '展开' : '收起',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<bool>(
                  valueListenable: isCollapsedNotifier,
                  builder: (context, isCollapsed, child) {
                    final logsToShow = isCollapsed
                        ? displayLogs.take(3).toList()
                        : displayLogs;
                    return Column(
                      children: logsToShow.map((log) {
                        final DateTime createdAt =
                            DateTime.fromMillisecondsSinceEpoch(
                                log['created_at'] as int);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 时间标签
                              Text(
                                _formatDateWithSeconds(createdAt),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 操作内容
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${log['operator']} - ${log['action']}',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                    // 如果有描述，显示描述
                                    if (log['description'] != null &&
                                        log['description']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        log['description'].toString(),
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                // 显示更多按钮
                ValueListenableBuilder<bool>(
                  valueListenable: isCollapsedNotifier,
                  builder: (context, isCollapsed, child) {
                    if (isCollapsed && displayLogs.length > 3) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            isCollapsedNotifier.value = false;
                          },
                          child: Text(
                            '查看全部 ${displayLogs.length} 条记录',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 获取售后原因
  String? _getAfterSalesReason(MerchantOrder order) {
    // 优先使用售后记录中的原因
    if (_order.afterSalesRecords != null &&
        _order.afterSalesRecords!.isNotEmpty) {
      for (var record in _order.afterSalesRecords!) {
        if (record.reason != null && record.reason!.isNotEmpty) {
          return record.reason;
        }
      }
    }

    // 然后使用专门的退款原因字段
    if (_order.refundReason != null && _order.refundReason!.isNotEmpty) {
      return _order.refundReason;
    }

    // 然后使用售后描述字段
    if (_order.afterSalesDescription != null &&
        _order.afterSalesDescription!.isNotEmpty) {
      return _order.afterSalesDescription;
    }

    return null;
  }

  /// 获取售后描述
  String? _getAfterSalesDescription(MerchantOrder order) {
    // 优先使用售后描述字段
    if (_order.afterSalesDescription != null &&
        _order.afterSalesDescription!.isNotEmpty) {
      return _order.afterSalesDescription;
    }

    // 然后使用退款原因字段
    if (_order.refundReason != null && _order.refundReason!.isNotEmpty) {
      return _order.refundReason;
    }

    return null;
  }

  /// 构建完整的售后图片路径
  Future<String> _buildAfterSalesImagePath(String imageName) async {
    try {
      // 获取当前用户ID（售后图片属于下单用户）
      final String userId = _order.id.split('_')[0]; // 假设订单ID格式为 userId_orderId

      // 从SharedPreferences获取自定义存储路径
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('storage_path');
      String basePath;

      if (customPath != null && customPath.isNotEmpty) {
        // 使用自定义存储路径
        basePath = customPath;
      } else {
        // 使用默认路径
        Directory directory;
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          // 移动端使用应用文档目录
          directory = await getApplicationDocumentsDirectory();
        } else if (defaultTargetPlatform == TargetPlatform.windows) {
          // Windows使用文档目录
          directory = Directory(
              path.join(Platform.environment['USERPROFILE']!, 'Documents'));
        } else if (defaultTargetPlatform == TargetPlatform.macOS) {
          // macOS使用文档目录
          directory =
              Directory(path.join(Platform.environment['HOME']!, 'Documents'));
        } else if (defaultTargetPlatform == TargetPlatform.linux) {
          // Linux使用文档目录
          directory =
              Directory(path.join(Platform.environment['HOME']!, 'Documents'));
        } else {
          throw UnsupportedError('Unsupported platform');
        }

        // 使用默认存储目录
        basePath = path.join(directory.path, 'MomentKeep');
      }

      // 构建完整的售后图片路径
      // 根据用户描述：售后图片存放在用户设置目录的default目录下store目录下用户目录下after-sales目录下
      final fullPath = path.join(
          basePath, 'default', 'store', userId, 'after-sales', imageName);

      return fullPath;
    } catch (e) {
      debugPrint('构建售后图片路径失败: $e');
      return imageName; // 失败时返回原始名称
    }
  }

  /// 构建售后记录项组件（可折叠）
  Widget _buildAfterSalesRecordItem(AfterSalesRecord record, ThemeData theme) {
    final bool isRepair = record.type == 'repair';
    final bool isRefund = record.type == 'refund';

    return Builder(
      builder: (context) {
        return Card(
          color: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRepair
                        ? '维修申请'
                        : isRefund
                            ? '退款申请'
                            : '售后申请',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (record.status != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: record.status == '已拒绝'
                            ? theme.colorScheme.error.withOpacity(0.2)
                            : record.status == '已同意'
                                ? theme.colorScheme.primary.withOpacity(0.2)
                                : theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record.status!,
                        style: TextStyle(
                          color: record.status == '已拒绝'
                              ? theme.colorScheme.error
                              : record.status == '已同意'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                record.applyTime != null
                    ? _formatDate(record.applyTime!)
                    : '暂无申请时间',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 显示维修/退款原因
                      _buildInfoRow(isRepair ? '维修原因' : '退款原因',
                          record.reason ?? record.description ?? '暂无原因', theme),
                      // 显示问题描述
                      _buildInfoRow('问题描述',
                          record.description ?? record.reason ?? '暂无描述', theme),
                      // 显示申请时间
                      _buildInfoRow(
                          '申请时间',
                          record.applyTime != null
                              ? _formatDate(record.applyTime!)
                              : '暂无时间', theme),
                      // 显示退款金额（仅退款时）
                      if (isRefund) ...[
                        _buildInfoRow('退款金额', '¥${_order.actualAmount}', theme),
                      ],
                      // 显示退款/维修图片
                      const SizedBox(height: 12),
                      Text(
                        isRepair ? '维修图片' : '退款图片',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: record.images != null &&
                                record.images!.isNotEmpty
                            ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: record.images!.length,
                                itemBuilder: (context, index) {
                                  final imageName = record.images![index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () {
                                        // 点击放大图片
                                        _showImagePreview(context, imageName);
                                      },
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: const Color(0xFF16291d),
                                        ),
                                        child: imageName.startsWith('http')
                                            ? CachedNetworkImage(
                                                imageUrl: imageName,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Color(0xFF13ec5b),
                                                  ),
                                                ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              )
                                            : FutureBuilder<String>(
                                                future:
                                                    _buildAfterSalesImagePath(
                                                        imageName),
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.done) {
                                                    final fullPath =
                                                        snapshot.data ??
                                                            imageName;
                                                    return Image(
                                                      image: FileImage(
                                                          File(fullPath)),
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const Center(
                                                        child: Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    return const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        color:
                                                            Color(0xFF13ec5b),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFF16291d),
                                    border: Border.all(
                                        color: Colors.white24, width: 1),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                          size: 24,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          '暂无图片',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 显示图片预览
  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              // 返回false，通知订单管理页不需要刷新订单列表
              Navigator.pop(context, false);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: imageUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF13ec5b),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          )
                        : FutureBuilder<String>(
                            future: _buildAfterSalesImagePath(imageUrl),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                final fullPath = snapshot.data ?? imageUrl;
                                return Image(
                                  image: FileImage(File(fullPath)),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white,
                                      size: 64,
                                    ),
                                  ),
                                );
                              } else {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF13ec5b),
                                  ),
                                );
                              }
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // 返回false，通知订单管理页不需要刷新订单列表
                      Navigator.pop(context, false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13ec5b),
                      foregroundColor: const Color(0xFF112217),
                    ),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 消息输入控制器
  final TextEditingController _messageController = TextEditingController();
  // 沟通记录列表状态
  final ValueNotifier<List<Map<String, String>>> _communicationLogs =
      ValueNotifier([]);
  // 记录是否折叠
  final ValueNotifier<bool> _isCollapsed = ValueNotifier(false);

  /// 发送消息
  Future<void> _sendMessage(
      {String? existingMessageId, int? index, String? imagePath}) async {
    String messageContent;

    if (imagePath != null) {
      // 图片消息
      messageContent = 'image:$imagePath';
    } else {
      // 文本消息
      messageContent = existingMessageId != null
          ? _communicationLogs.value[index!]['content']!
          : _messageController.text.trim();

      if (messageContent.isEmpty) return;
    }

    // 创建或更新消息对象
    final newMessage = {
      'id':
          existingMessageId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender': '商家',
      'content': messageContent,
      'time': _formatDateWithSeconds(DateTime.now()),
      'status': 'sending', // sending, sent, failed
    };

    List<Map<String, dynamic>> updatedLogs =
        List.from(_communicationLogs.value);

    if (existingMessageId != null && index != null) {
      // 更新现有消息
      updatedLogs[index] = newMessage;
    } else {
      // 添加新消息
      updatedLogs.add(newMessage);
      // 清空输入框（仅文本消息）
      if (imagePath == null) {
        _messageController.clear();
      }
    }

    // 更新本地状态，立即显示消息
    _communicationLogs.value = List<Map<String, String>>.from(updatedLogs);

    try {
      // 创建NotificationInfo对象
      final notification = NotificationInfo(
        id: 'notification_${DateTime.now().millisecondsSinceEpoch}',
        orderId: _order.id,
        productName: _order.productName,
        productImage: _order.productImage,
        type: NotificationType.system, // 使用system类型，因为这是商家发送的消息
        status: NotificationStatus.unread,
        content: messageContent,
        createdAt: DateTime.now(),
      );

      // 发送通知到数据库
      await _notificationService.addNotification(notification);

      // 更新消息状态为已发送
      if (existingMessageId != null && index != null) {
        updatedLogs[index]['status'] = 'sent';
      } else {
        updatedLogs.last['status'] = 'sent';
      }
      _communicationLogs.value = List<Map<String, String>>.from(updatedLogs);
    } catch (e) {
      debugPrint('发送消息失败: $e');

      // 更新消息状态为发送失败
      if (existingMessageId != null && index != null) {
        updatedLogs[index]['status'] = 'failed';
      } else {
        updatedLogs.last['status'] = 'failed';
      }
      _communicationLogs.value = List<Map<String, String>>.from(updatedLogs);
    }
  }

  // 从数据库获取真实沟通记录
  Future<void> _loadCommunicationLogs() async {
    try {
      // 从通知数据库获取该订单的所有通知
      final notifications =
          await _notificationService.getNotificationsByOrderId(_order.id);
      // 将通知转换为沟通记录格式
      final communicationLogs = notifications.map((notification) {
        // 修复发送者识别：根据通知ID前缀判断发送者
        // notification_前缀的通知是商家发送的，其他是买家发送的
        final isSeller = notification.id.startsWith('notification_');
        return <String, String>{
          'sender': isSeller ? '商家' : '买家',
          'content': notification.content,
          'time': _formatDateWithSeconds(notification.createdAt),
        };
      }).toList();
      // 修复消息顺序：最新消息显示在最下面
      communicationLogs.sort((a, b) {
        return DateTime.parse(a['time']!).compareTo(DateTime.parse(b['time']!));
      });
      _communicationLogs.value = communicationLogs;
    } catch (e) {
      debugPrint('获取沟通记录失败: $e');
      _communicationLogs.value = <Map<String, String>>[];
    }
  }

  /// 构建沟通记录卡片
  Widget _buildCommunicationLogCard(BuildContext context, ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和折叠按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '沟通记录',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _isCollapsed,
                  builder: (context, isCollapsed, child) {
                    return TextButton.icon(
                      onPressed: () {
                        _isCollapsed.value = !isCollapsed;
                      },
                      icon: Icon(
                        isCollapsed ? Icons.expand_more : Icons.expand_less,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      label: Text(
                        isCollapsed ? '展开' : '收起',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 沟通记录列表
            ValueListenableBuilder<bool>(
              valueListenable: _isCollapsed,
              builder: (context, isCollapsed, child) {
                return ValueListenableBuilder<List<Map<String, String>>>(
                  valueListenable: _communicationLogs,
                  builder: (context, logs, child) {
                    if (isCollapsed) {
                      // 折叠状态下只显示最新的3条记录
                      final displayLogs = logs.length > 3
                          ? logs.sublist(logs.length - 3)
                          : logs;
                      return Column(
                        children: [
                          _buildCommunicationList(displayLogs, context),
                          if (logs.length > 3) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _isCollapsed.value = false;
                              },
                              child: Text(
                                '查看全部 ${logs.length} 条记录',
                                style: const TextStyle(
                                  color: Color(0xFF13ec5b),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    } else {
                      // 展开状态下显示所有记录
                      return _buildCommunicationList(logs, context);
                    }
                  },
                );
              },
            ),

            // 发送消息输入框
            Row(
              children: [
                // 图片选择按钮
                IconButton(
                  onPressed: () async {
                    // 选择图片
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );

                    if (pickedFile != null) {
                      try {
                        // 从订单ID中提取用户ID
                        final userId = _order.id.split('_')[0];

                        // 构建目标目录路径：basePath/default/store/userId/after-sales
                        final prefs = await SharedPreferences.getInstance();
                        final customPath = prefs.getString('storage_path');
                        String basePath;

                        if (customPath != null && customPath.isNotEmpty) {
                          basePath = customPath;
                        } else {
                          // 使用默认路径
                          Directory directory;
                          if (Platform.isAndroid || Platform.isIOS) {
                            directory =
                                await getApplicationDocumentsDirectory();
                          } else if (Platform.isWindows) {
                            directory = Directory(path.join(
                                Platform.environment['USERPROFILE']!,
                                'Documents'));
                          } else if (Platform.isMacOS) {
                            directory = Directory(path.join(
                                Platform.environment['HOME']!, 'Documents'));
                          } else if (Platform.isLinux) {
                            directory = Directory(path.join(
                                Platform.environment['HOME']!, 'Documents'));
                          } else {
                            throw UnsupportedError('Unsupported platform');
                          }
                          basePath =
                              path.join(directory.path, 'MomentKeep');
                        }

                        // 创建目标目录
                        final targetDir = Directory(path.join(basePath,
                            'default', 'store', userId, 'after-sales'));
                        await targetDir.create(recursive: true);

                        // 生成新的图片文件名
                        final imageName =
                            'chat_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
                        final targetPath = path.join(targetDir.path, imageName);

                        // 复制图片到目标目录
                        final sourceFile = File(pickedFile.path);
                        await sourceFile.copy(targetPath);

                        // 发送图片消息
                        await _sendMessage(imagePath: targetPath);
                      } catch (e) {
                        debug.log('发送图片失败: $e');
                        // 显示错误提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('发送图片失败'),
                            backgroundColor: Color(0xFFff6b6b),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      onSubmitted: (value) {
                        _sendMessage();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: Icon(
                    Icons.send,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建沟通记录列表
  Widget _buildCommunicationList(
      List<Map<String, String>> logs, BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    if (logs.isEmpty) {
      return Center(
        child: Text(
          '暂无沟通记录',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 300, // 限制最大高度为300
      ),
      child: SingleChildScrollView(
        reverse: true, // 从底部开始显示，最新消息在底部
        child: Column(
          children: logs.map((log) {
            final isSeller = log['sender'] == '商家';
            final messageStatus =
                log['status'] ?? 'sent'; // sending, sent, failed
            final messageId = log['id'];
            final content = log['content']!;
            final isImage = content.startsWith('image:');

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    isSeller ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  // 买家头像（在左侧）
                  if (!isSeller) ...[
                    // 买家头像
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      child: Text('买',
                          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 消息内容和状态
                  Column(
                    crossAxisAlignment: isSeller
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // 消息内容
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: isImage
                            ? const EdgeInsets.all(4)
                            : const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSeller
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isSeller
                                ? const Radius.circular(12)
                                : const Radius.circular(0),
                            bottomRight: isSeller
                                ? const Radius.circular(0)
                                : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isSeller
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (isImage) ...[
                              // 显示图片消息
                              GestureDetector(
                                onTap: () {
                                  // 查看大图
                                  _showImagePreview(
                                      context, content.substring(6));
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(content.substring(6)),
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // 显示文本消息
                              Text(
                                content,
                                style: TextStyle(
                                  color: isSeller ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  log['time']!,
                                  style: TextStyle(
                                    color: isSeller
                                        ? theme.colorScheme.onPrimary.withOpacity(0.7)
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // 消息状态指示器
                                if (messageStatus == 'sending') ...[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ] else if (messageStatus == 'failed') ...[
                                  GestureDetector(
                                    onTap: () {
                                      // 重新发送消息
                                      _sendMessage(
                                          existingMessageId: messageId);
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: theme.colorScheme.error,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '发送失败，点击重试',
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 商家头像（在右侧）
                  if (isSeller) ...[
                    const SizedBox(width: 8),
                    // 商家头像
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text('商',
                          style: TextStyle(fontSize: 14, color: theme.colorScheme.onPrimary)),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 构建商家备注卡片
  Widget _buildMerchantNoteCard(BuildContext context, ThemeData theme) {
    // 备注编辑状态
    bool isEditing = false;
    // 备注内容
    String noteContent = _order.merchantNote ?? '';

    return Card(
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '商家备注',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                  onPressed: () {
                    // 打开备注编辑对话框
                    _showNoteEditDialog(context, _order.merchantNote ?? '');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _order.merchantNote ?? '暂无备注',
              style: TextStyle(
                color: _order.merchantNote != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示备注编辑对话框
  void _showNoteEditDialog(BuildContext context, String currentNote) {
    String noteText = currentNote;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            '编辑备注',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            maxLines: 4,
            onChanged: (value) {
              noteText = value;
            },
            decoration: InputDecoration(
              hintText: '请输入备注内容',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
            controller: TextEditingController(text: currentNote),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // 保存备注功能
                if (noteText.isNotEmpty) {
                  // 这里应该调用数据库服务保存备注
                  // 由于数据库服务尚未实现，我们暂时通过重建订单对象来模拟
                  final updatedOrder = MerchantOrder(
                    id: _order.id,
                    productName: _order.productName,
                    productImage: _order.productImage,
                    productVariant: _order.productVariant,
                    quantity: _order.quantity,
                    points: _order.points,
                    originalAmount: _order.originalAmount,
                    actualAmount: _order.actualAmount,
                    buyerName: _order.buyerName,
                    buyerPhone: _order.buyerPhone,
                    deliveryAddress: _order.deliveryAddress,
                    buyerNote: _order.buyerNote,
                    paymentMethod: _order.paymentMethod,
                    deliveryMethod: _order.deliveryMethod,
                    isAbnormal: _order.isAbnormal,
                    orderTime: _order.orderTime,
                    paymentTime: _order.paymentTime,
                    isPaid: _order.isPaid,
                    status: _order.status,
                    logisticsInfo: _order.logisticsInfo,
                    refundReason: _order.refundReason,
                    refundImages: _order.refundImages,
                    merchantNote: noteText,
                  );

                  // 使用Navigator.popAndPushNamed重新加载页面，以显示更新后的备注
                  Navigator.pop(dialogContext);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MerchantOrderDetailPage(order: updatedOrder),
                    ),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('备注保存成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('备注内容不能为空', style: TextStyle(color: theme.colorScheme.onError)),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 标记订单为异常
  void _markOrderAbnormal(BuildContext context) {
    // 标记订单为异常功能暂时留空，后续可以根据实际情况补充
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('标记订单异常功能暂未实现'),
        backgroundColor: Color(0xFF13ec5b),
      ),
    );
  }

  /// 取消异常标记
  void _cancelOrderAbnormal(BuildContext context) {
    // 取消订单异常标记功能暂时留空，后续可以根据实际情况补充
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('取消订单异常标记功能暂未实现'),
        backgroundColor: Color(0xFF13ec5b),
      ),
    );
  }

  /// 显示价格编辑对话框
  void _showPriceEditDialog(BuildContext context) {
    double newPrice = _order.actualAmount;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16291d),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            '手动改价',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  newPrice = double.tryParse(value) ?? _order.actualAmount;
                },
                decoration: InputDecoration(
                  hintText: '请输入新价格',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1e3626),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                controller: TextEditingController(
                    text: _order.actualAmount.toStringAsFixed(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                '改价原因',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '请输入改价原因',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1e3626),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // 手动改价功能暂时留空，后续可以根据实际情况补充
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('手动改价功能暂未实现'),
                    backgroundColor: Color(0xFF13ec5b),
                  ),
                );
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 切换订单锁定状态
  void _toggleOrderLock(BuildContext context) {
    // 切换订单锁定状态功能暂时留空，后续可以根据实际情况补充
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('切换订单锁定状态功能暂未实现'),
        backgroundColor: Color(0xFF13ec5b),
      ),
    );
  }

  /// 录入物流
  void _enterLogistics() {
    // 创建物流信息录入对话框
    showDialog(
      context: context,
      builder: (context) {
        String logisticsCompany = '';
        String trackingNumber = '';
        final theme = ref.watch(currentThemeProvider);

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
                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
                // 返回false，通知订单管理页不需要刷新订单列表
                Navigator.pop(context, false);
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

                // 创建物流信息对象
                final logisticsInfo = LogisticsInfo(
                  logisticsCompany: logisticsCompany,
                  trackingNumber: trackingNumber,
                  logisticsStatus: '已发货',
                );

                // 更新订单状态为已发货，并保存物流信息
                final updateData = {
                  'status': '已发货',
                  'logistics_info': jsonEncode({
                    'logistics_company': logisticsCompany,
                    'tracking_number': trackingNumber,
                    'logistics_status': '已发货',
                    'tracks': [],
                  }),
                };

                final currentTime = DateTime.now().millisecondsSinceEpoch;
                debugPrint('[$currentTime] 开始更新订单 ${_order.id} 的物流信息');
                debugPrint(
                    '[$currentTime] 更新前订单 ${_order.id} 的状态: ${_order.status}');

                // 使用单例更新订单
                ProductDatabaseService()
                    .updateOrder(_order.id, updateData)
                    .then((result) {
                  debugPrint('[$currentTime] 更新订单 ${_order.id} 结果: $result');

                  if (result > 0) {
                    // 更新成功，直接刷新本地数据并通知父页面
                    _refreshOrderData().then((_) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('已成功录入物流信息'),
                          backgroundColor: theme.colorScheme.primary,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      debugPrint('[$currentTime] 订单详情页关闭，返回true，通知订单管理页刷新订单列表');
                      Navigator.pop(context, true);
                    });
                  } else {
                    // 更新失败
                    debugPrint('[$currentTime] 更新订单 ${_order.id} 失败，没有找到匹配的订单');
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('更新订单失败，没有找到匹配的订单'),
                        backgroundColor: theme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context, false);
                  }
                }).catchError((e) {
                  debugPrint('[$currentTime] 更新订单 ${_order.id} 出错: $e');
                  Navigator.pop(context, false);
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

  /// 构建订单操作按钮
  Widget _buildOrderActionButtons(BuildContext context, ThemeData theme) {
    List<Widget> actions = [];

    switch (_order.status) {
      case MerchantOrderStatus.pendingPayment:
        actions = [
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  // 更新状态为已取消
                  await _productDatabaseService.updateOrderStatus(
                    _order.id,
                    '已取消',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('订单已取消'),
                        backgroundColor: Color(0xFF13ec5b),
                      ),
                    );
                    // 返回true，通知订单管理页刷新
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('取消失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '取消订单',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () {
                // 联系买家功能暂时留空，后续可以根据实际情况补充
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('联系买家功能暂未实现'),
                    backgroundColor: Color(0xFF13ec5b),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.message,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '联系买家',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
        break;
      case MerchantOrderStatus.pendingAccept:
        actions = [
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  // 更新状态为已拒绝
                  await _productDatabaseService.updateOrderStatus(
                    _order.id,
                    '已拒绝',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已拒绝该订单'),
                        backgroundColor: Color(0xFF13ec5b),
                      ),
                    );
                    // 返回true，通知订单管理页刷新
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('拒绝失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '拒单',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  // 更新状态为待发货
                  await _productDatabaseService.updateOrderStatus(
                    _order.id,
                    '待发货',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已成功接单，请尽快发货'),
                        backgroundColor: Color(0xFF13ec5b),
                      ),
                    );
                    // 返回true，通知订单管理页刷新
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('接单失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                shadowColor: const Color(0xFF13ec5b).withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '立即接单',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
        break;
      case MerchantOrderStatus.pendingShip:
        actions = [
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () {
                // 查看详情操作
                debugPrint('查看详情: ${_order.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '查看详情',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () {
                // 录入物流操作
                _enterLogistics();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.local_shipping,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '录入物流',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        ];
        break;
      case MerchantOrderStatus.shipped:
        actions = [
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () {
                // 查看物流操作
                debugPrint('查看物流: ${_order.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '查看物流',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () {
                // 联系买家操作
                debugPrint('联系买家: ${_order.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.message,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '联系买家',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
        break;
      case MerchantOrderStatus.refunding:
        actions = [
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () async {
                // 拒绝退款操作
                debugPrint('拒绝退款: ${_order.id}');
                try {
                  // 使用ProductDatabaseService的拒绝退款方法
                  await _productDatabaseService.rejectRefund(
                    _order.id,
                    '商家',
                    '拒绝退款申请',
                  );

                  // 刷新订单数据
                  await _refreshOrderData();

                  // 显示成功提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已拒绝退款申请'),
                      backgroundColor: Color(0xFF13ec5b),
                    ),
                  );
                } catch (e) {
                  // 显示错误提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('拒绝退款失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '拒绝退款',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () async {
                // 同意退款操作
                debugPrint('同意退款: ${_order.id}');
                try {
                  // 使用ProductDatabaseService的同意退款方法
                  await _productDatabaseService.approveRefund(
                    _order.id,
                    '商家',
                    '同意退款申请',
                    databaseService: _databaseService,
                  );

                  // 刷新订单数据
                  await _refreshOrderData();

                  // 显示成功提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已同意退款申请'),
                      backgroundColor: Color(0xFF13ec5b),
                    ),
                  );
                } catch (e) {
                  // 显示错误提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('同意退款失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '同意退款',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ];
        break;
      case MerchantOrderStatus.repair:
        // 检查售后状态，决定显示什么按钮
        final afterSalesStatus = _order.afterSalesStatus;
        if (afterSalesStatus == 'approved') {
          // 售后状态已批准，显示维修完成按钮
          actions = [
            SizedBox(
              width: 312,
              child: ElevatedButton(
                onPressed: () async {
                  // 维修完成操作
                  debugPrint('维修完成: ${_order.id}');
                  try {
                    // 使用ProductDatabaseService的维修完成方法
                    await _productDatabaseService.completeRepair(
                      _order.id,
                      '商家',
                      '维修完成',
                    );

                    // 刷新订单数据
                    await _refreshOrderData();

                    // 显示成功提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('维修已完成'),
                        backgroundColor: Color(0xFF13ec5b),
                      ),
                    );
                  } catch (e) {
                    // 显示错误提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('维修完成失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13ec5b),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '维修完成',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ];
        } else {
          // 售后状态未批准，显示拒绝维修和同意维修按钮
          actions = [
            SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: () async {
                  // 拒绝维修操作
                  debugPrint('拒绝维修: ${_order.id}');
                  try {
                    // 使用ProductDatabaseService的拒绝维修方法
                    await _productDatabaseService.rejectRepair(
                      _order.id,
                      '商家',
                      '拒绝维修申请',
                    );

                    // 刷新订单数据
                    await _refreshOrderData();

                    // 显示成功提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已拒绝维修申请'),
                        backgroundColor: Color(0xFF13ec5b),
                      ),
                    );
                  } catch (e) {
                    // 显示错误提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('拒绝维修失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '拒绝维修',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: () async {
                  // 同意维修操作
                  debugPrint('同意维修: ${_order.id}');
                  try {
                    // 使用ProductDatabaseService的同意维修方法
                    await _productDatabaseService.approveRepair(
                      _order.id,
                      '商家',
                      '同意维修申请',
                    );

                    // 刷新订单数据
                    await _refreshOrderData();

                    // 显示成功提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已同意维修申请'),
                        backgroundColor: Color(0xFF13ec5b),
                      ),
                    );
                  } catch (e) {
                    // 显示错误提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('同意维修失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13ec5b),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '同意维修',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ];
        }
        break;
      case MerchantOrderStatus.refunded:
        // 已退款状态，添加查看退款详情按钮
        actions = [
          SizedBox(
            width: 312,
            child: ElevatedButton(
              onPressed: () {
                // 查看退款详情操作
                debugPrint('查看退款详情: ${_order.id}');
                // 这里可以添加调用API的逻辑
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '查看退款详情',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ];
        break;
      case MerchantOrderStatus.completed:
      case MerchantOrderStatus.cancelled:
      case MerchantOrderStatus.rejected:
        actions = [
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () {
                // 查看订单操作
                debugPrint('查看订单: ${_order.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '查看订单',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ];
        break;
      default:
        actions = [];
    }

    return Row(
      children: actions,
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
      case MerchantOrderStatus.repair:
        return '维修中';
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

  /// 获取状态颜色
  Color _getStatusColor(MerchantOrderStatus status, ThemeData theme) {
    switch (status) {
      case MerchantOrderStatus.pendingPayment:
        return theme.colorScheme.secondary;
      case MerchantOrderStatus.pendingAccept:
        return theme.colorScheme.primary;
      case MerchantOrderStatus.pendingShip:
        return theme.colorScheme.primary;
      case MerchantOrderStatus.shipped:
        return theme.colorScheme.secondary;
      case MerchantOrderStatus.refunding:
        return theme.colorScheme.error;
      case MerchantOrderStatus.repair:
        return theme.colorScheme.primary;
      case MerchantOrderStatus.completed:
        return theme.colorScheme.onSurfaceVariant;
      case MerchantOrderStatus.cancelled:
        return theme.colorScheme.error;
      case MerchantOrderStatus.refunded:
        return theme.colorScheme.error;
      case MerchantOrderStatus.rejected:
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}

/// 商家版售后记录组件
class MerchantAfterSalesRecordsWidget extends StatefulWidget {
  /// 构造函数
  const MerchantAfterSalesRecordsWidget({
    super.key,
    required this.afterSalesRecords,
    required this.buildSingleRecord,
  });

  /// 所有售后记录
  final List<AfterSalesRecord> afterSalesRecords;

  /// 构建单条记录的回调函数
  final Widget Function(AfterSalesRecord record) buildSingleRecord;

  @override
  State<MerchantAfterSalesRecordsWidget> createState() =>
      _MerchantAfterSalesRecordsWidgetState();
}

class _MerchantAfterSalesRecordsWidgetState
    extends State<MerchantAfterSalesRecordsWidget> {
  /// 状态管理：是否显示全部记录
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    // 决定显示哪些记录
    List<AfterSalesRecord> displayedRecords = _showAll
        ? widget.afterSalesRecords
        : widget.afterSalesRecords.take(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(color: Colors.white24),
        const SizedBox(height: 12),
        // 售后记录标题和查看全部按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '售后记录',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 如果有超过1条记录，显示查看全部/收起按钮
            if (widget.afterSalesRecords.length > 1)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                child: Text(
                  _showAll ? '收起' : '查看全部 (${widget.afterSalesRecords.length})',
                  style: const TextStyle(
                    color: Color(0xFF13ec5b),
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 显示售后记录列表
        ...displayedRecords.map((record) {
          return widget.buildSingleRecord(record);
        }).toList(),
      ],
    );
  }
}
