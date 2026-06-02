import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'product_detail_page.dart';

class MerchantDetailPage extends ConsumerStatefulWidget {
  const MerchantDetailPage({super.key, required this.merchant});

  final Merchant merchant;

  @override
  ConsumerState<MerchantDetailPage> createState() => _MerchantDetailPageState();
}

class _MerchantDetailPageState extends ConsumerState<MerchantDetailPage> {
  List<StarProduct> _merchantProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantProducts();
    });
  }

  Future<void> _loadMerchantProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = ProductDatabaseService();
      final merchantId = widget.merchant.id;
      if (merchantId == null) {
        _merchantProducts = [];
      } else {
        final productMaps = await databaseService.getProductsByMerchantId(merchantId);
        _merchantProducts = productMaps.map((map) => StarProduct.fromMap(map)).toList();
      }
    } catch (e) {
      debugPrint('加载商家商品失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '待审核';
      case 'active':
        return '营业中';
      case 'suspended':
        return '已暂停';
      case 'rejected':
        return '已拒绝';
      default:
        return '未知';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final merchant = widget.merchant;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: theme.colorScheme.background,
            foregroundColor: theme.colorScheme.onBackground,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildMerchantHeader(merchant, theme),
            ),
          ),
        ],
        body: _isLoading
            ? _buildLoadingState(theme)
            : _buildMerchantContent(merchant, theme),
      ),
    );
  }

  Widget _buildMerchantHeader(Merchant merchant, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  if (merchant.logo != null && merchant.logo!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image(
                        image: NetworkImage(merchant.logo!),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.store,
                        color: theme.colorScheme.primary,
                        size: 48,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    merchant.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(merchant.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(merchant.status),
                      style: TextStyle(
                        color: _getStatusColor(merchant.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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
            '加载中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantContent(Merchant merchant, ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMerchantStats(merchant, theme),
                const SizedBox(height: 20),
                if (merchant.description != null && merchant.description!.isNotEmpty) ...[
                  _buildSectionTitle('商家简介', theme),
                  const SizedBox(height: 8),
                  Text(
                    merchant.description!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildContactInfo(merchant, theme),
                const SizedBox(height: 20),
                _buildSectionTitle('店铺商品', theme),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _buildProductsGrid(theme),
      ],
    );
  }

  Widget _buildMerchantStats(Merchant merchant, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.star,
            '评分',
            merchant.rating.toStringAsFixed(1),
            theme,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          _buildStatItem(
            Icons.shopping_bag,
            '销量',
            merchant.totalSales.toString(),
            theme,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          _buildStatItem(
            Icons.access_time,
            '入驻',
            '${_calculateDaysSince(merchant.createdAt)}天',
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo(Merchant merchant, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('联系方式', theme),
          const SizedBox(height: 12),
          if (merchant.phone != null && merchant.phone!.isNotEmpty)
            _buildContactItem(Icons.phone, '电话', merchant.phone!, theme),
          if (merchant.email != null && merchant.email!.isNotEmpty)
            _buildContactItem(Icons.email, '邮箱', merchant.email!, theme),
          if (merchant.address != null && merchant.address!.isNotEmpty)
            _buildContactItem(Icons.location_on, '地址', merchant.address!, theme),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
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

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildProductsGrid(ThemeData theme) {
    if (_merchantProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  '该商家暂无商品',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildProductItem(_merchantProducts[index], theme);
          },
          childCount: _merchantProducts.length,
        ),
      ),
    );
  }

  Widget _buildProductItem(StarProduct product, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image(
                  image: NetworkImage(product.image),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (product.price > 0)
                          Text(
                            '¥${product.price}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (product.price > 0 && product.points > 0)
                          const SizedBox(width: 8),
                        if (product.points > 0)
                          Text(
                            '✨${product.points}',
                            style: const TextStyle(
                              color: Color(0xFFffc107),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateDaysSince(DateTime date) {
    final now = DateTime.now();
    return now.difference(date).inDays;
  }
}
