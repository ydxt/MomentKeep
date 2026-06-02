import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';

class BrowsingHistoryPage extends ConsumerStatefulWidget {
  final String? userId;

  const BrowsingHistoryPage({super.key, this.userId});

  @override
  ConsumerState<BrowsingHistoryPage> createState() => _BrowsingHistoryPageState();
}

class _BrowsingHistoryPageState extends ConsumerState<BrowsingHistoryPage> {
  List<BrowsingHistory> _historyItems = [];
  bool _isLoading = true;
  final ProductDatabaseService _productDb = ProductDatabaseService();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = DatabaseService();
      final userId = widget.userId ?? await databaseService.getCurrentUserId() ?? 'default_user';
      final results = await _productDb.getBrowsingHistoryByUserId(userId);
      setState(() {
        _historyItems = results.map((map) => BrowsingHistory.fromMap(map)).toList();
      });
    } catch (e) {
      debugPrint('Load browsing history failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearAllHistory() async {
    final theme = ref.watch(currentThemeProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('确认清空', style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Text('确定要清空所有浏览历史吗？此操作不可恢复。', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final databaseService = DatabaseService();
        final userId = widget.userId ?? await databaseService.getCurrentUserId() ?? 'default_user';
        await _productDb.clearBrowsingHistory(userId);
        if (mounted) {
          setState(() {
            _historyItems = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('已清空浏览历史'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        debugPrint('Clear browsing history failed: $e');
      }
    }
  }

  Future<void> _deleteHistoryItem(BrowsingHistory item) async {
    if (item.id == null) return;
    try {
      await _productDb.deleteBrowsingHistory(item.id!);
      if (mounted) {
        setState(() {
          _historyItems.removeWhere((h) => h.id == item.id);
        });
      }
    } catch (e) {
      debugPrint('Delete browsing history item failed: $e');
    }
  }

  Map<String, List<BrowsingHistory>> _groupByDate() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));

    final groups = <String, List<BrowsingHistory>>{
      '今天': [],
      '昨天': [],
      '本周': [],
      '更早': [],
    };

    for (final item in _historyItems) {
      if (item.visitedAt.isAfter(todayStart)) {
        groups['今天']!.add(item);
      } else if (item.visitedAt.isAfter(yesterdayStart)) {
        groups['昨天']!.add(item);
      } else if (item.visitedAt.isAfter(weekStart)) {
        groups['本周']!.add(item);
      } else {
        groups['更早']!.add(item);
      }
    }

    return groups;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: Text('浏览足迹', style: TextStyle(color: theme.colorScheme.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_historyItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurfaceVariant),
              onPressed: _clearAllHistory,
              tooltip: '清空历史',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _historyItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无浏览历史',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: theme.colorScheme.primary,
                  onRefresh: _loadHistory,
                  child: _buildHistoryList(theme),
                ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    final groups = _groupByDate();
    final activeGroups = groups.entries.where((e) => e.value.isNotEmpty).toList();

    if (activeGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无浏览历史',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: activeGroups.length,
      itemBuilder: (context, groupIndex) {
        final groupEntry = activeGroups[groupIndex];
        final groupName = groupEntry.key;
        final items = groupEntry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                groupName,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...items.map((item) => _buildHistoryItem(item, theme)),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItem(BrowsingHistory item, ThemeData theme) {
    return Dismissible(
      key: Key('history_${item.id}_${item.productId}_${item.visitedAt.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text('确认删除', style: TextStyle(color: theme.colorScheme.onSurface)),
              content: Text('确定要删除"${item.productName}"的浏览记录吗？', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) => _deleteHistoryItem(item),
      child: GestureDetector(
        onTap: () {
          final product = StarProduct(
            id: item.productId,
            name: item.productName,
            image: item.productImage,
            mainImages: [],
            productCode: '',
            points: item.productPoints,
            costPrice: 0,
            stock: 0,
            categoryId: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            price: item.productPrice,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(product: product),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: theme.colorScheme.surfaceVariant,
                  child: Image(
                    image: ImageLoaderService.getImageProvider(item.productImage),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.productPrice > 0) ...[
                          Text(
                            '¥${item.productPrice}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.productPoints > 0) ...[
                          Text(
                            '✨${item.productPoints}',
                            style: const TextStyle(
                              color: Color(0xFFffc107),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(item.visitedAt),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
