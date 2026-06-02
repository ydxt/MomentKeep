import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moment_keep/services/database_service.dart';
import 'my_orders_page.dart';
import 'after_sales_apply_page.dart';
import 'package:moment_keep/presentation/components/return_logistics_dialog.dart';
import 'package:moment_keep/presentation/pages/return_logistics_tracking_page.dart';
import 'package:moment_keep/services/product_database_service.dart';

/// 售后工单状态枚举
enum AfterSalesStatus {
  pending,
  processing,
  approved,
  rejected,
  completed,
}

/// 售后类型枚举
enum AfterSalesType {
  refund,
  returnGoods,
  repair,
}

/// 售后工单模型
class AfterSalesOrder {
  final String id;
  final String orderId;
  final String productName;
  final String productImage;
  final String variant;
  final int quantity;
  final double amount;
  final AfterSalesType type;
  final AfterSalesStatus status;
  final String reason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? description;
  final List<String>? images;

  AfterSalesOrder({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.productImage,
    required this.variant,
    required this.quantity,
    required this.amount,
    required this.type,
    required this.status,
    required this.reason,
    required this.createdAt,
    this.updatedAt,
    this.description,
    this.images,
  });
}

/// 售后页面
class AfterSalesPage extends StatefulWidget {
  /// 售后页面构造函数
  const AfterSalesPage({super.key});

  @override
  State<AfterSalesPage> createState() => _AfterSalesPageState();
}

class _AfterSalesPageState extends State<AfterSalesPage> {
  List<AfterSalesOrder> _afterSalesOrders = [];
  bool _isLoading = true;
  AfterSalesStatus? _selectedStatus;
  Map<String, bool> _hasReturnLogistics = {};
  
  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadAfterSalesOrders();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label已复制'), duration: const Duration(seconds: 1)),
    );
  }

  /// 加载售后工单数据
  Future<void> _loadAfterSalesOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 从数据库加载售后工单数据
      final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
      final orderMaps = await _databaseService.getOrdersByUserId(userId);
      final orders = orderMaps.map((map) => Order.fromMap(map)).toList();
      
      // 转换为售后工单列表
      final afterSalesOrders = <AfterSalesOrder>[];
      
      for (final order in orders) {
        // 检查订单是否有售后记录
        if (order.afterSalesRecords != null && order.afterSalesRecords!.isNotEmpty) {
          for (final record in order.afterSalesRecords!) {
            // 转换售后类型
            AfterSalesType type;
            switch (record.type) {
              case 'refund':
                type = AfterSalesType.refund;
                break;
              case 'return':
                type = AfterSalesType.returnGoods;
                break;
              case 'repair':
                type = AfterSalesType.repair;
                break;
              default:
                type = AfterSalesType.refund;
            }
            
            // 转换售后状态
            AfterSalesStatus status;
            switch (record.status) {
              case 'pending':
                status = AfterSalesStatus.pending;
                break;
              case 'processing':
              case 'approved':
                status = AfterSalesStatus.processing;
                break;
              case 'completed':
                status = AfterSalesStatus.completed;
                break;
              case 'rejected':
                status = AfterSalesStatus.rejected;
                break;
              default:
                status = AfterSalesStatus.pending;
            }
            
            // 转换图片列表
            List<String> images = [];
            if (record.images != null) {
              images = record.images!;
            }
            
            // 创建售后工单
            final afterSalesOrder = AfterSalesOrder(
              id: record.id ?? '',
              orderId: order.id,
              productName: order.items.isNotEmpty ? order.items[0].name : '未知商品',
              productImage: order.items.isNotEmpty ? order.items[0].image : '',
              variant: order.items.isNotEmpty ? order.items[0].variant : '',
              quantity: order.items.isNotEmpty ? order.items[0].quantity : 1,
              amount: order.totalPrice,
              type: type,
              status: status,
              reason: record.reason ?? '',
              createdAt: record.createTime,
              updatedAt: record.createTime, // 使用createTime作为updatedAt的默认值
              description: record.description,
              images: images,
            );
            
            afterSalesOrders.add(afterSalesOrder);
          }
        }
      }
      
      setState(() {
        _afterSalesOrders = afterSalesOrders;
      });

      final hasReturnLogistics = <String, bool>{};
      final productDb = ProductDatabaseService();
      for (final order in afterSalesOrders) {
        if (order.type == AfterSalesType.returnGoods) {
          final returnLogistics =
              await productDb.getReturnLogisticsByOrderId(order.orderId);
          hasReturnLogistics[order.id] = returnLogistics.isNotEmpty;
        }
      }
      _hasReturnLogistics = hasReturnLogistics;
    } catch (e) {
      debugPrint('Error loading after-sales orders: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 获取售后类型文本
  String _getAfterSalesTypeText(AfterSalesType type) {
    switch (type) {
      case AfterSalesType.refund:
        return '退款';
      case AfterSalesType.returnGoods:
        return '退货';
      case AfterSalesType.repair:
        return '维修';
    }
  }

  /// 获取售后状态文本
  String _getAfterSalesStatusText(AfterSalesStatus status) {
    switch (status) {
      case AfterSalesStatus.pending:
        return '待审核';
      case AfterSalesStatus.processing:
        return '处理中';
      case AfterSalesStatus.approved:
        return '已通过';
      case AfterSalesStatus.rejected:
        return '已拒绝';
      case AfterSalesStatus.completed:
        return '已完成';
    }
  }

  /// 获取售后状态颜色
  Color _getAfterSalesStatusColor(AfterSalesStatus status) {
    switch (status) {
      case AfterSalesStatus.pending:
        return const Color(0xFFffc107);
      case AfterSalesStatus.processing:
        return const Color(0xFF13ec5b);
      case AfterSalesStatus.approved:
        return const Color(0xFF13ec5b);
      case AfterSalesStatus.rejected:
        return const Color(0xFFff4757);
      case AfterSalesStatus.completed:
        return const Color(0xFF92c9a4);
    }
  }

  /// 构建售后工单筛选栏
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1a3525),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '筛选',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  label: '全部状态',
                  isActive: _selectedStatus == null,
                  onTap: () {
                    setState(() {
                      _selectedStatus = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  label: '待审核',
                  isActive: _selectedStatus == AfterSalesStatus.pending,
                  onTap: () {
                    setState(() {
                      _selectedStatus = AfterSalesStatus.pending;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  label: '处理中',
                  isActive: _selectedStatus == AfterSalesStatus.processing,
                  onTap: () {
                    setState(() {
                      _selectedStatus = AfterSalesStatus.processing;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  label: '已通过',
                  isActive: _selectedStatus == AfterSalesStatus.approved,
                  onTap: () {
                    setState(() {
                      _selectedStatus = AfterSalesStatus.approved;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  label: '已拒绝',
                  isActive: _selectedStatus == AfterSalesStatus.rejected,
                  onTap: () {
                    setState(() {
                      _selectedStatus = AfterSalesStatus.rejected;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  label: '已完成',
                  isActive: _selectedStatus == AfterSalesStatus.completed,
                  onTap: () {
                    setState(() {
                      _selectedStatus = AfterSalesStatus.completed;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建筛选标签
  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF112217) : const Color(0xFF1a3525),
          border: Border.all(
            color: isActive ? const Color(0xFF13ec5b) : const Color(0xFF326744),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF13ec5b) : const Color(0xFF92c9a4),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建售后工单列表
  Widget _buildAfterSalesList() {
    // 筛选售后工单
    final filteredOrders = _afterSalesOrders.where((order) {
      if (_selectedStatus != null && order.status != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF13ec5b)));
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              color: Color(0xFF92c9a4),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无售后工单',
              style: TextStyle(
                color: const Color(0xFF92c9a4).withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildAfterSalesItem(order);
      },
    );
  }

  /// 构建售后工单项
  Widget _buildAfterSalesItem(AfterSalesOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a3525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF326744).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工单头部
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getAfterSalesTypeText(order.type)}工单',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getAfterSalesStatusColor(order.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getAfterSalesStatusText(order.status),
                  style: TextStyle(
                    color: _getAfterSalesStatusColor(order.status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF2a4532),
                ),
                child: CachedNetworkImage(
                  imageUrl: order.productImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF13ec5b), strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF92c9a4),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.variant,
                      style: const TextStyle(
                        color: Color(0xFF92c9a4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'x${order.quantity}',
                          style: const TextStyle(
                            color: Color(0xFF92c9a4),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '¥${order.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
          const SizedBox(height: 12),
          // 工单信息
          _buildInfoRow('工单编号', order.id),
          _buildInfoRow('订单编号', order.orderId, copyable: true),
          _buildInfoRow('申请原因', order.reason),
          if (order.description != null && order.description!.isNotEmpty)
            _buildInfoRow('问题描述', order.description!),
          const SizedBox(height: 12),
          // 工单时间
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '申请时间: ${_formatDate(order.createdAt)}',
                style: TextStyle(
                  color: const Color(0xFF92c9a4).withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              if (order.updatedAt != null)
                Text(
                  '更新时间: ${_formatDate(order.updatedAt!)}',
                  style: TextStyle(
                    color: const Color(0xFF92c9a4).withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton('查看详情', () {
                // 查看工单详情
                _viewAfterSalesDetail(order);
              }),
              if (order.status == AfterSalesStatus.pending)
                _buildActionButton('取消申请', () {
                  // 取消申请
                  _cancelAfterSales(order);
                }, isPrimary: true),
              if (order.status == AfterSalesStatus.approved && order.type == AfterSalesType.returnGoods)
                _buildActionButton('填写物流', () {
                  // 填写物流信息
                  _fillLogistics(order);
                }, isPrimary: true),
              if (_hasReturnLogistics[order.id] == true)
                _buildActionButton('查看退货物流', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReturnLogisticsTrackingPage(orderId: order.orderId),
                    ),
                  );
                }, isPrimary: false),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF92c9a4),
              fontSize: 12,
            ),
          ),
          Expanded(
            child: copyable
                ? InkWell(
                    onTap: () => _copyToClipboard(value, label),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy,
                          size: 12,
                          color: Color(0xFF92c9a4),
                        ),
                      ],
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton(String label, VoidCallback onPressed, {bool isPrimary = false}) {
    return Padding(
      padding: EdgeInsets.only(left: isPrimary ? 12 : 0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFF13ec5b) : Colors.transparent,
          foregroundColor: isPrimary ? const Color(0xFF112217) : const Color(0xFF13ec5b),
          side: isPrimary
              ? null
              : const BorderSide(color: Color(0xFF13ec5b)),
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

  /// 查看工单详情
  void _viewAfterSalesDetail(AfterSalesOrder order) {
    _showAfterSalesDetail(order);
  }

  /// 显示售后详情对话框
  void _showAfterSalesDetail(AfterSalesOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF112217),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1a3525),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '售后详情',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF92c9a4)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // 内容区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 状态时间线
                      _buildStatusTimeline(order),
                      const SizedBox(height: 20),
                      // 详情信息
                      _buildDetailInfo(order),
                    ],
                  ),
                ),
              ),
              // 底部操作按钮
              _buildDialogActions(order),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建状态时间线
  Widget _buildStatusTimeline(AfterSalesOrder order) {
    final steps = _getTimelineSteps(order);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '处理进度',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧时间线
              Column(
                children: [
                  // 状态点
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: step.isCompleted
                          ? const Color(0xFF13ec5b)
                          : step.isCurrent
                              ? const Color(0xFFffc107)
                              : const Color(0xFF326744),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: step.isCurrent
                            ? const Color(0xFFffc107)
                            : step.isCompleted
                                ? const Color(0xFF13ec5b)
                                : const Color(0xFF326744),
                        width: 2,
                      ),
                    ),
                    child: step.isCompleted
                        ? const Icon(Icons.check, color: Color(0xFF112217), size: 16)
                        : step.isCurrent
                            ? const Icon(Icons.pending, color: Color(0xFF112217), size: 16)
                            : null,
                  ),
                  // 连接线
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: step.isCompleted
                          ? const Color(0xFF13ec5b)
                          : const Color(0xFF326744),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // 右侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        color: step.isCompleted || step.isCurrent
                            ? Colors.white
                            : const Color(0xFF92c9a4),
                        fontSize: 14,
                        fontWeight: step.isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.subtitle,
                      style: TextStyle(
                        color: const Color(0xFF92c9a4).withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    if (step.timestamp != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.timestamp!,
                        style: TextStyle(
                          color: const Color(0xFF92c9a4).withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (step.isRejected) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFff4757).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFff4757).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '拒绝原因：${step.rejectionReason ?? '未说明'}',
                          style: const TextStyle(
                            color: Color(0xFFff4757),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// 获取时间线步骤数据
  List<_TimelineStep> _getTimelineSteps(AfterSalesOrder order) {
    final steps = <_TimelineStep>[];
    
    // 步骤1: 提交申请
    steps.add(_TimelineStep(
      title: '提交申请',
      subtitle: '售后申请已提交',
      timestamp: _formatDate(order.createdAt),
      isCompleted: true,
    ));
    
    // 步骤2: 商家审核
    if (order.status == AfterSalesStatus.pending) {
      steps.add(_TimelineStep(
        title: '商家审核',
        subtitle: '等待商家审核...',
        isCurrent: true,
      ));
    } else {
      steps.add(_TimelineStep(
        title: '商家审核',
        subtitle: order.status == AfterSalesStatus.rejected ? '审核未通过' : '审核通过',
        timestamp: order.updatedAt != null ? _formatDate(order.updatedAt!) : null,
        isCompleted: true,
      ));
    }
    
    // 步骤3: 处理中
    if (order.status == AfterSalesStatus.processing) {
      steps.add(_TimelineStep(
        title: '处理中',
        subtitle: '商家正在处理您的售后申请...',
        isCurrent: true,
      ));
    } else if (order.status != AfterSalesStatus.pending) {
      steps.add(_TimelineStep(
        title: '处理中',
        subtitle: order.status == AfterSalesStatus.rejected ? '审核未通过，无需处理' : '处理完成',
        timestamp: order.updatedAt != null ? _formatDate(order.updatedAt!) : null,
        isCompleted: order.status != AfterSalesStatus.rejected,
      ));
    }
    
    // 步骤4: 最终状态
    if (order.status == AfterSalesStatus.completed) {
      steps.add(_TimelineStep(
        title: '已完成',
        subtitle: '售后流程已完成',
        timestamp: order.updatedAt != null ? _formatDate(order.updatedAt!) : null,
        isCompleted: true,
      ));
    } else if (order.status == AfterSalesStatus.rejected) {
      steps.add(_TimelineStep(
        title: '已拒绝',
        subtitle: '商家已拒绝此售后申请',
        timestamp: order.updatedAt != null ? _formatDate(order.updatedAt!) : null,
        isCompleted: true,
        isRejected: true,
        rejectionReason: order.description,
      ));
    } else if (order.status == AfterSalesStatus.approved) {
      steps.add(_TimelineStep(
        title: '已通过',
        subtitle: order.type == AfterSalesType.returnGoods ? '请退货并填写物流信息' : '等待退款到账',
        isCurrent: true,
      ));
    }
    
    return steps;
  }

  /// 构建详情信息区域
  Widget _buildDetailInfo(AfterSalesOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '详细信息',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // 商品信息卡片
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1a3525),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF326744).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF2a4532),
                ),
                child: CachedNetworkImage(
                  imageUrl: order.productImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF13ec5b), strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF92c9a4),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.variant,
                      style: const TextStyle(
                        color: Color(0xFF92c9a4),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'x${order.quantity}',
                          style: const TextStyle(
                            color: Color(0xFF92c9a4),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '¥${order.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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
        ),
        const SizedBox(height: 12),
        // 售后信息
        _buildInfoRow('售后类型', _getAfterSalesTypeText(order.type)),
        _buildInfoRow('工单编号', order.id),
        _buildInfoRow('订单编号', order.orderId, copyable: true),
        _buildInfoRow('申请原因', order.reason),
        if (order.description != null && order.description!.isNotEmpty)
          _buildInfoRow('问题描述', order.description!),
        const SizedBox(height: 8),
        // 时间信息
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '申请时间: ${_formatDate(order.createdAt)}',
              style: TextStyle(
                color: const Color(0xFF92c9a4).withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            if (order.updatedAt != null)
              Text(
                '更新时间: ${_formatDate(order.updatedAt!)}',
                style: TextStyle(
                  color: const Color(0xFF92c9a4).withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建对话框底部操作按钮
  Widget _buildDialogActions(AfterSalesOrder order) {
    Widget? actionButton;
    
    switch (order.status) {
      case AfterSalesStatus.pending:
        actionButton = _buildDialogActionButton(
          '取消申请',
          () {
            Navigator.of(context).pop();
            _cancelAfterSales(order);
          },
          isPrimary: false,
        );
        break;
      case AfterSalesStatus.processing:
        actionButton = Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Text(
            '请耐心等待商家处理',
            style: TextStyle(
              color: Color(0xFF92c9a4),
              fontSize: 12,
            ),
          ),
        );
        break;
      case AfterSalesStatus.approved:
        if (order.type == AfterSalesType.returnGoods) {
          actionButton = _buildDialogActionButton(
            '填写退货物流',
            () {
              Navigator.of(context).pop();
              _fillLogistics(order);
            },
            isPrimary: true,
          );
        } else {
          actionButton = Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              '退款将原路返回您的账户',
              style: TextStyle(
                color: Color(0xFF92c9a4),
                fontSize: 12,
              ),
            ),
          );
        }
        break;
      case AfterSalesStatus.completed:
        actionButton = _buildDialogActionButton(
          '再次购买',
          () {
            Navigator.of(context).pop();
            // 跳转到商品详情页或申请售后页面
            debugPrint('再次购买: ${order.orderId}');
          },
          isPrimary: true,
        );
        break;
      case AfterSalesStatus.rejected:
        actionButton = _buildDialogActionButton(
          '重新申请',
          () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AfterSalesApplyPage(
                  orderId: order.orderId,
                  productId: '',
                  productName: order.productName,
                  productImage: order.productImage,
                  variant: order.variant,
                  quantity: order.quantity,
                  amount: order.amount,
                ),
              ),
            );
          },
          isPrimary: true,
        );
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1a3525),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          actionButton ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  /// 构建对话框操作按钮
  Widget _buildDialogActionButton(String label, VoidCallback onPressed, {bool isPrimary = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF13ec5b) : Colors.transparent,
        foregroundColor: isPrimary ? const Color(0xFF112217) : const Color(0xFF13ec5b),
        side: isPrimary ? null : const BorderSide(color: Color(0xFF13ec5b)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(label),
    );
  }

  /// 取消申请
  void _cancelAfterSales(AfterSalesOrder order) {
    // 实现取消申请逻辑
    debugPrint('取消申请: ${order.id}');
  }

  /// 填写物流信息
  void _fillLogistics(AfterSalesOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => ReturnLogisticsDialog(
        orderId: order.orderId,
        onSubmitted: () {
          _loadAfterSalesOrders();
        },
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF112217),
      appBar: AppBar(
        backgroundColor: const Color(0xFF112217),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '售后工单',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              // 跳转到申请售后页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AfterSalesApplyPage(
                    orderId: '',
                    productId: '',
                    productName: '',
                    productImage: '',
                    variant: '',
                    quantity: 1,
                    amount: 0.0,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildAfterSalesList(),
          ),
        ],
      ),
    );
  }
}

/// 时间线步骤数据模型
class _TimelineStep {
  final String title;
  final String subtitle;
  final String? timestamp;
  final bool isCompleted;
  final bool isCurrent;
  final bool isRejected;
  final String? rejectionReason;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    this.timestamp,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isRejected = false,
    this.rejectionReason,
  });
}