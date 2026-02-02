import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'review_page.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/services/cart_database_service.dart';
import 'shopping_cart_page.dart';
import 'shopping_card_page.dart';
import 'coupons_detail_page.dart';
import 'package:moment_keep/presentation/components/payment_dialog.dart';

class PreviousIntent extends Intent {
  const PreviousIntent();
}

class NextIntent extends Intent {
  const NextIntent();
}

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.product});
  
  final StarProduct product;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

// 支付方式枚举
enum PaymentMethod {
  cash, // 现金
  points, // 积分
  hybrid, // 混合
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  int _currentImageIndex = 0;
  late PageController _pageController;
  bool _isImagePreviewVisible = false;
  int _previewImageIndex = 0;
  Timer? _autoPlayTimer;
  static const autoPlayInterval = 3000;
  bool _isAutoPlayEnabled = false;
  Map<String, VideoPlayerController> _videoControllers = {};
  String? _currentPlayingVideoUrl;
  bool _isVideoMuted = true;
  bool _showVideoControls = true;
  double _startDragPosition = 0;
  int _startDragIndex = 0;
  double _initialOffset = 0;
  List<Map<String, dynamic>> _reviews = [];
  bool _isReviewsLoading = false;
  // 数量选择
  int _selectedQuantity = 1;
  
  // 规格选择
  Map<String, String> _selectedSpecs = {}; // 存储选中的规格，如 {'颜色': '红色', '尺寸': 'L'}
  StarProductSku? _selectedSku; // 选中的SKU

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
      // 当切换到评价标签页时加载评价数据
      if (_tabController.index == 1) {
        _loadReviews();
      }
    });
    
    _pageController = PageController(viewportFraction: 1.0);
    
    if (_isAutoPlayEnabled) {
      _startAutoPlay();
    }
  }
  
  /// 加载商品评价
  Future<void> _loadReviews() async {
    if (_reviews.isNotEmpty) {
      return; // 已经加载过，不需要重复加载
    }
    
    setState(() {
      _isReviewsLoading = true;
    });
    
    try {
      final productId = widget.product.id;
      if (productId == null) {
        debugPrint('商品ID为空，无法加载评价');
        return;
      }
      
      final databaseService = ProductDatabaseService();
      final reviewsResults = await databaseService.getReviewsByProductId(productId);
      
      // 获取最新的用户信息
      final userDatabaseService = UserDatabaseService();
      final reviews = <Map<String, dynamic>>[];
      
      for (var reviewData in reviewsResults) {
        final bool isAnonymous = (reviewData['is_anonymous'] ?? 1) == 1;
        String? userId = reviewData['user_id'] as String?;
        String? userName = reviewData['user_name'] as String?;
        String? userAvatar = reviewData['user_avatar'] as String?;
        
        // 如果不是匿名评论，获取最新的用户信息
        if (!isAnonymous && userId != null) {
          final userData = await userDatabaseService.getUserById(userId);
          if (userData != null) {
            // 使用正确的字段名：nickname，而不是user_name
            userName = userData['nickname'] as String? ?? userData['user_name'] as String?;
            userAvatar = userData['avatar'] as String?;
          }
        }
        
        // 创建包含最新用户信息的评论数据
        final review = Map<String, dynamic>.from(reviewData);
        review['user_name'] = userName;
        review['user_avatar'] = userAvatar;
        reviews.add(review);
      }
      
      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      debugPrint('加载评价失败: $e');
    } finally {
      setState(() {
        _isReviewsLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    _disposeAllVideoControllers();
    super.dispose();
  }
  
  void _disposeAllVideoControllers() {
    _videoControllers.forEach((url, controller) {
      controller.dispose();
    });
    _videoControllers.clear();
  }
  
  Future<void> _initializeVideoController(String url) async {
    if (_videoControllers.containsKey(url)) {
      final controller = _videoControllers[url]!;
      if (controller.value.isInitialized) {
        return;
      }
    }
    
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoControllers[url] = controller;
    try {
      await controller.initialize();
      controller.setVolume(_isVideoMuted ? 0 : 1);
    } catch (e) {
      _videoControllers.remove(url);
    }
  }
  
  void _toggleVideoPlayPause(String url) {
    final controller = _videoControllers[url];
    if (controller != null) {
      if (controller.value.isPlaying) {
        controller.pause();
        setState(() {});
      } else {
        controller.play();
        setState(() {});
      }
    }
  }
  
  void _toggleVideoMute() {
    setState(() {
      _isVideoMuted = !_isVideoMuted;
      _videoControllers.forEach((url, controller) {
        controller.setVolume(_isVideoMuted ? 0 : 1);
      });
    });
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  void _handlePageChanged(int index) {
    final List<Map<String, dynamic>> mediaItems = [];
    mediaItems.add({'type': 'image', 'url': widget.product.image});
    for (var imageUrl in widget.product.mainImages) {
      if (imageUrl.isNotEmpty) {
        mediaItems.add({'type': 'image', 'url': imageUrl});
      }
    }
    if (widget.product.video != null && widget.product.video!.isNotEmpty) {
      mediaItems.add({
        'type': 'video', 
        'url': widget.product.video!,
        'cover': widget.product.videoCover
      });
    }
    
    if (mediaItems.isNotEmpty && index < mediaItems.length) {
      final currentMediaItem = mediaItems[index];
      
      // Pause previous video if any
      if (_currentPlayingVideoUrl != null) {
        final previousController = _videoControllers[_currentPlayingVideoUrl!];
        if (previousController != null) {
          previousController.pause();
        }
      }
      
      // If current item is video, play it muted
      if (currentMediaItem['type'] == 'video') {
        final videoUrl = currentMediaItem['url'];
        _initializeVideoController(videoUrl).then((_) {
          final controller = _videoControllers[videoUrl];
          if (controller != null) {
            setState(() {
              _currentPlayingVideoUrl = videoUrl;
            });
            controller.setVolume(_isVideoMuted ? 0 : 1);
            controller.play();
          }
        });
      } else {
        setState(() {
          _currentPlayingVideoUrl = null;
        });
      }
    }
  }
  
  Widget _buildVideoControls(VideoPlayerController controller, ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // 直接控制视频播放状态
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            },
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            iconSize: 24,
          ),
          Text(
            _formatDuration(controller.value.position),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: theme.colorScheme.primary,
                bufferedColor: theme.colorScheme.primary.withOpacity(0.3),
                backgroundColor: theme.colorScheme.outline.withOpacity(0.1),
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(controller.value.duration),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isVideoMuted = !_isVideoMuted;
                controller.setVolume(_isVideoMuted ? 0 : 1);
              });
            },
            icon: Icon(
              _isVideoMuted ? Icons.volume_off : Icons.volume_up,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            iconSize: 24,
          ),
        ],
      ),
    );
  }
  
  void _startAutoPlay() {
    if (_autoPlayTimer == null) {
      _autoPlayTimer = Timer.periodic(
        Duration(milliseconds: autoPlayInterval),
        (timer) {
          final List<Map<String, dynamic>> mediaItems = [];
          mediaItems.add({'type': 'image', 'url': widget.product.image});
          for (var imageUrl in widget.product.mainImages) {
            if (imageUrl.isNotEmpty) {
              mediaItems.add({'type': 'image', 'url': imageUrl});
            }
          }
          if (widget.product.video != null && widget.product.video!.isNotEmpty) {
            mediaItems.add({
              'type': 'video', 
              'url': widget.product.video!,
              'cover': widget.product.videoCover
            });
          }
          
          setState(() {
            _currentImageIndex = (_currentImageIndex + 1) % mediaItems.length;
            _pageController.animateToPage(
              _currentImageIndex,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        },
      );
    }
  }
  
  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }
  
  void _resetAutoPlay() {
    _stopAutoPlay();
    if (_isAutoPlayEnabled) {
      _startAutoPlay();
    }
  }
  
  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlayEnabled = !_isAutoPlayEnabled;
      if (_isAutoPlayEnabled) {
        _startAutoPlay();
      } else {
        _stopAutoPlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = ref.watch(currentThemeProvider);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PreviousIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextIntent(),
        },
        child: Actions(
          actions: {
            PreviousIntent: CallbackAction<PreviousIntent>(onInvoke: (intent) => _goToPreviousPage()),
            NextIntent: CallbackAction<NextIntent>(onInvoke: (intent) => _goToNextPage()),
          },
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroImageCarousel(product, theme),
                          _buildProductInfo(product, theme),
                          _buildSpecSelector(product, theme),
                          _buildPaymentMethodSelector(product, theme),
                          _buildGuaranteeServices(theme),
                          Container(height: 8, color: theme.colorScheme.outline.withOpacity(0.1)),
                          _buildTabNavigation(product, theme),
                          _buildTabContent(product, theme),
                        ],
                      ),
                    ),
                    
                    _buildTopNavigation(theme),
                    _buildBottomActionBar(theme),
                    
                    if (_isImagePreviewVisible) 
                      _buildImagePreview(product, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _goToPreviousPage() {
    if (_currentImageIndex > 0) {
      _pageController.animateToPage(
        _currentImageIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _goToNextPage() {
    final List<Map<String, dynamic>> mediaItems = [];
    mediaItems.add({'type': 'image', 'url': widget.product.image});
    for (var imageUrl in widget.product.mainImages) {
      if (imageUrl.isNotEmpty) {
        mediaItems.add({'type': 'image', 'url': imageUrl});
      }
    }
    if (widget.product.video != null && widget.product.video!.isNotEmpty) {
      mediaItems.add({'type': 'video', 'url': widget.product.video!});
    }
    
    if (_currentImageIndex < mediaItems.length - 1) {
      _pageController.animateToPage(
        _currentImageIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Widget _buildTopNavigation(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildIconButton(
              icon: Icons.arrow_back_ios_new,
              onPressed: () => Navigator.pop(context),
              color: theme.colorScheme.onSurface,
              backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
            ),
            
            Row(
              children: [
                _buildIconButton(
                  icon: Icons.favorite_border,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('收藏功能开发中', style: TextStyle(color: theme.colorScheme.onSurface)),
                        backgroundColor: theme.colorScheme.surfaceVariant,
                      ),
                    );
                  },
                  color: theme.colorScheme.onSurface,
                  backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                ),
                const SizedBox(width: 12),
                _buildIconButton(
                  icon: Icons.ios_share,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('分享功能开发中', style: TextStyle(color: theme.colorScheme.onSurface)),
                        backgroundColor: theme.colorScheme.surfaceVariant,
                      ),
                    );
                  },
                  color: theme.colorScheme.onSurface,
                  backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    Color? backgroundColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color),
        padding: EdgeInsets.zero,
      ),
    );
  }
  
  Widget _buildHeroImageCarousel(StarProduct product, ThemeData theme) {
    final List<Map<String, dynamic>> mediaItems = [];
    
    mediaItems.add({'type': 'image', 'url': product.image});
    
    for (var imageUrl in product.mainImages) {
      if (imageUrl.isNotEmpty) {
        mediaItems.add({'type': 'image', 'url': imageUrl});
      }
    }
    
    if (product.video != null && product.video!.isNotEmpty) {
      mediaItems.add({
        'type': 'video', 
        'url': product.video!,
        'cover': product.videoCover
      });
    }
    
    if (mediaItems.isEmpty) {
      mediaItems.add({'type': 'image', 'url': ''});
    }

    return SizedBox(
      width: double.infinity,
      height: carouselHeight,
      child: _buildCarouselStack(mediaItems, theme),
    );
  }
  
  Widget _buildCarouselStack(List<Map<String, dynamic>> mediaItems, ThemeData theme) {
     return MouseRegion(
       cursor: SystemMouseCursors.resizeLeftRight,
       child: Stack(
         children: [
           _buildBasicPageView(mediaItems, theme),
           _buildBottomIndicators(mediaItems, theme),
         ],
       ),
     );
   }
   
   Widget _buildBasicPageView(List<Map<String, dynamic>> mediaItems, ThemeData theme) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 针对Windows平台添加鼠标拖动支持
        onPanStart: (details) {
          _startDragPosition = details.globalPosition.dx;
          _startDragIndex = _currentImageIndex;
          _initialOffset = _pageController.offset;
        },
        onPanUpdate: (details) {
          // 实时更新拖动位置
          final delta = details.globalPosition.dx - _startDragPosition;
          // 手动控制PageView滚动
          _pageController.jumpTo(
            _initialOffset - delta,
          );
        },
        onPanEnd: (details) {
          final velocity = details.velocity.pixelsPerSecond.dx;
          
          // 基于拖动后的位置和速度判断是否切换页面
          final currentPage = _pageController.page ?? _startDragIndex.toDouble();
          
          if (velocity.abs() > 500) {
            // 基于速度切换页面
            if (velocity < 0 && _startDragIndex < mediaItems.length - 1) {
              _pageController.animateToPage(
                _startDragIndex + 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else if (velocity > 0 && _startDragIndex > 0) {
              _pageController.animateToPage(
                _startDragIndex - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              _pageController.animateToPage(
                _startDragIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } else {
            // 基于当前页面位置切换
            final targetPage = currentPage.round();
            _pageController.animateToPage(
              targetPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: mediaItems.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
            _resetAutoPlay();
            _handlePageChanged(index);
          },
          // 禁用默认滚动，使用自定义拖动逻辑
          physics: const NeverScrollableScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final mediaItem = mediaItems[index];
            
            if (mediaItem['type'] == 'image') {
              return _buildImageSlide(mediaItem, theme);
            } else {
              return _buildVideoSlide(mediaItem, theme);
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildPageViewWithMouseDrag(List<Map<String, dynamic>> mediaItems, ThemeData theme) {
     return GestureDetector(
       onHorizontalDragStart: (details) {
         _startDragPosition = details.globalPosition.dx;
         _startDragIndex = _currentImageIndex;
       },
       onHorizontalDragEnd: (details) {
         final dragPosition = details.globalPosition.dx;
         final dragDelta = dragPosition - _startDragPosition;
         
         if (dragDelta.abs() > 50) {
           if (dragDelta > 0) {
             if (_startDragIndex > 0) {
               _pageController.animateToPage(
                 _startDragIndex - 1,
                 duration: const Duration(milliseconds: 300),
                 curve: Curves.easeInOut,
               );
             }
           } else {
             if (_startDragIndex < mediaItems.length - 1) {
               _pageController.animateToPage(
                 _startDragIndex + 1,
                 duration: const Duration(milliseconds: 300),
                 curve: Curves.easeInOut,
               );
             }
           }
         }
       },
       child: PageView.builder(
         controller: _pageController,
         itemCount: mediaItems.length,
         onPageChanged: (index) {
           setState(() {
             _currentImageIndex = index;
           });
           _resetAutoPlay();
           _handlePageChanged(index);
         },
         physics: const NeverScrollableScrollPhysics(),
         scrollDirection: Axis.horizontal,
         itemBuilder: (context, index) {
           final mediaItem = mediaItems[index];
           
           if (mediaItem['type'] == 'image') {
             return _buildImageSlide(mediaItem, theme);
           } else {
             return _buildVideoSlide(mediaItem, theme);
           }
         },
       ),
     );
   }
  
  Widget _buildImageSlide(Map<String, dynamic> mediaItem, ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      color: theme.colorScheme.surface,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isImagePreviewVisible = true;
            _previewImageIndex = _currentImageIndex;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Image(
          image: ImageLoaderService.getImageProvider(mediaItem['url']),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
  
  Widget _buildVideoSlide(Map<String, dynamic> mediaItem, ThemeData theme) {
    final videoUrl = mediaItem['url'];
    
    return _buildVideoPlayerWithInitialization(videoUrl, theme);
  }
  
  Widget _buildVideoPlayerWithInitialization(String videoUrl, ThemeData theme) {
    final controller = _videoControllers[videoUrl];
    
    if (controller != null && controller.value.isInitialized) {
      return _buildVideoPlayer(controller, videoUrl, theme);
    }
    
    if (controller == null) {
      _initializeVideoController(videoUrl);
      return Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        color: theme.colorScheme.surface,
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }
    
    if (controller.value.hasError) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        color: theme.colorScheme.surface,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 8),
            Text('加载失败', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _videoControllers.remove(videoUrl);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: Text('重试', style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ],
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      color: theme.colorScheme.surface,
      child: CircularProgressIndicator(color: theme.colorScheme.primary),
    );
  }
  
  Widget _buildVideoPlayer(VideoPlayerController controller, String videoUrl, ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      color: theme.colorScheme.surface,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showVideoControls = !_showVideoControls;
                });
                // 直接切换播放状态，不依赖URL查找
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
                setState(() {});
              },
              child: AnimatedOpacity(
                opacity: _showVideoControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 28,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showVideoControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildVideoControls(controller, theme),
            ),
          ),
        ],
      ),
    );
  }
  
  double get carouselHeight => 400.0;
   
   Widget _buildGradientOverlay(ThemeData theme) {
     return Container(
       width: double.infinity,
       height: carouselHeight,
       decoration: BoxDecoration(
         gradient: LinearGradient(
           begin: Alignment.topCenter,
           end: Alignment.bottomCenter,
           colors: [
             Colors.transparent,
             Colors.transparent,
             theme.scaffoldBackgroundColor.withOpacity(0.8),
           ],
         ),
       ),
       child: const IgnorePointer(ignoring: true),
     );
   }
   
   Widget _buildBottomIndicators(List<Map<String, dynamic>> mediaItems, ThemeData theme) {
     return Positioned(
       bottom: 8,
       left: 0,
       right: 0,
       child: Center(
         child: Wrap(
           alignment: WrapAlignment.center,
           crossAxisAlignment: WrapCrossAlignment.center,
           children: [
             for (int i = 0; i < mediaItems.length; i++)
               GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _currentImageIndex ? theme.colorScheme.primary : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
             const SizedBox(width: 12),
             GestureDetector(
               onTap: _toggleAutoPlay,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.black.withOpacity(0.3),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(
                       _isAutoPlayEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                       size: 14,
                       color: Colors.white,
                     ),
                     const SizedBox(width: 3),
                     Text(
                       _isAutoPlayEnabled ? '自动' : '手动',
                       style: TextStyle(
                         color: Colors.white,
                         fontSize: 10,
                         fontWeight: FontWeight.bold,
                       ),
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
  

  
  Widget _buildProductInfo(StarProduct product, ThemeData theme) {
    // 使用选中的SKU价格和库存，如果没有选中则使用商品默认值
    final currentPrice = _selectedSku?.price ?? product.price;
    final currentPoints = _selectedSku?.points ?? product.points;
    final currentStock = _selectedSku?.stock ?? product.stock;
    final currentHybridPrice = _selectedSku?.hybridPrice ?? (product.hybridPrice > 0 ? product.hybridPrice : currentPrice~/2);
    final currentHybridPoints = _selectedSku?.hybridPoints ?? (product.hybridPoints > 0 ? product.hybridPoints : currentPoints~/2);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 显示支持的支付方式价格
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主价格显示
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (product.supportCashPayment) ...[
                    Text(
                      '¥$currentPrice',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (product.supportCashPayment && product.supportPointsPayment) ...[
                    const SizedBox(width: 12),
                  ],
                  if (product.supportPointsPayment) ...[
                    Text(
                      '✨$currentPoints',
                      style: TextStyle(
                        color: const Color(0xFFffc107),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // 支持的其他支付方式
              if (product.supportHybridPayment) ...[
                Row(
                  children: [
                    Text(
                      '¥$currentHybridPrice + ✨$currentHybridPoints',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // 原价和会员价
              Row(
                children: [
                  Text(
                    '原价: ¥${product.originalPrice}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (product.memberPrice > 0 && product.memberPrice < currentPrice) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '会员价: ¥${product.memberPrice}',
                        style: TextStyle(
                          color: theme.colorScheme.onError,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '限时特惠',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            product.name,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '库存: $currentStock件',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (product.brand != null && product.brand!.isNotEmpty)
                  Text(
                    product.brand!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpecSelector(StarProduct product, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GestureDetector(
        onTap: () {
          _showSpecSelectorModal();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已选择',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedSpecs.isEmpty
                        ? product.name
                        : _formatSelectedSpecs(_selectedSpecs),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建支付方式选择器
  Widget _buildPaymentMethodSelector(StarProduct product, ThemeData theme) {
    // 过滤出商品支持的支付方式
    final availablePaymentMethods = <PaymentMethod>[];
    if (product.supportCashPayment) {
      availablePaymentMethods.add(PaymentMethod.cash);
    }
    if (product.supportPointsPayment) {
      availablePaymentMethods.add(PaymentMethod.points);
    }
    if (product.supportHybridPayment) {
      availablePaymentMethods.add(PaymentMethod.hybrid);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择支付方式',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: availablePaymentMethods.map((method) {
              String methodText;
              String methodIcon;
              
              switch (method) {
                case PaymentMethod.cash:
                  methodText = '现金支付';
                  methodIcon = '¥';
                  break;
                case PaymentMethod.points:
                  methodText = '积分支付';
                  methodIcon = '✨';
                  break;
                case PaymentMethod.hybrid:
                  methodText = '混合支付';
                  methodIcon = '✨+¥';
                  break;
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      methodIcon,
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      methodText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '支付方式将在支付对话框中最终选择',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGuaranteeServices(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildGuaranteeItem(
              icon: Icons.check_circle,
              text: '官方保障',
              theme: theme,
            ),
            const SizedBox(width: 24),
            _buildGuaranteeItem(
              icon: Icons.check_circle,
              text: '免费配送',
              theme: theme,
            ),
            const SizedBox(width: 24),
            _buildGuaranteeItem(
              icon: Icons.check_circle,
              text: '7天退货',
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGuaranteeItem({
    required IconData icon,
    required String text,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTabNavigation(StarProduct product, ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabItem(
            index: 0,
            title: '详情',
            isSelected: _selectedTabIndex == 0,
            onTap: () => _tabController.animateTo(0),
            theme: theme,
          ),
          const SizedBox(width: 24),
          _buildTabItem(
            index: 1,
            title: '评价',
            isSelected: _selectedTabIndex == 1,
            onTap: () => _tabController.animateTo(1),
            theme: theme,
          ),
          const SizedBox(width: 24),
          _buildTabItem(
            index: 2,
            title: '推荐',
            isSelected: _selectedTabIndex == 2,
            onTap: () => _tabController.animateTo(2),
            theme: theme,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabItem({
    required int index,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 32,
              height: 2,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTabContent(StarProduct product, ThemeData theme) {
    return SizedBox(
      height: 800,
      child: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildDetailsContent(product, theme),
          _buildReviewsContent(product, theme),
          _buildRecommendContent(product, theme),
        ],
      ),
    );
  }
  
  Widget _buildDetailsContent(StarProduct product, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.description != null && product.description!.isNotEmpty) ...[
            Text(
              product.description!,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          if (product.detailImages != null && product.detailImages.isNotEmpty) ...[
            for (var imageUrl in product.detailImages) 
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image(
                    image: ImageLoaderService.getImageProvider(imageUrl),
                    width: double.infinity,
                    height: 400,
                    fit: BoxFit.contain,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: child,
                      );
                    },
                  ),
                ),
              ),
          ] else if (product.image != null && product.image!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: ImageLoaderService.getImageProvider(product.image),
                  width: double.infinity,
                  height: 400,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  Widget _buildSpecRow({
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewsContent(StarProduct product, ThemeData theme) {
    if (_isReviewsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF13ec5b)),
      );
    }
    
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无评价',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewItem(review, theme);
      },
    );
  }
  
  /// 构建评价项
  Widget _buildReviewItem(Map<String, dynamic> review, ThemeData theme) {
    // 解析评价图片
    List<String> images = [];
    final dynamic imagesValue = review['images'];
    if (imagesValue != null) {
      if (imagesValue is List<dynamic>) {
        images = imagesValue.cast<String>();
      } else if (imagesValue is String && imagesValue.isNotEmpty && imagesValue != '[]') {
        try {
          images = List<String>.from(json.decode(imagesValue));
        } catch (e) {
          debugPrint('Failed to parse images: $e');
        }
      }
    }
    
    // 解析追加评价图片
    List<String> appendedImages = [];
    final dynamic appendedImagesValue = review['appended_images'];
    if (appendedImagesValue != null) {
      if (appendedImagesValue is List<dynamic>) {
        appendedImages = appendedImagesValue.cast<String>();
      } else if (appendedImagesValue is String && appendedImagesValue.isNotEmpty && appendedImagesValue != '[]') {
        try {
          appendedImages = List<String>.from(json.decode(appendedImagesValue));
        } catch (e) {
          debugPrint('Failed to parse appended images: $e');
        }
      }
    }
    
    // 根据匿名状态获取用户信息
    final bool isAnonymous = (review['is_anonymous'] ?? 1) == 1;
    final String userNickname = isAnonymous ? '匿名用户' : (review['user_name'] ?? '用户');
    final String userAvatar = isAnonymous ? 'https://via.placeholder.com/150' : (review['user_avatar'] ?? 'https://via.placeholder.com/150');
    
    // 选择正确的ImageProvider
    ImageProvider getAvatarImageProvider(String avatarUrl) {
      if (avatarUrl.startsWith('http')) {
        return NetworkImage(avatarUrl);
      } else {
        // 本地文件路径，使用FileImage
        return FileImage(File(avatarUrl));
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评价头部：用户头像、昵称、评分、时间
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey,
                    ),
                    child: ClipOval(
                      child: Image(
                        image: getAvatarImageProvider(userAvatar),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              userNickname.substring(0, 1),
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userNickname,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          ...List.generate(5, (i) {
                            return Icon(
                              i < (review['rating'] ?? 5) ? Icons.star : Icons.star_border,
                              color: const Color(0xFFffc107),
                              size: 14,
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            DateTime.fromMillisecondsSinceEpoch(review['created_at']).toString().substring(0, 16),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 评价内容
          Text(
            review['content'] ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          
          // 评价图片缩略图
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GridView.count(
                crossAxisCount: 8, // 增加列数，进一步减小图像大小
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.0, // 确保图像为正方形
                children: images.map((imageUrl) {
                  return GestureDetector(
                    onTap: () {
                      // 点击图片放大查看
                      _showImageViewer(context, imageUrl, 0, images);
                    },
                    child: Container(
                      width: 40, // 设置更小的固定宽度
                      height: 40, // 设置更小的固定高度
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey,
                        image: DecorationImage(
                          image: (imageUrl.startsWith('http') ? NetworkImage(imageUrl) : FileImage(File(imageUrl))) as ImageProvider<Object>,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
          // 追加评价
          if (review['appended_content'] != null && (review['appended_content'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '追加评价:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    review['appended_content'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  
                  // 追加评价图片
                  if (appendedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GridView.count(
                        crossAxisCount: 8, // 增加列数，进一步减小图像大小
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.0, // 确保图像为正方形
                        children: appendedImages.map((imageUrl) {
                          return GestureDetector(
                            onTap: () {
                              // 点击图片放大查看
                              _showImageViewer(context, imageUrl, 0, appendedImages);
                            },
                            child: Container(
                              width: 40, // 设置更小的固定宽度
                              height: 40, // 设置更小的固定高度
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey,
                                image: DecorationImage(
                                  image: (imageUrl.startsWith('http') ? NetworkImage(imageUrl) : FileImage(File(imageUrl))) as ImageProvider<Object>,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            
          // 商家回复
          if (review['seller_reply'] != null && (review['seller_reply'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '商家回复:',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review['seller_reply'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    if (review['seller_reply_at'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateTime.fromMillisecondsSinceEpoch(review['seller_reply_at']).toString().substring(0, 16),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // 商家回复
          if (review['seller_reply'] != null && (review['seller_reply'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '商家回复:',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      review['seller_reply'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendContent(StarProduct product, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.recommend,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无推荐',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomActionBar(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
          ),
        ),
        child: Row(
          children: [
            Row(
              children: [
                _buildBottomIcon(
                  icon: Icons.storefront,
                  label: '商店',
                  isSelected: false,
                  theme: theme,
                  onPressed: () {
                    // 返回星星商店页面
                    Navigator.popUntil(context, (route) {
                      return route.settings.name == '/star_exchange';
                    });
                  },
                ),
                const SizedBox(width: 24),
                _buildBottomIcon(
                  icon: Icons.chat_bubble_outline,
                  label: '客服',
                  isSelected: false,
                  theme: theme,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('客服功能开发中', style: TextStyle(color: theme.colorScheme.onSurface)),
                        backgroundColor: theme.colorScheme.surfaceVariant,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 24),
                _buildBottomIcon(
                  icon: Icons.shopping_cart_outlined,
                  label: '购物车',
                  isSelected: false,
                  theme: theme,
                  onPressed: () async {
                    final databaseService = DatabaseService();
                    final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShoppingCartPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(width: 20),
            
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final product = widget.product;
                        if (product.stock <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('商品库存不足，无法加入购物车', style: TextStyle(color: theme.colorScheme.onSurface)),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                            ),
                          );
                          return;
                        }
                        
                        final databaseService = DatabaseService();
                        final cartDatabaseService = CartDatabaseService();
                        final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                        await cartDatabaseService.addToCart(product, 1, userId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已加入购物车', style: TextStyle(color: theme.colorScheme.onSurface)),
                            backgroundColor: theme.colorScheme.surfaceVariant,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        '加入购物车',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // 弹出支付对话框
                        _showPaymentDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 4,
                        shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                      child: Text(
                        '立即购买',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
  
  Widget _buildBottomIcon({
    required IconData icon,
    required String label,
    required bool isSelected,
    int? badgeCount,
    required ThemeData theme,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Stack(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: TextStyle(
                        color: theme.colorScheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImagePreview(StarProduct product, ThemeData theme) {
    final List<String> images = [
      product.image,
      ...((product.mainImages ?? []) as List<dynamic>).map((image) => image.toString()),
    ].where((image) => image.isNotEmpty).toList();
    
    if (images.isEmpty) {
      images.add('');
    }
    
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: _previewImageIndex),
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _previewImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image(
                    image: ImageLoaderService.getImageProvider(images[index]),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            },
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isImagePreviewVisible = false;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.close,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < images.length; i++)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _previewImageIndex = i;
                      });
                    },
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i == _previewImageIndex ? theme.colorScheme.primary : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          GestureDetector(
            onTap: () {
              setState(() {
                _isImagePreviewVisible = false;
              });
            },
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
  


  /// 显示支付对话框
  void _showPaymentDialog() {
    final product = widget.product;
    
    // 使用新的支付对话框组件
    showPaymentDialog(
      context: context,
      product: product,
      selectedSpecs: _selectedSpecs,
      selectedSku: _selectedSku,
    );
  }



  void _showSpecSelectorModal() {
    final product = widget.product;
    
    // 如果商品没有规格，显示提示
    if (product.specs?.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该商品暂无规格选择')),
      );
      return;
    }
    
    // 创建一个临时变量来存储选中的规格，避免直接修改状态
    final Map<String, String> tempSelectedSpecs = Map.from(_selectedSpecs);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF102216),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 根据当前选中的规格匹配对应的SKU
            StarProductSku? matchedSku;
            if (tempSelectedSpecs.length == (product.specs?.length ?? 0) && product.skus != null) {
              for (final sku in product.skus!) {
                if (_isSkuMatchSpecs(sku, tempSelectedSpecs)) {
                  matchedSku = sku;
                  break;
                }
              }
            }
            
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  // 模态框头部
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '选择规格',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  
                  // 商品信息
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFF1e3626),
                          ),
                          child: product.image.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: product.image,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(product.image),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // 价格显示，使用匹配到的SKU价格，如果没有匹配到则使用商品默认价格
                              Text(
                                product.supportCashPayment
                                    ? '¥${matchedSku?.price ?? product.price}'
                                    : '',
                                style: const TextStyle(
                                  color: Color(0xFF13ec5b),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (product.supportPointsPayment)
                                Text(
                                  '✨${matchedSku?.points ?? product.points}',
                                  style: const TextStyle(
                                    color: const Color(0xFFffc107),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              // 库存显示
                              Text(
                                '库存: ${matchedSku?.stock ?? product.stock}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 规格选择区域
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (product.specs ?? []).map((spec) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  spec.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: spec.values.map((value) {
                                    final isSelected = tempSelectedSpecs[spec.name] == value;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          tempSelectedSpecs[spec.name] = value;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF13ec5b)
                                              : const Color(0xFF1e3626),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF13ec5b)
                                                : Colors.white24,
                                          ),
                                        ),
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  
                  // 底部确认按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () {
                        // 确认选择，更新状态
                        setState(() {
                          _selectedSpecs = Map.from(tempSelectedSpecs);
                          _selectedSku = matchedSku;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13ec5b),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '确认选择',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  /// 检查SKU是否匹配选中的规格
  bool _isSkuMatchSpecs(StarProductSku sku, Map<String, String> selectedSpecs) {
    for (final entry in selectedSpecs.entries) {
      final specName = entry.key;
      final specValue = entry.value;
      if (sku.specValues[specName] != specValue) {
        return false;
      }
    }
    return true;
  }
  
  /// 格式化选中的规格为可读字符串
  String _formatSelectedSpecs(Map<String, String> selectedSpecs) {
    return selectedSpecs.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('; ');
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
                    image: (initialImageUrl.startsWith('http') ? NetworkImage(initialImageUrl) : FileImage(File(initialImageUrl))) as ImageProvider<Object>,
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
                    color: AppTheme.currentTheme.primaryColor,
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


} 