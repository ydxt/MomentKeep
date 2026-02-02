import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'review_edit_page.dart';

/// 评价状态枚举
enum ReviewStatus {
  pending, // 待评价
  completed, // 已评价
  appended, // 已追加评价
}

/// 评价模型
class Review {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final String productImage;
  final String variant;
  final int rating;
  final String content;
  final List<String>? images;
  final DateTime createdAt;
  final DateTime? appendedAt;
  final String? appendedContent;
  final List<String>? appendedImages;
  final String? sellerReply;
  final DateTime? sellerReplyAt;
  final ReviewStatus status;
  final bool isAnonymous;
  final String? userId;
  final String? userName;
  final String? userAvatar;

  Review({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.variant,
    required this.rating,
    required this.content,
    this.images,
    required this.createdAt,
    this.appendedAt,
    this.appendedContent,
    this.appendedImages,
    this.sellerReply,
    this.sellerReplyAt,
    required this.status,
    this.isAnonymous = true,
    this.userId,
    this.userName,
    this.userAvatar,
  });
}

/// 评价页面
class ReviewPage extends ConsumerStatefulWidget {
  /// 评价页面构造函数
  const ReviewPage({
    super.key,
    this.orderId,
    this.isWriting = false,
  });

  /// 订单ID（可选，用于查看特定订单的评价）
  final String? orderId;
  
  /// 是否处于写评价模式
  final bool isWriting;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  ReviewStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  /// 加载评价数据
  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 从数据库加载评价数据
      final productDatabaseService = ProductDatabaseService();
      List<Map<String, dynamic>> reviewsData;
      
      if (widget.orderId != null) {
        // 获取特定订单的评价
        reviewsData = await productDatabaseService.getReviewsByOrderId(widget.orderId!);
      } else {
        // 获取所有评价
        reviewsData = await productDatabaseService.getAllReviews();
        

      }
      
      // 转换为Review对象
      final userDatabaseService = UserDatabaseService();
      final reviews = <Review>[];
      
      for (var data in reviewsData) {
        // 处理productId类型转换
        final dynamic productIdValue = data['product_id'];
        final String productId = productIdValue.toString();
        
        // 处理images字段，从JSON字符串解析为List<String>
        List<String>? images = [];
        final dynamic imagesValue = data['images'];
        if (imagesValue != null) {
          if (imagesValue is List<dynamic>) {
            images = imagesValue.cast<String>();
          } else if (imagesValue is String && imagesValue.isNotEmpty && imagesValue != '[]') {
            try {
              images = List<String>.from(json.decode(imagesValue));
            } catch (e) {
              debugPrint('Failed to parse images: $e');
              images = [];
            }
          }
        }
        
        // 处理appendedImages字段，从JSON字符串解析为List<String>
        List<String>? appendedImages = [];
        final dynamic appendedImagesValue = data['appended_images'];
        if (appendedImagesValue != null) {
          if (appendedImagesValue is List<dynamic>) {
            appendedImages = appendedImagesValue.cast<String>();
          } else if (appendedImagesValue is String && appendedImagesValue.isNotEmpty && appendedImagesValue != '[]') {
            try {
              appendedImages = List<String>.from(json.decode(appendedImagesValue));
            } catch (e) {
              debugPrint('Failed to parse appendedImages: $e');
              appendedImages = [];
            }
          }
        }
        
        // 获取用户信息
        final bool isAnonymous = (data['is_anonymous'] ?? 1) == 1;
        String? userId = data['user_id'] as String?;
        String? userName = data['user_name'] as String?;
        String? userAvatar = data['user_avatar'] as String?;
        
        // 如果不是匿名评论，获取最新的用户信息
        if (!isAnonymous && userId != null) {
          final userData = await userDatabaseService.getUserById(userId);
          if (userData != null) {
            // 使用正确的字段名：nickname，而不是user_name
            userName = userData['nickname'] as String? ?? userData['user_name'] as String?;
            userAvatar = userData['avatar'] as String?;
          }
        }
        
        reviews.add(Review(
          id: data['id'] as String,
          orderId: data['order_id'] as String,
          productId: productId,
          productName: data['product_name'] as String,
          productImage: data['product_image'] as String,
          variant: data['variant'] as String? ?? '',
          rating: data['rating'] as int,
          content: data['content'] as String,
          images: images,
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int),
          appendedAt: data['appended_at'] != null ? DateTime.fromMillisecondsSinceEpoch(data['appended_at'] as int) : null,
          appendedContent: data['appended_content'] as String?,
          appendedImages: appendedImages,
          sellerReply: data['seller_reply'] as String?,
          sellerReplyAt: data['seller_reply_at'] != null ? DateTime.fromMillisecondsSinceEpoch(data['seller_reply_at'] as int) : null,
          status: data['status'] == 'pending' ? ReviewStatus.pending : 
                 data['status'] == 'completed' ? ReviewStatus.completed : 
                 ReviewStatus.appended,
          isAnonymous: isAnonymous,
          userId: userId,
          userName: userName,
          userAvatar: userAvatar,
        ));
      }
      
      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 获取评价状态文本
  String _getReviewStatusText(ReviewStatus status) {
    switch (status) {
      case ReviewStatus.pending:
        return '待评价';
      case ReviewStatus.completed:
        return '已评价';
      case ReviewStatus.appended:
        return '已追加评价';
    }
  }

  /// 构建星级评分
  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: const Color(0xFFffc107),
          size: 16,
        );
      }),
    );
  }

  /// 构建评价筛选栏
  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '筛选',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  theme: theme,
                  label: '全部状态',
                  isActive: _selectedStatus == null,
                  onTap: () {
                    setState(() {
                      _selectedStatus = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  theme: theme,
                  label: '待评价',
                  isActive: _selectedStatus == ReviewStatus.pending,
                  onTap: () {
                    setState(() {
                      _selectedStatus = ReviewStatus.pending;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  theme: theme,
                  label: '已评价',
                  isActive: _selectedStatus == ReviewStatus.completed || _selectedStatus == ReviewStatus.appended,
                  onTap: () {
                    setState(() {
                      // 合并已评价和已追加评价
                      _selectedStatus = ReviewStatus.completed;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建筛选标签
  Widget _buildFilterChip({
    required ThemeData theme,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.surface : theme.colorScheme.surfaceVariant,
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建评价列表
  Widget _buildReviewsList(ThemeData theme) {
    // 筛选评价
    final filteredReviews = _reviews.where((review) {
      if (widget.orderId != null && review.orderId != widget.orderId) {
        return false;
      }
      if (_selectedStatus != null) {
        if (_selectedStatus == ReviewStatus.completed) {
          // 显示已评价和已追加评价
          return review.status == ReviewStatus.completed || review.status == ReviewStatus.appended;
        } else {
          return review.status == _selectedStatus;
        }
      }
      return true;
    }).toList();

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    if (filteredReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无评价',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            if (widget.isWriting)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () {
                    _writeReview();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('立即评价'),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReviews.length,
      itemBuilder: (context, index) {
        final review = filteredReviews[index];
        return _buildReviewItem(review, theme);
      },
    );
  }

  /// 构建评价项
  Widget _buildReviewItem(Review review, ThemeData theme) {
    // 根据匿名状态获取用户信息
    final String userNickname = review.isAnonymous ? '匿名用户' : review.userName ?? '用户';
    final String userAvatar = review.isAnonymous ? 'https://via.placeholder.com/150' : (review.userAvatar ?? 'https://via.placeholder.com/150');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品信息
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: theme.colorScheme.surface,
                ),
                child: CachedNetworkImage(
                  imageUrl: review.productImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 1.5),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.productName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      review.variant,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildRatingStars(review.rating),
                    const SizedBox(height: 3),
                    // 用户信息
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surface,
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: userAvatar,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Icon(
                                Icons.person,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 14,
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.person,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          userNickname,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _getReviewStatusText(review.status),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 评价内容
          Padding(
            padding: const EdgeInsets.only(left: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.content,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                
                // 评价图片缩略图
                if (review.images != null && review.images!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GridView.count(
                      crossAxisCount: 8, // 增加列数，进一步减小图像大小
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.0, // 确保图像为正方形
                      children: review.images!.map((imageUrl) {
                        return GestureDetector(
                          onTap: () {
                            // 点击图片放大查看
                            _showImageViewer(context, imageUrl, 0, review.images!);
                          },
                          child: Container(
                            width: 40, // 设置更小的固定宽度
                            height: 40, // 设置更小的固定高度
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: theme.colorScheme.surface,
                              image: DecorationImage(
                                image: imageUrl.startsWith('http') ? CachedNetworkImageProvider(imageUrl) as ImageProvider<Object> : FileImage(File(imageUrl)) as ImageProvider<Object>,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                const SizedBox(height: 6),
                Text(
                  _formatDate(review.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                // 追加评价
                if (review.appendedContent != null && review.appendedContent!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '追加评价:',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          review.appendedContent!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                        
                        // 追加评价图片
                        if (review.appendedImages != null && review.appendedImages!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: GridView.count(
                              crossAxisCount: 8, // 增加列数，进一步减小图像大小
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.0, // 确保图像为正方形
                              children: review.appendedImages!.map((imageUrl) {
                                return GestureDetector(
                                  onTap: () {
                                    // 点击图片放大查看
                                    _showImageViewer(context, imageUrl, 0, review.appendedImages!);
                                  },
                                  child: Container(
                                    width: 40, // 设置更小的固定宽度
                                    height: 40, // 设置更小的固定高度
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: theme.colorScheme.surface,
                                      image: DecorationImage(
                                        image: imageUrl.startsWith('http') ? CachedNetworkImageProvider(imageUrl) as ImageProvider<Object> : FileImage(File(imageUrl)) as ImageProvider<Object>,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          
                        const SizedBox(height: 3),
                        Text(
                          '追加时间: ${_formatDate(review.appendedAt!)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                // 商家回复
                if (review.sellerReply != null && review.sellerReply!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '商家回复:',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            review.sellerReply!,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '回复时间: ${_formatDate(review.sellerReplyAt!)}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 操作按钮
                if (review.status == ReviewStatus.completed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _appendReview(review);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Text('追加评价'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 显示图片查看器
  void _showImageViewer(BuildContext context, String initialImageUrl, int initialIndex, List<String> images) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: initialImageUrl.startsWith('http') ? CachedNetworkImageProvider(initialImageUrl) as ImageProvider<Object> : FileImage(File(initialImageUrl)) as ImageProvider<Object>,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13ec5b),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '关闭',
                    style: TextStyle(
                      color: const Color(0xFF112217),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 撰写评价
  void _writeReview() {
    // 跳转到评价编辑页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewEditPage(
          orderId: widget.orderId ?? '',
          productId: '',
          productName: '',
          productImage: '',
        ),
      ),
    );
  }

  /// 追加评价
  void _appendReview(Review review) {
    // 跳转到追加评价编辑页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewEditPage(
          orderId: review.orderId,
          productId: review.productId,
          productName: review.productName,
          productImage: review.productImage,
          isAppend: true,
          originalReviewId: review.id,
        ),
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.isWriting ? '写评价' : widget.orderId != null ? '订单评价' : '我的评价',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.orderId == null && !widget.isWriting)
            IconButton(
              icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
              onPressed: () {
                // 跳转到待评价订单页面
                debugPrint('写评价');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.orderId == null && !widget.isWriting)
            _buildFilterBar(theme),
          Expanded(
            child: _buildReviewsList(theme),
          ),
        ],
      ),
    );
  }
}
