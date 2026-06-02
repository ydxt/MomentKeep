import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';

/// 积分兑换页面
class PointsExchangePage extends ConsumerStatefulWidget {
  /// 用户ID,可选,为空时自动获取
  final String? userId;
  
  const PointsExchangePage({super.key, this.userId});

  @override
  ConsumerState<PointsExchangePage> createState() => _PointsExchangePageState();
}

class _PointsExchangePageState extends ConsumerState<PointsExchangePage> {
  /// 用户可用积分
  int _userPoints = 0;
  
  /// 可兑换商品列表
  List<StarProduct> _pointsProducts = [];
  
  /// 加载状态
  bool _loading = true;
  
  /// 积分筛选上限
  int _maxPointsFilter = 99999;

  /// 数据库服务
  final DatabaseService _databaseService = DatabaseService();
  final ProductDatabaseService _productService = ProductDatabaseService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载用户积分和商品数据
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final userId = widget.userId ?? await _databaseService.getCurrentUserId() ?? 'default_user';
      
      // 获取用户积分
      final pointsResult = await _databaseService.getUserPoints(userId);
      
      // 获取商品列表
      final allProductsMap = await _productService.getAllProducts();
      final allProducts = allProductsMap.map((map) => StarProduct.fromMap(map)).toList();
      
      setState(() {
        _userPoints = pointsResult.round();
        _pointsProducts = allProducts
            .where((p) => p.points > 0 && p.isDeleted == false)
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  /// 获取经过积分筛选后的商品列表
  List<StarProduct> get _filteredProducts {
    return _pointsProducts
        .where((p) => p.points <= _maxPointsFilter)
        .toList()
      ..sort((a, b) => a.points.compareTo(b.points));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('积分兑换'),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          TextButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => _buildFilterSheet(theme),
              );
            },
            icon: const Icon(Icons.filter_list),
            label: const Text('筛选'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPointsHeader(theme),
                Expanded(child: _buildProductList(theme)),
              ],
            ),
    );
  }

  /// 构建积分头部显示
  Widget _buildPointsHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '可用积分',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                '✨ $_userPoints',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建商品列表
  Widget _buildProductList(ThemeData theme) {
    final products = _filteredProducts;
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无可兑换商品',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product, theme);
      },
    );
  }

  /// 构建商品卡片
  Widget _buildProductCard(StarProduct product, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProductDetailPage(product: product)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Image(
                  image: ImageLoaderService.getImageProvider(product.image),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '✨ ${product.points}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (product.price > 0)
                        Text(
                          '¥${product.price}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (product.stock > 0)
                    Text(
                      '库存:${product.stock}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      '已售罄',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.error,
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

  /// 构建筛选面板
  Widget _buildFilterSheet(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '积分范围筛选',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('100积分以内'),
            onTap: () {
              setState(() => _maxPointsFilter = 100);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('500积分以内'),
            onTap: () {
              setState(() => _maxPointsFilter = 500);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('1000积分以内'),
            onTap: () {
              setState(() => _maxPointsFilter = 1000);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('全部'),
            onTap: () {
              setState(() => _maxPointsFilter = 99999);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
