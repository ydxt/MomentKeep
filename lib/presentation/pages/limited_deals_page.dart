import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';

/// 限时优惠页面
/// 展示限时特价商品，包含倒计时和价格对比功能
class LimitedDealsPage extends ConsumerStatefulWidget {
  const LimitedDealsPage({super.key});

  @override
  ConsumerState<LimitedDealsPage> createState() => _LimitedDealsPageState();
}

class _LimitedDealsPageState extends ConsumerState<LimitedDealsPage> {
  /// 限时优惠商品列表
  List<StarProduct> _deals = [];
  
  /// 加载状态标识
  bool _loading = true;
  
  /// 倒计时定时器
  late Timer _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadDeals();
    // 每秒更新一次倒计时显示
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  /// 加载限时优惠商品列表
  /// 筛选标签包含"限时"或"优惠"的商品，并按结束时间排序
  Future<void> _loadDeals() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    try {
      final productService = ProductDatabaseService();
      final allProductsData = await productService.getAllProducts();
      final allProducts = allProductsData
          .map((map) => StarProduct.fromMap(map))
          .toList();
      
      // 筛选包含限时或优惠标签的商品
      final deals = allProducts.where((product) {
        return product.tags.any(
          (tag) => tag.contains('限时') || tag.contains('优惠'),
        );
      }).toList();
      
      // 按结束时间排序（使用预售结束时间作为限时结束时间）
      deals.sort((a, b) {
        final aEnd = a.preSaleEndTime ?? DateTime.now().add(const Duration(hours: 24));
        final bEnd = b.preSaleEndTime ?? DateTime.now().add(const Duration(hours: 24));
        return aEnd.compareTo(bEnd);
      });
      
      if (mounted) {
        setState(() {
          _deals = deals;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 格式化剩余时间为 HH:MM:SS 格式
  /// [duration] 剩余时间间隔
  /// 返回格式化的时间字符串，如果已过期则返回"已结束"
  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '已结束';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// 计算折扣百分比
  /// [originalPrice] 原价
  /// [currentPrice] 现价
  /// 返回折扣百分比文本，如"5折"
  String _getDiscountText(int originalPrice, int currentPrice) {
    if (originalPrice <= 0 || currentPrice <= 0) return '';
    final discount = (currentPrice / originalPrice * 10).round();
    return '${discount}折';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('限时优惠'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deals.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _deals.length,
                  itemBuilder: (context, index) {
                    final deal = _deals[index];
                    return _buildDealCard(deal, theme);
                  },
                ),
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无限时优惠',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建优惠商品卡片
  Widget _buildDealCard(StarProduct deal, ThemeData theme) {
    final now = DateTime.now();
    final endTime = deal.preSaleEndTime ?? now.add(const Duration(hours: 24));
    final remaining = endTime.difference(now);
    final isExpired = remaining.isNegative;
    
    return GestureDetector(
      onTap: isExpired ? null : () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: deal),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: isExpired 
                ? theme.colorScheme.outline.withOpacity(0.2)
                : theme.colorScheme.error.withOpacity(0.3),
            width: isExpired ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图片
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Image.network(
                  deal.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: Icon(
                      Icons.image_not_supported,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
            // 商品信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 商品名称
                    Text(
                      deal.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isExpired
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 倒计时标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? theme.colorScheme.onSurfaceVariant.withOpacity(0.1)
                            : theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: isExpired
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired 
                                ? '已结束'
                                : '剩余: ${_formatDuration(remaining)}',
                            style: TextStyle(
                              color: isExpired
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 价格区域
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 当前价格
                        Text(
                          '¥${(deal.price / 100).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isExpired
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.error,
                          ),
                        ),
                        // 折扣标签
                        if (deal.originalPrice > deal.price && deal.originalPrice > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              _getDiscountText(deal.originalPrice, deal.price),
                              style: TextStyle(
                                color: theme.colorScheme.onError,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // 原价（划线）
                        if (deal.originalPrice > deal.price && deal.originalPrice > 0)
                          Text(
                            '¥${(deal.originalPrice / 100).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
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
}
