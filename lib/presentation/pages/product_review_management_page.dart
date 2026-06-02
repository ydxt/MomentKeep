import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';

class ProductReviewManagementPage extends ConsumerStatefulWidget {
  const ProductReviewManagementPage({super.key});

  @override
  ConsumerState<ProductReviewManagementPage> createState() => _ProductReviewManagementPageState();
}

class _ProductReviewManagementPageState extends ConsumerState<ProductReviewManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProductReview> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final ProductDatabaseService _dbService = ProductDatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reviewsData = await _dbService.getAllReviews();
      final reviews = reviewsData.map((map) => ProductReview.fromMap(map)).toList();
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载评价失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载评价失败，请重试';
      });
    }
  }

  List<ProductReview> _getFilteredReviews(String status) {
    var reviews = _reviews;

    if (status != 'all') {
      reviews = reviews.where((r) => r.status == status).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      reviews = reviews.where((r) =>
        (r.userName?.toLowerCase().contains(query) ?? false) ||
        r.productName.toLowerCase().contains(query) ||
        r.content.toLowerCase().contains(query)
      ).toList();
    }

    return reviews;
  }

  Future<void> _approveReview(ProductReview review) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('审核通过', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Text('确定要通过这条评价吗？', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _dbService.updateReviewStatus(review.id, 'approved');
                  await _loadReviews();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('评价已通过', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        backgroundColor: theme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('审核通过失败: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('操作失败: $e', style: TextStyle(color: theme.colorScheme.onError)),
                        backgroundColor: theme.colorScheme.error,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: Text('确定', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _rejectReview(ProductReview review) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('驳回评价', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '驳回原因',
              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _dbService.updateReviewStatus(review.id, 'rejected');
                  await _loadReviews();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('评价已驳回', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        backgroundColor: theme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('驳回失败: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('操作失败: $e', style: TextStyle(color: theme.colorScheme.onError)),
                        backgroundColor: theme.colorScheme.error,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: Text('确定', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  void _replyToReview(ProductReview review) {
    final controller = TextEditingController(text: review.sellerReply ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('回复评价', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '回复内容',
              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _dbService.updateReviewReply(review.id, controller.text);
                  await _loadReviews();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('回复已保存', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        backgroundColor: theme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('回复保存失败: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('操作失败: $e', style: TextStyle(color: theme.colorScheme.onError)),
                        backgroundColor: theme.colorScheme.error,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: Text('保存', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
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
        title: Text('评价管理', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '待审核'),
            Tab(text: '已通过'),
            Tab(text: '已驳回'),
          ],
        ),
      ),
      body: _isLoading ? _buildLoadingState(theme) : _errorMessage != null ? _buildErrorState(theme) : Column(
        children: [
          _buildSearchBar(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReviewList('all', theme),
                _buildReviewList('pending', theme),
                _buildReviewList('approved', theme),
                _buildReviewList('rejected', theme),
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

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '加载失败',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadReviews,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('重试'),
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
          hintText: '搜索用户、商品或评价内容...',
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

  Widget _buildReviewList(String status, ThemeData theme) {
    final reviews = _getFilteredReviews(status);

    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无评价',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          return _buildReviewItem(reviews[index], theme);
        },
      ),
    );
  }

  Widget _buildReviewItem(ProductReview review, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (review.userAvatar != null && review.userAvatar!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image(
                      image: NetworkImage(review.userAvatar!),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(theme),
                    ),
                  )
                else
                  _buildDefaultAvatar(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.isAnonymous ? '匿名用户' : (review.userName ?? '未知用户'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        review.productName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(review.status, theme).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(review.status),
                    style: TextStyle(
                      color: _getStatusColor(review.status, theme),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < review.rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFffc107),
                  size: 18,
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              review.content,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (review.images != null && review.images!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images!.length,
                  itemBuilder: (context, index) {
                    final imagePath = review.images![index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildReviewImage(imagePath, theme),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatTime(review.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (review.sellerReply != null && review.sellerReply!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '商家回复',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.sellerReply!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (review.sellerReplyAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(review.sellerReplyAt!),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (review.status == 'pending') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectReview(review),
                      icon: const Icon(Icons.close),
                      label: const Text('驳回'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveReview(review),
                      icon: const Icon(Icons.check),
                      label: const Text('通过'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
                if (review.status == 'approved')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _replyToReview(review),
                      icon: const Icon(Icons.reply),
                      label: Text(review.sellerReply != null && review.sellerReply!.isNotEmpty ? '编辑回复' : '回复'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, color: theme.colorScheme.primary),
    );
  }

  Widget _buildReviewImage(String imagePath, ThemeData theme) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image(
        image: NetworkImage(imagePath),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 80,
          height: 80,
          color: theme.colorScheme.surfaceVariant,
          child: Icon(Icons.broken_image, color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Image.asset(
      imagePath,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 80,
        height: 80,
        color: theme.colorScheme.surfaceVariant,
        child: Icon(Icons.broken_image, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '待审核';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已驳回';
      case 'completed':
        return '已完成';
      default:
        return '未知';
    }
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return theme.colorScheme.error;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}-${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
