import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 商家财务统计页面
class MerchantFinancePage extends ConsumerStatefulWidget {
  const MerchantFinancePage({super.key});

  @override
  ConsumerState<MerchantFinancePage> createState() => _MerchantFinancePageState();
}

class _MerchantFinancePageState extends ConsumerState<MerchantFinancePage> with SingleTickerProviderStateMixin {
  /// 选中的时间范围
  String _selectedTimeRange = '今日';
  
  /// 时间范围选项
  final List<String> _timeRanges = ['今日', '本周', '本月', '本年', '全部'];
  
  /// 当前选中的标签页
  int _currentTabIndex = 0;
  
  /// TabController 实例
  late TabController _tabController;
  
  /// 模拟财务数据
  Map<String, dynamic> _financeData = {
    'totalRevenue': 125680,
    'totalOrders': 328,
    'refundAmount': 5680,
    'refundCount': 12,
    'netProfit': 120000,
    'averageOrderAmount': 383,
    'revenueByDate': [
      {'date': '2024-01-01', 'amount': 2580, 'orders': 8},
      {'date': '2024-01-02', 'amount': 3240, 'orders': 12},
      {'date': '2024-01-03', 'amount': 2890, 'orders': 9},
      {'date': '2024-01-04', 'amount': 4120, 'orders': 15},
      {'date': '2024-01-05', 'amount': 3780, 'orders': 11},
      {'date': '2024-01-06', 'amount': 5230, 'orders': 18},
      {'date': '2024-01-07', 'amount': 4560, 'orders': 14},
    ],
    'recentTransactions': [
      {
        'id': 'ORD20240107001',
        'type': 'income',
        'amount': 258,
        'description': '时光良品旗舰店 - 创意笔记本',
        'time': '2024-01-07 14:32:18',
        'status': 'completed'
      },
      {
        'id': 'ORD20240107002',
        'type': 'income',
        'amount': 128,
        'description': '文创精品店 - 定制书签',
        'time': '2024-01-07 13:25:42',
        'status': 'completed'
      },
      {
        'id': 'REF20240106001',
        'type': 'refund',
        'amount': 88,
        'description': '退款 - 手工艺术馆',
        'time': '2024-01-06 16:45:33',
        'status': 'refunded'
      },
      {
        'id': 'ORD20240106003',
        'type': 'income',
        'amount': 368,
        'description': '时光书店 - 精装书籍',
        'time': '2024-01-06 11:18:25',
        'status': 'completed'
      },
    ],
    'topProducts': [
      {'name': '创意笔记本', 'sales': 86, 'revenue': 22080},
      {'name': '定制书签', 'sales': 125, 'revenue': 16000},
      {'name': '精装书籍', 'sales': 58, 'revenue': 21460},
      {'name': '手工艺品', 'sales': 42, 'revenue': 18900},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            child: _buildTabContent(theme),
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

  /// 构建标签栏
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

  /// 构建标签内容
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

  /// 构建概览标签页
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

  /// 构建统计卡片
  Widget _buildStatisticsCards(ThemeData theme) {
    final stats = [
      {
        'title': '总营收',
        'value': _financeData['totalRevenue'],
        'icon': Icons.trending_up,
        'color': theme.colorScheme.primary,
      },
      {
        'title': '订单数',
        'value': _financeData['totalOrders'],
        'icon': Icons.shopping_bag,
        'color': theme.colorScheme.secondary,
      },
      {
        'title': '退款金额',
        'value': _financeData['refundAmount'],
        'icon': Icons.trending_down,
        'color': theme.colorScheme.error,
      },
      {
        'title': '净收入',
        'value': _financeData['netProfit'],
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFF13ec5b),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(
          theme: theme,
          title: stat['title'] as String,
          value: stat['value'],
          icon: stat['icon'] as IconData,
          color: stat['color'] as Color,
        );
      },
    );
  }

  /// 构建单个统计卡片
  Widget _buildStatCard({
    required ThemeData theme,
    required String title,
    required dynamic value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                size: 24,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+12%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value is int ? '¥$value' : value.toString(),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建营收图表
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
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: RevenueChartPainter(
                data: _financeData['revenueByDate'],
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建最近交易部分
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
          ..._financeData['recentTransactions'].take(3).map((transaction) {
            return _buildTransactionItem(transaction, theme);
          }).toList(),
        ],
      ),
    );
  }

  /// 构建交易明细标签页
  Widget _buildTransactionsTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _financeData['recentTransactions'].length,
      itemBuilder: (context, index) {
        final transaction = _financeData['recentTransactions'][index];
        return _buildTransactionItem(transaction, theme);
      },
    );
  }

  /// 构建单个交易项
  Widget _buildTransactionItem(Map<String, dynamic> transaction, ThemeData theme) {
    final isIncome = transaction['type'] == 'income';
    final color = isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
    
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
                  transaction['description'],
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
                    Text(
                      transaction['id'],
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(transaction['status'], theme).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(transaction['status']),
                        style: TextStyle(
                          color: _getStatusColor(transaction['status'], theme),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  transaction['time'],
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-' }¥${transaction['amount']}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建商品排行标签页
  Widget _buildProductsTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _financeData['topProducts'].length,
      itemBuilder: (context, index) {
        final product = _financeData['topProducts'][index];
        return _buildProductRankItem(product, index + 1, theme);
      },
    );
  }

  /// 构建商品排行项
  Widget _buildProductRankItem(Map<String, dynamic> product, int rank, ThemeData theme) {
    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    
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
                  product['name'],
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '销量: ${product['sales']} 件',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${product['revenue']}',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取状态颜色
  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'completed':
        return theme.colorScheme.primary;
      case 'refunded':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  /// 获取状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'refunded':
        return '已退款';
      default:
        return '未知';
    }
  }

  /// 导出数据
  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('导出功能开发中'),
      ),
    );
  }
}

/// 营收图表绘制器
class RevenueChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final ThemeData theme;

  RevenueChartPainter({required this.data, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    if (data.isEmpty) return;

    final maxAmount = data.map((d) => d['amount'] as int).reduce((a, b) => a > b ? a : b);
    final width = size.width / (data.length + 1);
    final height = size.height - 40;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = width * (i + 1);
      final y = height - (data[i]['amount'] / maxAmount) * height * 0.8;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (data.isNotEmpty) {
      fillPath.lineTo(width * data.length, height);
      fillPath.close();
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    for (int i = 0; i < data.length; i++) {
      final x = width * (i + 1);
      final y = height - (data[i]['amount'] / maxAmount) * height * 0.8;

      final dotPaint = Paint()
        ..color = theme.colorScheme.primary
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 6, dotPaint);

      final borderPaint = Paint()
        ..color = theme.colorScheme.surface
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
