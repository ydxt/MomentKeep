import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

class ProductReview {
  final String id;
  final String productId;
  final String productName;
  final String userId;
  final String userName;
  final String? userAvatar;
  final int rating;
  final String content;
  final List<String>? images;
  final DateTime createdAt;
  final String status;
  final String? reply;
  final DateTime? replyAt;
  final int helpfulCount;

  ProductReview({
    required this.id,
    required this.productId,
    required this.productName,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.content,
    this.images,
    required this.createdAt,
    this.status = 'pending',
    this.reply,
    this.replyAt,
    this.helpfulCount = 0,
  });
}

class ProductReviewManagementPage extends ConsumerStatefulWidget {
  const ProductReviewManagementPage({super.key});

  @override
  ConsumerState<ProductReviewManagementPage> createState() => _ProductReviewManagementPageState();
}

class _ProductReviewManagementPageState extends ConsumerState<ProductReviewManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProductReview> _reviews = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      _reviews = [
        ProductReview(
          id: '1',
          productId: '1',
          productName: '精美茶具套装',
          userId: 'user1',
          userName: '张小明',
          userAvatar: 'https://picsum.photos/seed/user1/100/100',
          rating: 5,
          content: '这个茶具套装真的太棒了！做工精细，包装精美，非常满意的一次购物体验。茶壶的手感很好，茶杯的大小也合适。强烈推荐给喜欢喝茶的朋友们！',
          images: [
            'https://picsum.photos/seed/review1_1/400/400',
            'https://picsum.photos/seed/review1_2/400/400',
          ],
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          status: 'pending',
          helpfulCount: 12,
        ),
        ProductReview(
          id: '2',
          productId: '2',
          productName: '精品咖啡礼盒',
          userId: 'user2',
          userName: '李小红',
          rating: 4,
          content: '咖啡礼盒包装很精美，咖啡豆的品质也不错，就是价格稍微贵了一点。作为礼物送人还是很体面的。',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          status: 'approved',
          helpfulCount: 8,
        ),
        ProductReview(
          id: '3',
          productId: '3',
          productName: '手工笔记本',
          userId: 'user3',
          userName: '王大伟',
          rating: 3,
          content: '笔记本的做工还可以，但是纸的质量一般，不太适合用钢笔书写，会有点透墨。',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          status: 'rejected',
          helpfulCount: 3,
        ),
        ProductReview(
          id: '4',
          productId: '4',
          productName: '智能保温杯',
          userId: 'user4',
          userName: '赵芳芳',
          userAvatar: 'https://picsum.photos/seed/user4/100/100',
          rating: 5,
          content: '非常实用的保温杯！温度显示功能很准确，保温效果也很好，一整天水都还是热的。强烈推荐！',
          images: [
            'https://picsum.photos/seed/review4_1/400/400',
          ],
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
          status: 'approved',
          reply: '感谢您的好评！我们会继续努力提供更好的产品。',
          replyAt: DateTime.now().subtract(const Duration(days: 3)),
          helpfulCount: 25,
        ),
      ];
    } catch (e) {
      debugPrint('加载评价失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ProductReview> _getFilteredReviews(String status) {
    var reviews = _reviews;
    
    if (status != 'all') {
      reviews = reviews.where((r) => r.status == status).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      reviews = reviews.where((r) =>
        r.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.content.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return reviews;
  }

  void _approveReview(ProductReview review) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('审核通过', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Text('确定要通过这条评价吗？', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final index = _reviews.indexWhere((r) => r.id == review.id);
                  if (index != -1) {
                    _reviews[index] = ProductReview(
                      id: review.id,
                      productId: review.productId,
                      productName: review.productName,
                      userId: review.userId,
                      userName: review.userName,
                      userAvatar: review.userAvatar,
                      rating: review.rating,
                      content: review.content,
                      images: review.images,
                      createdAt: review.createdAt,
                      status: 'approved',
                      reply: review.reply,
                      replyAt: review.replyAt,
                      helpfulCount: review.helpfulCount,
                    );
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('评价已通过', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
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
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final index = _reviews.indexWhere((r) => r.id == review.id);
                  if (index != -1) {
                    _reviews[index] = ProductReview(
                      id: review.id,
                      productId: review.productId,
                      productName: review.productName,
                      userId: review.userId,
                      userName: review.userName,
                      userAvatar: review.userAvatar,
                      rating: review.rating,
                      content: review.content,
                      images: review.images,
                      createdAt: review.createdAt,
                      status: 'rejected',
                      reply: review.reply,
                      replyAt: review.replyAt,
                      helpfulCount: review.helpfulCount,
                    );
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('评价已驳回', style: TextStyle(color: theme.colorScheme.onPrimary)),
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

  void _replyToReview(ProductReview review) {
    final controller = TextEditingController(text: review.reply ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final index = _reviews.indexWhere((r) => r.id == review.id);
                  if (index != -1) {
                    _reviews[index] = ProductReview(
                      id: review.id,
                      productId: review.productId,
                      productName: review.productName,
                      userId: review.userId,
                      userName: review.userName,
                      userAvatar: review.userAvatar,
                      rating: review.rating,
                      content: review.content,
                      images: review.images,
                      createdAt: review.createdAt,
                      status: review.status,
                      reply: controller.text,
                      replyAt: DateTime.now(),
                      helpfulCount: review.helpfulCount,
                    );
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('回复已保存', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
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
      body: _isLoading ? _buildLoadingState(theme) : Column(
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        return _buildReviewItem(reviews[index], theme);
      },
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
                if (review.userAvatar != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image(
                      image: NetworkImage(review.userAvatar!),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: theme.colorScheme.primary),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
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
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image(
                          image: NetworkImage(review.images![index]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.thumb_up, color: theme.colorScheme.onSurfaceVariant, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${review.helpfulCount}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatTime(review.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (review.reply != null && review.reply!.isNotEmpty) ...[
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
                      review.reply!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (review.replyAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(review.replyAt!),
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
                      label: Text(review.reply != null && review.reply!.isNotEmpty ? '编辑回复' : '回复'),
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

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '待审核';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已驳回';
      default:
        return '未知';
    }
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
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
