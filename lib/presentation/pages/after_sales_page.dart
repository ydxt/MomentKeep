import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moment_keep/services/database_service.dart';
import 'my_orders_page.dart';
import 'after_sales_apply_page.dart';

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
  
  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadAfterSalesOrders();
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
          _buildInfoRow('订单编号', order.orderId),
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
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
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
            child: Text(
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
    // 实现查看工单详情逻辑
    debugPrint('查看工单详情: ${order.id}');
  }

  /// 取消申请
  void _cancelAfterSales(AfterSalesOrder order) {
    // 实现取消申请逻辑
    debugPrint('取消申请: ${order.id}');
  }

  /// 填写物流信息
  void _fillLogistics(AfterSalesOrder order) {
    // 实现填写物流信息逻辑
    debugPrint('填写物流信息: ${order.id}');
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