import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';
import 'package:moment_keep/presentation/pages/star_exchange_page.dart';

class FavoriteProductsPage extends ConsumerStatefulWidget {
  const FavoriteProductsPage({super.key});

  @override
  ConsumerState<FavoriteProductsPage> createState() => _FavoriteProductsPageState();
}

class _FavoriteProductsPageState extends ConsumerState<FavoriteProductsPage> {
  List<Map<String, dynamic>> _favoriteItems = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavoriteProducts();
    });
  }

  Future<void> _loadFavoriteProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = DatabaseService();
      final userId = await databaseService.getCurrentUserId() ?? 'default_user';
      final productDb = ProductDatabaseService();
      final results = await productDb.getFavoriteProductsWithTime(userId);
      setState(() {
        _favoriteItems = results;
      });
    } catch (e) {
      debugPrint('加载收藏商品失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    if (_searchQuery.isEmpty) {
      return _favoriteItems;
    }
    return _favoriteItems.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      final code = (item['product_code'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  void _removeFromFavorites(Map<String, dynamic> item) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('确认取消收藏', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Text('确定要取消收藏"${item['name']}"吗？', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final databaseService = DatabaseService();
                  final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                  final productDb = ProductDatabaseService();
                  final productId = item['id'] as int;
                  await productDb.removeFavoriteProduct(userId, productId);
                  await _loadFavoriteProducts();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已取消收藏', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        backgroundColor: theme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('取消收藏失败: $e');
                }
              },
              child: Text('确定', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  String _formatFavoriteTime(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return '刚刚';
        return '${diff.inMinutes}分钟前';
      }
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final filteredProducts = _getFilteredProducts();

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
        title: Text('我的收藏', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState(theme)
          : RefreshIndicator(
              color: theme.colorScheme.primary,
              onRefresh: _loadFavoriteProducts,
              child: Column(
                children: [
                  _buildSearchBar(theme),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildProductGrid(filteredProducts, theme),
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
          hintText: '搜索收藏的商品...',
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildEmptyState(ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无收藏商品',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '快去逛逛吧',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StarExchangePage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  '去逛逛',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductItem(products[index], theme);
      },
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item, ThemeData theme) {
    final String name = item['name'] ?? '';
    final String image = item['image'] ?? '';
    final int price = item['price'] ?? 0;
    final int points = item['points'] ?? 0;
    final int? favoritedAt = item['favorited_at'] as int?;

    return GestureDetector(
      onTap: () async {
        try {
          final product = StarProduct.fromMap(item);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailPage(product: product),
              ),
            ).then((_) => _loadFavoriteProducts());
          }
        } catch (e) {
          debugPrint('跳转商品详情失败: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      width: double.infinity,
                      color: theme.colorScheme.surface,
                      child: image.isNotEmpty
                          ? Image(
                              image: ImageLoaderService.getImageProvider(image),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                                    size: 40,
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                                size: 40,
                              ),
                            ),
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
                          name,
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
                            if (price > 0)
                              Text(
                                '¥$price',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (price > 0 && points > 0)
                              const SizedBox(width: 8),
                            if (points > 0)
                              Text(
                                '✨$points',
                                style: const TextStyle(
                                  color: Color(0xFFffc107),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        if (favoritedAt != null)
                          Text(
                            _formatFavoriteTime(favoritedAt),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removeFromFavorites(item),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
