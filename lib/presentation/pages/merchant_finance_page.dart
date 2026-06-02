import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/presentation/components/charts/chart_gradient_palette.dart';
import 'package:moment_keep/presentation/components/charts/premium_trend_chart.dart';
import 'package:moment_keep/services/product_database_service.dart';

class MerchantFinancePage extends ConsumerStatefulWidget {
  const MerchantFinancePage({super.key});

  @override
  ConsumerState<MerchantFinancePage> createState() => _MerchantFinancePageState();
}

class _MerchantFinancePageState extends ConsumerState<MerchantFinancePage> with SingleTickerProviderStateMixin {
  String _selectedTimeRange = '今日';
  final List<String> _timeRanges = ['今日', '本周', '本月', '本年', '全部'];
  int _currentTabIndex = 0;
  late TabController _tabController;

  final ProductDatabaseService _productDb = ProductDatabaseService();

  int? _merchantId;
  Map<String, String> _orderNames = {};

  bool _isLoading = true;

  double _totalPointsRevenue = 0;
  double _totalCashRevenue = 0;
  int _totalOrders = 0;
  double _refundAmount = 0;
  double _netProfit = 0;
  double _escrowPoints = 0;
  double _escrowCash = 0;

  double _pointsRevenueGrowth = 0;
  double _cashRevenueGrowth = 0;
  double _ordersGrowth = 0;
  double _refundGrowth = 0;
  double _netProfitGrowth = 0;
  double _escrowPointsGrowth = 0;
  double _escrowCashGrowth = 0;

  List<Map<String, dynamic>> _revenueByDate = [];
  List<PaymentRecord> _paymentRecords = [];
  List<Map<String, dynamic>> _productRankings = [];

  final _currencyFormat = NumberFormat('#,##0', 'zh_CN');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initMerchantId();
  }

  Future<void> _initMerchantId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(StorageKeys.userId) ?? 'default_user';
      final merchants = await _productDb.getAllMerchants();
      if (merchants.isEmpty) {
        debugPrint('财务统计: 商家列表为空，将加载所有订单数据');
      } else {
        final userMerchant = merchants.firstWhere(
          (m) => m.userId == userId,
          orElse: () => merchants.first,
        );
        _merchantId = userMerchant.id;
        debugPrint('财务统计: 已加载商家ID=$_merchantId, 名称=${userMerchant.name}');
      }
    } catch (e) {
      debugPrint('获取商家ID失败: $e');
    }
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange _getDateRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case '今日':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case '本周':
        final weekday = now.weekday;
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case '本月':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case '本年':
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case '全部':
        return DateTimeRange(
          start: DateTime(2000, 1, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
    }
  }

  DateTimeRange _getPreviousDateRange(String range) {
    final current = _getDateRange(range);
    final duration = current.end.difference(current.start);
    return DateTimeRange(
      start: current.start.subtract(duration),
      end: current.start.subtract(const Duration(milliseconds: 1)),
    );
  }

  double _calcGrowth(double current, double previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dateRange = _getDateRange(_selectedTimeRange);
      final prevDateRange = _getPreviousDateRange(_selectedTimeRange);

      final orders = await _productDb.getOrdersByDateRange(dateRange.start, dateRange.end, merchantId: _merchantId);
      final prevOrders = await _productDb.getOrdersByDateRange(prevDateRange.start, prevDateRange.end, merchantId: _merchantId);

      final records = await _productDb.getPaymentRecordsByDateRange(dateRange.start, dateRange.end, merchantId: _merchantId);
      final rankings = await _productDb.getProductSalesRanking(limit: 10, merchantId: _merchantId);

      final orderNames = <String, String>{};
      for (final order in orders) {
        final orderId = order['id'] as String?;
        final productName = order['product_name'] as String?;
        if (orderId != null && productName != null) {
          orderNames[orderId] = productName;
        }
      }

      double totalPointsRevenue = 0;
      double totalCashRevenue = 0;
      int totalOrders = orders.length;
      double refundAmount = 0;
      double escrowPoints = 0;
      double escrowCash = 0;

      final revenueMap = <String, double>{};
      final pointsMap = <String, double>{};
      final ordersMap = <String, int>{};

      for (final order in orders) {
        final status = order['status'] as String? ?? '';
        String fundStatus = order['fund_status'] as String? ?? '';
        if (fundStatus.isEmpty) {
          fundStatus = 'escrow';
        }
        final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
        final pointsUsed = (order['points_used'] as num?)?.toDouble() ?? 0;
        final cashAmount = (order['cash_amount'] as num?)?.toDouble() ?? 0;
        final createdAt = order['created_at'] as int?;
        final quantity = (order['quantity'] as num?)?.toInt() ?? 1;

        if (status == 'refunded' || status == 'cancelled') {
          refundAmount += totalAmount;
        } else if (fundStatus == 'released') {
          totalPointsRevenue += pointsUsed;
          totalCashRevenue += cashAmount;
        } else if (fundStatus == 'escrow') {
          escrowPoints += pointsUsed;
          escrowCash += cashAmount;
        }

        if (createdAt != null && fundStatus == 'released') {
          final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          revenueMap[dateKey] = (revenueMap[dateKey] ?? 0) + cashAmount;
          pointsMap[dateKey] = (pointsMap[dateKey] ?? 0) + pointsUsed;
          ordersMap[dateKey] = (ordersMap[dateKey] ?? 0) + quantity;
        }
      }

      final allDateKeys = <String>{...revenueMap.keys, ...pointsMap.keys};
      final sortedKeys = allDateKeys.toList()..sort();
      final revenueByDate = sortedKeys.map((key) => {
        'date': key,
        'amount': revenueMap[key] ?? 0,
        'points': pointsMap[key] ?? 0,
        'orders': ordersMap[key] ?? 0,
      }).toList();

      double prevTotalPointsRevenue = 0;
      double prevTotalCashRevenue = 0;
      int prevTotalOrders = prevOrders.length;
      double prevRefundAmount = 0;
      double prevNetProfit = 0;
      double prevEscrowPoints = 0;
      double prevEscrowCash = 0;

      for (final order in prevOrders) {
        final status = order['status'] as String? ?? '';
        String fundStatus = order['fund_status'] as String? ?? '';
        if (fundStatus.isEmpty) {
          fundStatus = 'escrow';
        }
        final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
        final pointsUsed = (order['points_used'] as num?)?.toDouble() ?? 0;
        final cashAmount = (order['cash_amount'] as num?)?.toDouble() ?? 0;
        if (status == 'refunded' || status == 'cancelled') {
          prevRefundAmount += totalAmount;
        } else if (fundStatus == 'released') {
          prevTotalPointsRevenue += pointsUsed;
          prevTotalCashRevenue += cashAmount;
        } else if (fundStatus == 'escrow') {
          prevEscrowPoints += pointsUsed;
          prevEscrowCash += cashAmount;
        }
      }
      prevNetProfit = prevTotalCashRevenue - prevRefundAmount;

      final netProfit = totalCashRevenue - refundAmount;

      setState(() {
        _totalPointsRevenue = totalPointsRevenue;
        _totalCashRevenue = totalCashRevenue;
        _totalOrders = totalOrders;
        _refundAmount = refundAmount;
        _netProfit = netProfit;
        _escrowPoints = escrowPoints;
        _escrowCash = escrowCash;
        _revenueByDate = revenueByDate;
        _paymentRecords = records;
        _productRankings = rankings;
        _orderNames = orderNames;

        _pointsRevenueGrowth = _calcGrowth(totalPointsRevenue, prevTotalPointsRevenue);
        _cashRevenueGrowth = _calcGrowth(totalCashRevenue, prevTotalCashRevenue);
        _ordersGrowth = _calcGrowth(totalOrders.toDouble(), prevTotalOrders.toDouble());
        _refundGrowth = _calcGrowth(refundAmount, prevRefundAmount);
        _netProfitGrowth = _calcGrowth(netProfit, prevNetProfit);
        _escrowPointsGrowth = _calcGrowth(escrowPoints, prevEscrowPoints);
        _escrowCashGrowth = _calcGrowth(escrowCash, prevEscrowCash);

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载财务数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double value) {
    return '¥${_currencyFormat.format(value.round())}';
  }

  String _formatPoints(double value) {
    return '${_currencyFormat.format(value.round())}积分';
  }

  String _formatGrowth(double growth) {
    if (growth == 0) return '0%';
    final prefix = growth > 0 ? '+' : '';
    return '$prefix${growth.toStringAsFixed(1)}%';
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
          _buildTabBar(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTabContent(theme),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: Text(
        '财务统计',
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
      ],
    );
  }

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
                  if (_selectedTimeRange != range) {
                    setState(() {
                      _selectedTimeRange = range;
                    });
                    _loadData();
                  }
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

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: '概览'),
          Tab(text: '交易明细'),
          Tab(text: '商品排行'),
        ],
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme) {
    switch (_currentTabIndex) {
      case 0:
        return _buildOverviewTab(theme);
      case 1:
        return _buildTransactionsTab(theme);
      case 2:
        return _buildProductsTab(theme);
      default:
        return _buildOverviewTab(theme);
    }
  }

  Widget _buildOverviewTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatisticsCards(theme),
          const SizedBox(height: 24),
          _buildRevenueChart(theme),
          const SizedBox(height: 24),
          _buildRecentTransactionsSection(theme),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(ThemeData theme) {
    final stats = [
      {
        'title': '积分收入',
        'value': _formatPoints(_totalPointsRevenue),
        'icon': Icons.stars,
        'color': ChartGradientPalette.pointsColor,
        'growth': _pointsRevenueGrowth,
      },
      {
        'title': '现金收入',
        'value': _formatCurrency(_totalCashRevenue),
        'icon': Icons.trending_up,
        'color': ChartGradientPalette.positiveColor,
        'growth': _cashRevenueGrowth,
      },
      {
        'title': '订单数',
        'value': _currencyFormat.format(_totalOrders),
        'icon': Icons.shopping_bag,
        'color': ChartGradientPalette.todoColor,
        'growth': _ordersGrowth,
      },
      {
        'title': '退款金额',
        'value': _formatCurrency(_refundAmount),
        'icon': Icons.trending_down,
        'color': ChartGradientPalette.negativeColor,
        'growth': _refundGrowth,
      },
      {
        'title': '净收入',
        'value': _formatCurrency(_netProfit),
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFF4CAF50),
        'growth': _netProfitGrowth,
      },
      {
        'title': '监管中积分',
        'value': _formatPoints(_escrowPoints),
        'icon': Icons.lock_clock,
        'color': ChartGradientPalette.diaryColor,
        'growth': _escrowPointsGrowth,
      },
      {
        'title': '监管中现金',
        'value': _formatCurrency(_escrowCash),
        'icon': Icons.lock_outline,
        'color': const Color(0xFFFF9800),
        'growth': _escrowCashGrowth,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 10) * 0.48;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: stats.map((stat) {
            return SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                theme: theme,
                title: stat['title'] as String,
                value: stat['value'] as String,
                icon: stat['icon'] as IconData,
                color: stat['color'] as Color,
                growth: stat['growth'] as double,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double growth,
  }) {
    final isPositive = growth >= 0;
    final growthColor = title == '退款金额' ? (isPositive ? ChartGradientPalette.negativeColor : ChartGradientPalette.positiveColor) : (isPositive ? ChartGradientPalette.positiveColor : ChartGradientPalette.negativeColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: growthColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatGrowth(growth),
                  style: TextStyle(
                    color: growthColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '营收趋势',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _revenueByDate.isEmpty
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : PremiumTrendChart(
                  series: [
                    ChartSeries(
                      id: 'cash',
                      name: '现金收入',
                      color: ChartGradientPalette.positiveColor,
                      values: _revenueByDate.map((e) => (e['amount'] as num).toDouble()).toList(),
                    ),
                    ChartSeries(
                      id: 'points',
                      name: '积分收入',
                      color: ChartGradientPalette.pointsColor,
                      values: _revenueByDate.map((e) => (e['points'] as num).toDouble()).toList(),
                    ),
                  ],
                  dates: _revenueByDate.map((e) => e['date'] as String).toList(),
                  title: '',
                  height: 250,
                  compact: true,
                  showGradientFill: true,
                  showGlowEffect: true,
                  showDots: true,
                ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近交易',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentTabIndex = 1;
                  });
                },
                child: Text(
                  '查看全部',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _paymentRecords.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '暂无交易记录',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: _paymentRecords.take(3).map((record) {
                    return _buildTransactionItem(record, theme);
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(ThemeData theme) {
    if (_paymentRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
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
      itemCount: _paymentRecords.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(_paymentRecords[index], theme);
      },
    );
  }

  Widget _buildTransactionItem(PaymentRecord record, ThemeData theme) {
    final isRefund = record.status == 'refunded';
    final isIncome = !isRefund;
    final color = isIncome ? ChartGradientPalette.positiveColor : ChartGradientPalette.negativeColor;

    final timeStr = record.paidAt != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(record.paidAt!)
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(record.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.add : Icons.remove,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _orderNames[record.orderId] ?? _getPaymentMethodLabel(record.paymentMethod),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPaymentMethodColor(record.paymentMethod, theme).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getPaymentMethodLabel(record.paymentMethod),
                        style: TextStyle(
                          color: _getPaymentMethodColor(record.paymentMethod, theme),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.paymentNo,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(record.status, theme).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getPaymentStatusText(record.status),
                        style: TextStyle(
                          color: _getPaymentStatusColor(record.status, theme),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (record.cashAmount > 0)
                Text(
                  '${isIncome ? '+' : '-'}${_formatCurrency(record.cashAmount / 100.0)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (record.pointsUsed > 0)
                Text(
                  '${isIncome ? '+' : '-'}${_formatPoints(record.pointsUsed.toDouble())}',
                  style: TextStyle(
                    color: ChartGradientPalette.pointsColor,
                    fontSize: record.cashAmount > 0 ? 13 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (record.cashAmount == 0 && record.pointsUsed == 0)
                Text(
                  '${isIncome ? '+' : '-'}${_formatCurrency(record.amount / 100.0)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodLabel(String method) {
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
        return method;
    }
  }

  Color _getPaymentMethodColor(String method, ThemeData theme) {
    switch (method) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'points':
        return ChartGradientPalette.pointsColor;
      case 'hybrid':
        return const Color(0xFF9C27B0);
      case 'shopping_card':
        return const Color(0xFFFF9800);
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  Color _getPaymentStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'success':
        return ChartGradientPalette.positiveColor;
      case 'refunded':
        return ChartGradientPalette.negativeColor;
      case 'pending':
        return ChartGradientPalette.pointsColor;
      case 'failed':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status) {
      case 'success':
        return '已完成';
      case 'refunded':
        return '已退款';
      case 'pending':
        return '待支付';
      case 'failed':
        return '支付失败';
      default:
        return '未知';
    }
  }

  Widget _buildProductsTab(ThemeData theme) {
    if (_productRankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              '暂无商品排行数据',
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
      itemCount: _productRankings.length,
      itemBuilder: (context, index) {
        final product = _productRankings[index];
        return _buildProductRankItem(product, index + 1, theme);
      },
    );
  }

  Widget _buildProductRankItem(Map<String, dynamic> product, int rank, ThemeData theme) {
    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];

    final totalSales = (product['total_sales'] as num?)?.toInt() ?? 0;
    final totalRevenue = (product['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final productName = product['product_name'] as String? ?? '未知商品';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? rankColors[rank - 1].withOpacity(0.2)
                  : theme.colorScheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  color: rank <= 3
                      ? rankColors[rank - 1]
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '销量: $totalSales 件',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(totalRevenue),
            style: TextStyle(
              color: ChartGradientPalette.positiveColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final dateRange = _getDateRange(_selectedTimeRange);
      final orders = await _productDb.getOrdersByDateRange(
        dateRange.start,
        dateRange.end,
        merchantId: _merchantId,
      );

      final buffer = StringBuffer();
      buffer.writeln('订单ID,商品名称,支付方式,金额,积分使用,现金金额,状态,创建时间');

      for (final order in orders) {
        final id = order['id'] ?? '';
        final productName = order['product_name'] ?? '';
        final paymentMethod = order['payment_method'] ?? '';
        final totalAmount = order['total_amount'] ?? 0;
        final pointsUsed = order['points_used'] ?? 0;
        final cashAmount = order['cash_amount'] ?? 0;
        final status = order['status'] ?? '';
        final createdAt = order['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(order['created_at'] as int).toString()
            : '';
        buffer.writeln('$id,$productName,$paymentMethod,$totalAmount,$pointsUsed,$cashAmount,$status,$createdAt');
      }

      if (mounted) {
        Navigator.of(context).pop();
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/财务数据_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '商家财务数据导出',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
}
