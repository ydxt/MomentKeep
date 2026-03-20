import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class FavoriteProductsPage extends ConsumerStatefulWidget {
  const FavoriteProductsPage({super.key});

  @override
  ConsumerState<FavoriteProductsPage> createState() => _FavoriteProductsPageState();
}

class _FavoriteProductsPageState extends ConsumerState<FavoriteProductsPage> {
  List<StarProduct> _favoriteProducts = [];
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
      await Future.delayed(const Duration(milliseconds: 500));
      
      _favoriteProducts = [
        StarProduct(
          id: 1,
          name: '精美茶具套装',
          description: '高品质陶瓷茶具，包含茶壶和4个茶杯',
          image: 'https://picsum.photos/seed/product1/400/400',
          mainImages: ['https://picsum.photos/seed/product1/400/400'],
          productCode: 'PROD001',
          points: 1000,
          costPrice: 50,
          stock: 45,
          categoryId: 1,
          isActive: true,
          isDeleted: false,
          status: 'active',
          price: 99,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
        ),
        StarProduct(
          id: 3,
          name: '手工笔记本',
          description: '精美手工笔记本，记录美好时光',
          image: 'https://picsum.photos/seed/product3/400/400',
          mainImages: ['https://picsum.photos/seed/product3/400/400'],
          productCode: 'PROD003',
          points: 200,
          costPrice: 15,
          stock: 25,
          categoryId: 2,
          isActive: true,
          isDeleted: false,
          status: 'active',
          price: 29,
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
          updatedAt: DateTime.now(),
        ),
        StarProduct(
          id: 4,
          name: '智能保温杯',
          description: '温度显示，智能提醒喝水',
          image: 'https://picsum.photos/seed/product4/400/400',
          mainImages: ['https://picsum.photos/seed/product4/400/400'],
          productCode: 'PROD004',
          points: 800,
          costPrice: 45,
          stock: 10,
          categoryId: 1,
          isActive: true,
          isDeleted: false,
          status: 'active',
          price: 79,
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
          updatedAt: DateTime.now(),
        ),
      ];
    } catch (e) {
      debugPrint('加载收藏商品失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<StarProduct> _getFilteredProducts() {
    if (_searchQuery.isEmpty) {
      return _favoriteProducts;
    }
    return _favoriteProducts.where((product) =>
      product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      product.productCode.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _removeFromFavorites(StarProduct product) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('确认取消收藏', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Text('确定要取消收藏"${product.name}"吗？', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _favoriteProducts.removeWhere((p) => p.id == product.id);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已取消收藏', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text('确定', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
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
      body: _isLoading ? _buildLoadingState(theme) : Column(
        children: [
          _buildSearchBar(theme),
          Expanded(
            child: filteredProducts.isEmpty
                ? _buildEmptyState(theme)
                : _buildProductGrid(filteredProducts, theme),
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
    return Center(
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
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<StarProduct> products, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductItem(products[index], theme);
      },
    );
  }

  Widget _buildProductItem(StarProduct product, ThemeData theme) {
    return Container(
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
                              style: TextStyle(
                                color: const Color(0xFFffc107),
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
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeFromFavorites(product),
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
    );
  }
}
