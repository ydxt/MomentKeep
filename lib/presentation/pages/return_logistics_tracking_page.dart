import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';

/// 退货物流追踪页面
/// 展示退货快递的物流轨迹信息
class ReturnLogisticsTrackingPage extends ConsumerStatefulWidget {
  const ReturnLogisticsTrackingPage({super.key, this.orderId = ''});

  final String orderId;

  @override
  ConsumerState<ReturnLogisticsTrackingPage> createState() =>
      _ReturnLogisticsTrackingPageState();
}

class _ReturnLogisticsTrackingPageState
    extends ConsumerState<ReturnLogisticsTrackingPage> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOrderUnavailable = false;
  List<LogisticsTrack> _trackingRecords = [];
  String _currentStatus = 'shipped';
  String? _trackingNumber;
  String? _logisticsCompanyName;

  final _dbService = ProductDatabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrackingData();
    });
  }

  /// 加载退货物流数据
  Future<void> _loadTrackingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.orderId.isEmpty) {
        debugPrint('ReturnLogisticsTrackingPage: orderId为空，无法加载退货物流数据');
        setState(() {
          _isLoading = false;
          _isOrderUnavailable = true;
        });
        return;
      }

      final returnLogisticsList =
          await _dbService.getReturnLogisticsByOrderId(widget.orderId);

      if (returnLogisticsList.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '未找到退货物流信息';
        });
        return;
      }

      final returnLogistics = returnLogisticsList.first;
      _trackingNumber = returnLogistics['tracking_number'] as String?;
      _currentStatus = returnLogistics['status'] as String? ?? 'shipped';

      final logisticsCompanyId = returnLogistics['logistics_company_id'] as int?;
      if (logisticsCompanyId != null) {
        final company =
            await _dbService.getLogisticsCompanyById(logisticsCompanyId);
        if (company != null) {
          _logisticsCompanyName = company.name;
        }
      }

      final tracks =
          await _dbService.getLogisticsTracksByOrderId(widget.orderId);
      _trackingRecords = tracks;

      if (tracks.isNotEmpty) {
        _currentStatus = tracks.first.status;
      }
    } catch (e) {
      debugPrint('加载退货物流信息失败: $e');
      _errorMessage = '加载退货物流信息失败，请重试';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 获取退货物流状态信息映射
  /// shipped→已寄出, picked→已揽收, transporting→运输中,
  /// delivering→派送中, delivered→商家已签收
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'shipped':
        return {
          'text': '已寄出',
          'color': Colors.blue,
          'icon': Icons.local_shipping,
          'progress': 0.2,
          'desc': '买家已寄出退货包裹，等待快递揽收'
        };
      case 'picked':
        return {
          'text': '已揽收',
          'color': Colors.indigo,
          'icon': Icons.inventory_2,
          'progress': 0.4,
          'desc': '快递已揽收，准备运输'
        };
      case 'transporting':
        return {
          'text': '运输中',
          'color': Colors.orange,
          'icon': Icons.local_shipping,
          'progress': 0.6,
          'desc': '退货包裹正在运输途中'
        };
      case 'delivering':
        return {
          'text': '派送中',
          'color': Colors.deepPurple,
          'icon': Icons.delivery_dining,
          'progress': 0.8,
          'desc': '快递员正在派送退货包裹'
        };
      case 'delivered':
        return {
          'text': '商家已签收',
          'color': Colors.green,
          'icon': Icons.check_circle,
          'progress': 1.0,
          'desc': '商家已签收退货包裹'
        };
      case 'exception':
        return {
          'text': '异常',
          'color': Colors.red,
          'icon': Icons.error,
          'progress': 0.0,
          'desc': '物流出现异常'
        };
      default:
        return {
          'text': '未知',
          'color': Colors.grey,
          'icon': Icons.help,
          'progress': 0.0,
          'desc': '状态未知'
        };
    }
  }

  /// 获取进度值
  double _getProgress(String status) {
    final info = _getStatusInfo(status);
    return (info['progress'] as double?) ?? 0.0;
  }

  /// 复制运单号到剪贴板
  Future<void> _copyTrackingNumber() async {
    if (_trackingNumber == null || _trackingNumber!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _trackingNumber!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('运单号已复制: $_trackingNumber'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        foregroundColor: theme.colorScheme.onBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: theme.colorScheme.onBackground),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('退货物流',
            style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState(theme)
          : _isOrderUnavailable
              ? _buildOrderUnavailableState(theme)
              : _errorMessage != null
                  ? _buildErrorState(theme)
                  : RefreshIndicator(
                      onRefresh: _loadTrackingData,
                      child: Column(
                        children: [
                          _buildOrderInfo(theme),
                          Expanded(
                            child: _trackingRecords.isEmpty
                                ? _buildEmptyState(theme)
                                : _buildTrackingTimeline(theme),
                          ),
                        ],
                      ),
                    ),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '加载退货物流信息中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建订单不可用状态
  Widget _buildOrderUnavailableState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text(
            '订单信息不可用，请返回重试',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '加载失败',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTrackingData,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_return_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant
                        .withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  '暂无退货物流轨迹',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建退货物流信息卡片
  Widget _buildOrderInfo(ThemeData theme) {
    final statusInfo = _getStatusInfo(_currentStatus);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (statusInfo['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusInfo['icon'] as IconData,
                  color: statusInfo['color'] as Color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusInfo['text'] as String,
                      style: TextStyle(
                        color: statusInfo['color'] as Color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '订单号: ${widget.orderId}',
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
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          if (_logisticsCompanyName != null &&
              _logisticsCompanyName!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.local_shipping,
                    color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Text(
                  '退货物流公司: $_logisticsCompanyName',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_trackingNumber != null && _trackingNumber!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.confirmation_number,
                    color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '退货运单号: $_trackingNumber',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy,
                      color: theme.colorScheme.primary, size: 20),
                  onPressed: _copyTrackingNumber,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _buildProgressBar(theme),
        ],
      ),
    );
  }

  /// 构建退货物流轨迹时间线
  Widget _buildTrackingTimeline(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _trackingRecords.length,
      itemBuilder: (context, index) {
        final record = _trackingRecords[index];
        final isFirst = index == 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isFirst
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: isFirst
                            ? Icon(Icons.check,
                                color: theme.colorScheme.onPrimary, size: 16)
                            : null,
                      ),
                      if (index < _trackingRecords.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.description,
                          style: TextStyle(
                            color: isFirst
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: 15,
                            fontWeight:
                                isFirst ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (record.location != null &&
                            record.location!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 16),
                              const SizedBox(width: 4),
                              Text(
                                record.location!,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          _formatTime(record.trackTime),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(ThemeData theme) {
    final progress = _getProgress(_currentStatus);
    final statusInfo = _getStatusInfo(_currentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '退货进度',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: statusInfo['color'] as Color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor:
                theme.colorScheme.onSurfaceVariant.withOpacity(0.15),
            valueColor:
                AlwaysStoppedAnimation<Color>(statusInfo['color'] as Color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          statusInfo['desc'] as String? ?? '',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// 格式化时间为相对时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}-${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}