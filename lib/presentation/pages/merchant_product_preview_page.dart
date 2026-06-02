import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';

class MerchantProductPreviewPage extends StatefulWidget {
  const MerchantProductPreviewPage({super.key, required this.product});
  
  final StarProduct product;

  @override
  State<MerchantProductPreviewPage> createState() => _MerchantProductPreviewPageState();
}

class _MerchantProductPreviewPageState extends State<MerchantProductPreviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  int _currentImageIndex = 0;
  late PageController _pageController;
  bool _isImagePreviewVisible = false;
  int _previewImageIndex = 0;
  Map<String, VideoPlayerController> _videoControllers = {};
  String? _currentPlayingVideoUrl;
  bool _isVideoMuted = true;
  bool _showVideoControls = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    
    _pageController = PageController(viewportFraction: 1.0);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
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
  
  Widget _buildVideoControls(VideoPlayerController controller) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            },
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            iconSize: 24,
          ),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Color(0x4DFFFFFF),
                backgroundColor: Color(0x1AFFFFFF),
              ),
              padding: EdgeInsets.zero,
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
              color: Colors.white,
            ),
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      extendBody: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImageCarousel(product),
            _buildProductInfo(product),
            _buildMerchantSpecificInfo(product),
            Container(height: 8, color: theme.colorScheme.outline.withOpacity(0.1)),
            _buildTabNavigation(),
            _buildTabContent(product),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 返回上一页
          Navigator.pop(context);
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.edit),
        label: Text('返回编辑', style: TextStyle(color: theme.colorScheme.onPrimary)),
      ),
    );
  }
  
  Widget _buildTopNavigation() {
    final theme = Theme.of(context);
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
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        padding: EdgeInsets.zero,
      ),
    );
  }
  
  Widget _buildHeroImageCarousel(StarProduct product) {
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
      height: 400,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: mediaItems.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
              _handlePageChanged(index);
            },
            itemBuilder: (context, index) {
              final mediaItem = mediaItems[index];
              
              if (mediaItem['type'] == 'image') {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  color: Colors.black,
                  child: Image(
                    image: ImageLoaderService.getImageProvider(mediaItem['url']),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              } else {
                final videoUrl = mediaItem['url'];
                final controller = _videoControllers[videoUrl];
                
                if (controller != null && controller.value.isInitialized) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: _buildVideoControls(controller),
                      ),
                    ],
                  );
                }
                
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  color: Colors.black,
                  child: const CircularProgressIndicator(),
                );
              }
            },
          ),
          Positioned(
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
                          color: i == _currentImageIndex ? const Color(0xFF13ec5b) : const Color(0x80FFFFFF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildTopNavigation(),
        ],
      ),
    );
  }
  
  Widget _buildProductInfo(StarProduct product) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品名称
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
          
          // 价格显示
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (product.supportCashPayment) ...[
                Text(
                  '¥${product.price}',
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
                  '✨${product.points}',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 原价
          if (product.originalPrice > 0 && product.originalPrice > product.price) ...[
            Text(
              '原价: ¥${product.originalPrice}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // 品牌
          if (product.brand != null && product.brand!.isNotEmpty) ...[
            Text(
              '品牌: ${product.brand}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // 分类
          if (product.categoryPath != null && product.categoryPath!.isNotEmpty) ...[
            Text(
              '分类: ${product.categoryPath}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMerchantSpecificInfo(StarProduct product) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '商家信息',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 库存
            _buildInfoRow('库存', '${product.stock}件', theme),
            
            // 状态
            _buildInfoRow('状态', _getStatusText(product.status), theme),
            
            // 销量
            _buildInfoRow('总销量', '${product.totalSales}件', theme),
            
            // 7天销量
            _buildInfoRow('7天销量', '${product.sales7Days}件', theme),
            
            // 访客数
            _buildInfoRow('访客数', '${product.visitors}人', theme),
            
            // 转化率
            _buildInfoRow('转化率', '${product.conversionRate}%', theme),
            
            // 上架时间
            if (product.releaseTime != null) ...[
              _buildInfoRow('上架时间', product.releaseTime!.toString(), theme),
            ],
            
            // 支付方式
            _buildInfoRow('支持支付方式', _getPaymentMethodsText(product), theme),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  

  
  Widget _buildTabNavigation() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabItem(
            index: 0,
            title: '商品详情',
            isSelected: _selectedTabIndex == 0,
            onTap: () => _tabController.animateTo(0),
            theme: theme,
          ),
          const SizedBox(width: 24),
          _buildTabItem(
            index: 1,
            title: '规格信息',
            isSelected: _selectedTabIndex == 1,
            onTap: () => _tabController.animateTo(1),
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
  
  Widget _buildTabContent(StarProduct product) {
    return SizedBox(
      height: 600,
      child: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildDetailsContent(product),
          _buildSpecsContent(product),
        ],
      ),
    );
  }
  
  Widget _buildDetailsContent(StarProduct product) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.description != null && product.description!.isNotEmpty) ...[
            Text(
              '商品描述',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.description!,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          if (product.detailImages != null && product.detailImages.isNotEmpty) ...[
            Text(
              '商品图片',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (var imageUrl in product.detailImages) 
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSpecsContent(StarProduct product) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.skus != null && product.skus!.isNotEmpty) ...[
            Text(
              'SKU规格',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (var sku in product.skus!) 
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sku.skuCode,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '价格: ¥${sku.price} | 积分: ${sku.points}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '库存: ${sku.stock}件',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          
          if (product.specs != null && product.specs!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '商品规格',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (var spec in product.specs!) 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        spec.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        spec.values.join(', '),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return '草稿';
      case 'pending':
        return '审核中';
      case 'approved':
        return '审核通过';
      case 'active':
        return '已上架';
      case 'inactive':
        return '已下架';
      case 'rejected':
        return '已拒绝';
      case 'violated':
        return '违规';
      case 'deleted':
        return '已删除';
      default:
        return status;
    }
  }
  
  String _getPaymentMethodsText(StarProduct product) {
    final List<String> methods = [];
    if (product.supportCashPayment) {
      methods.add('现金');
    }
    if (product.supportPointsPayment) {
      methods.add('积分');
    }
    if (product.supportHybridPayment) {
      methods.add('混合');
    }
    return methods.join('、');
  }
}
