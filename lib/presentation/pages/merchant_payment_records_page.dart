import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 商家版支付记录页面
class MerchantPaymentRecordsPage extends ConsumerStatefulWidget {
  const MerchantPaymentRecordsPage({super.key});

  @override
  ConsumerState<MerchantPaymentRecordsPage> createState() =>
      _MerchantPaymentRecordsPageState();
}

class _MerchantPaymentRecordsPageState
    extends ConsumerState<MerchantPaymentRecordsPage> {
  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();

  /// 当前选中的时间范围
  String _selectedTimeRange = '全部';

  /// 时间范围选项
  final List<String> _timeRanges = ['今日', '本周', '本月', '全部'];

  /// 当前选中的标签页索引
  int _currentTabIndex = 0;

  /// 搜索关键词
  String _searchQuery = '';

  /// 支付记录列表
  List<PaymentRecord> _paymentRecords = [];

  /// 筛选后的支付记录列表
  List<PaymentRecord> _filteredRecords = [];

  /// 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentRecords();
  }

  /// 加载支付记录数据
  Future<void> _loadPaymentRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productDb = ProductDatabaseService();
      final allRecords = await productDb.getAllPaymentRecords();

      setState(() {
        _paymentRecords = allRecords;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载支付记录失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 应用筛选条件
  void _applyFilters() {
    List<PaymentRecord> filtered = _paymentRecords;

    /// 标签页筛选
    if (_currentTabIndex == 1) {
      filtered =
          filtered.where((record) => record.status == 'success').toList();
    } else if (_currentTabIndex == 2) {
      filtered =
          filtered.where((record) => record.status == 'pending').toList();
    } else if (_currentTabIndex == 3) {
      filtered =
          filtered.where((record) => record.status == 'refunded').toList();
    }

    /// 搜索筛选
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((record) {
        return record.orderId.toLowerCase().contains(query) ||
            record.paymentNo.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredRecords = filtered;
    });
  }

  /// 获取状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'success':
        return '收入';
      case 'pending':
        return '待支付';
      case 'failed':
        return '失败';
      case 'refunded':
        return '退款';
      default:
        return '未知';
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'success':
        return const Color(0xFF13ec5b);
      case 'pending':
        return theme.colorScheme.secondary;
      case 'failed':
        return theme.colorScheme.error;
      case 'refunded':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.outline;
    }
  }

  /// 获取支付方式文本
  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'cash':
        return '现金支付';
      case 'points':
        return '积分支付';
      case 'hybrid':
        return '混合支付';
      case 'shopping_card':
        return '购物卡支付';
      default:
        return '未知';
    }
  }

  /// 显示支付详情
  void _showPaymentDetail(PaymentRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text(
            '交易详情',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailItem(
                  '订单编号',
                  record.orderId,
                  theme,
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  '支付流水号',
                  record.paymentNo,
                  theme,
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  '交易金额',
                  '¥${record.amount.toStringAsFixed(2)}',
                  theme,
                ),
                if (record.pointsUsed > 0) ...[
                  const SizedBox(height: 12),
                  _buildDetailItem(
                    '积分抵扣',
                    '${record.pointsUsed} 积分',
                    theme,
                  ),
                ],
                const SizedBox(height: 12),
                _buildDetailItem(
                  '支付方式',
                  _getPaymentMethodText(record.paymentMethod),
                  theme,
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  '交易状态',
                  _getStatusText(record.status),
                  theme,
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  '交易时间',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(record.createdAt),
                  theme,
                ),
                if (record.refundedAt != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailItem(
                    '退款时间',
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(record.refundedAt!),
                    theme,
                  ),
                ],
                if (record.failureReason != null &&
                    record.failureReason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailItem(
                    '失败原因',
                    record.failureReason!,
                    theme,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '关闭',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建详情项
  Widget _buildDetailItem(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 导出数据
  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('导出功能开发中'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          _buildTimeRangeSelector(theme),
          _buildSearchBar(theme),
          _buildTabBar(theme),
          _buildStatisticsSection(theme),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  )
                : _buildPaymentList(theme),
          ),
        ],
      ),
    );
  }

  /// 构建顶部AppBar
  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: Text(
        '商家交易记录',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: Icon(
          Icons.arrow_back,
          color: theme.colorScheme.onSurface,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.download,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: _exportData,
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: _loadPaymentRecords,
        ),
      ],
    );
  }

  /// 构建时间范围选择器
  Widget _buildTimeRangeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _timeRanges.map((range) {
            final isSelected = _selectedTimeRange == range;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTimeRange = range;
                  });
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    range,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: TextField(
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: '搜索订单号或支付流水号',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _applyFilters();
        },
      ),
    );
  }

  /// 构建标签栏
  Widget _buildTabBar(ThemeData theme) {
    final tabs = ['全部', '收入', '待支付', '退款'];
    return Container(
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tabs.length,
          itemBuilder: (context, index) {
            final isSelected = _currentTabIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentTabIndex = index;
                  });
                  _applyFilters();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建统计区域
  Widget _buildStatisticsSection(ThemeData theme) {
    final incomeCount =
        _paymentRecords.where((r) => r.status == 'success').length;
    final pendingCount =
        _paymentRecords.where((r) => r.status == 'pending').length;
    final refundCount =
        _paymentRecords.where((r) => r.status == 'refunded').length;

    final totalIncome = _paymentRecords
        .where((r) => r.status == 'success')
        .fold(0.0, (sum, r) => sum + r.amount);

    final totalRefund = _paymentRecords
        .where((r) => r.status == 'refunded')
        .fold(0.0, (sum, r) => sum + r.amount);

    final netIncome = totalIncome - totalRefund;

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '总收入',
                  '¥${totalIncome.toStringAsFixed(2)}',
                  const Color(0xFF13ec5b),
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '净收入',
                  '¥${netIncome.toStringAsFixed(2)}',
                  theme.colorScheme.primary,
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '收入笔数',
                  '$incomeCount',
                  const Color(0xFF13ec5b),
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '退款金额',
                  '¥${totalRefund.toStringAsFixed(2)}',
                  theme.colorScheme.error,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatCard(
      String title, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建支付记录列表
  Widget _buildPaymentList(ThemeData theme) {
    if (_filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无交易记录',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];
        return _buildPaymentItem(record, theme);
      },
    );
  }

  /// 构建支付记录项
  Widget _buildPaymentItem(PaymentRecord record, ThemeData theme) {
    final isIncome = record.status == 'success';
    final isRefund = record.status == 'refunded';
    final displayAmount = isRefund ? '-¥${record.amount.toStringAsFixed(2)}' : '+¥${record.amount.toStringAsFixed(2)}';
    final displayColor = isRefund ? theme.colorScheme.error : const Color(0xFF13ec5b);

    return GestureDetector(
      onTap: () => _showPaymentDetail(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '订单号: ${record.orderId}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPaymentMethodText(record.paymentMethod),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(record.status, theme)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(record.status),
                    style: TextStyle(
                      color: _getStatusColor(record.status, theme),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  displayAmount,
                  style: TextStyle(
                    color: displayColor,
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
}