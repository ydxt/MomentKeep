import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';

class VirtualProductsPage extends ConsumerStatefulWidget {
  const VirtualProductsPage({super.key});

  @override
  ConsumerState<VirtualProductsPage> createState() => _VirtualProductsPageState();
}

class _VirtualProductsPageState extends ConsumerState<VirtualProductsPage> {
  List<StarProduct> _virtualProducts = [];
  bool _loading = true;
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final productService = ProductDatabaseService();
      final allProductsMap = await productService.getAllProducts();
      final allProducts = allProductsMap.map((map) => StarProduct.fromMap(map)).toList();
      final virtualProducts = allProducts.where((p) =>
        p.tags.any((tag) => tag.contains('虚拟') || tag.contains('无需物流') || tag.contains('卡密'))
      ).toList();

      setState(() {
        _virtualProducts = virtualProducts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<String> get _productTypes {
    final types = <String>{'all'};
    for (final product in _virtualProducts) {
      for (final tag in product.tags) {
        if (tag.contains('卡密') || tag.contains('会员') || tag.contains('充值')) {
          types.add(tag);
        }
      }
    }
    return types.toList();
  }

  List<StarProduct> get _filteredProducts {
    if (_selectedType == 'all') return _virtualProducts;
    return _virtualProducts.where((p) =>
      p.tags.any((tag) => tag == _selectedType)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('虚拟商品'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTypeFilter(theme),
                Expanded(child: _buildProductList(theme)),
              ],
            ),
    );
  }

  Widget _buildTypeFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTypeChip('全部', 'all', theme),
            ..._productTypes.where((t) => t != 'all').map((type) =>
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildTypeChip(type, type, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String type, ThemeData theme) {
    final isSelected = _selectedType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedType = type),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
    );
  }

  Widget _buildProductList(ThemeData theme) {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('暂无虚拟商品', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
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
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product, theme);
      },
    );
  }

  Widget _buildProductCard(StarProduct product, ThemeData theme) {
    String? badgeText;
    for (final tag in product.tags) {
      if (tag.contains('卡密')) {
        badgeText = '卡密';
        break;
      } else if (tag.contains('会员')) {
        badgeText = '会员';
        break;
      } else if (tag.contains('充值')) {
        badgeText = '充值';
        break;
      } else if (tag.contains('虚拟')) {
        badgeText = '虚拟';
        break;
      }
    }

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
            Stack(
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
                        child: Icon(Icons.image_not_supported, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ),
                if (badgeText != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '无需物流',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
                      if (product.points > 0)
                        Text(
                          '✨ ${product.points}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      if (product.price > 0)
                        Text(
                          ' ¥${(product.price / 100).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
