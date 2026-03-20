import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class PaymentRecordsPage extends ConsumerStatefulWidget {
  const PaymentRecordsPage({super.key});

  @override
  ConsumerState<PaymentRecordsPage> createState() => _PaymentRecordsPageState();
}

class _PaymentRecordsPageState extends ConsumerState<PaymentRecordsPage> with SingleTickerProviderStateMixin {
  List<PaymentRecord> _paymentRecords = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPaymentRecords();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = ProductDatabaseService();
      _paymentRecords = await databaseService.getAllPaymentRecords();
      
      if (_paymentRecords.isEmpty) {
        final mockRecords = [
          PaymentRecord(
            id: 1,
            orderId: 'ORD20260401001',
            userId: 'default_user',
            paymentNo: 'PAY202604010001',
            amount: 99,
            pointsUsed: 0,
            cashAmount: 99,
            paymentMethod: 'cash',
            status: 'success',
            paidAt: DateTime.now().subtract(const Duration(days: 5)),
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
            updatedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          PaymentRecord(
            id: 2,
            orderId: 'ORD20260402002',
            userId: 'default_user',
            paymentNo: 'PAY202604020002',
            amount: 199,
            pointsUsed: 100,
            cashAmount: 99,
            paymentMethod: 'hybrid',
            status: 'success',
            paidAt: DateTime.now().subtract(const Duration(days: 3)),
            createdAt: DateTime.now().subtract(const Duration(days: 3)),
            updatedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
          PaymentRecord(
            id: 3,
            orderId: 'ORD20260403003',
            userId: 'default_user',
            paymentNo: 'PAY202604030003',
            amount: 59,
            pointsUsed: 59,
            cashAmount: 0,
            paymentMethod: 'points',
            status: 'pending',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          PaymentRecord(
            id: 4,
            orderId: 'ORD20260328004',
            userId: 'default_user',
            paymentNo: 'PAY202603280004',
            amount: 299,
            pointsUsed: 0,
            cashAmount: 299,
            paymentMethod: 'cash',
            status: 'failed',
            failureReason: '余额不足',
            createdAt: DateTime.now().subtract(const Duration(days: 7)),
            updatedAt: DateTime.now().subtract(const Duration(days: 7)),
          ),
          PaymentRecord(
            id: 5,
            orderId: 'ORD20260325005',
            userId: 'default_user',
            paymentNo: 'PAY202603250005',
            amount: 158,
            pointsUsed: 0,
            cashAmount: 158,
            paymentMethod: 'shopping_card',
            status: 'refunded',
            paidAt: DateTime.now().subtract(const Duration(days: 12)),
            refundedAt: DateTime.now().subtract(const Duration(days: 10)),
            createdAt: DateTime.now().subtract(const Duration(days: 12)),
            updatedAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          PaymentRecord(
            id: 6,
            orderId: 'ORD20260320006',
            userId: 'default_user',
            paymentNo: 'PAY202603200006',
            amount: 88,
            pointsUsed: 50,
            cashAmount: 38,
            paymentMethod: 'hybrid',
            status: 'success',
            paidAt: DateTime.now().subtract(const Duration(days: 15)),
            createdAt: DateTime.now().subtract(const Duration(days: 15)),
            updatedAt: DateTime.now().subtract(const Duration(days: 15)),
          ),
        ];
        
        for (var record in mockRecords) {
          await databaseService.insertPaymentRecord(record);
        }
        _paymentRecords = mockRecords;
      }
    } catch (e) {
      debugPrint('加载支付记录失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<PaymentRecord> _getFilteredRecords(String status) {
    var records = _paymentRecords;
    
    if (status != 'all') {
      records = records.where((r) => r.status == status).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      records = records.where((r) => 
        r.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.paymentNo.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return records;
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
        title: Text('支付记录', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '成功'),
            Tab(text: '待支付'),
            Tab(text: '失败'),
            Tab(text: '已退款'),
          ],
        ),
      ),
      body: _isLoading ? _buildLoadingState(theme) : Column(
        children: [
          _buildSearchBar(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentList('all', theme),
                _buildPaymentList('success', theme),
                _buildPaymentList('pending', theme),
                _buildPaymentList('failed', theme),
                _buildPaymentList('refunded', theme),
              ],
            ),
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
            '加载支付记录中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: '搜索订单号或支付流水号...',
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          suffixIcon: IconButton(
            icon: Icon(Icons.insert_chart_outlined, color: theme.colorScheme.primary),
            onPressed: () => _showStatisticsDialog(theme),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPaymentList(String status, ThemeData theme) {
    final records = _getFilteredRecords(status);
    
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              color: theme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无支付记录',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildPaymentItem(record, theme);
      },
    );
  }

  Widget _buildPaymentItem(PaymentRecord record, ThemeData theme) {
    final statusInfo = _getStatusInfo(record.status);
    final paymentInfo = _getPaymentMethodInfo(record.paymentMethod);

    return GestureDetector(
      onTap: () {
        _showPaymentDetail(record, theme);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: record.status == 'success' ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(paymentInfo['icon'] as IconData, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        paymentInfo['text'] as String,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (statusInfo['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusInfo['text'] as String,
                      style: TextStyle(
                        color: statusInfo['color'] as Color,
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
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '支付流水号: ${record.paymentNo}',
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
                      Text(
                        '¥${record.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (record.pointsUsed > 0)
                        Text(
                          '积分: ${record.pointsUsed}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record.createdAt.toString().substring(0, 16),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (record.status == 'success')
                    TextButton.icon(
                      onPressed: () => _showRefundDialog(record, theme),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('申请退款'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              if (record.failureReason != null && record.failureReason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '失败原因: ${record.failureReason}',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'success':
        return {'text': '支付成功', 'color': Theme.of(context).colorScheme.primary};
      case 'pending':
        return {'text': '待支付', 'color': Colors.orange};
      case 'failed':
        return {'text': '支付失败', 'color': Theme.of(context).colorScheme.error};
      case 'refunded':
        return {'text': '已退款', 'color': Colors.grey};
      default:
        return {'text': '未知状态', 'color': Colors.grey};
    }
  }

  Map<String, dynamic> _getPaymentMethodInfo(String method) {
    switch (method) {
      case 'cash':
        return {'text': '现金支付', 'icon': Icons.payment};
      case 'points':
        return {'text': '积分支付', 'icon': Icons.stars};
      case 'hybrid':
        return {'text': '混合支付', 'icon': Icons.account_balance_wallet};
      case 'shopping_card':
        return {'text': '购物卡支付', 'icon': Icons.credit_card};
      default:
        return {'text': '其他支付', 'icon': Icons.credit_card};
    }
  }

  void _showPaymentDetail(PaymentRecord record, ThemeData theme) {
    final statusInfo = _getStatusInfo(record.status);
    final paymentInfo = _getPaymentMethodInfo(record.paymentMethod);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('支付详情', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('订单号', record.orderId, theme),
                _buildDetailItem('支付流水号', record.paymentNo, theme),
                if (record.thirdPartyPaymentId != null && record.thirdPartyPaymentId!.isNotEmpty)
                  _buildDetailItem('第三方支付ID', record.thirdPartyPaymentId!, theme),
                const Divider(height: 24),
                _buildDetailItem('支付金额', '¥${record.amount.toStringAsFixed(2)}', theme),
                _buildDetailItem('使用积分', '${record.pointsUsed}', theme),
                _buildDetailItem('现金金额', '¥${record.cashAmount.toStringAsFixed(2)}', theme),
                const Divider(height: 24),
                _buildDetailItem('支付方式', paymentInfo['text'] as String, theme),
                _buildDetailItem('支付状态', statusInfo['text'] as String, theme),
                if (record.failureReason != null && record.failureReason!.isNotEmpty)
                  _buildDetailItem('失败原因', record.failureReason!, theme),
                const Divider(height: 24),
                _buildDetailItem('创建时间', record.createdAt.toString().substring(0, 19), theme),
                if (record.paidAt != null)
                  _buildDetailItem('支付时间', record.paidAt!.toString().substring(0, 19), theme),
                if (record.refundedAt != null)
                  _buildDetailItem('退款时间', record.refundedAt!.toString().substring(0, 19), theme),
              ],
            ),
          ),
          actions: [
            if (record.status == 'success')
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showRefundDialog(record, theme);
                },
                child: Text('申请退款', style: TextStyle(color: theme.colorScheme.error)),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
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
            ),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(PaymentRecord record, ThemeData theme) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('申请退款', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '订单: ${record.orderId}',
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  '退款金额: ¥${record.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: '退款原因',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('退款申请已提交', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text('确认退款', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  void _showStatisticsDialog(ThemeData theme) {
    final totalAmount = _paymentRecords.fold<double>(0, (sum, r) => r.status == 'success' ? sum + r.amount : sum);
    final successCount = _paymentRecords.where((r) => r.status == 'success').length;
    final pendingCount = _paymentRecords.where((r) => r.status == 'pending').length;
    final failedCount = _paymentRecords.where((r) => r.status == 'failed').length;
    final refundedCount = _paymentRecords.where((r) => r.status == 'refunded').length;
    final totalPoints = _paymentRecords.fold<int>(0, (sum, r) => sum + r.pointsUsed);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('支付统计', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildStatCard(theme, Icons.check_circle, '成功', '$successCount', theme.colorScheme.primary),
                    _buildStatCard(theme, Icons.pending, '待支付', '$pendingCount', Colors.orange),
                    _buildStatCard(theme, Icons.error, '失败', '$failedCount', theme.colorScheme.error),
                    _buildStatCard(theme, Icons.undo, '已退款', '$refundedCount', Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildDetailItem('总交易金额', '¥${totalAmount.toStringAsFixed(2)}', theme),
                _buildDetailItem('总使用积分', '$totalPoints', theme),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(ThemeData theme, IconData icon, String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
