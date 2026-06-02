import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage> {
  final ProductDatabaseService _databaseService = ProductDatabaseService();
  
  List<StarProduct> _salesRanking = [];
  List<StarProduct> _viewsRanking = [];
  List<StarProduct> _newProducts = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRankings();
  }

  Future<void> _loadRankings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final salesResults = await _databaseService.getRankingProducts(
        sortBy: 'sales',
        limit: 20,
      );
      
      final viewsResults = await _databaseService.getRankingProducts(
        sortBy: 'visitors',
        limit: 20,
      );
      
      final newResults = await _databaseService.getNewProducts(limit: 20);

      setState(() {
        _salesRanking = salesResults.map((map) => StarProduct.fromMap(map)).toList();
        _viewsRanking = viewsResults.map((map) => StarProduct.fromMap(map)).toList();
        _newProducts = newResults.map((map) => StarProduct.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载榜单失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<StarProduct> get _currentList {
    switch (_selectedTabIndex) {
      case 0:
        return _salesRanking;
      case 1:
        return _viewsRanking;
      case 2:
        return _newProducts;
      default:
        return _salesRanking;
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
        title: Text(
          '商品榜单',
          style: TextStyle(color: theme.colorScheme.onBackground),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTabBar(theme),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : RefreshIndicator(
                    onRefresh: _loadRankings,
                    color: theme.colorScheme.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _currentList.length,
                      itemBuilder: (context, index) {
                        final product = _currentList[index];
                        return _buildRankingCard(product, index + 1, theme);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          _buildTabItem('销量榜', 0, Icons.trending_up, theme),
          _buildTabItem('人气榜', 1, Icons.visibility, theme),
          _buildTabItem('新品榜', 2, Icons.new_releases, theme),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index, IconData icon, ThemeData theme) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: isSelected
                  ? BorderSide(color: theme.colorScheme.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingCard(StarProduct product, int rank, ThemeData theme) {
    Color rankColor;
    Color badgeColor;
    IconData? medalIcon;
    
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      badgeColor = const Color(0xFFFFD700).withOpacity(0.1);
      medalIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      badgeColor = const Color(0xFFC0C0C0).withOpacity(0.1);
      medalIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      badgeColor = const Color(0xFFCD7F32).withOpacity(0.1);
      medalIcon = Icons.emoji_events;
    } else {
      rankColor = theme.colorScheme.onSurfaceVariant;
      badgeColor = theme.colorScheme.surfaceVariant;
    }

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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: rank <= 3
                ? rankColor.withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // 排名徽章
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: medalIcon != null
                  ? Icon(medalIcon, color: rankColor, size: 24)
                  : Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: rankColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            
            // 商品图片
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(
                image: ImageLoaderService.getImageProvider(product.image),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: theme.colorScheme.surfaceVariant,
                  child: Icon(Icons.image, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // 商品信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '¥${product.price}',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (product.points > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${product.points}积分',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        '已售 ${product.totalSales}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 箭头
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
