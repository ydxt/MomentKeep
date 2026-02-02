import 'dart:io';
import 'dart:convert' as json;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:moment_keep/presentation/pages/my_orders_page.dart';
import 'package:moment_keep/presentation/pages/after_sales_apply_page.dart';
import 'package:moment_keep/presentation/pages/review_page.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'dart:developer' as debug;

/// 订单详情页
class OrderDetailPage extends ConsumerWidget {
  /// 订单详情页构造函数
  const OrderDetailPage({
    super.key,
    required this.order,
  });

  /// 订单数据
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () {
            Navigator.pop(context);
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 订单状态卡片
            _buildOrderStatusCard(theme),
            const SizedBox(height: 16),
            // 订单基础信息
            _buildOrderBasicInfo(theme),
            const SizedBox(height: 16),
            // 商品明细
            _buildProductDetails(theme),
            const SizedBox(height: 16),
            // 费用明细
            _buildCostDetails(theme),
            const SizedBox(height: 16),
            // 收货信息
            _buildShippingInfo(theme),
            const SizedBox(height: 16),
            // 交易信息
            _buildTransactionInfo(theme),
            const SizedBox(height: 16),
            // 状态轨迹
            _buildStatusTimeline(theme),
            const SizedBox(height: 16),

            // 售后记录（只要有售后记录就显示）
            if (order.afterSalesRecords != null &&
                order.afterSalesRecords!.isNotEmpty)
              _buildAfterSalesRecords(context, theme),
            if ((order.afterSalesType != null ||
                    order.afterSalesDescription != null ||
                    order.afterSalesStatus != null) &&
                (order.afterSalesRecords == null ||
                    order.afterSalesRecords!.isEmpty))
              _buildAfterSalesRecords(context, theme),
            if (order.status == OrderStatus.refundAfterSales &&
                (order.afterSalesRecords == null ||
                    order.afterSalesRecords!.isEmpty) &&
                order.afterSalesType == null &&
                order.afterSalesDescription == null &&
                order.afterSalesStatus == null)
              _buildAfterSalesRecords(context, theme),
            const SizedBox(height: 16),

            // 操作按钮
            _buildOperationButtons(context, theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 构建订单状态卡片
  Widget _buildOrderStatusCard(ThemeData theme) {
    String statusText;
    Color statusColor = const Color(0xFF13ec5b);

    switch (order.status) {
      case OrderStatus.pendingPayment:
        statusText = '等待付款';
        break;
      case OrderStatus.pendingShipment:
        statusText = '待发货';
        break;
      case OrderStatus.pendingReceipt:
        statusText = '卖家已发货';
        statusColor = const Color(0xFF92c9a4);
        break;
      case OrderStatus.completed:
        statusText = '交易成功';
        statusColor = const Color(0xFF92c9a4);
        break;
      case OrderStatus.refundAfterSales:
        statusText = '退款/售后';
        statusColor = const Color(0xFFff6b6b);
        break;
      case OrderStatus.pendingReview:
        statusText = '待评价';
        statusColor = const Color(0xFFffc107);
        break;
      default:
        statusText = '未知状态';
        statusColor = const Color(0xFF92c9a4);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (order.status == OrderStatus.pendingPayment &&
              order.remainingPaymentTime != null)
            _buildCountdown(order.remainingPaymentTime!, theme),
        ],
      ),
    );
  }

  /// 构建倒计时
  Widget _buildCountdown(int seconds, ThemeData theme) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return Text(
      '剩余 $minutes:$remainingSeconds 自动关闭',
      style: TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 14,
        fontFamily: 'monospace',
      ),
    );
  }

  /// 构建订单基础信息
  Widget _buildOrderBasicInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订单信息',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('订单编号', order.id, theme),
          _buildInfoRow('下单时间', _formatDate(order.date), theme),
          _buildInfoRow(
              '支付时间',
              order.status == OrderStatus.completed
                  ? _formatDate(order.date.add(const Duration(minutes: 5)))
                  : '未支付', theme),
          _buildInfoRow(
              '预计送达时间',
              order.status == OrderStatus.pendingReceipt
                  ? _formatDate(order.date.add(const Duration(days: 3)))
                  : '暂无', theme),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建商品明细
  Widget _buildProductDetails(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '商品明细',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...order.items.map((item) => _buildProductItem(item, theme)),
          if (order.totalItems > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '共${order.totalItems}件商品',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 构建商品项
  Widget _buildProductItem(OrderItem item, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品图片
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surfaceVariant,
            ),
            child: _buildProductImage(item.image, theme),
          ),
          const SizedBox(width: 12),
          // 商品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '¥${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
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
          ),
        ],
      ),
    );
  }

  /// 构建商品图片
  Widget _buildProductImage(String imageUrl, ThemeData theme) {
    // 检查图片URL是否为空或无效
    if (imageUrl.isEmpty ||
        imageUrl == 'null' ||
        imageUrl == 'https://example.com/iphone15pro.jpg') {
      return Icon(
        Icons.image_not_supported_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: 24,
      );
    }

    // 检查是否为网络图片
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(
              color: theme.colorScheme.primary, strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => Icon(
          Icons.image_not_supported_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          size: 24,
        ),
      );
    } else {
      // 本地图片处理
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.image_not_supported_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          size: 24,
        ),
      );
    }
  }

  /// 构建售后图片
  Widget _buildAfterSalesImage(
      BuildContext context, String imageName, String userId) {
    // 构建完整的售后图片路径
    Future<String> _buildAfterSalesImagePath(String imageName) async {
      try {
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
          if (Platform.isAndroid || Platform.isIOS) {
            // 移动端使用应用文档目录
            directory = await getApplicationDocumentsDirectory();
          } else if (Platform.isWindows) {
            // Windows使用文档目录
            directory = Directory(
                path.join(Platform.environment['USERPROFILE']!, 'Documents'));
          } else if (Platform.isMacOS) {
            // macOS使用文档目录
            directory = Directory(
                path.join(Platform.environment['HOME']!, 'Documents'));
          } else if (Platform.isLinux) {
            // Linux使用文档目录
            directory = Directory(
                path.join(Platform.environment['HOME']!, 'Documents'));
          } else {
            throw UnsupportedError('Unsupported platform');
          }

          // 使用默认存储目录
          basePath = path.join(directory.path, 'MomentKeep');
        }

        // 构建完整的售后图片路径
        // 路径格式：basePath/default/store/userId/after-sales/imageName
        final fullPath = path.join(
            basePath, 'default', 'store', userId, 'after-sales', imageName);

        return fullPath;
      } catch (e) {
        debug.log('构建售后图片路径失败: $e');
        return imageName; // 失败时返回原始名称
      }
    }

    return FutureBuilder<String>(
      future: _buildAfterSalesImagePath(imageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final fullPath = snapshot.data ?? imageName;

          // 检查是否为网络图片
          if (fullPath.startsWith('http://') ||
              fullPath.startsWith('https://')) {
            return CachedNetworkImage(
              imageUrl: fullPath,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const Icon(
                Icons.image_not_supported_outlined,
                color: Color(0xFF92c9a4),
                size: 24,
              ),
            );
          } else {
            // 本地图片处理
            return Image.file(
              File(fullPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.image_not_supported_outlined,
                color: Color(0xFF92c9a4),
                size: 24,
              ),
            );
          }
        } else {
          return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF13ec5b), strokeWidth: 2),
          );
        }
      },
    );
  }

  /// 构建费用明细
  Widget _buildCostDetails(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '费用明细',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildCostRow('商品总价', order.totalPrice, theme),
          _buildCostRow('运费', 0.0, theme), // 模拟运费
          _buildCostRow('优惠金额', 0.0, theme), // 模拟优惠金额
          Divider(color: theme.colorScheme.outline, thickness: 0.5),

          // 根据支付方式显示不同的费用明细
          if (order.paymentMethod == PaymentMethod.points)
            _buildCostRow('积分支付', order.totalPrice, theme,
                isPoints: true, isTotal: true),
          if (order.paymentMethod == PaymentMethod.cash)
            _buildCostRow('现金支付', order.totalPrice, theme, isTotal: true),
          if (order.paymentMethod == PaymentMethod.hybrid) ...[
            _buildCostRow('积分支付', order.pointsUsed.toDouble(), theme, isPoints: true),
            _buildCostRow('现金支付', order.cashAmount, theme),
            _buildCostRow('实付金额', order.totalPrice, theme, isTotal: true),
          ],
        ],
      ),
    );
  }

  /// 构建费用行
  Widget _buildCostRow(String label, double amount, ThemeData theme, {bool isPoints = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            isPoints ? '${amount.toInt()}积分' : '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isTotal ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建收货信息
  Widget _buildShippingInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '收货信息',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (order.status == OrderStatus.pendingPayment ||
                  order.status == OrderStatus.pendingShipment)
                TextButton(
                  onPressed: () {
                    // 修改收货地址逻辑
                  },
                  child: const Text(
                    '修改',
                    style: TextStyle(
                      color: Color(0xFF13ec5b),
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF92c9a4),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '张三 138****8888',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '北京市朝阳区建国路88号 SOHO现代城 3号楼 1001室',
                      style: const TextStyle(
                        color: Color(0xFF92c9a4),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建交易信息
  Widget _buildTransactionInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '交易信息',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('支付方式', '微信支付', theme),
          _buildInfoRow('商家名称', order.storeName, theme),
          _buildInfoRow('商家客服', '400-123-4567', theme),
        ],
      ),
    );
  }

  /// 构建状态轨迹
  Widget _buildStatusTimeline(ThemeData theme) {
    // 使用FutureBuilder从数据库获取真实操作记录
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ProductDatabaseService().getOperationLogsByOrderId(order.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '订单轨迹',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary, strokeWidth: 2),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> operationLogs = [];
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          // 创建新的列表副本，避免直接修改只读列表
          operationLogs = List.from(snapshot.data!);
          // 按创建时间排序，确保顺序正确
          operationLogs.sort((a, b) =>
              (a['created_at'] as int).compareTo(b['created_at'] as int));
        } else {
          // 如果没有操作记录，创建基础的订单创建记录
          operationLogs = [
            {
              'status': '下单',
              'time': order.date,
              'created_at': order.date.millisecondsSinceEpoch
            }
          ];
          // 添加支付记录（如果已支付）
          if (order.status != OrderStatus.pendingPayment) {
            operationLogs.add({
              'status': '付款',
              'time': order.date.add(const Duration(minutes: 5)),
              'created_at': order.date
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch
            });
          }
        }

        // 使用ValueNotifier来管理折叠状态
        final isCollapsedNotifier = ValueNotifier<bool>(false);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和折叠按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '订单轨迹',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (operationLogs.length > 3) ...[
                    TextButton.icon(
                      onPressed: () {
                        isCollapsedNotifier.value = !isCollapsedNotifier.value;
                      },
                      icon: ValueListenableBuilder<bool>(
                        valueListenable: isCollapsedNotifier,
                        builder: (context, isCollapsed, child) {
                          return Icon(
                            isCollapsed ? Icons.expand_more : Icons.expand_less,
                            color: theme.colorScheme.onSurfaceVariant,
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
                              color: theme.colorScheme.onSurfaceVariant,
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
                  final displayLogs = isCollapsed
                      ? operationLogs.take(3).toList()
                      : operationLogs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayLogs.length,
                    itemBuilder: (context, index) {
                      final log = displayLogs[index];
                      final isLast = index == displayLogs.length - 1;

                      // 获取状态文本和时间
                      String statusText;
                      DateTime statusTime;

                      if (log.containsKey('action')) {
                        // 从操作日志中获取状态
                        statusText = log['action'] as String;
                        statusTime = DateTime.fromMillisecondsSinceEpoch(
                            log['created_at'] as int);
                      } else {
                        // 使用兼容的状态和时间
                        statusText = log['status'] as String;
                        statusTime = log['time'] as DateTime;
                      }

                      return _buildTimelineItem(
                        statusText,
                        statusTime,
                        theme,
                        isLast: isLast,
                      );
                    },
                  );
                },
              ),
              // 显示更多按钮
              ValueListenableBuilder<bool>(
                valueListenable: isCollapsedNotifier,
                builder: (context, isCollapsed, child) {
                  if (isCollapsed && operationLogs.length > 3) {
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            isCollapsedNotifier.value = false;
                          },
                          child: Text(
                            '查看全部 ${operationLogs.length} 条记录',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建时间线项
  Widget _buildTimelineItem(String status, DateTime time, ThemeData theme,
      {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // 时间线点
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: theme.colorScheme.secondary,
                ),
            ],
          ),
          const SizedBox(width: 12),
          // 时间线内容
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(time),
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
  }

  /// 构建操作按钮
  Widget _buildOperationButtons(BuildContext context, ThemeData theme) {
    List<Widget> actions = [];

    switch (order.status) {
      case OrderStatus.pendingPayment:
        actions = [
          _buildActionButton('修改地址', () => _modifyAddress(context)),
          _buildActionButton('取消订单', () => _cancelOrder(context)),
          _buildActionButton('立即支付', () => _payOrder(context), isPrimary: true),
        ];
        break;
      case OrderStatus.pendingShipment:
        actions = [
          _buildActionButton('联系商家', () => _contactSeller(context)),
          _buildActionButton('催发货', () => _remindShipment(context)),
          _buildActionButton('修改地址', () => _modifyAddress(context)),
          _buildActionButton('取消订单', () => _cancelOrder(context),
              isPrimary: true),
        ];
        break;
      case OrderStatus.pendingReceipt:
        actions = [
          _buildActionButton('联系商家', () => _contactSeller(context)),
          _buildActionButton('查看物流', () => _viewLogistics(context)),
          _buildActionButton('申请退款/退货', () => _applyRefund(context)),
          _buildActionButton('确认收货', () => _confirmReceipt(context),
              isPrimary: true),
        ];
        break;
      case OrderStatus.completed:
        actions = [
          _buildActionButton('联系商家', () => _contactSeller(context)),
          _buildActionButton('查看评价', () => _viewReview(context)),
          _buildActionButton('申请售后', () => _applyAfterSales(context)),
          _buildActionButton('再次购买', () => _buyAgain(context)),
          _buildActionButton('评价', () => _writeReview(context),
              isPrimary: true),
        ];
        break;
      case OrderStatus.refundAfterSales:
        actions = [
          _buildActionButton('联系商家', () => _contactSeller(context)),
          _buildActionButton('查看进度', () => _viewRefundProgress(context)),
          _buildActionButton('补充凭证', () => _addRefundProof(context)),
          _buildActionButton('取消申请', () => _cancelRefund(context),
              isPrimary: true),
        ];
        break;
      case OrderStatus.pendingReview:
        actions = [
          _buildActionButton('联系商家', () => _contactSeller(context)),
          _buildActionButton('追加评价', () => _addReview(context)),
          _buildActionButton('查看回复', () => _viewSellerReply(context)),
          _buildActionButton('撰写评价', () => _writeReview(context),
              isPrimary: true),
        ];
        break;
      default:
        // 已取消 / 驳回状态
        actions = [
          _buildActionButton('联系商家', () => _contactSeller(context)),
          _buildActionButton('查看原因', () => _viewCancelReason(context)),
          _buildActionButton('重新下单', () => _reorder(context), isPrimary: true),
        ];
        break;
    }

    if (actions.isEmpty) return Container();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions,
    );
  }

  /// 支付订单
  void _payOrder(BuildContext context) async {
    // 实现支付订单逻辑
    debugPrint('支付订单: ${order.id}');

    try {
      // 在实际应用中，这里会有支付网关调用
      // 这里模拟支付成功，更新订单状态为 待发货
      await ProductDatabaseService().updateOrderStatus(order.id, '待发货');

      if (context.mounted) {
        // 显示支付成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('支付成功，等待商家发货'),
            backgroundColor: Color(0xFF13ec5b),
          ),
        );
        // 返回上一页并通知刷新
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('支付失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('支付失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 取消订单
  void _cancelOrder(BuildContext context) {
    // 实现取消订单逻辑
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('确认取消订单', style: TextStyle(color: theme.colorScheme.onSurface)),
          content:
              Text('您确定要取消此订单吗？', style: TextStyle(color: theme.colorScheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            TextButton(
              onPressed: () async {
                debugPrint('取消订单: ${order.id}');
                // 关闭对话框
                Navigator.pop(context);

                // 更新订单状态为已取消
                await ProductDatabaseService()
                    .updateOrderStatus(order.id, '已取消');

                // 只有已支付或已完成的订单才需要返还积分
                if (order.pointsUsed > 0 &&
                    (order.status == '已支付' || order.status == '已完成')) {
                  try {
                    // 导入用户数据库服务
                    final userDbService = UserDatabaseService();
                    // 获取当前用户ID
                    final userId = await DatabaseService().getCurrentUserId() ??
                        'default_user';
                    // 获取用户当前积分
                    final userData = await userDbService.getUserById(userId);
                    if (userData != null) {
                      final currentPoints = userData['points'] as int? ?? 0;
                      // 计算新积分
                      final newPoints = currentPoints + order.pointsUsed;
                      // 更新用户积分
                      await userDbService.updateUser(
                          userId,
                          {}, // 主表不需要更新
                          {'points': newPoints} // 更新买家扩展表的积分
                          );
                    }
                  } catch (e) {
                    debug.log('Error refunding points: $e');
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
                await NotificationDatabaseService()
                    .addNotification(notification);

                // 显示取消成功提示
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('订单已取消'),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
                // 返回上一页，并传递刷新信号
                Navigator.pop(context, true);
              },
              child: Text('确定', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  /// 修改收货地址
  void _modifyAddress(BuildContext context) {
    // 实现修改收货地址逻辑
    debugPrint('修改收货地址: ${order.id}');
    final theme = Theme.of(context);
    // 显示修改地址提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('修改地址功能已实现'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  /// 催发货
  void _remindShipment(BuildContext context) {
    // 实现催发货逻辑
    debugPrint('催发货: ${order.id}');
    final theme = Theme.of(context);
    // 显示催发货提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已通知商家尽快发货'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  /// 申请取消订单
  void _applyCancel(BuildContext context) {
    // 实现申请取消订单逻辑
    debugPrint('申请取消订单: ${order.id}');
    final theme = Theme.of(context);
    // 显示申请取消提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('取消申请已提交'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  /// 查看物流轨迹
  void _viewLogistics(BuildContext context) {
    // 实现查看物流轨迹逻辑
    debugPrint('查看物流轨迹: ${order.id}');
    // 显示物流信息
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '物流信息',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '暂无物流信息',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 确认收货
  void _confirmReceipt(BuildContext context) {
    // 实现确认收货逻辑
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('确认收货', style: TextStyle(color: theme.colorScheme.onSurface)),
          content:
              Text('您确定已收到商品吗？', style: TextStyle(color: theme.colorScheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            TextButton(
              onPressed: () async {
                debugPrint('确认收货: ${order.id}');
                // 关闭对话框
                Navigator.pop(context);

                try {
                  // 更新订单状态为已完成
                  await ProductDatabaseService()
                      .updateOrderStatus(order.id, '已完成');

                  // 显示确认收货成功提示
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('已确认收货'),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                    // 返回上一页
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  debugPrint('确认收货失败: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('确认收货失败: $e'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: Text('确定', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  /// 申请退款/退货
  void _applyRefund(BuildContext context) {
    // 实现申请退款/退货逻辑
    debugPrint('申请退款/退货: ${order.id}');
    // 跳转到售后申请页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AfterSalesApplyPage(
          orderId: order.id,
          productId: order.items.first.id,
          productName: order.items.first.name,
          productImage: order.items.first.image,
          variant: order.items.first.variant,
          quantity: order.items.first.quantity,
          amount: order.totalPrice,
        ),
      ),
    ).then((value) {
      if (value == true) {
        Navigator.pop(context, true);
      }
    });
  }

  /// 联系商家
  void _contactSeller(BuildContext context) {
    // 实现联系商家逻辑
    debugPrint('联系商家: ${order.storeName}');

    // 打开聊天窗口，显示沟通记录和消息输入框
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        // 消息输入控制器
        final TextEditingController _messageController =
            TextEditingController();

        // 发送消息
        Future<void> _sendMessage() async {
          final messageContent = _messageController.text.trim();
          if (messageContent.isEmpty) return;

          try {
            // 创建新的通知
            final notification = NotificationInfo(
              id: 'buyer_${DateTime.now().millisecondsSinceEpoch}',
              orderId: order.id,
              productName: order.items.first.name,
              productImage: order.items.first.image,
              type: NotificationType.system, // 买家消息使用system类型
              status: NotificationStatus.unread,
              content: messageContent,
              createdAt: DateTime.now(),
            );

            // 保存到数据库
            await NotificationDatabaseService().addNotification(notification);

            // 清空输入框
            _messageController.clear();

            // 刷新页面
            Navigator.pop(dialogContext);
            _contactSeller(context);
          } catch (e) {
            debug.log('发送消息失败: $e');
          }
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 聊天标题
              Text(
                '与商家沟通',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 聊天记录列表
              Expanded(
                child: FutureBuilder<List<Map<String, String>>>(
                  future: _getCommunicationLogs(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      );
                    }

                    final logs = snapshot.data ?? [];
                    return ListView.builder(
                      reverse: true, // 最新消息显示在最下面，并且自动滚动到底部
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        // 反转索引，因为reverse: true会反转列表顺序
                        final log = logs[logs.length - 1 - index];
                        final isSeller = log['sender'] == '商家';
                        final content = log['content'] ?? '';
                        final isImage = content.startsWith('image:');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: isSeller
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.end,
                            children: [
                              // 卖家头像（在左侧）
                              if (isSeller) ...[
                                // 卖家头像
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text('商',
                                      style: TextStyle(
                                          fontSize: 14, color: theme.colorScheme.onPrimary)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              // 消息内容和状态
                              Column(
                                crossAxisAlignment: isSeller
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  // 消息内容
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.7,
                                    ),
                                    padding: isImage
                                        ? const EdgeInsets.all(4)
                                        : const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSeller
                                          ? theme.colorScheme.surfaceVariant
                                          : theme.colorScheme.primary,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(12),
                                        topRight: const Radius.circular(12),
                                        bottomLeft: isSeller
                                            ? const Radius.circular(0)
                                            : const Radius.circular(12),
                                        bottomRight: isSeller
                                            ? const Radius.circular(12)
                                            : const Radius.circular(0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isSeller
                                          ? CrossAxisAlignment.start
                                          : CrossAxisAlignment.end,
                                      children: [
                                        if (isImage) ...[
                                          // 显示图片消息
                                          GestureDetector(
                                            onTap: () {
                                              // 查看大图
                                              _showImagePreview(context,
                                                  content.substring(6));
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(content.substring(6)),
                                                width: 150,
                                                height: 150,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
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
                                                color: isSeller
                                                    ? theme.colorScheme.onSurface
                                                    : theme.colorScheme.onPrimary),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          log['time'] ?? '',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // 买家头像（在右侧）
                              if (!isSeller) ...[
                                const SizedBox(width: 8),
                                // 买家头像
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text('我',
                                      style: TextStyle(
                                          fontSize: 14, color: theme.colorScheme.onPrimary)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // 消息输入框
              const SizedBox(height: 16),
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
                          final userId = order.id.split('_')[0];

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
                            basePath = path.join(
                                directory.path, 'MomentKeep');
                          }

                          // 创建目标目录
                          final targetDir = Directory(path.join(basePath,
                              'default', 'store', userId, 'after-sales'));
                          await targetDir.create(recursive: true);

                          // 生成新的图片文件名
                          final imageName =
                              'chat_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
                          final targetPath =
                              path.join(targetDir.path, imageName);

                          // 复制图片到目标目录
                          final sourceFile = File(pickedFile.path);
                          await sourceFile.copy(targetPath);

                          // 创建新的通知，使用特殊格式存储图片路径
                          final notification = NotificationInfo(
                            id: 'buyer_${DateTime.now().millisecondsSinceEpoch}',
                            orderId: order.id,
                            productName: order.items.first.name,
                            productImage: order.items.first.image,
                            type: NotificationType.system, // 买家消息使用system类型
                            status: NotificationStatus.unread,
                            content: 'image:$targetPath', // 图片消息格式
                            createdAt: DateTime.now(),
                          );

                          // 保存到数据库
                          await NotificationDatabaseService()
                              .addNotification(notification);

                          // 刷新聊天窗口
                          Navigator.pop(dialogContext);
                          _contactSeller(context);
                        } catch (e) {
                          debug.log('发送图片失败: $e');
                          // 显示错误提示
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: const Text('发送图片失败'),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      Icons.image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
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
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        onSubmitted: (value) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('发送'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 获取沟通记录
  Future<List<Map<String, String>>> _getCommunicationLogs() async {
    // 在方法内部创建通知服务实例
    final notificationService = NotificationDatabaseService();
    try {
      // 从通知数据库获取该订单的所有通知
      final notifications =
          await notificationService.getNotificationsByOrderId(order.id);
      // 将通知转换为沟通记录格式
      final communicationLogs = notifications.map((notification) {
        // 根据通知ID前缀判断发送者
        // notification_前缀的通知是商家发送的，其他是买家发送的
        final isSeller = notification.id.startsWith('notification_');
        return {
          'sender': isSeller ? '商家' : '买家',
          'content': notification.content,
          'time': _formatDateWithSeconds(notification.createdAt),
        };
      }).toList();
      // 按时间排序，最新消息显示在最下面
      communicationLogs.sort((a, b) {
        return DateTime.parse(a['time']!).compareTo(DateTime.parse(b['time']!));
      });
      return communicationLogs;
    } catch (e) {
      debug.log('获取沟通记录失败: $e');
      return [];
    }
  }

  /// 格式化日期，包含秒
  String _formatDateWithSeconds(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  /// 查看评价
  void _viewReview(BuildContext context) {
    // 跳转到订单评价页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(orderId: order.id),
      ),
    );
  }

  /// 申请售后
  void _applyAfterSales(BuildContext context) {
    // 跳转到售后申请页面，并传递必要的订单信息
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AfterSalesApplyPage(
          orderId: order.id,
          productId: order.items.first.id,
          productName: order.items.first.name,
          productImage: order.items.first.image,
          variant: order.items.first.variant,
          quantity: order.items.first.quantity,
          amount: order.totalPrice,
        ),
      ),
    ).then((value) {
      // 如果从售后申请页面返回并带有刷新信号，通知父页面刷新订单列表
      if (value == true) {
        Navigator.pop(context, true);
      }
    });
  }

  /// 再次购买
  void _buyAgain(BuildContext context) {
    // 实现再次购买逻辑
    // 这里可以跳转到商品详情页或购物车
    debugPrint('再次购买: ${order.id}');
    final theme = Theme.of(context);
    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已添加到购物车'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  /// 评价
  void _writeReview(BuildContext context) {
    // 跳转到写评价页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(orderId: order.id, isWriting: true),
      ),
    );
  }

  /// 查看退款进度
  void _viewRefundProgress(BuildContext context) {
    // 实现查看退款进度逻辑
    debugPrint('查看退款进度: ${order.id}');
    // 显示退款进度
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
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
                        '退款金额: ${order.paymentMethod == PaymentMethod.points ? '✨${order.pointsUsed}' : '¥${order.totalPrice.toStringAsFixed(2)}'}',
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
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      final progressLogs = [
                        {
                          'time': order.afterSalesCreateTime != null
                              ? _formatDateWithSeconds(
                                  order.afterSalesCreateTime!)
                              : '',
                          'status': '提交申请',
                          'description':
                              '您已提交${order.afterSalesType == 'repair' ? '维修' : '退款'}申请，等待商家处理',
                          'isActive': true
                        },
                        {
                          'time': order.afterSalesCreateTime != null
                              ? _formatDateWithSeconds(order.afterSalesCreateTime!
                                  .add(const Duration(hours: 2)))
                              : '',
                          'status': '商家已同意',
                          'description':
                              '商家已同意${order.afterSalesType == 'repair' ? '维修' : '退款'}申请，等待${order.afterSalesType == 'repair' ? '维修' : '退款'}处理',
                          'isActive': order.afterSalesStatus == 'approved' ||
                              order.afterSalesStatus == 'completed'
                        },
                        {
                          'time': order.afterSalesCreateTime != null &&
                                  order.afterSalesStatus == 'completed'
                              ? _formatDateWithSeconds(order.afterSalesCreateTime!
                                  .add(const Duration(hours: 4)))
                              : '',
                          'status':
                              '${order.afterSalesType == 'repair' ? '维修' : '退款'}完成',
                          'description':
                              '${order.afterSalesType == 'repair' ? '维修' : '退款'}已完成，感谢您的配合',
                          'isActive': order.afterSalesStatus == 'completed'
                        },
                      ];
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
                                    color: progress['isActive'] as bool
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                if (index < progressLogs.length - 1)
                                  Container(
                                    width: 2,
                                    height: 40,
                                    color: theme.colorScheme.outlineVariant,
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
                                      color: progress['isActive'] as bool
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                      fontWeight: progress['isActive'] as bool
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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
        );
      },
    );
  }

  /// 补充退款凭证
  void _addRefundProof(BuildContext context) {
    // 实现补充退款凭证逻辑
    debugPrint('补充退款凭证: ${order.id}');
    // 显示补充凭证对话框，与订单列表页保持一致
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
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
                        content: const Text('图片选择功能已实现'),
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
                                _showImagePreview(context, imageUrl);
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: imageUrl.startsWith('http') ||
                                        imageUrl.startsWith('https')
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            Icon(
                                          Icons.image,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          size: 40,
                                        ),
                                      )
                                    : Image.file(
                                        File(imageUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Icon(
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
              onPressed: () async {
                // 实现图片上传逻辑
                try {
                  // 模拟上传成功
                  await Future.delayed(const Duration(milliseconds: 500));

                  // 关闭对话框
                  Navigator.pop(context);

                  // 显示上传成功提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('退款凭证已提交，等待审核'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                } catch (e) {
                  // 显示上传失败提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('凭证上传失败，请重试'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('提交'),
            ),
          ],
        );
      },
    );
  }

  /// 取消退款申请
  void _cancelRefund(BuildContext context) {
    // 实现取消退款申请逻辑
    // 保存主页面上下文
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('确认取消退款申请', style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Text('您确定要取消此退款申请吗？',
              style: TextStyle(color: theme.colorScheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            TextButton(
              onPressed: () {
                debugPrint('取消退款申请: ${order.id}');

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

                    // 使用保存的主页面上下文显示取消成功提示
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(
                        content: const Text('退款申请已取消，订单状态已更新'),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );

                    // 返回上一页并传递刷新信号
                    Navigator.pop(scaffoldContext, true);
                  } catch (e) {
                    // 使用保存的主页面上下文显示取消失败提示
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
              child:
                  Text('确定', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  /// 追加评价
  void _addReview(BuildContext context) {
    // 跳转到追加评价页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(orderId: order.id, isWriting: true),
      ),
    );
  }

  /// 查看商家回复
  void _viewSellerReply(BuildContext context) {
    // 跳转到订单评价页面查看商家回复
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(orderId: order.id),
      ),
    );
  }

  /// 查看取消/驳回原因
  void _viewCancelReason(BuildContext context) {
    // 显示取消/驳回原因
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('取消原因', style: TextStyle(color: theme.colorScheme.onSurface)),
          content:
              Text('商家取消了订单：商品库存不足', style: TextStyle(color: theme.colorScheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('确定', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  /// 重新下单
  void _reorder(BuildContext context) {
    // 实现重新下单逻辑
    debugPrint('重新下单: ${order.id}');
    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已添加到购物车'),
        backgroundColor: Color(0xFF13ec5b),
      ),
    );
  }

  /// 构建售后记录
  Widget _buildAfterSalesRecords(BuildContext context, ThemeData theme) {
    // 获取售后记录列表，如果没有则创建一个包含单条记录的列表
    List<AfterSalesRecord> allAfterSalesRecords = [];

    debug.log('原始afterSalesRecords数量: ${order.afterSalesRecords?.length}');
    debug.log('原始afterSalesRecords: ${order.afterSalesRecords}');

    // 1. 优先使用售后记录列表，无论是否为空
    if (order.afterSalesRecords != null) {
      allAfterSalesRecords = order.afterSalesRecords!;
      debug.log('使用afterSalesRecords，数量: ${allAfterSalesRecords.length}');
    }

    // 2. 如果没有售后记录列表，检查是否有单条售后信息
    if (allAfterSalesRecords.isEmpty) {
      debug.log('售后记录列表为空，检查单条售后信息');
      if (order.afterSalesType != null ||
          order.afterSalesReason != null ||
          order.afterSalesDescription != null ||
          order.afterSalesImages != null ||
          order.afterSalesCreateTime != null ||
          order.afterSalesStatus != null) {
        // 创建单条售后记录
        final singleRecord = AfterSalesRecord(
          id: order.id,
          type: order.afterSalesType ?? 'repair',
          reason: order.afterSalesReason,
          description: order.afterSalesDescription,
          images: order.afterSalesImages,
          createTime: order.afterSalesCreateTime ?? DateTime.now(),
          status: order.afterSalesStatus,
        );
        allAfterSalesRecords = [singleRecord];
        debug.log('创建单条售后记录');
      }
    }

    // 按创建时间降序排序，确保最新的记录在前面
    allAfterSalesRecords.sort((a, b) => b.createTime.compareTo(a.createTime));
    debug.log('排序后售后记录数量: ${allAfterSalesRecords.length}');

    // 使用独立的StatefulWidget来管理显示全部/仅显示最近1条的状态
    return AfterSalesRecordsWidget(
      afterSalesRecords: allAfterSalesRecords,
      buildSingleRecord: (context, record, index, totalCount) =>
          _buildSingleAfterSalesRecord(context, record, index, totalCount),
    );
  }

  /// 构建单条可折叠的售后记录
  Widget _buildSingleAfterSalesRecord(BuildContext context,
      AfterSalesRecord record, int index, int totalCount) {
    return Column(
      children: [
        if (index > 0) const SizedBox(height: 16),
        if (index > 0) const Divider(color: Color(0xFF326744), thickness: 0.5),

        // 售后记录项
        AfterSalesRecordItem(
          record: record,
          onImageTap: (imageUrl) => _showImagePreview(context, imageUrl),
          buildProductImage: (imageUrl) =>
              _buildAfterSalesImage(context, imageUrl, order.id.split('_')[0]),
        ),
      ],
    );
  }

  /// 显示图片预览
  void _showImagePreview(BuildContext context, String imageName) {
    // 从订单ID中提取用户ID
    final userId = order.id.split('_')[0];

    // 构建完整的售后图片路径
    Future<String> _buildFullImagePath(String imageName) async {
      try {
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
          if (Platform.isAndroid || Platform.isIOS) {
            // 移动端使用应用文档目录
            directory = await getApplicationDocumentsDirectory();
          } else if (Platform.isWindows) {
            // Windows使用文档目录
            directory = Directory(
                path.join(Platform.environment['USERPROFILE']!, 'Documents'));
          } else if (Platform.isMacOS) {
            // macOS使用文档目录
            directory = Directory(
                path.join(Platform.environment['HOME']!, 'Documents'));
          } else if (Platform.isLinux) {
            // Linux使用文档目录
            directory = Directory(
                path.join(Platform.environment['HOME']!, 'Documents'));
          } else {
            throw UnsupportedError('Unsupported platform');
          }

          // 使用默认存储目录
          basePath = path.join(directory.path, 'MomentKeep');
        }

        // 构建完整的售后图片路径
        // 路径格式：basePath/default/store/userId/after-sales/imageName
        final fullPath = path.join(
            basePath, 'default', 'store', userId, 'after-sales', imageName);

        return fullPath;
      } catch (e) {
        debug.log('构建售后图片路径失败: $e');
        return imageName; // 失败时返回原始名称
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(dialogContext);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _buildFullImagePath(imageName),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          final fullPath = snapshot.data ?? imageName;

                          return fullPath.startsWith('http') ||
                                  fullPath.startsWith('https://')
                              ? Image.network(
                                  fullPath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                )
                              : Image.file(
                                  File(fullPath),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                );
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF13ec5b), strokeWidth: 2),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
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

  /// 构建操作按钮
  Widget _buildActionButton(String label, VoidCallback onPressed,
      {bool isPrimary = false}) {
    return Padding(
      padding: EdgeInsets.only(
        left: isPrimary ? 12 : 0,
        right: isPrimary ? 0 : 12,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? const Color(0xFF13ec5b) : Colors.transparent,
          foregroundColor:
              isPrimary ? const Color(0xFF112217) : const Color(0xFF13ec5b),
          side: isPrimary ? null : const BorderSide(color: Color(0xFF13ec5b)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: TextStyle(
            fontSize: 14,
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
}

/// 售后记录组件
class AfterSalesRecordsWidget extends StatefulWidget {
  /// 构造函数
  const AfterSalesRecordsWidget({
    super.key,
    required this.afterSalesRecords,
    required this.buildSingleRecord,
  });

  /// 所有售后记录
  final List<AfterSalesRecord> afterSalesRecords;

  /// 构建单条记录的回调函数
  final Widget Function(BuildContext context, AfterSalesRecord record,
      int index, int totalCount) buildSingleRecord;

  @override
  State<AfterSalesRecordsWidget> createState() =>
      _AfterSalesRecordsWidgetState();
}

class _AfterSalesRecordsWidgetState extends State<AfterSalesRecordsWidget> {
  /// 状态管理：是否显示全部记录
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    // 决定显示哪些记录
    List<AfterSalesRecord> displayedRecords = _showAll
        ? widget.afterSalesRecords
        : widget.afterSalesRecords.take(1).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a3525),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF326744).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 售后记录标题和查看全部按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '售后记录',
                style: TextStyle(
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
                    _showAll
                        ? '收起'
                        : '查看全部 (${widget.afterSalesRecords.length})',
                    style: const TextStyle(
                      color: Color(0xFF13ec5b),
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 售后记录列表
          ...displayedRecords.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            return widget.buildSingleRecord(
                context, record, index, displayedRecords.length);
          }).toList(),
        ],
      ),
    );
  }
}

/// 可折叠的售后记录项组件
class AfterSalesRecordItem extends StatefulWidget {
  const AfterSalesRecordItem({
    super.key,
    required this.record,
    required this.onImageTap,
    required this.buildProductImage,
  });

  final AfterSalesRecord record;
  final void Function(String) onImageTap;
  final Widget Function(String) buildProductImage;

  @override
  State<AfterSalesRecordItem> createState() => _AfterSalesRecordItemState();
}

class _AfterSalesRecordItemState extends State<AfterSalesRecordItem> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 售后记录标题栏（可点击展开/折叠）
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${record.type == 'repair' ? '维修' : '退款'}申请 - ${_formatDateWithSeconds(record.createTime)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                color: const Color(0xFF92c9a4),
              ),
            ],
          ),
        ),

        // 展开时显示的内容
        if (_isExpanded) ...[
          const SizedBox(height: 12),

          // 售后类型
          _buildInfoRow('售后类型', record.type == 'repair' ? '维修' : '退款'),
          // 申请原因
          _buildInfoRow('申请原因', record.reason ?? '未填写'),
          // 问题描述
          _buildInfoRow('问题描述', record.description ?? '未填写'),
          // 申请时间
          _buildInfoRow('申请时间', _formatDateWithSeconds(record.createTime)),
          // 处理状态
          _buildInfoRow('处理状态', record.status ?? '未处理'),
          // 处理结果
          if (record.result != null) _buildInfoRow('处理结果', record.result!),
          // 处理时间
          if (record.handleTime != null)
            _buildInfoRow('处理时间', _formatDateWithSeconds(record.handleTime!)),

          // 售后图片
          const SizedBox(height: 12),
          const Text(
            '售后图片',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (record.images == null || record.images!.isEmpty) ...[
                const Text(
                  '暂无售后图片',
                  style: TextStyle(
                    color: Color(0xFF92c9a4),
                    fontSize: 12,
                  ),
                ),
              ] else ...[
                ...record.images!.map((imageUrl) {
                  return GestureDetector(
                    onTap: () {
                      widget.onImageTap(imageUrl);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF2a4532),
                      ),
                      child: widget.buildProductImage(imageUrl),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF92c9a4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          _buildDescriptionContent(value),
        ],
      ),
    );
  }

  /// 构建描述内容，支持Quill Delta格式
  Widget _buildDescriptionContent(String content) {
    // 检查是否为Quill Delta格式
    if (content.isEmpty) {
      return const Text(
        '未填写',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      );
    }

    try {
      // 尝试解析为Quill Delta格式
      final decoded = json.jsonDecode(content);
      if (decoded is List<dynamic>) {
        // 创建Quill文档
        final document = flutter_quill.Document.fromJson(decoded);

        // 使用QuillEditor显示内容
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2a4532),
            borderRadius: BorderRadius.circular(8),
          ),
          child: flutter_quill.QuillEditor.basic(
            controller: flutter_quill.QuillController(
              document: document,
              selection: const TextSelection.collapsed(offset: 0),
            ),
            config: flutter_quill.QuillEditorConfig(
              autoFocus: false,
              scrollable: true,
              padding: EdgeInsets.zero,
            ),
          ),
        );
      }
    } catch (e) {
      // 如果解析失败，直接显示文本
      debug.log('解析Quill Delta失败: $e');
    }

    // 不是Quill Delta格式，直接显示文本
    return Text(
      content,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      textAlign: TextAlign.left,
      overflow: TextOverflow.visible,
    );
  }

  /// 格式化日期，包含秒
  String _formatDateWithSeconds(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}
