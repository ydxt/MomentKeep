import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class LogisticsTrackingPage extends ConsumerStatefulWidget {
  const LogisticsTrackingPage({super.key, this.orderId = ''});

  final String orderId;

  @override
  ConsumerState<LogisticsTrackingPage> createState() => _LogisticsTrackingPageState();
}

class _LogisticsTrackingPageState extends ConsumerState<LogisticsTrackingPage> {
  bool _isLoading = true;
  List<LogisticsTrack> _trackingRecords = [];
  String _currentStatus = 'created';
  String? _trackingNumber = '';
  String? _logisticsCompanyName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrackingData();
    });
  }

  Future<void> _loadTrackingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      _trackingNumber = 'SF1234567890';
      _logisticsCompanyName = '顺丰速运';
      _currentStatus = 'delivering';
      
      _trackingRecords = [
        LogisticsTrack(
          id: 5,
          orderId: widget.orderId,
          logisticsCompanyId: 1,
          trackingNumber: _trackingNumber,
          status: 'delivering',
          description: '快递员正在派送中，请保持电话畅通',
          location: '北京市朝阳区',
          trackTime: DateTime.now().subtract(const Duration(hours: 2)),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        LogisticsTrack(
          id: 4,
          orderId: widget.orderId,
          logisticsCompanyId: 1,
          trackingNumber: _trackingNumber,
          status: 'transporting',
          description: '快件已到达【北京朝阳区营业点】',
          location: '北京市朝阳区',
          trackTime: DateTime.now().subtract(const Duration(hours: 6)),
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        LogisticsTrack(
          id: 3,
          orderId: widget.orderId,
          logisticsCompanyId: 1,
          trackingNumber: _trackingNumber,
          status: 'transporting',
          description: '快件已从【北京转运中心】发出',
          location: '北京市',
          trackTime: DateTime.now().subtract(const Duration(days: 1)),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        LogisticsTrack(
          id: 2,
          orderId: widget.orderId,
          logisticsCompanyId: 1,
          trackingNumber: _trackingNumber,
          status: 'picked',
          description: '快递员已揽收',
          location: '上海市浦东新区',
          trackTime: DateTime.now().subtract(const Duration(days: 2)),
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        LogisticsTrack(
          id: 1,
          orderId: widget.orderId,
          logisticsCompanyId: 1,
          trackingNumber: _trackingNumber,
          status: 'created',
          description: '商家已发货，等待揽收',
          location: '上海市',
          trackTime: DateTime.now().subtract(const Duration(days: 3)),
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];
    } catch (e) {
      debugPrint('加载物流信息失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'created':
        return {'text': '已发货', 'color': Colors.grey, 'icon': Icons.local_shipping};
      case 'picked':
        return {'text': '已揽收', 'color': Colors.blue, 'icon': Icons.local_mall};
      case 'transporting':
        return {'text': '运输中', 'color': Colors.orange, 'icon': Icons.local_shipping};
      case 'delivering':
        return {'text': '派送中', 'color': Colors.purple, 'icon': Icons.delivery_dining};
      case 'delivered':
        return {'text': '已签收', 'color': Colors.green, 'icon': Icons.check_circle};
      case 'exception':
        return {'text': '异常', 'color': Colors.red, 'icon': Icons.error};
      default:
        return {'text': '未知', 'color': Colors.grey, 'icon': Icons.help};
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
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('物流跟踪', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: _isLoading ? _buildLoadingState(theme) : Column(
        children: [
          _buildOrderInfo(theme),
          Expanded(
            child: _buildTrackingTimeline(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '加载物流信息中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

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
          if (_logisticsCompanyName != null && _logisticsCompanyName!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.local_shipping, color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Text(
                  '物流公司: $_logisticsCompanyName',
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
                Icon(Icons.confirmation_number, color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '运单号: $_trackingNumber',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: theme.colorScheme.primary, size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('运单号已复制', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        backgroundColor: theme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _trackingRecords.length,
      itemBuilder: (context, index) {
        final record = _trackingRecords[index];
        final isFirst = index == 0;
        final statusInfo = _getStatusInfo(record.status);
        final color = isFirst ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withOpacity(0.5);
        
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
                          color: isFirst ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: isFirst
                            ? Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 16)
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
                            color: isFirst ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                            fontSize: 15,
                            fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (record.location != null && record.location!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.location_on, color: theme.colorScheme.onSurfaceVariant, size: 16),
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
