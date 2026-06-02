import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/pages/merchant_management_page.dart';
import 'package:moment_keep/presentation/pages/settings_page.dart';
import 'package:moment_keep/presentation/pages/coupon_management_page.dart';
import 'package:moment_keep/presentation/pages/red_packet_management_page.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/database_service.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _totalUsers = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlatformStats();
    });
  }

  Future<void> _loadPlatformStats() async {
    try {
      final productDb = ProductDatabaseService();
      final userDb = DatabaseService();

      final allOrders = await productDb.getAllOrders();
      double revenue = 0;
      for (final order in allOrders) {
        final status = order['status'] as String?;
        if (status != null && status.contains('已付款') || status == '待发货' || status == '已发货' || status == '运输中' || status == '派送中' || status == '已签收' || status == '交易完成') {
          final cashAmount = (order['cash_amount'] as num?)?.toDouble() ?? 0;
          revenue += cashAmount;
        }
      }

      final allPaymentRecords = await productDb.getAllPaymentRecords();
      double paymentRevenue = 0;
      for (final record in allPaymentRecords) {
        if (record.status == 'success') {
          paymentRevenue += record.cashAmount;
        }
      }

      final totalUsersResult = await userDb.getAllUsers();

      if (mounted) {
        setState(() {
          _totalRevenue = paymentRevenue > 0 ? paymentRevenue : revenue;
          _totalOrders = allOrders.length;
          _totalUsers = totalUsersResult.length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('加载平台统计数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    final features = [
      {'icon': Icons.store, 'label': '商家管理', 'page': const MerchantManagementPage()},
      {'icon': Icons.verified, 'label': '商品审核', 'page': _buildProductReviewPage(theme)},
      {'icon': Icons.local_offer, 'label': '优惠券管理', 'page': const CouponManagementPage()},
      {'icon': Icons.card_giftcard, 'label': '红包管理', 'page': const RedPacketManagementPage()},
      {'icon': Icons.settings, 'label': '系统设置', 'page': const SettingsPage()},
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('平台管理'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsSection(theme),
              const SizedBox(height: 16),
              _buildAdminFeatures(features, theme, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductReviewPage(ThemeData theme) {
    return _ProductReviewPage(theme: theme);
  }

  Widget _buildStatsSection(ThemeData theme) {
    final stats = [
      {'label': '总交易额', 'value': '¥${_totalRevenue.toStringAsFixed(2)}', 'icon': Icons.account_balance_wallet, 'color': theme.colorScheme.primary},
      {'label': '总订单数', 'value': '$_totalOrders', 'icon': Icons.receipt_long, 'color': theme.colorScheme.secondary},
      {'label': '总用户数', 'value': '$_totalUsers', 'icon': Icons.people, 'color': theme.colorScheme.tertiary},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '平台概览',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoadingStats)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: stats.map((stat) {
              return Expanded(
                child: _buildStatCard(
                  icon: stat['icon'] as IconData,
                  label: stat['label'] as String,
                  value: stat['value'] as String,
                  color: stat['color'] as Color,
                  theme: theme,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFeatures(List<Map<String, dynamic>> features, ThemeData theme, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '管理功能',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return _buildFeatureItem(
                icon: feature['icon'] as IconData,
                label: feature['label'] as String,
                page: feature['page'] as Widget,
                theme: theme,
                context: context,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required Widget page,
    required ThemeData theme,
    required BuildContext context,
  }) {
    return Material(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductReviewPage extends ConsumerStatefulWidget {
  final ThemeData theme;

  const _ProductReviewPage({required this.theme});

  @override
  ConsumerState<_ProductReviewPage> createState() => _ProductReviewPageState();
}

class _ProductReviewPageState extends ConsumerState<_ProductReviewPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingProducts = [];
  List<Map<String, dynamic>> _approvedProducts = [];
  List<Map<String, dynamic>> _rejectedProducts = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productDb = ProductDatabaseService();
      final allProducts = await productDb.getAllProducts();

      _pendingProducts = [];
      _approvedProducts = [];
      _rejectedProducts = [];

      for (final product in allProducts) {
        final reviewStatus = product['review_status'] as String? ?? 'approved';
        switch (reviewStatus) {
          case 'pending':
            _pendingProducts.add(product);
            break;
          case 'rejected':
            _rejectedProducts.add(product);
            break;
          default:
            _approvedProducts.add(product);
        }
      }
    } catch (e) {
      debugPrint('加载商品审核数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProductReviewStatus(int productId, String status) async {
    try {
      final productDb = ProductDatabaseService();
      final db = await productDb.database;
      await db.update(
        'star_products',
        {'review_status': status, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? '商品已通过审核' : '商品已拒绝'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('商品审核', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(text: '待审核 (${_pendingProducts.length})'),
            Tab(text: '已通过 (${_approvedProducts.length})'),
            Tab(text: '已拒绝 (${_rejectedProducts.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(_pendingProducts, theme, isPending: true),
                _buildProductList(_approvedProducts, theme),
                _buildProductList(_rejectedProducts, theme),
              ],
            ),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> products, ThemeData theme, {bool isPending = false}) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无商品', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductItem(product, theme, isPending: isPending);
      },
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product, ThemeData theme, {bool isPending = false}) {
    final name = product['name'] as String? ?? '未知商品';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = product['stock'] as int? ?? 0;
    final productId = product['id'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_2, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('¥${price.toStringAsFixed(2)} | 库存: $stock', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            if (isPending) ...[
              IconButton(
                onPressed: () => _updateProductReviewStatus(productId!, 'approved'),
                icon: Icon(Icons.check_circle, color: Colors.green),
                tooltip: '通过',
              ),
              IconButton(
                onPressed: () => _updateProductReviewStatus(productId!, 'rejected'),
                icon: Icon(Icons.cancel, color: Colors.red),
                tooltip: '拒绝',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
