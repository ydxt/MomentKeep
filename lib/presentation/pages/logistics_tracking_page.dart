import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';

class LogisticsTrackingPage extends ConsumerStatefulWidget {
  const LogisticsTrackingPage({super.key, this.orderId = ''});

  final String orderId;

  @override
  ConsumerState<LogisticsTrackingPage> createState() => _LogisticsTrackingPageState();
}

class _LogisticsTrackingPageState extends ConsumerState<LogisticsTrackingPage> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOrderUnavailable = false;
  List<LogisticsTrack> _trackingRecords = [];
  String _currentStatus = 'created';
  String? _trackingNumber;
  String? _logisticsCompanyName;
  bool _isElectronic = false;

  final _dbService = ProductDatabaseService();

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
      _errorMessage = null;
    });

    try {
      debugPrint('=== 物流追踪页: 开始加载物流数据 ===');
      debugPrint('物流追踪页: orderId=${widget.orderId}');

      if (widget.orderId.isEmpty) {
        debugPrint('LogisticsTrackingPage: orderId为空，无法加载物流数据');
        setState(() {
          _isLoading = false;
          _isOrderUnavailable = true;
        });
        return;
      }

      final orderData = await _dbService.getOrderById(widget.orderId);
      if (orderData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '未找到该订单';
        });
        return;
      }
      _isElectronic = orderData['is_electronic'] == 1;
      debugPrint('物流追踪页: orderData状态=${orderData['status']}, isElectronic=$_isElectronic');
      debugPrint('物流追踪页: orderData中logistics_info字段=${orderData['logistics_info']}');
      debugPrint('物流追踪页: orderData中logistics_company_id字段=${orderData['logistics_company_id']}');

      List<LogisticsTrack> tracks = [];
      try {
        tracks = await _dbService.getLogisticsTracksByOrderId(widget.orderId);
      } catch (e) {
        debugPrint('查询物流轨迹失败，尝试从订单JSON解析: $e');
      }
      _trackingRecords = tracks;
      debugPrint('物流追踪页: 从DB查询到 ${tracks.length} 条物流轨迹');
      if (tracks.isNotEmpty) {
        debugPrint('物流追踪页: 首条轨迹 - trackingNumber=${tracks.first.trackingNumber}, logisticsCompanyId=${tracks.first.logisticsCompanyId}, status=${tracks.first.status}');
      }

      if (tracks.isNotEmpty) {
        final firstStatus = tracks.first.status;
        _currentStatus = firstStatus.isNotEmpty ? firstStatus : (orderData['status'] as String? ?? 'created');
        _trackingNumber = tracks.first.trackingNumber;
        debugPrint('物流追踪页: 从DB轨迹设置 _trackingNumber=$_trackingNumber');
        if (tracks.first.logisticsCompanyId != null) {
          final company = await _dbService.getLogisticsCompanyById(tracks.first.logisticsCompanyId!);
          if (company != null) {
            _logisticsCompanyName = company.name;
            debugPrint('物流追踪页: 从DB公司表查询到物流公司名称=$_logisticsCompanyName');
          } else {
            debugPrint('物流追踪页: 根据ID=${tracks.first.logisticsCompanyId}查询公司表返回null');
          }
        } else {
          debugPrint('物流追踪页: 轨迹中logisticsCompanyId为null，跳过公司查询');
        }
      } else {
        String resolvedStatus = 'created';
        resolvedStatus = _parseLogisticsJson(orderData, resolvedStatus);
        if (resolvedStatus == 'created') {
          resolvedStatus = orderData['status'] as String? ?? 'created';
        }
        _currentStatus = resolvedStatus;
        debugPrint('物流追踪页: 轨迹为空，从JSON回填后 _currentStatus=$_currentStatus, _trackingNumber=$_trackingNumber, _logisticsCompanyName=$_logisticsCompanyName');
      }

      if (tracks.isNotEmpty) {
        String resolvedStatus = _currentStatus;
        resolvedStatus = _parseLogisticsJson(orderData, resolvedStatus);
        _currentStatus = resolvedStatus;
        debugPrint('物流追踪页: 轨迹非空，JSON回填后 _currentStatus=$_currentStatus, _trackingNumber=$_trackingNumber, _logisticsCompanyName=$_logisticsCompanyName');
      }

      debugPrint('=== 物流追踪页: 最终数据 _trackingNumber=$_trackingNumber, _logisticsCompanyName=$_logisticsCompanyName, _currentStatus=$_currentStatus, _trackingRecords.length=${_trackingRecords.length} ===');
    } catch (e) {
      debugPrint('加载物流信息失败: $e');
      _errorMessage = '加载物流信息失败，请重试';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 从 orderData 的 logistics_info JSON 中解析并回填缺失的物流字段
  /// 返回解析到的物流状态（若无则返回传入的 fallback 值）
  String _parseLogisticsJson(Map<String, dynamic> orderData, String fallbackStatus) {
    final logisticsInfoRaw = orderData['logistics_info'];
    if (logisticsInfoRaw == null || logisticsInfoRaw is! String || logisticsInfoRaw.isEmpty) {
      return fallbackStatus;
    }

    try {
      final logisticsJson = jsonDecode(logisticsInfoRaw) as Map<String, dynamic>;

      final jsonTrackingNumber = logisticsJson['tracking_number'] as String?;
      final jsonLogisticsCompany = logisticsJson['logistics_company'] as String?;
      final jsonLogisticsStatus = logisticsJson['logistics_status'] as String?;

      if ((_trackingNumber == null || _trackingNumber!.isEmpty) &&
          jsonTrackingNumber != null && jsonTrackingNumber.isNotEmpty) {
        _trackingNumber = jsonTrackingNumber;
        debugPrint('物流追踪: 从JSON回填运单号=$jsonTrackingNumber');
      }
      if ((_logisticsCompanyName == null || _logisticsCompanyName!.isEmpty) &&
          jsonLogisticsCompany != null && jsonLogisticsCompany.isNotEmpty) {
        _logisticsCompanyName = jsonLogisticsCompany;
        debugPrint('物流追踪: 从JSON回填物流公司=$jsonLogisticsCompany');
      }
      if (jsonLogisticsStatus == '无需物流') {
        _isElectronic = true;
      }

      if (jsonLogisticsStatus != null && jsonLogisticsStatus.isNotEmpty) {
        return jsonLogisticsStatus;
      }
    } catch (e) {
      debugPrint('解析logistics_info JSON失败: $e');
    }

    return fallbackStatus;
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'created':
      case 'shipped':
      case '已发货':
        return {'text': '已发货', 'color': Colors.blue, 'icon': Icons.local_shipping, 'progress': 0.2, 'desc': '商家已发货，等待快递揽收'};
      case 'picked':
      case '已揽收':
        return {'text': '已揽收', 'color': Colors.indigo, 'icon': Icons.inventory_2, 'progress': 0.4, 'desc': '快递已揽收，准备运输'};
      case 'transporting':
      case '运输中':
        return {'text': '运输中', 'color': Colors.orange, 'icon': Icons.local_shipping, 'progress': 0.6, 'desc': '包裹正在运输途中'};
      case 'delivering':
      case '派送中':
        return {'text': '派送中', 'color': Colors.deepPurple, 'icon': Icons.delivery_dining, 'progress': 0.8, 'desc': '快递员正在为您派送'};
      case 'delivered':
      case '已签收':
        return {'text': '已签收', 'color': Colors.green, 'icon': Icons.check_circle, 'progress': 1.0, 'desc': '包裹已签收，祝您购物愉快'};
      case 'exception':
      case '异常':
        return {'text': '异常', 'color': Colors.red, 'icon': Icons.error, 'progress': 0.0, 'desc': '物流出现异常'};
      case '无需物流':
        return {'text': '无需物流', 'color': Colors.green, 'icon': Icons.cloud_done, 'progress': 1.0, 'desc': '虚拟商品无需物流配送'};
      default:
        return {'text': status, 'color': Colors.grey, 'icon': Icons.local_shipping, 'progress': 0.2, 'desc': '状态: $status'};
    }
  }

  double _getProgress(String status) {
    final info = _getStatusInfo(status);
    return (info['progress'] as double?) ?? 0.0;
  }

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
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('物流跟踪', style: TextStyle(color: theme.colorScheme.onBackground)),
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
                            ? (_isElectronic
                                ? _buildElectronicGoodsState(theme)
                                : _trackingNumber != null && _trackingNumber!.isNotEmpty
                                    ? _buildShippedNotPickedState(theme)
                                    : _buildEmptyState(theme))
                            : _buildTrackingTimeline(theme),
                      ),
                    ],
                  ),
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
            child: Text('重试'),
          ),
        ],
      ),
    );
  }

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
            child: Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  '暂无物流信息',
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

  Widget _buildShippedNotPickedState(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '商家已发货，等待快递揽收',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: theme.colorScheme.onSurfaceVariant, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '物流公司: ${_logisticsCompanyName != null && _logisticsCompanyName!.isNotEmpty ? _logisticsCompanyName : '未知物流公司'}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
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
                    onPressed: _copyTrackingNumber,
                    tooltip: '复制运单号',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '物流信息将在快递揽收后更新，请耐心等待',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildElectronicGoodsState(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_done_outlined,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '虚拟商品无需物流配送',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '该商品为虚拟商品，系统发放后即刻生效',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '权益已生效，无需等待物流配送',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
          Row(
            children: [
              Icon(Icons.local_shipping, color: theme.colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Text(
                '物流公司: ${_logisticsCompanyName != null && _logisticsCompanyName!.isNotEmpty ? _logisticsCompanyName : '未知物流公司'}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                        width: isFirst ? 28 : 24,
                        height: isFirst ? 28 : 24,
                        decoration: BoxDecoration(
                          color: isFirst ? theme.colorScheme.primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: isFirst
                            ? Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 16)
                            : null,
                      ),
                      if (index < _trackingRecords.length - 1)
                        Expanded(
                          child: isFirst
                              ? Container(
                                  width: 3,
                                  color: theme.colorScheme.primary,
                                )
                              : CustomPaint(
                                  size: const Size(2, double.infinity),
                                  painter: _DashedLinePainter(
                                    color: theme.colorScheme.outline.withOpacity(0.3),
                                  ),
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
              '配送进度',
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
            backgroundColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(statusInfo['color'] as Color),
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

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double dashHeight = 5;
    const double gapHeight = 4;
    double startY = 0;

    while (startY < size.height) {
      final endY = (startY + dashHeight).clamp(0.0, size.height).toDouble();
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, endY),
        paint,
      );
      startY += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
